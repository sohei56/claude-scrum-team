#!/usr/bin/env bash
# scripts/scrum/update-sprint-status.sh — set status in .scrum/sprint.json.
# Usage: update-sprint-status.sh <status>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=lib/errors.sh
source "$HERE/lib/errors.sh"
# shellcheck source=lib/atomic.sh
source "$HERE/lib/atomic.sh"

[ "$#" -eq 1 ] || fail E_INVALID_ARG "usage: update-sprint-status.sh <status>"
STATUS="$1"
case "$STATUS" in
  planning|active|cross_review|sprint_review|complete|failed) ;;
  *) fail E_INVALID_ARG "bad status: $STATUS" ;;
esac

atomic_write ".scrum/sprint.json" \
  ".status = \"$STATUS\"" \
  "$ROOT/docs/contracts/scrum-state/sprint.schema.json"
