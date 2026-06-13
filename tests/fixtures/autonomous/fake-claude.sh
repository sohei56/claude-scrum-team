#!/usr/bin/env bash
# fake-claude.sh — test stub that mimics `claude -p` for the autonomous
# watchdog integration tests.
#
# Behaviour is driven by a scenario file pointed to by FAKE_CLAUDE_SCENARIO
# (default: ./fake-claude-scenario.json). The scenario maps the per-call
# invocation index (1-based, stored in ./fake-claude-call-count) to actions:
#
#   {
#     "calls": [
#       {
#         "phase_to":   "backlog_created",        // (optional) overwrite
#                                                 //   .scrum/state.json.phase
#         "backlog_status_updates": [             // (optional) list of
#           {"id": "pbi-001", "status": "done"}   //   PBI status changes
#         ],
#         "stdout_json": {"total_cost_usd": 0.42, "result": "ok"},
#         "exit_code":  0,
#         "dashboard_events": [                   // (optional) appended to
#           {                                     //   .scrum/dashboard.json
#             "type": "stop_failure",
#             "detail": "rate_limit_exceeded"
#           }
#         ]
#       },
#       … one entry per expected call …
#     ]
#   }
#
# Behavioural notes:
#   - Index out of range → prints empty {}, exits 0.
#   - All paths are taken relative to the current working directory at the
#     time fake-claude.sh is invoked (the watchdog inherits the test's PWD).
#   - phase_to writes are atomic (tmp+mv).
#   - Timestamps for dashboard events are set to the current ISO8601 UTC.

set -euo pipefail

SCENARIO_FILE="${FAKE_CLAUDE_SCENARIO:-./fake-claude-scenario.json}"
COUNTER_FILE="${FAKE_CLAUDE_COUNTER:-./fake-claude-call-count}"

# Allow probing flags without crashing.
case "${1:-}" in
  --version|-V)
    echo "fake-claude 0.0.1 (stub)"
    exit 0 ;;
esac

# Increment call counter (1-indexed).
count=0
if [ -f "$COUNTER_FILE" ]; then
  count="$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)"
fi
count=$((count + 1))
printf '%d\n' "$count" > "$COUNTER_FILE"

# Default outputs when scenario absent or index out of range.
stdout_json='{}'
exit_code=0
phase_to=""
if [ -f "$SCENARIO_FILE" ]; then
  idx=$((count - 1))
  # Pull just this call's spec.
  call="$(jq -c --argjson i "$idx" '.calls[$i] // null' "$SCENARIO_FILE" 2>/dev/null || echo null)"
  if [ "$call" != "null" ] && [ -n "$call" ]; then
    stdout_json="$(printf '%s' "$call" | jq -c '.stdout_json // {}')"
    exit_code="$(printf '%s' "$call" | jq -r '.exit_code // 0')"
    phase_to="$(printf '%s' "$call" | jq -r '.phase_to // empty')"

    # Apply phase update if requested.
    if [ -n "$phase_to" ] && [ -f .scrum/state.json ]; then
      tmp=".scrum/state.json.tmp.fake.$$.${RANDOM}"
      jq --arg p "$phase_to" '.phase = $p' .scrum/state.json > "$tmp"
      mv "$tmp" .scrum/state.json
    fi

    # Apply backlog status updates.
    updates_n="$(printf '%s' "$call" | jq -r '(.backlog_status_updates // []) | length')"
    if [ "${updates_n:-0}" -gt 0 ] && [ -f .scrum/backlog.json ]; then
      i=0
      while [ "$i" -lt "$updates_n" ]; do
        upd="$(printf '%s' "$call" | jq -c ".backlog_status_updates[$i]")"
        pid="$(printf '%s' "$upd" | jq -r '.id')"
        st="$(printf '%s' "$upd" | jq -r '.status')"
        tmp=".scrum/backlog.json.tmp.fake.$$.${RANDOM}"
        jq --arg id "$pid" --arg s "$st" \
          '(.items[] | select(.id == $id)).status = $s' \
          .scrum/backlog.json > "$tmp"
        mv "$tmp" .scrum/backlog.json
        i=$((i + 1))
      done
    fi

    # Append dashboard events.
    events_n="$(printf '%s' "$call" | jq -r '(.dashboard_events // []) | length')"
    if [ "${events_n:-0}" -gt 0 ]; then
      mkdir -p .scrum
      if [ ! -f .scrum/dashboard.json ] || ! jq empty .scrum/dashboard.json >/dev/null 2>&1; then
        printf '{"events":[]}\n' > .scrum/dashboard.json
      fi
      i=0
      now="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
      while [ "$i" -lt "$events_n" ]; do
        ev="$(printf '%s' "$call" | jq -c ".dashboard_events[$i]")"
        tmp=".scrum/dashboard.json.tmp.fake.$$.${RANDOM}"
        jq --argjson ev "$ev" --arg ts "$now" \
          '.events = ((.events // []) + [($ev + {timestamp: $ts})])' \
          .scrum/dashboard.json > "$tmp"
        mv "$tmp" .scrum/dashboard.json
        i=$((i + 1))
      done
    fi
  fi
fi

# Emit stdout JSON exactly once.
printf '%s\n' "$stdout_json"
exit "$exit_code"
