#!/usr/bin/env bash
# Markdown / shell backticks in literal prompts are not parameter
# expansions; silence the noisy SC2016 warnings file-wide (the directive
# must precede the first command to apply to the whole file).
# shellcheck disable=SC2016
# scripts/autonomous/watchdog.sh — autonomous-PO outer loop (Ralph Loop).
#
# Repeatedly launches a headless `claude -p` Scrum Master session per
# iteration. Each session runs until the Stop hook releases (typically when
# the workflow phase advances or a checkpoint is reached); on process exit
# control returns here. The watchdog enforces global safety bounds (max
# iterations / wall clock / sprints / consecutive failures / budget) and
# handles rate-limit backoff observed via dashboard `stop_failure` events.
#
# Usage: scripts/autonomous/watchdog.sh
#   Reads `.scrum/config.json`.autonomous and `.scrum/autonomy.json` (which
#   must already exist — produced by scrum-start.sh --autonomous).
#
# Exit codes:
#   0 — workflow phase reached `complete`
#   1 — connsecutive failures exceeded threshold (incl. sustained rate-limit)
#   2 — safety valve tripped (iterations / wall clock / sprints / budget)
#   3 — configuration error (missing autonomy.json, etc.)
#
# Test hooks (env vars; harmless in production):
#   AUTON_CLAUDE_BIN     — claude binary (default `claude`)
#   AUTON_SLEEP_SCALE    — multiplier on every sleep duration (default 1; 0
#                          disables sleeping entirely — useful for tests)
#   AUTON_NOW_CMD        — command emitting epoch seconds for the "now"
#                          comparison points (default `date +%s`)
#
# Bash 3.2 compatible. shellcheck clean.
#
# Note on --teammate-mode:
#   The `--teammate-mode in-process` flag is undocumented in `claude --help`
#   but is accepted by the CLI (verified 2026-06: `claude --teammate-mode
#   in-process --version` exits 0). The interactive `scrum-start.sh` uses
#   it. For headless `-p` sessions we currently rely on the default mode and
#   omit the flag — there is no behavioural reason to force in-process mode
#   when no human is attached to the tmux pane, and using only documented
#   flags reduces breakage risk if the flag is ever removed.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/report.sh
. "$SCRIPT_DIR/lib/report.sh"

# --- Configurable test hooks --------------------------------------------------
AUTON_CLAUDE_BIN="${AUTON_CLAUDE_BIN:-claude}"
AUTON_SLEEP_SCALE="${AUTON_SLEEP_SCALE:-1}"
AUTON_NOW_CMD="${AUTON_NOW_CMD:-date +%s}"

# --- Files -------------------------------------------------------------------
CONFIG_FILE=".scrum/config.json"
AUTONOMY_FILE=".scrum/autonomy.json"
STATE_FILE=".scrum/state.json"
SPRINT_HISTORY_FILE=".scrum/sprint-history.json"
BACKLOG_FILE=".scrum/backlog.json"
DASHBOARD_FILE=".scrum/dashboard.json"
ITER_OUT_DIR=".scrum/autonomous"

# --- Defaults (mirrored from .scrum-config.example.json) ---------------------
DEFAULT_MAX_ITERATIONS=50
DEFAULT_MAX_WALL_HOURS=8
DEFAULT_MAX_SPRINTS=5
DEFAULT_MAX_CONSECUTIVE_FAILURES=3
DEFAULT_MAX_BUDGET_PER_ITER=10
DEFAULT_MAX_TOTAL_BUDGET=50
DEFAULT_PERMISSION_MODE="dontAsk"

# --- Helpers ----------------------------------------------------------------

now_epoch() {
  eval "$AUTON_NOW_CMD"
}

iso_utc_now() {
  date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "1970-01-01T00:00:00Z"
}

