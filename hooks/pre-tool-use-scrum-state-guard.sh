#!/usr/bin/env bash
# pre-tool-use-scrum-state-guard.sh — PreToolUse hook.
# Blocks agent edits to .scrum/**/*.json that bypass scripts/scrum/.
# Stdin payload: JSON {tool_name, tool_input.{file_path,command,...}, ...}.
# Exit 2 = block (with stderr message). Exit 0 = allow.
#
# Fail-open principle: any unexpected input, unknown tool, missing fields → allow.
# Better to miss enforcement than to break unrelated tool calls.
set -euo pipefail

block() {
  echo "[scrum-guard] BLOCKED: $1. Use scripts/scrum/* instead. See docs/MIGRATION-scrum-state-tools.md." >&2
  exit 2
}

# Read payload defensively
payload="$(cat)"
[ -n "$payload" ] || exit 0

# Extract tool_name; bail to allow if missing
tool="$(printf '%s' "$payload" | jq -r '.tool_name // empty' 2>/dev/null || true)"
[ -n "$tool" ] || exit 0

case "$tool" in
  Write|Edit|MultiEdit)
    file="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null || true)"
    [ -n "$file" ] || exit 0
    # Strip leading $PWD for relative comparison
    rel="${file#"$PWD"/}"
    # Note: bash `case` glob `*` matches `/`, so `.scrum/*.json` covers nested paths
    # like `.scrum/pbi/pbi-001/state.json` too.
    case "$rel" in
      .scrum/*.json) block "$tool $rel" ;;
    esac
    ;;
  Bash)
    cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // empty' 2>/dev/null || true)"
    [ -n "$cmd" ] || exit 0

    # Whitelist: any invocation of scripts/scrum/* is allowed unconditionally
    if [[ "$cmd" == *"scripts/scrum/"* ]]; then
      exit 0
    fi

    # Block redirects/in-place edits targeting .scrum/*.json
    # Patterns we treat as raw writes:
    #   X > .scrum/foo.json
    #   X >> .scrum/foo.json
    #   X | tee .scrum/foo.json
    #   X | sponge .scrum/foo.json
    #   jq -i ... .scrum/foo.json
    #   sed -i ... .scrum/foo.json
    if [[ "$cmd" =~ (\>\>?|tee|sponge)[[:space:]]+\.scrum/[^[:space:]]*\.json ]]; then
      block "raw redirect to .scrum json from Bash"
    fi
    if [[ "$cmd" =~ jq[[:space:]]+-i.*\.scrum/[^[:space:]]*\.json ]]; then
      block "jq -i in-place edit on .scrum json"
    fi
    if [[ "$cmd" =~ sed[[:space:]]+-i.*\.scrum/[^[:space:]]*\.json ]]; then
      block "sed -i in-place edit on .scrum json"
    fi
    # Also block `mv X.json.tmp .scrum/X.json` — common second half of jq-redirect-then-rename pattern
    if [[ "$cmd" =~ mv[[:space:]]+[^[:space:]]+[[:space:]]+\.scrum/[^[:space:]]*\.json ]]; then
      block "mv into .scrum json from Bash (use scripts/scrum/* wrapper)"
    fi
    ;;
  *)
    : # other tools (Read, Grep, Glob, ...) allowed
    ;;
esac

exit 0
