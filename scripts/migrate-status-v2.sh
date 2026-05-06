#!/usr/bin/env bash
# scripts/migrate-status-v2.sh — phase-aware v1->v2 status migration.
#
# Converts a project's `.scrum/` from the legacy 6-value `backlog.json.status`
# + 10-value `pbi-state.json.phase` model to the unified 12-value status enum
# defined in PBI-A. After migration:
#   - backlog.json.items[].status holds one of the 12 new values
#   - pbi-state.json no longer carries `phase` (key deleted)
#
# This complements the existing scripts/scrum/migrate-legacy.sh:
#   - migrate-legacy.sh handles structural drift (.pbis -> .items, lowercasing,
#     etc.) and a conservative phase-blind status remap.
#   - migrate-status-v2.sh (this script) does the precise phase-aware mapping
#     that requires reading per-PBI state.json files.
#
# Mapping table (Plan PBI-G Step 2):
#   draft|refined|done                              -> same
#   blocked + phase=escalated                       -> escalated
#   blocked (other)                                 -> blocked
#   in_progress + phase=design                      -> in_progress_design
#   in_progress + phase=impl_ut                     -> in_progress_impl
#   review + phase=complete                         -> in_progress_pbi_review
#   review + phase=ready_to_merge                   -> in_progress_merge
#   review + phase=merged                           -> awaiting_cross_review
#   review + phase=merge_conflict
#         |merge_artifact_missing
#         |merge_regression                         -> escalated
#   review + phase=review_complete                  -> done
# Anything outside the table aborts with an error so a human can review.
#
# Usage: scripts/migrate-status-v2.sh [--dry-run]
# Operates on `.scrum/` in $PWD. A timestamped backup is written to
# `.scrum/backups/migrate-v2-<timestamp>/` before any file is rewritten.

set -euo pipefail

DRY_RUN=0
case "${1:-}" in
  --dry-run|-n) DRY_RUN=1 ;;
  "")           : ;;
  -h|--help)
    grep '^# ' "$0" | sed 's/^# //'
    exit 0
    ;;
  *)
    echo "usage: $0 [--dry-run]" >&2
    exit 64
    ;;
esac

SCRUM_DIR=".scrum"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ ! -d "$SCRUM_DIR" ]; then
  echo "No .scrum/ directory in $PWD - nothing to migrate."
  exit 0
fi

if [ ! -f "$SCRUM_DIR/backlog.json" ]; then
  echo "No $SCRUM_DIR/backlog.json - nothing to migrate."
  exit 0
fi

# Locate v2 schemas (source repo or target project layout).
SCHEMA_DIR=""
for candidate in \
  "$SCRIPT_DIR/../docs/contracts/scrum-state" \
  "$PWD/docs/contracts/scrum-state"; do
  if [ -d "$candidate" ]; then
    SCHEMA_DIR="$(cd "$candidate" && pwd)"
    break
  fi
done
if [ -z "$SCHEMA_DIR" ]; then
  echo "Error: scrum-state schemas not found (looked beside this script and under \$PWD/docs/contracts/scrum-state)" >&2
  exit 67
fi

iso_now() { date -u +"%Y-%m-%dT%H:%M:%SZ"; }
NOW="$(iso_now)"
TIMESTAMP_TAG="$(date -u +"%Y%m%dT%H%M%SZ")"
BACKUP_DIR="$SCRUM_DIR/backups/migrate-v2-$TIMESTAMP_TAG"

# fail <msg> — abort migration with a human-readable error.
fail() {
  echo "ERROR: $*" >&2
  exit 65
}

# derive_v2_status <old_status> [old_phase]
# Echoes the new 12-value status. Aborts the script on non-mappable inputs.
derive_v2_status() {
  local old_status="$1"
  local old_phase="${2:-}"
  case "$old_status" in
    draft|refined|done)
      echo "$old_status"
      ;;
    blocked)
      if [ "$old_phase" = "escalated" ]; then
        echo "escalated"
      else
        echo "blocked"
      fi
      ;;
    in_progress)
      case "$old_phase" in
        design)  echo "in_progress_design" ;;
        impl_ut) echo "in_progress_impl" ;;
        *)       fail "non-mappable: status=in_progress, phase=${old_phase:-<missing>}" ;;
      esac
      ;;
    review)
      case "$old_phase" in
        complete)        echo "in_progress_pbi_review" ;;
        ready_to_merge)  echo "in_progress_merge" ;;
        merged)          echo "awaiting_cross_review" ;;
        merge_conflict|merge_artifact_missing|merge_regression)
                         echo "escalated" ;;
        review_complete) echo "done" ;;
        *)               fail "non-mappable: status=review, phase=${old_phase:-<missing>}" ;;
      esac
      ;;
    # New-schema values pass through (idempotency for partially-migrated state).
    in_progress_design|in_progress_impl|in_progress_pbi_review|in_progress_ut_run|in_progress_merge|awaiting_cross_review|cross_review|escalated)
      echo "$old_status"
      ;;
    *)
      fail "unknown old status: $old_status"
      ;;
  esac
}

