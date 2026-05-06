#!/usr/bin/env bash
# stop-failure.sh — StopFailure hook
# Logs session failure events (rate_limit, authentication_failed, etc.)
# to the dashboard for visibility. Reads hook event JSON from stdin.
set -euo pipefail

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/validate.sh
. "$HOOK_DIR/lib/validate.sh"

DASHBOARD_FILE=".scrum/dashboard.json"
MAX_EVENTS=100

ensure_dashboard_file() {
  # shellcheck disable=SC2016  # $max is a jq variable, not shell expansion.
  ensure_json_file "$DASHBOARD_FILE" \
    '{"events": [], "max_events": $max}' \
    --argjson max "$MAX_EVENTS"
}

append_dashboard_event() {
  local event_json="$1"
  ensure_dashboard_file
  append_to_json_array "$DASHBOARD_FILE" events "$event_json" max_events "$MAX_EVENTS"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

hook_event="$(cat)"

reason="$(echo "$hook_event" | jq -r '.reason // "unknown"')"
agent_id="$(echo "$hook_event" | jq -r '.agent_id // .session_id // "unknown"')"
timestamp="$(get_timestamp)"

log_hook "stop-failure" "ERROR" "Session failed: $reason (agent: $agent_id)"

event_json="$(jq -n \
  --arg ts "$timestamp" \
  --arg agent "$agent_id" \
  --arg reason "$reason" \
  --arg detail "Session failed: ${reason}" \
  '{
    "timestamp": $ts,
    "type": "stop_failure",
    "agent_id": $agent,
    "file_path": null,
    "change_type": null,
    "detail": $detail
  }')"

append_dashboard_event "$event_json"

exit 0