# do_sleep <seconds>
# Sleeps for <seconds> * AUTON_SLEEP_SCALE. When the product is 0 (e.g. in
# tests with AUTON_SLEEP_SCALE=0) we skip sleep entirely.
do_sleep() {
  local secs="$1"
  local effective
  effective="$(awk -v s="$secs" -v m="$AUTON_SLEEP_SCALE" 'BEGIN{print s*m}')"
  case "$effective" in
    0|0.0|0.00|"") return 0 ;;
  esac
  # awk produces a float; sleep accepts both ints and floats on GNU and BSD.
  sleep "$effective" 2>/dev/null || true
}

# Bash 3.2-compatible UUID v4 generator (xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx).
generate_uuid() {
  if command -v uuidgen >/dev/null 2>&1; then
    uuidgen | tr '[:upper:]' '[:lower:]'
    return 0
  fi
  # Fallback: synthesize from /dev/urandom hex.
  local hex
  hex="$(od -An -tx1 -N16 /dev/urandom 2>/dev/null | tr -d ' \n')"
  if [ -z "$hex" ] || [ "${#hex}" -lt 32 ]; then
    # Last-resort fallback (deterministic-ish): epoch + pid + RANDOM
    hex="$(printf '%08x%04x%04x%04x%012x' \
      "$(now_epoch)" "$$" "$RANDOM" "$RANDOM" "$RANDOM")"
    hex="${hex:0:32}"
  fi
  # Force version=4 and variant=10xx
  printf '%s-%s-4%s-%s%s-%s\n' \
    "${hex:0:8}" "${hex:8:4}" "${hex:13:3}" "8" "${hex:17:3}" "${hex:20:12}"
}

# cfg_num <jq_path> <default>
cfg_num() {
  local path="$1" default="$2" val
  if [ ! -f "$CONFIG_FILE" ]; then
    printf '%s\n' "$default"
    return 0
  fi
  if ! jq empty "$CONFIG_FILE" >/dev/null 2>&1; then
    printf '%s\n' "$default"
    return 0
  fi
  val="$(jq -r "$path // empty" "$CONFIG_FILE" 2>/dev/null || true)"
  if [ -z "$val" ] || [ "$val" = "null" ]; then
    printf '%s\n' "$default"
    return 0
  fi
  printf '%s\n' "$val"
}

# cfg_str_or_null <jq_path>
cfg_str_or_null() {
  local path="$1" val
  if [ ! -f "$CONFIG_FILE" ]; then
    return 0
  fi
  val="$(jq -r "$path // empty" "$CONFIG_FILE" 2>/dev/null || true)"
  [ "$val" = "null" ] && val=""
  printf '%s' "$val"
}

# autonomy_atomic_write <jq_expr>
autonomy_atomic_write() {
  local expr="$1" tmp
  tmp="${AUTONOMY_FILE}.tmp.$$.${RANDOM}"
  if jq "$expr" "$AUTONOMY_FILE" > "$tmp" 2>/dev/null; then
    mv "$tmp" "$AUTONOMY_FILE"
    return 0
  fi
  rm -f "$tmp"
  return 1
}

# progress_hash — emits sha of phase + current_sprint_id + every PBI's id:status.
progress_hash() {
  local body=""
  local phase sid items
  phase="$(_jq_safe "$STATE_FILE" '.phase // ""' '')"
  sid="$(_jq_safe "$STATE_FILE" '.current_sprint_id // ""' '')"
  if [ -f "$BACKLOG_FILE" ] && jq empty "$BACKLOG_FILE" >/dev/null 2>&1; then
    items="$(jq -r '(.items // [])[] | (.id // "") + ":" + (.status // "")' \
      "$BACKLOG_FILE" 2>/dev/null | sort)"
  else
    items=""
  fi
  body="${phase}|${sid}|${items}"
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$body" | shasum | awk '{print $1}'
  elif command -v sha1sum >/dev/null 2>&1; then
    printf '%s' "$body" | sha1sum | awk '{print $1}'
  else
    printf '%s' "$body" | cksum | awk '{print $1}'
  fi
}