# Locate a JSON-schema validator. Mirrors scripts/scrum/lib/check-validator.sh
# logic in a self-contained form (this script is scripts/-level, not under
# scripts/scrum/, so we don't source the library to keep the dependency
# surface small).
detect_validator() {
  if [ -n "${SCRUM_VALIDATOR_OVERRIDE:-}" ]; then
    echo "$SCRUM_VALIDATOR_OVERRIDE"
    return 0
  fi
  if command -v check-jsonschema >/dev/null 2>&1; then
    echo "check-jsonschema"; return 0
  fi
  if command -v jsonschema >/dev/null 2>&1; then
    echo "jsonschema-cli"; return 0
  fi
  if python3 -c "import jsonschema" >/dev/null 2>&1; then
    echo "python"; return 0
  fi
  if command -v npx >/dev/null 2>&1; then
    echo "ajv"; return 0
  fi
  echo "none"
}

VALIDATOR="$(detect_validator)"

validate_json() {
  local json_path="$1" schema_path="$2"
  case "$VALIDATOR" in
    ajv)
      npx --yes ajv-cli validate --strict=false -s "$schema_path" -d "$json_path" >/dev/null 2>&1
      ;;
    check-jsonschema)
      check-jsonschema --schemafile "$schema_path" "$json_path" >/dev/null 2>&1
      ;;
    jsonschema-cli)
      jsonschema --instance "$json_path" "$schema_path" >/dev/null 2>&1
      ;;
    python)
      python3 - "$json_path" "$schema_path" <<'PY' >/dev/null 2>&1
import json, sys, jsonschema
data = json.load(open(sys.argv[1]))
schema = json.load(open(sys.argv[2]))
jsonschema.validate(data, schema)
PY
      ;;
    none|*)
      # No validator available: skip strict validation (caller still gets
      # jq-level structural checks). Print a warning once.
      if [ -z "${_VALIDATOR_WARNED:-}" ]; then
        echo "  warn: no JSON-schema validator on PATH; skipping strict validation" >&2
        _VALIDATOR_WARNED=1
      fi
      return 0
      ;;
  esac
}

# atomic_write_jq <path> <jq_expr> <schema_path>
# Writes jq <expr> applied to <path> back to <path> atomically (tmp+mv) under
# a directory lock. Validates against <schema_path> first.
atomic_write_jq() {
  local path="$1" expr="$2" schema="$3"
  local lock_dir
  lock_dir="$SCRUM_DIR/.locks/$(basename "$path").lock.d"
  local tmp="${path}.tmp.$$.${RANDOM}"

  mkdir -p "$SCRUM_DIR/.locks"
  local i=0 max=200
  while ! mkdir "$lock_dir" 2>/dev/null; do
    i=$((i + 1))
    [ "$i" -ge "$max" ] && fail "lock timeout: $lock_dir"
    sleep 0.05
  done
  # shellcheck disable=SC2064
  trap "rmdir '$lock_dir' 2>/dev/null || true; rm -f '$tmp' 2>/dev/null || true" RETURN

  if ! jq --arg now "$NOW" "$expr" "$path" > "$tmp"; then
    fail "jq failed on $path"
  fi
  if ! validate_json "$tmp" "$schema"; then
    fail "validation failed for $path against $(basename "$schema")"
  fi
  mv "$tmp" "$path"
  rmdir "$lock_dir" 2>/dev/null || true
  trap - RETURN
}

# read_phase <state_path>
# Echoes the phase string from a legacy pbi-state.json. Empty string if the
# file lacks the key or doesn't exist.
read_phase() {
  local p="$1"
  [ -f "$p" ] || { echo ""; return 0; }
  jq -r '.phase // ""' "$p" 2>/dev/null || echo ""
}

# --- Main ---

