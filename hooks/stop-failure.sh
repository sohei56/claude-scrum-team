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

# Initialize dashboard.json if it does not exist
ensure_dashboard_file() {
  ensure_scrum_dir
  if [ ! -f "$DASHBOARD_FILE" ]; then
    jq -n --argjson max "$MAX_EVENTS" '{"events": [], "max_events": $max}' > "$DASHBOARD_FILE"
  fi
}

# Append an event to dashboard.json, trimming oldest if over cap
append_dashboard_event() {
  local event_json="$1"
  ensure_dashboard_file

  local tmp_file
  tmp_file="${DASHBOARD_FILE}.tmp.$$"

  local file_max
  file_max="$(jq '.max_events // 100' "$DASHBOARD_FILE" 2>/dev/null || echo "$MAX_EVENTS")"

  jq --argjson evt "$event_json" --argjson max "$file_max" '
    .events += [$evt] |
    if (.events | length) > $max then
      .events = .events[(.events | length) - $max:]
    else
      .
    end
  ' "$DASHBOARD_FILE" > "$tmp_file" && mv "$tmp_file" "$DASHBOARD_FILE"
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
