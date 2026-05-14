#!/usr/bin/env bash
# scripts/scrum/mark-pbi-ready-to-merge.sh — Developer-side handoff wrapper.
# Computes paths_touched (base..HEAD), atomically sets head_sha/ready_at/
# paths_touched on pbi-state.json, then sets backlog status to in_progress_merge.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=lib/errors.sh
source "$HERE/lib/errors.sh"
# shellcheck source=lib/atomic.sh
source "$HERE/lib/atomic.sh"
# shellcheck source=lib/queries.sh
source "$HERE/lib/queries.sh"

[ "$#" -eq 1 ] || fail E_INVALID_ARG "usage: mark-pbi-ready-to-merge.sh <pbi-id>"
PBI="$1"
case "$PBI" in pbi-[0-9]*) ;; *) fail E_INVALID_ARG "bad pbi-id: $PBI" ;; esac

read_pbi_worktree_state "$PBI"
[ -n "$PBI_BASE_SHA" ] || fail E_INVALID_ARG "state.base_sha unset"
STATE=".scrum/pbi/$PBI/state.json"

HEAD="$(git -C "$PBI_WT" rev-parse HEAD)"
PATHS=()
# --diff-filter=AMR: include Added, Modified, Renamed paths only.
# Excluding Deleted paths prevents `merge-pbi.sh` artifact_missing
# false-positives when a PBI intentionally deletes files (the deleted
# paths would otherwise be recorded in `paths_touched` and then trip
# the `git ls-files --error-unmatch` artifact check post-merge).
while IFS= read -r line; do
  PATHS+=("$line")
done < <(git -C "$PBI_WT" diff --name-only --diff-filter=AMR "$PBI_BASE_SHA..HEAD")
if [ "${#PATHS[@]}" -eq 0 ]; then
  fail E_INVALID_ARG "no commits beyond base — refusing to mark ready_to_merge"
fi

# Build paths_touched array literal for jq.
PATHS_JSON="$(printf '%s\n' "${PATHS[@]}" | jq -R . | jq -s .)"
NOW="$(_iso_utc_now)"

EXPR=".head_sha = \"$HEAD\""
EXPR="$EXPR | .ready_at = \"$NOW\""
EXPR="$EXPR | .paths_touched = $PATHS_JSON"

atomic_write "$STATE" "$EXPR" "$ROOT/docs/contracts/scrum-state/pbi-state.schema.json"

# Update backlog status to in_progress_merge (silently skip if PBI not in backlog).
BACKLOG=".scrum/backlog.json"
if pbi_in_backlog "$PBI" "$BACKLOG"; then
  "$HERE/update-backlog-status.sh" "$PBI" in_progress_merge
fi

printf '[mark-pbi-ready-to-merge] %s @ %s (%d paths)\n' "$PBI" "$HEAD" "${#PATHS[@]}"