echo "v1->v2 status migration in $SCRUM_DIR (schemas: $SCHEMA_DIR)"
[ "$DRY_RUN" = 1 ] && echo "  (dry-run; no files written)"

# Step 1: enumerate PBIs and decide new status for each.
mapfile -t PBI_IDS < <(jq -r '.items[].id' "$SCRUM_DIR/backlog.json")

declare -a MAPPING_LINES=()
for pbi_id in "${PBI_IDS[@]}"; do
  old_status="$(jq -r --arg id "$pbi_id" '.items[] | select(.id==$id) | .status' "$SCRUM_DIR/backlog.json")"
  state_path="$SCRUM_DIR/pbi/$pbi_id/state.json"
  old_phase="$(read_phase "$state_path")"
  new_status="$(derive_v2_status "$old_status" "$old_phase")"
  MAPPING_LINES+=("$pbi_id|$old_status|$old_phase|$new_status")
  printf '  %-12s old=%-12s phase=%-22s -> new=%s\n' \
    "$pbi_id" "$old_status" "${old_phase:-<none>}" "$new_status"
done

if [ "$DRY_RUN" = 1 ]; then
  echo "(dry-run) no files written. Run without --dry-run to apply."
  exit 0
fi

# Step 2: backup before any mutation.
mkdir -p "$BACKUP_DIR/pbi"
cp "$SCRUM_DIR/backlog.json" "$BACKUP_DIR/backlog.json"
for pbi_id in "${PBI_IDS[@]}"; do
  src="$SCRUM_DIR/pbi/$pbi_id/state.json"
  if [ -f "$src" ]; then
    mkdir -p "$BACKUP_DIR/pbi/$pbi_id"
    cp "$src" "$BACKUP_DIR/pbi/$pbi_id/state.json"
  fi
done
echo "  backup: $BACKUP_DIR"

# Step 3: rewrite backlog.json with new status values.
# Build a jq filter that reduces over a JSON-encoded mapping array.
mapping_json="["
first=1
for line in "${MAPPING_LINES[@]}"; do
  IFS='|' read -r mid _mold _mphase mnew <<<"$line"
  [ "$first" = 1 ] || mapping_json+=','
  first=0
  mapping_json+="{\"id\":\"$mid\",\"new\":\"$mnew\"}"
done
mapping_json+="]"

# shellcheck disable=SC2016  # $mapping/$m are jq variables, not shell.
BACKLOG_EXPR='
  ($mapping | from_entries) as $m
  | .items |= map(
      if $m[.id] then .status = $m[.id] else . end
    )
'
# from_entries needs {key,value}; rebuild mapping accordingly.
mapping_kv="["
first=1
for line in "${MAPPING_LINES[@]}"; do
  IFS='|' read -r mid _mold _mphase mnew <<<"$line"
  [ "$first" = 1 ] || mapping_kv+=','
  first=0
  mapping_kv+="{\"key\":\"$mid\",\"value\":\"$mnew\"}"
done
mapping_kv+="]"

# Inline the mapping via --argjson so the jq filter stays simple.
tmp_backlog="$SCRUM_DIR/backlog.json.tmp.$$"
jq --argjson mapping "$mapping_kv" "$BACKLOG_EXPR" "$SCRUM_DIR/backlog.json" > "$tmp_backlog"
if ! validate_json "$tmp_backlog" "$SCHEMA_DIR/backlog.schema.json"; then
  rm -f "$tmp_backlog"
  fail "post-migration backlog.json fails schema validation"
fi
mv "$tmp_backlog" "$SCRUM_DIR/backlog.json"
echo "  rewrote: $SCRUM_DIR/backlog.json"

# Step 4: strip phase key from every pbi-state.json.
for pbi_id in "${PBI_IDS[@]}"; do
  state_path="$SCRUM_DIR/pbi/$pbi_id/state.json"
  [ -f "$state_path" ] || continue
  if ! jq -e 'has("phase")' "$state_path" >/dev/null 2>&1; then
    echo "  ok: $state_path (no phase key)"
    continue
  fi
  # shellcheck disable=SC2016  # $now is a jq --arg variable, not shell.
  atomic_write_jq "$state_path" 'del(.phase) | .updated_at = $now' \
    "$SCHEMA_DIR/pbi-state.schema.json"
  echo "  stripped phase: $state_path"
done

echo ""
echo "v1->v2 migration complete. Backup at: $BACKUP_DIR"
