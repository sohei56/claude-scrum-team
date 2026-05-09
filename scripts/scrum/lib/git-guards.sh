#!/usr/bin/env bash
# scripts/scrum/lib/git-guards.sh — pre-flight git invariants shared by
# merge-pbi.sh / merge-main-into-pbi.sh / safe-switch-to-main.sh.
# Requires lib/errors.sh sourced first.

if [ "${_SCRUM_GIT_GUARDS_SH_LOADED:-}" = "1" ]; then
  # shellcheck disable=SC2317
  return 0 2>/dev/null || true
fi
_SCRUM_GIT_GUARDS_SH_LOADED=1

# assert_scrum_untracked
# Refuse to proceed when `.scrum/` is tracked in the main repo's git index.
# Branch switches with tracked `.scrum/` silently delete state files that
# only exist on the current branch — the recovery instruction below is the
# same as the inline checks this helper replaces.
assert_scrum_untracked() {
  if [ -n "$(git ls-files .scrum/ 2>/dev/null)" ]; then
    fail E_INVALID_ARG ".scrum/ is tracked in git — runtime state must stay untracked. Recover with: git rm -r --cached .scrum/ && echo '.scrum/' >> .gitignore"
  fi
}

# assert_clean_worktree [-C <dir>] [hint]
# Refuse if the (specified) worktree has staged/modified/deleted tracked-file
# changes. Untracked files are ignored — `.scrum/` is untracked by design.
# Without `-C <dir>`, checks the current worktree. `hint` is an optional
# trailing clause appended after " — " to guide the caller's recovery.
assert_clean_worktree() {
  local dir="" hint=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      -C) [ "$#" -ge 2 ] || fail E_INVALID_ARG "assert_clean_worktree -C requires a directory"
          dir="$2"; shift 2 ;;
      *)  hint="$1"; shift ;;
    esac
  done
  local dirty
  if [ -n "$dir" ]; then
    dirty="$(git -C "$dir" status --porcelain | grep -v '^??' || true)"
  else
    dirty="$(git status --porcelain | grep -v '^??' || true)"
  fi
  if [ -n "$dirty" ]; then
    local where="${dir:-working tree}"
    fail E_INVALID_ARG "$where has uncommitted tracked changes${hint:+ — $hint}"
  fi
}