# rate_limited_since <epoch>
# Returns 0 if dashboard.json contains a stop_failure event newer than the
# given start epoch whose reason matches rate_limit / limit / overloaded.
rate_limited_since() {
  local since_epoch="$1"
  [ -f "$DASHBOARD_FILE" ] || return 1
  jq empty "$DASHBOARD_FILE" >/dev/null 2>&1 || return 1
  # Convert each event's timestamp into epoch using date; portable across
  # GNU/BSD by allowing the parser to fail (returns 0 then, treated as old).
  # We do the comparison in awk on the side of robustness.
  local matches
  matches="$(jq -r --argjson since "$since_epoch" '
    (.events // [])
    | map(select((.type // "") == "stop_failure"))
    | map(select(((.detail // .reason // "") | ascii_downcase)
        | test("rate.?limit|overload|too.?many")))
    | .[].timestamp // empty
  ' "$DASHBOARD_FILE" 2>/dev/null || true)"
  [ -n "$matches" ] || return 1

  local ts epoch
  while IFS= read -r ts; do
    [ -n "$ts" ] || continue
    # GNU date `--date` and BSD `-jf` differ; try GNU first, then BSD.
    epoch="$(date -u -d "$ts" +%s 2>/dev/null || \
             date -u -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" +%s 2>/dev/null || echo 0)"
    if [ "$epoch" -ge "$since_epoch" ]; then
      return 0
    fi
  done <<EOF
$matches
EOF
  return 1
}

# build_prompt <phase>
# Generates the per-iteration prompt fed to claude -p. The common preamble
# announces the autonomous context; the per-phase tail nudges the SM toward
# the right ceremony / handler.
build_prompt() {
  local phase="$1"
  local preamble tail
  preamble='AUTONOMOUS PO MODE: no human is present. po_mode=agent — every PO decision must be delegated to the product-owner teammate (Liveness Protocol). Read .scrum/state.json, .scrum/autonomy.json, .scrum/backlog.json, and .scrum/sprint.json before deciding. Operate as Scrum Master in Delegate mode. The Stop hook will release you when the workflow phase advances or a checkpoint is reached; do not stop early.'

  case "$phase" in
    ""|new|unknown)
      tail='No state.json yet — bootstrap: read docs/product/brief.md, then drive the Requirements Sprint with the product-owner teammate as the user proxy. Aim for `phase=backlog_created` this iteration.'
      ;;
    requirements_sprint)
      tail='Continue the Requirements Sprint. Drive elicitation through the product-owner teammate (no human prompts). When complete, transition to `backlog_created`.'
      ;;
    backlog_created)
      tail='Run Sprint Planning. Select the next batch of PBIs with the product-owner teammate and transition to `pbi_pipeline_active`.'
      ;;
    sprint_planning)
      tail='Finalise Sprint Planning. Spawn the developer teammates and transition to `pbi_pipeline_active`.'
      ;;
    pbi_pipeline_active)
      tail='PBI pipeline active. The previous session has exited and any in-process teammates have been destroyed — for every PBI in `in_progress_*`, re-spawn the responsible developer via Liveness Protocol (and, if po_mode=agent, re-spawn the product-owner teammate as well). Resume the PBI conductor loop until all PBIs are merged.'
      ;;
    review|sprint_review)
      tail='Run Sprint Review with the product-owner teammate, then drive Retrospective. After retrospective is recorded, transition either to `sprint_planning` (next Sprint) or, when the Product Goal is satisfied, to `integration_sprint`.'
      ;;
    retrospective)
      tail='Capture the retrospective output, persist sprint-history, then transition the workflow.'
      ;;
    integration_sprint)
      tail='Drive the Integration Sprint. Run product-wide QA / smoke tests. On defects, transition back to `backlog_created` (defect-fix loop). On pass, transition to `complete`.'
      ;;
    complete)
      tail='Workflow is complete. Verify .scrum/state.json reflects this and stop.'
      ;;
    *)
      tail='Continue the current ceremony for phase `'"$phase"'`. Drive PO decisions through the product-owner teammate.'
      ;;
  esac

  printf '%s\n\n%s\n' "$preamble" "$tail"
}

