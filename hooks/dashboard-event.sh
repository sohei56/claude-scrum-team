#!/usr/bin/env bash
# dashboard-event.sh — PostToolUse/TeammateIdle hook
# Feeds the dashboard events log and communications log.
# Reads hook event JSON from stdin (Claude Code hook payload).
# Appends file change events to .scrum/dashboard.json and agent
# communication messages to .scrum/communications.json.
set -euo pipefail

DASHBOARD_FILE=".scrum/dashboard.json"
COMMS_FILE=".scrum/communications.json"
MAX_EVENTS=100
MAX_MESSAGES=200

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

# Ensure .scrum directory exists
ensure_scrum_dir() {
  if [ ! -d ".scrum" ]; then
    mkdir -p ".scrum"
  fi
}

# Initialize dashboard.json if it does not exist
ensure_dashboard_file() {
  ensure_scrum_dir
  if [ ! -f "$DASHBOARD_FILE" ]; then
    jq -n --argjson max "$MAX_EVENTS" '{"events": [], "max_events": $max}' > "$DASHBOARD_FILE"
  fi
}

# Initialize communications.json if it does not exist
ensure_comms_file() {
  ensure_scrum_dir
  if [ ! -f "$COMMS_FILE" ]; then
    jq -n --argjson max "$MAX_MESSAGES" '{"messages": [], "max_messages": $max}' > "$COMMS_FILE"
  fi
}

# Get current ISO 8601 timestamp
get_timestamp() {
  # Compatible with both macOS (BSD date) and GNU date
  if date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null; then
    return
  fi
  # Fallback
  date -u "+%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "1970-01-01T00:00:00Z"
}

# Append an event to dashboard.json, trimming oldest if over cap
append_dashboard_event() {
  local event_json="$1"
  ensure_dashboard_file

  local tmp_file
  tmp_file="${DASHBOARD_FILE}.tmp.$$"

  # Read current max_events from file (default to MAX_EVENTS)
  local file_max
  file_max="$(jq '.max_events // 100' "$DASHBOARD_FILE" 2>/dev/null || echo "$MAX_EVENTS")"

  # Append new event and trim to max_events (keep newest)
  jq --argjson evt "$event_json" --argjson max "$file_max" '
    .events += [$evt] |
    if (.events | length) > $max then
      .events = .events[(.events | length) - $max:]
    else
      .
    end
  ' "$DASHBOARD_FILE" > "$tmp_file" && mv "$tmp_file" "$DASHBOARD_FILE"
}

# Append a message to communications.json, trimming oldest if over cap
append_comms_message() {
  local message_json="$1"
  ensure_comms_file

  local tmp_file
  tmp_file="${COMMS_FILE}.tmp.$$"

  # Read current max_messages from file (default to MAX_MESSAGES)
  local file_max
  file_max="$(jq '.max_messages // 200' "$COMMS_FILE" 2>/dev/null || echo "$MAX_MESSAGES")"

  # Append new message and trim to max_messages (keep newest)
  jq --argjson msg "$message_json" --argjson max "$file_max" '
    .messages += [$msg] |
    if (.messages | length) > $max then
      .messages = .messages[(.messages | length) - $max:]
    else
      .
    end
  ' "$COMMS_FILE" > "$tmp_file" && mv "$tmp_file" "$COMMS_FILE"
}

# Determine the change type for a file operation
determine_change_type() {
  local tool_name="$1"
  local file_path="$2"

  case "$tool_name" in
    Write)
      if [ -f "$file_path" ]; then
        echo "modified"
      else
        echo "created"
      fi
      ;;
    Edit)
      echo "modified"
      ;;
    Bash)
      # Cannot reliably determine — default to modified
      echo "modified"
      ;;
    *)
      echo "modified"
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# Read hook event JSON from stdin
hook_event="$(cat)"

# Extract common fields
# Claude Code uses "hook_event_name" as the event type field
hook_type="$(echo "$hook_event" | jq -r '.hook_event_name // .hook_type // .type // "unknown"')"
agent_id="$(echo "$hook_event" | jq -r '.agent_id // .session_id // "unknown"')"
timestamp="$(get_timestamp)"

