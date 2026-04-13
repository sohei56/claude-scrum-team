#!/usr/bin/env bash
# phase-gate.sh — PreToolUse hook
# Gates tools by current Scrum phase and enforces design catalog governance.
# Reads .scrum/state.json for the current phase, .design/catalog.md for
# document type validation, .design/catalog-config.json for enablement state,
# and the hook event JSON (Claude Code PreToolUse payload) from stdin.
# Outputs a permissionDecision JSON object.
set -euo pipefail

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/validate.sh
. "$HOOK_DIR/lib/validate.sh"

STATE_FILE=".scrum/state.json"
CATALOG_FILE=".design/catalog.md"
CONFIG_FILE=".design/catalog-config.json"

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
# Source files live outside .scrum/, .design/, docs/, agents/, skills/,
# hooks/, scripts/, dashboard/, tests/, and common dot-directories.
is_source_file() {
  local path="$1"
  case "$path" in
    .scrum/*|.design/*|docs/*|agents/*|skills/*|hooks/*|scripts/*|dashboard/*|tests/*) return 1 ;;
    .git/*|.claude/*|.github/*) return 1 ;;
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

# Check whether a spec ID exists in catalog.md (any table row).
# Design spec files follow the pattern: .design/specs/{category}/{id}-{slug}.md
# We extract the ID prefix (e.g. "S-001") and look for it in catalog.md.
has_catalog_entry() {
  local path="$1"
  if [ ! -f "$CATALOG_FILE" ]; then
    return 1
  fi

  local filename spec_id
  filename="$(basename "$path")"
  spec_id="$(echo "$filename" | sed -E 's/^([A-Z]+-[0-9]+)-.*/\1/')"

  if [ -z "$spec_id" ] || [ "$spec_id" = "$filename" ]; then
    return 1
  fi

  # Check if spec ID appears in any catalog table row
  if grep -qE "\\|\\s*${spec_id}\\s*\\|" "$CATALOG_FILE" 2>/dev/null; then
    return 0
  fi

  return 1
}

# Check whether a spec ID is enabled in catalog-config.json.
is_enabled_in_config() {
  local path="$1"
  if [ ! -f "$CONFIG_FILE" ]; then
    return 1
  fi

  local filename spec_id
  filename="$(basename "$path")"
  spec_id="$(echo "$filename" | sed -E 's/^([A-Z]+-[0-9]+)-.*/\1/')"

  if [ -z "$spec_id" ] || [ "$spec_id" = "$filename" ]; then
    return 1
  fi

  # Check if spec_id is in the enabled array
  if jq -e --arg id "$spec_id" '.enabled | index($id) != null' "$CONFIG_FILE" >/dev/null 2>&1; then
    return 0
  fi

  return 1
}

# shellcheck disable=SC2317,SC2329 # kept for external use and testability
has_enabled_catalog_entry() {
  local path="$1"
  has_catalog_entry "$path" && is_enabled_in_config "$path"
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

# Fast path: only Write/Edit tools are gated. All others→allow immediately.
# This avoids reading state.json, catalog.md, catalog-config.json on every
# Read/Grep/Glob/Bash call — the biggest hook overhead source.
if [ "$tool_name" != "Write" ] && [ "$tool_name" != "Edit" ]; then
  allow
fi

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
# From here: only Write/Edit tools reach this code (fast path above).
# ---------------------------------------------------------------------------

# No target path determinable (e.g. Bash tool) — allow
if [ -z "$target_path" ]; then
  allow
fi

# Source code gating: only implementation and review phases allow source edits
if is_source_file "$target_path"; then
  case "$phase" in
    implementation|review) ;;
    *) deny "$phase phase: source code changes not allowed. Only permitted during implementation/review." ;;
  esac
fi

# Catalog governance: catalog.md is read-only
case "$target_path" in
  .design/catalog.md)
    deny "catalog.md is read-only. Update .design/catalog-config.json instead." ;;
esac

# Design spec governance: require catalog entry + enabled config
if is_design_spec_path "$target_path"; then
  if ! has_catalog_entry "$target_path"; then
    deny "Cannot write '$target_path' — no matching entry in .design/catalog.md."
  fi
  if ! is_enabled_in_config "$target_path"; then
    deny "Cannot write '$target_path' — not enabled in .design/catalog-config.json."
  fi
fi

# All specific gating handled above — allow everything else
allow
