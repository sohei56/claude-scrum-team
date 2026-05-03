#!/usr/bin/env bash
# scripts/scrum/update-pbi-state.sh — variadic field=value setter for PBI pipeline state.
# Usage: update-pbi-state.sh <pbi-id> <field> <value> [<field> <value> ...]
#
# Mutates .scrum/pbi/<pbi-id>/state.json. All field/value pairs apply in a single
# atomic_write — one transaction, one schema validation, one mv. The schema's
# `additionalProperties: false` plus the local enum/integer checks here mean a
# single typo fails the whole batch (intentional).
#
# Writable fields (see docs/contracts/scrum-state/pbi-state.schema.json):
#   phase             design|impl_ut|complete|review_complete|escalated
#   design_round      integer >= 0
#   impl_round        integer >= 0
#   design_status     pending|in_review|fail|pass
#   impl_status       pending|in_review|fail|pass
#   ut_status         pending|in_review|fail|pass
#   coverage_status   pending|fail|pass
#   escalation_reason null|stagnation|divergence|max_rounds|budget_exhausted|
#                     requirements_unclear|coverage_tool_error|
#                     coverage_tool_unavailable|catalog_lock_timeout
#
# pbi_id, started_at, updated_at are NOT settable here.
# updated_at is auto-stamped by atomic_write.
#
# Side effect: when the batch sets `phase`, this script also projects the
# derived backlog.json items[].status (see lib/derive.sh) so the two SSOTs
# can never diverge. The projection is best-effort: missing backlog entry
# is not an error (PBI may not yet be in any sprint).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=lib/errors.sh
source "$HERE/lib/errors.sh"
# shellcheck source=lib/atomic.sh
source "$HERE/lib/atomic.sh"
# shellcheck source=lib/derive.sh
source "$HERE/lib/derive.sh"

[ "$#" -ge 3 ] || fail E_INVALID_ARG "usage: update-pbi-state.sh <pbi-id> <field> <value> [<field> <value> ...]"
PBI="$1"; shift
case "$PBI" in
  pbi-[0-9]*) ;;
  *) fail E_INVALID_ARG "bad pbi-id: $PBI" ;;
esac

PATHF=".scrum/pbi/$PBI/state.json"
[ -f "$PATHF" ] || fail E_FILE_MISSING "$PATHF (initialise via pbi-pipeline first)"

# Pair count must be even.
if [ $(( $# % 2 )) -ne 0 ]; then
  fail E_INVALID_ARG "field/value args must be paired (got odd count)"
fi

# Build the jq expression by accumulating per-pair sub-expressions. All field
# names and value literals below pass strict case-pattern whitelists, so direct
# interpolation is safe (no shell or jq injection risk).
EXPR="."
NEW_PHASE=""  # remembered for backlog.json projection below
while [ "$#" -ge 2 ]; do
  F="$1"; V="$2"; shift 2
  case "$F" in
    phase)
      case "$V" in
        design|impl_ut|complete|review_complete|escalated) ;;
        *) fail E_INVALID_ARG "bad phase: $V" ;;
      esac
      EXPR="$EXPR | .phase = \"$V\""
      NEW_PHASE="$V"
      ;;
    design_round|impl_round)
      case "$V" in
        ''|*[!0-9]*) fail E_INVALID_ARG "$F must be non-negative integer (got: $V)" ;;
      esac
      EXPR="$EXPR | .$F = $V"
      ;;
    design_status|impl_status|ut_status)
      case "$V" in
        pending|in_review|fail|pass) ;;
        *) fail E_INVALID_ARG "bad $F: $V" ;;
      esac
      EXPR="$EXPR | .$F = \"$V\""
      ;;
    coverage_status)
      case "$V" in
        pending|fail|pass) ;;
        *) fail E_INVALID_ARG "bad coverage_status: $V" ;;
      esac
      EXPR="$EXPR | .coverage_status = \"$V\""
      ;;
    escalation_reason)
      case "$V" in
        null) EXPR="$EXPR | .escalation_reason = null" ;;
        stagnation|divergence|max_rounds|budget_exhausted|requirements_unclear|coverage_tool_error|coverage_tool_unavailable|catalog_lock_timeout)
          EXPR="$EXPR | .escalation_reason = \"$V\""
          ;;
        *) fail E_INVALID_ARG "bad escalation_reason: $V" ;;
      esac
      ;;
    *) fail E_INVALID_ARG "unknown field: $F" ;;
  esac
done

atomic_write "$PATHF" "$EXPR" "$ROOT/docs/contracts/scrum-state/pbi-state.schema.json"

# Project derived backlog.json items[].status when phase changed. The phase→
# status map is the only SSOT bridge between pipeline state and backlog state.
if [ -n "$NEW_PHASE" ]; then
  DERIVED_STATUS="$(derive_backlog_status_from_phase "$NEW_PHASE")" \
    || fail E_INVALID_ARG "derive failed for phase: $NEW_PHASE"
  BACKLOG=".scrum/backlog.json"
  BACKLOG_SCHEMA="$ROOT/docs/contracts/scrum-state/backlog.schema.json"
  if [ -f "$BACKLOG" ] \
    && jq -e --arg id "$PBI" '.items | map(select(.id==$id)) | length > 0' "$BACKLOG" >/dev/null 2>&1
  then
    atomic_write "$BACKLOG" \
      "(.items[] | select(.id == \"$PBI\")).status = \"$DERIVED_STATUS\"" \
      "$BACKLOG_SCHEMA"
  fi
fi