case "$hook_type" in
  PostToolUse|post_tool_use)
    # Extract tool information
    tool_name="$(echo "$hook_event" | jq -r '.tool_name // empty')"
    tool_input="$(echo "$hook_event" | jq -c '.tool_input // {}')"

    # Only process file-modifying tools
    case "$tool_name" in
      Write|Edit)
        file_path="$(echo "$tool_input" | jq -r '.file_path // empty')"
        if [ -n "$file_path" ]; then
          change_type="$(determine_change_type "$tool_name" "$file_path")"
          detail="${tool_name} on ${file_path}"

          event_json="$(jq -n \
            --arg ts "$timestamp" \
            --arg type "file_changed" \
            --arg agent "$agent_id" \
            --arg fp "$file_path" \
            --arg ct "$change_type" \
            --arg detail "$detail" \
            '{
              "timestamp": $ts,
              "type": $type,
              "agent_id": $agent,
              "file_path": $fp,
              "change_type": $ct,
              "detail": $detail
            }')"

          append_dashboard_event "$event_json"
        fi
        ;;
      Bash)
        # For Bash tool, extract a summary but do not try to determine file paths
        command="$(echo "$tool_input" | jq -r '.command // empty' | head -c 200)"
        if [ -n "$command" ]; then
          detail="Bash command: ${command}"

          event_json="$(jq -n \
            --arg ts "$timestamp" \
            --arg type "file_changed" \
            --arg agent "$agent_id" \
            --arg detail "$detail" \
            '{
              "timestamp": $ts,
              "type": $type,
              "agent_id": $agent,
              "file_path": null,
              "change_type": null,
              "detail": $detail
            }')"

          append_dashboard_event "$event_json"
        fi
        ;;
    esac
    ;;

  TeammateIdle|teammate_idle)
    # Agent communication: progress update
    sender_id="$(echo "$hook_event" | jq -r '.teammate_id // .agent_id // "unknown"')"
    sender_role="$(echo "$hook_event" | jq -r '.teammate_role // "developer"')"
    content="$(echo "$hook_event" | jq -r '.message // .content // "Teammate idle"')"

    # Append to communications log
    message_json="$(jq -n \
      --arg ts "$timestamp" \
      --arg sid "$sender_id" \
      --arg role "$sender_role" \
      --arg type "progress_update" \
      --arg content "$content" \
      '{
        "timestamp": $ts,
        "sender_id": $sid,
        "sender_role": $role,
        "recipient_id": null,
        "type": $type,
        "content": $content
      }')"

    append_comms_message "$message_json"

    # Also add a dashboard event for teammate idle
    event_json="$(jq -n \
      --arg ts "$timestamp" \
      --arg agent "$sender_id" \
      --arg detail "Teammate idle: ${content}" \
      '{
        "timestamp": $ts,
        "type": "teammate_idle",
        "agent_id": $agent,
        "file_path": null,
        "change_type": null,
        "detail": $detail
      }')"

    append_dashboard_event "$event_json"
    ;;

  Stop|stop)
    # Session or teammate stopping
    reason="$(echo "$hook_event" | jq -r '.reason // "completed"')"
    detail="Session stopped: ${reason}"

    event_json="$(jq -n \
      --arg ts "$timestamp" \
      --arg agent "$agent_id" \
      --arg detail "$detail" \
      '{
        "timestamp": $ts,
        "type": "session_event",
        "agent_id": $agent,
        "file_path": null,
        "change_type": null,
        "detail": $detail
      }')"

    append_dashboard_event "$event_json"
    ;;

  SubagentStop|subagent_stop)
    # Teammate finished its work
    detail="Teammate finished"

    event_json="$(jq -n \
      --arg ts "$timestamp" \
      --arg agent "$agent_id" \
      --arg detail "$detail" \
      '{
        "timestamp": $ts,
        "type": "session_event",
        "agent_id": $agent,
        "file_path": null,
        "change_type": null,
        "detail": $detail
      }')"

    append_dashboard_event "$event_json"
    ;;

  *)
    # Other hook types — build a descriptive summary
    tool_name="$(echo "$hook_event" | jq -r '.tool_name // empty')"
    reason="$(echo "$hook_event" | jq -r '.reason // empty')"
    user_prompt="$(echo "$hook_event" | jq -r '.user_prompt // empty' | head -c 100)"

    if [ -n "$tool_name" ]; then
      detail="Tool: ${tool_name}"
    elif [ -n "$user_prompt" ]; then
      detail="User: ${user_prompt}"
    elif [ -n "$reason" ]; then
      detail="Event (${hook_type}): ${reason}"
    else
      detail="Event: ${hook_type}"
    fi

    event_json="$(jq -n \
      --arg ts "$timestamp" \
      --arg type "session_event" \
      --arg agent "$agent_id" \
      --arg detail "$detail" \
      '{
        "timestamp": $ts,
        "type": $type,
        "agent_id": $agent,
        "file_path": null,
        "change_type": null,
        "detail": $detail
      }')"

    append_dashboard_event "$event_json"
    ;;
esac

exit 0
