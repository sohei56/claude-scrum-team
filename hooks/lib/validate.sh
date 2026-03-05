#!/usr/bin/env bash
# validate.sh — Shared helpers for hooks: JSON validation and logging
# Sourced by hooks that parse .scrum/ state files.

# Guard against double-sourcing
# shellcheck disable=SC2317
if [ "${_VALIDATE_SH_LOADED:-}" = "1" ]; then
  return 0 2>/dev/null || true
fi
_VALIDATE_SH_LOADED=1

HOOK_LOG_FILE=".scrum/hooks.log"
HOOK_LOG_MAX_LINES=500

# Log a timestamped message to .scrum/hooks.log
# Usage: log_hook <hook_name> <level> <message>
# Levels: INFO, WARN, ERROR
log_hook() {
  local hook_name="$1"
  local level="$2"
  local message="$3"

  # Ensure .scrum directory exists
  if [ ! -d ".scrum" ]; then
    mkdir -p ".scrum"
  fi

  local ts
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "unknown")"

  printf '%s [%s] %s: %s\n' "$ts" "$level" "$hook_name" "$message" >> "$HOOK_LOG_FILE"

  # Trim log to max lines (keep newest)
  if [ -f "$HOOK_LOG_FILE" ]; then
    local line_count
    line_count="$(wc -l < "$HOOK_LOG_FILE" | tr -d ' ')"
    if [ "$line_count" -gt "$HOOK_LOG_MAX_LINES" ]; then
      local tmp_log="${HOOK_LOG_FILE}.tmp.$$"
      tail -n "$HOOK_LOG_MAX_LINES" "$HOOK_LOG_FILE" > "$tmp_log" && mv "$tmp_log" "$HOOK_LOG_FILE"
    fi
  fi
}

# Validate that a JSON file exists, is valid JSON, and contains required fields.
# Usage: validate_json_file <file> <field1> [field2 ...]
# Returns 0 if valid, 1 if invalid (prints warning to stderr).
validate_json_file() {
  local file="$1"
  shift

  if [ ! -f "$file" ]; then
    echo "[validate] WARNING: $file does not exist." >&2
    return 1
  fi

  if ! jq empty "$file" 2>/dev/null; then
    echo "[validate] WARNING: $file contains invalid JSON." >&2
    log_hook "validate" "ERROR" "$file contains invalid JSON"
    return 1
  fi

  local field
  for field in "$@"; do
    if ! jq -e "has(\"$field\")" "$file" >/dev/null 2>&1; then
      echo "[validate] WARNING: $file missing required field '$field'." >&2
      log_hook "validate" "WARN" "$file missing required field '$field'"
      return 1
    fi
  done

  return 0
}
