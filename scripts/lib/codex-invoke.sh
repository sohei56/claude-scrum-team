#!/usr/bin/env bash
# codex-invoke.sh — shared Codex CLI invocation helper.
# Sourced by codex-* reviewer agents (codex-design-reviewer,
# codex-impl-reviewer, codex-ut-reviewer) AND by the PBI pipeline
# conductor as a spawn-time preflight (codex_is_available).
#
# Usage:
#   source scripts/lib/codex-invoke.sh
#   codex_review_or_fallback <instructions_file> <output_file>
#   codex_is_available && echo "codex present"
# Returns:
#   codex_review_or_fallback: 0 on success, 1 when codex unavailable
#   codex_is_available:       0 when codex present, 1 when absent
#
# Honors CODEX_CMD_OVERRIDE for testing (path to a stub binary).

codex_is_available() {
  local cmd="${CODEX_CMD_OVERRIDE:-codex}"
  command -v "$cmd" >/dev/null 2>&1
}

codex_review_or_fallback() {
  local instructions=$1
  local output=$2
  local cmd="${CODEX_CMD_OVERRIDE:-codex}"

  if ! codex_is_available; then
    return 1
  fi

  "$cmd" review --uncommitted --ephemeral \
    --instructions "$instructions" \
    -o "$output" 2>&1 || return 1

  [ -s "$output" ] || return 1
  return 0
}
