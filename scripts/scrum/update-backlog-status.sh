#!/usr/bin/env bash
# scripts/scrum/update-backlog-status.sh — set a PBI's status in .scrum/backlog.json.
# Usage: update-backlog-status.sh <pbi-id> <status>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=lib/errors.sh
source "$HERE/lib/errors.sh"
# shellcheck source=lib/atomic.sh
source "$HERE/lib/atomic.sh"

[ "$#" -eq 2 ] || fail E_INVALID_ARG "usage: update-backlog-status.sh <pbi-id> <status>"
PBI="$1"; STATUS="$2"
case "$PBI" in pbi-[0-9]*) ;; *) fail E_INVALID_ARG "bad pbi-id: $PBI" ;; esac
case "$STATUS" in
  draft|refined|in_progress|review|done|blocked) ;;
  *) fail E_INVALID_ARG "bad status: $STATUS" ;;
esac

PATHF=".scrum/backlog.json"
SCHEMA="$ROOT/docs/contracts/scrum-state/backlog.schema.json"

# Pre-check existence of the pbi-id (atomic_write cannot tell us "not found")
jq -e --arg id "$PBI" '.items | map(select(.id==$id)) | length > 0' "$PATHF" >/dev/null \
  || fail E_INVALID_ARG "pbi not found: $PBI"

atomic_write "$PATHF" \
  "(.items[] | select(.id == \"$PBI\")).status = \"$STATUS\"" \
  "$SCHEMA"
