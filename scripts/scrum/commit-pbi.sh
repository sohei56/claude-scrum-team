#!/usr/bin/env bash
# scripts/scrum/commit-pbi.sh — Developer-side commit wrapper for the PBI worktree.
# Verifies branch == pbi/<id> before committing. Updates state.head_sha after.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/errors.sh
source "$HERE/lib/errors.sh"
# shellcheck source=lib/queries.sh
source "$HERE/lib/queries.sh"

[ "$#" -eq 2 ] || fail E_INVALID_ARG "usage: commit-pbi.sh <pbi-id> <message>"
PBI="$1"; MSG="$2"
case "$PBI" in
  pbi-[0-9]*) ;;
  *) fail E_INVALID_ARG "bad pbi-id: $PBI" ;;
esac

read_pbi_worktree_state "$PBI"
assert_pbi_worktree_branch "$PBI_WT" "$PBI_BRANCH"

# Exclude the .scrum symlink that create-pbi-worktree.sh installs back to the
# main repo SSOT. Without this, `add -A` would stage it (gitignore's `.scrum/`
# pattern matches directories only, not symlinks of git type 120000) and the
# symlink would propagate to main on merge.
git -C "$PBI_WT" add -A -- ':!.scrum'
if git -C "$PBI_WT" diff --cached --quiet; then
  printf '[commit-pbi] nothing to commit\n'
  exit 0
fi
git -C "$PBI_WT" commit -m "$MSG" >/dev/null

NEW_HEAD="$(git -C "$PBI_WT" rev-parse HEAD)"
"$HERE/update-pbi-state.sh" "$PBI" head_sha "$NEW_HEAD"
printf '[commit-pbi] %s @ %s\n' "$PBI" "$NEW_HEAD"
