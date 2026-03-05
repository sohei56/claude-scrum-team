#!/usr/bin/env bash
# phase-gate.sh — PreToolUse hook
# Gates tools by current Scrum phase and enforces design catalog governance.
# Reads .scrum/state.json for the current phase, .design/catalog.md for
# governance, and the hook event JSON (Claude Code PreToolUse payload) from
# stdin. Outputs a permissionDecision JSON object.
set -euo pipefail

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/validate.sh
. "$HOOK_DIR/lib/validate.sh"

STATE_FILE=".scrum/state.json"
CATALOG_FILE=".design/catalog.md"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

allow() {
  jq -n '{"decision": "allow"}'
  exit 0
}

deny() {
  local reason="$1"
  log_hook "phase-gate" "WARN" "Denied: $reason"
  jq -n --arg r "$reason" '{"decision": "deny", "reason": $r}'
  exit 0
}

# shellcheck disable=SC2317,SC2329 # called indirectly by future phase rules
ask() {
  jq -n '{"decision": "ask"}'
  exit 0
}

# Check whether a file path targets source code (not metadata / config).
# Source files live outside .scrum/, .design/, specs/, agents/, skills/,
# hooks/, scripts/, dashboard/, tests/, and common dot-directories.
is_source_file() {
  local path="$1"
  case "$path" in
    .scrum/*|.design/*|specs/*|agents/*|skills/*|hooks/*|scripts/*|dashboard/*|tests/*) return 1 ;;
    .git/*|.claude/*|.specify/*|.github/*) return 1 ;;
    *.md|*.json|*.yaml|*.yml|*.toml|*.cfg|*.ini|*.editorconfig|LICENSE*|.gitignore|.gitmodules|.shellcheckrc) return 1 ;;
    *) return 0 ;;
  esac
}

# Check whether a target path is under .design/specs/
is_design_spec_path() {
  local path="$1"
  case "$path" in
    .design/specs/*) return 0 ;;
    *) return 1 ;;
  esac
}

# Check whether a filename has a matching enabled catalog entry.
# Catalog entries are in markdown table rows: | ID | Name | enabled | ...
# We check if the catalog file contains an "enabled" row.  Design spec files
# follow the pattern: .design/specs/{category}/{id}-{slug}.md
# We extract the ID prefix (e.g. "S-001") and look for it in catalog.md.
has_enabled_catalog_entry() {
  local path="$1"
  if [ ! -f "$CATALOG_FILE" ]; then
    return 1
  fi

  # Extract filename from path: e.g. S-001-system-architecture.md
  local filename
  filename="$(basename "$path")"

  # Extract the spec ID prefix (everything before the second hyphen group,
  # e.g. "S-001" from "S-001-system-architecture.md" or "D-001" from
  # "D-001-architecture-decision-record.md").
  local spec_id
  spec_id="$(echo "$filename" | sed -E 's/^([A-Z]+-[0-9]+)-.*/\1/')"

  if [ -z "$spec_id" ] || [ "$spec_id" = "$filename" ]; then
    # Could not parse a spec ID — fail closed
    return 1
  fi

  # Look for a table row containing the spec_id and "enabled"
  # Grep returns 0 if found, 1 if not found
  if grep -qE "\\|\\s*${spec_id}\\s*\\|.*\\|\\s*enabled\\s*\\|" "$CATALOG_FILE" 2>/dev/null; then
    return 0
  fi

  return 1
}

# Extract target file path from tool_input JSON.
# For Write/Edit tools, the path is in "file_path".
# For Bash tool, we cannot reliably parse — return empty.
get_target_path() {
  local tool_name="$1"
  local tool_input="$2"

  case "$tool_name" in
    Write|Edit)
      echo "$tool_input" | jq -r '.file_path // empty' 2>/dev/null
      ;;
    *)
      echo ""
      ;;
  esac
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# Read hook event JSON from stdin
hook_event="$(cat)"

tool_name="$(echo "$hook_event" | jq -r '.tool_name // empty')"
tool_input="$(echo "$hook_event" | jq -c '.tool_input // {}')"

# If state file does not exist, allow everything (project not initialized)
if [ ! -f "$STATE_FILE" ]; then
  allow
fi

# Read phase from state file — allow if file is unreadable (race condition
# with concurrent writes, or file is being created for the first time)
phase="$(jq -r '.phase // "unknown"' "$STATE_FILE" 2>/dev/null)" || allow

# Get the target file path (if determinable)
target_path="$(get_target_path "$tool_name" "$tool_input")"

# Normalize target_path: strip leading "./" or absolute prefix pointing to cwd
if [ -n "$target_path" ]; then
  target_path="${target_path#./}"
  # Strip absolute path prefix if it matches the working directory
  local_cwd="$(pwd)"
  target_path="${target_path#"${local_cwd}"/}"
fi

# ---------------------------------------------------------------------------
# Phase gating rules
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# Source code gating: only implementation and review phases allow source edits
# ---------------------------------------------------------------------------

if [ "$tool_name" = "Write" ] || [ "$tool_name" = "Edit" ]; then
  if [ -n "$target_path" ] && is_source_file "$target_path"; then
    case "$phase" in
      implementation|review)
        # Allowed — these are the only phases where source code may be modified
        ;;
      *)
        deny "$phase phase: source code changes are not allowed. Work on source code is only permitted during implementation and review phases. If you found a defect, report it to the Scrum Master to create a PBI."
        ;;
    esac
  fi
fi

# ---------------------------------------------------------------------------
# Phase-specific rules
# ---------------------------------------------------------------------------

case "$phase" in
  design)
    # During design phase, deny Write/Edit under .design/specs/
    # if the target file has no enabled catalog entry
    if [ "$tool_name" = "Write" ] || [ "$tool_name" = "Edit" ]; then
      if [ -n "$target_path" ] && is_design_spec_path "$target_path"; then
        if ! has_enabled_catalog_entry "$target_path"; then
          deny "Design phase: cannot write to '$target_path' — no enabled catalog entry found in .design/catalog.md. Enable the spec in the catalog first."
        fi
      fi
    fi

    allow
    ;;

  *)
    # Default: allow (source code gating already handled above)
    allow
    ;;
esac