# _jq_safe is also exposed by report.sh — keep a local copy to avoid
# coupling watchdog flow to report.sh load order.
_jq_safe() {
  local f="$1" expr="$2" fb="$3" out
  if [ ! -f "$f" ]; then
    printf '%s\n' "$fb"
    return 0
  fi
  if ! out="$(jq -r "$expr" "$f" 2>/dev/null)" || [ -z "$out" ] || [ "$out" = "null" ]; then
    printf '%s\n' "$fb"
    return 0
  fi
  printf '%s\n' "$out"
}

# finalize <exit_code> <reason>
# Always invoked on watchdog exit (success or failure).
finalize() {
  local code="$1" reason="$2"
  local report_path
  report_path="$(generate_morning_report "$reason" || true)"
  if [ -n "$report_path" ]; then
    printf 'watchdog: morning report → %s\n' "$report_path" >&2
  fi
  run_notify "$code" || true
  exit "$code"
}

# ---------------------------------------------------------------------------
# Initialisation
# ---------------------------------------------------------------------------

if [ ! -f "$AUTONOMY_FILE" ]; then
  printf 'watchdog: %s missing — run scrum-start.sh --autonomous first.\n' \
    "$AUTONOMY_FILE" >&2
  exit 3
fi
if ! jq empty "$AUTONOMY_FILE" >/dev/null 2>&1; then
  printf 'watchdog: %s is not valid JSON.\n' "$AUTONOMY_FILE" >&2
  exit 3
fi
mkdir -p "$ITER_OUT_DIR"

MAX_ITERATIONS="$(cfg_num '.autonomous.max_iterations' "$DEFAULT_MAX_ITERATIONS")"
MAX_WALL_HOURS="$(cfg_num '.autonomous.max_wall_clock_hours' "$DEFAULT_MAX_WALL_HOURS")"
MAX_SPRINTS="$(cfg_num '.autonomous.max_sprints' "$DEFAULT_MAX_SPRINTS")"
MAX_CONSECUTIVE_FAILURES="$(cfg_num '.autonomous.max_consecutive_failures' "$DEFAULT_MAX_CONSECUTIVE_FAILURES")"
MAX_BUDGET_PER_ITER="$(cfg_num '.autonomous.max_budget_usd_per_iteration' "$DEFAULT_MAX_BUDGET_PER_ITER")"
MAX_TOTAL_BUDGET="$(cfg_num '.autonomous.max_total_budget_usd' "$DEFAULT_MAX_TOTAL_BUDGET")"
PERMISSION_MODE="$(cfg_num '.autonomous.permission_mode' "$DEFAULT_PERMISSION_MODE")"
case "$PERMISSION_MODE" in
  dontAsk|bypassPermissions) ;;
  *) PERMISSION_MODE="$DEFAULT_PERMISSION_MODE" ;;
esac
FALLBACK_MODEL="$(cfg_str_or_null '.autonomous.fallback_model')"

# wall-clock seconds limit
MAX_WALL_SECS="$(awk -v h="$MAX_WALL_HOURS" 'BEGIN{printf "%d", h*3600}')"
START_EPOCH="$(now_epoch)"

printf 'watchdog: starting (max_iter=%s, max_hours=%s, max_sprints=%s, max_failures=%s, max_total_budget=%s)\n' \
  "$MAX_ITERATIONS" "$MAX_WALL_HOURS" "$MAX_SPRINTS" "$MAX_CONSECUTIVE_FAILURES" "$MAX_TOTAL_BUDGET" >&2

# Loop-local accumulators
ITER=0
FAIL_STREAK=0
RATE_BACKOFF=60
RATE_STREAK=0
LAST_HASH="__INIT__"

