#!/usr/bin/env bash
# session-context.sh — SessionStart hook
# Reads .scrum/state.json and outputs additionalContext JSON
# with current phase, Sprint ID, Sprint Goal, and resume context.
set -euo pipefail

STATE_FILE=".scrum/state.json"
SPRINT_FILE=".scrum/sprint.json"

# Build context based on available state
if [ -f "$STATE_FILE" ]; then
  phase="$(jq -r '.phase // "unknown"' "$STATE_FILE")"
  sprint_id="$(jq -r '.current_sprint_id // "none"' "$STATE_FILE")"
  product_goal="$(jq -r '.product_goal // "Not yet defined"' "$STATE_FILE")"

  # Get Sprint Goal if sprint file exists
  sprint_goal="No active Sprint"
  if [ -f "$SPRINT_FILE" ] && [ "$sprint_id" != "none" ] && [ "$sprint_id" != "null" ]; then
    sprint_goal="$(jq -r '.goal // "No goal set"' "$SPRINT_FILE")"
    sprint_type="$(jq -r '.type // "unknown"' "$SPRINT_FILE")"
    sprint_status="$(jq -r '.status // "unknown"' "$SPRINT_FILE")"
  fi

  # Build resume context
  context="Resuming project. Product Goal: ${product_goal}. Current phase: ${phase}."
  if [ "$sprint_id" != "none" ] && [ "$sprint_id" != "null" ]; then
    context="${context} Active Sprint: ${sprint_id} (${sprint_type:-unknown}, ${sprint_status:-unknown}). Sprint Goal: ${sprint_goal}."
  fi

  # Output additionalContext JSON
  jq -n \
    --arg phase "$phase" \
    --arg sprint_id "$sprint_id" \
    --arg sprint_goal "$sprint_goal" \
    --arg context "$context" \
    '{
      "additionalContext": $context
    }'
else
  # New project — no state yet
  jq -n '{
    "additionalContext": "New project. No .scrum/state.json found. Begin by starting a Requirements Sprint to define the Product Goal and gather requirements."
  }'
fi
