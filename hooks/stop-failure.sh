#!/usr/bin/env bash
# stop-failure.sh — StopFailure hook
# Logs session failure events (rate_limit, authentication_failed, etc.)
# to the dashboard for visibility. Reads hook event JSON from stdin.
set -euo pipefail

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/validate.sh
. "$HOOK_DIR/lib/validate.sh"
# shellcheck source=lib/dashboard.sh
. "$HOOK_DIR/lib/dashboard.sh"
# shellcheck source=lib/autonomy.sh
. "$HOOK_DIR/lib/autonomy.sh"

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

# Autonomous mode: also persist the failure on .scrum/autonomy.json so the
# watchdog can read last_failure and decide whether to retry / abort the
# outer loop. Fail-open: any error reading/writing autonomy.json is silently
# ignored — the dashboard event above is the authoritative log.
if autonomy_enabled; then
  AUTONOMY_FILE=".scrum/autonomy.json"
  if [ -f "$AUTONOMY_FILE" ] && jq empty "$AUTONOMY_FILE" >/dev/null 2>&1; then
    tmp="${AUTONOMY_FILE}.tmp.$$.${RANDOM}"
    if jq --arg reason "$reason" --arg ts "$timestamp" '
      .last_failure = {reason: $reason, at: $ts}
      | .updated_at = $ts
    ' "$AUTONOMY_FILE" > "$tmp" 2>/dev/null; then
      mv "$tmp" "$AUTONOMY_FILE"
    else
      rm -f "$tmp"
    fi
  fi
fi

exit 0