# ---------------------------------------------------------------------------
# Main loop
# ---------------------------------------------------------------------------

while :; do
  ITER=$((ITER + 1))

  # ----- 1. Safety valves -----
  if [ "$ITER" -gt "$MAX_ITERATIONS" ]; then
    printf 'watchdog: max_iterations (%s) exceeded.\n' "$MAX_ITERATIONS" >&2
    finalize 2 "max_iterations_exceeded"
  fi

  NOW_EPOCH="$(now_epoch)"
  ELAPSED=$((NOW_EPOCH - START_EPOCH))
  if [ "$ELAPSED" -gt "$MAX_WALL_SECS" ]; then
    printf 'watchdog: max_wall_clock_hours (%s) exceeded (elapsed=%ss).\n' \
      "$MAX_WALL_HOURS" "$ELAPSED" >&2
    finalize 2 "max_wall_clock_exceeded"
  fi

  SPRINT_COUNT=0
  if [ -f "$SPRINT_HISTORY_FILE" ] && jq empty "$SPRINT_HISTORY_FILE" >/dev/null 2>&1; then
    SPRINT_COUNT="$(jq -r '(.sprints // []) | length' "$SPRINT_HISTORY_FILE" 2>/dev/null || echo 0)"
  fi
  if [ "${SPRINT_COUNT:-0}" -ge "$MAX_SPRINTS" ]; then
    printf 'watchdog: max_sprints (%s) reached (history=%s).\n' \
      "$MAX_SPRINTS" "$SPRINT_COUNT" >&2
    finalize 2 "max_sprints_reached"
  fi

  TOTAL_COST="$(jq -r '.total_cost_usd // 0' "$AUTONOMY_FILE" 2>/dev/null || echo 0)"
  # Compare floats with awk
  if awk -v a="$TOTAL_COST" -v b="$MAX_TOTAL_BUDGET" 'BEGIN{exit !(a>=b)}'; then
    printf 'watchdog: max_total_budget_usd (%s) reached (cost=%s).\n' \
      "$MAX_TOTAL_BUDGET" "$TOTAL_COST" >&2
    finalize 2 "max_total_budget_reached"
  fi

  # ----- 2. Phase check -----
  PHASE="$(_jq_safe "$STATE_FILE" '.phase // ""' '')"
  if [ "$PHASE" = "complete" ]; then
    printf 'watchdog: phase=complete — finishing.\n' >&2
    finalize 0 "complete"
  fi

  # ----- 3. Session ID + autonomy bookkeeping -----
  SID="$(generate_uuid)"
  if ! autonomy_atomic_write \
       "(.iteration = ${ITER}) | (.lead_session_id = \"${SID}\") | (.stop_blocks = {phase: (.stop_blocks.phase // \"\"), count: 0}) | (.updated_at = \"$(iso_utc_now)\")"; then
    printf 'watchdog: failed to update autonomy.json — aborting.\n' >&2
    finalize 3 "autonomy_write_failed"
  fi

  # ----- 4. Build prompt + launch -----
  PROMPT="$(build_prompt "$PHASE")"
  ITER_STDOUT="${ITER_OUT_DIR}/iter-${ITER}.json"
  ITER_STDERR="${ITER_OUT_DIR}/iter-${ITER}.err"
  ITER_START_EPOCH="$NOW_EPOCH"

  printf 'watchdog: iteration %s (phase=%s, sid=%s)\n' "$ITER" "${PHASE:-<empty>}" "$SID" >&2

  CLAUDE_ARGS=(
    -p "$PROMPT"
    --agent scrum-master
    --session-id "$SID"
    --permission-mode "$PERMISSION_MODE"
    --max-budget-usd "$MAX_BUDGET_PER_ITER"
    --output-format json
  )
  if [ -n "$FALLBACK_MODEL" ]; then
    CLAUDE_ARGS+=( --fallback-model "$FALLBACK_MODEL" )
  fi

  # Capture rc without aborting under `set -e`.
  rc=0
  CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 \
    "$AUTON_CLAUDE_BIN" "${CLAUDE_ARGS[@]}" \
    >"$ITER_STDOUT" 2>"$ITER_STDERR" || rc=$?

  # ----- 5. Cost accounting -----
  if [ -s "$ITER_STDOUT" ] && jq empty "$ITER_STDOUT" >/dev/null 2>&1; then
    ITER_COST="$(jq -r '.total_cost_usd // 0' "$ITER_STDOUT" 2>/dev/null || echo 0)"
    if [ -n "$ITER_COST" ] && [ "$ITER_COST" != "null" ] && [ "$ITER_COST" != "0" ]; then
      autonomy_atomic_write \
        "(.total_cost_usd = ((.total_cost_usd // 0) + ${ITER_COST})) | (.updated_at = \"$(iso_utc_now)\")" \
        || true
    fi
  fi

  # ----- 6. Progress + rate-limit + failure judgement -----
  NEW_HASH="$(progress_hash)"

  if rate_limited_since "$ITER_START_EPOCH"; then
    RATE_STREAK=$((RATE_STREAK + 1))
    if [ "$RATE_STREAK" -ge 6 ]; then
      printf 'watchdog: rate-limit streak >=6 — giving up.\n' >&2
      finalize 1 "rate_limit_persistent"
    fi
    printf 'watchdog: rate-limit detected; sleeping %ss (streak=%s)\n' \
      "$RATE_BACKOFF" "$RATE_STREAK" >&2
    do_sleep "$RATE_BACKOFF"
    RATE_BACKOFF=$((RATE_BACKOFF * 2))
    if [ "$RATE_BACKOFF" -gt 3600 ]; then
      RATE_BACKOFF=3600
    fi
    LAST_HASH="$NEW_HASH"
    continue
  fi

  CB_TRIPPED="$(jq -r '.circuit_breaker_tripped // empty' "$AUTONOMY_FILE" 2>/dev/null || true)"
  # Clear the breaker so the next iteration starts clean.
  if [ -n "$CB_TRIPPED" ]; then
    autonomy_atomic_write \
      "(.circuit_breaker_tripped = null) | (.updated_at = \"$(iso_utc_now)\")" || true
  fi

  PROGRESSED=0
  if [ "$NEW_HASH" != "$LAST_HASH" ] && [ "$LAST_HASH" != "__INIT__" ]; then
    PROGRESSED=1
  elif [ "$LAST_HASH" = "__INIT__" ]; then
    # First iteration — treat as progress if there's no rc failure and no CB.
    if [ "$rc" -eq 0 ] && [ -z "$CB_TRIPPED" ]; then
      PROGRESSED=1
    fi
  fi

  if [ "$PROGRESSED" = "1" ] && [ "$rc" -eq 0 ] && [ -z "$CB_TRIPPED" ]; then
    FAIL_STREAK=0
    RATE_BACKOFF=60
    RATE_STREAK=0
  else
    FAIL_STREAK=$((FAIL_STREAK + 1))
    REASON="no_progress"
    [ "$rc" -ne 0 ]      && REASON="claude_exit_${rc}"
    [ -n "$CB_TRIPPED" ] && REASON="circuit_breaker"
    autonomy_atomic_write \
      "(.last_failure = {reason: \"${REASON}\", at: \"$(iso_utc_now)\"}) | (.updated_at = \"$(iso_utc_now)\")" \
      || true
    printf 'watchdog: failure (%s); fail_streak=%s\n' "$REASON" "$FAIL_STREAK" >&2
  fi

  LAST_HASH="$NEW_HASH"

  if [ "$FAIL_STREAK" -ge "$MAX_CONSECUTIVE_FAILURES" ]; then
    printf 'watchdog: %s consecutive failures — giving up.\n' "$FAIL_STREAK" >&2
    finalize 1 "max_consecutive_failures"
  fi
done
