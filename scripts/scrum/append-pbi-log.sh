#!/usr/bin/env bash
# scripts/scrum/append-pbi-log.sh — append one line to .scrum/pbi/<pbi-id>/pipeline.log.
# Usage: append-pbi-log.sh <pbi-id> <phase> <round> <event> <detail>
# Format: <ISO8601-UTC>\t<phase>\t<round>\t<event>\t<detail>
# Note: short writes (<4KB total) are line-atomic per POSIX; longer details may interleave.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/errors.sh
source "$HERE/lib/errors.sh"

[ "$#" -eq 5 ] || fail E_INVALID_ARG "usage: append-pbi-log.sh <pbi-id> <phase> <round> <event> <detail>"
PBI="$1"; PHASE="$2"; ROUND="$3"; EVENT="$4"; DETAIL="$5"

case "$PBI" in
  pbi-[0-9]*) ;;
  *) fail E_INVALID_ARG "bad pbi-id: $PBI" ;;
esac
case "$PHASE" in
  init|design|impl_ut|complete|escalated) ;;
  *) fail E_INVALID_ARG "bad phase: $PHASE" ;;
esac
case "$ROUND" in
  ''|*[!0-9]*) fail E_INVALID_ARG "round must be non-negative integer (got: $ROUND)" ;;
esac

LOGF=".scrum/pbi/$PBI/pipeline.log"
mkdir -p "$(dirname "$LOGF")"
ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
printf '%s\t%s\t%s\t%s\t%s\n' "$ts" "$PHASE" "$ROUND" "$EVENT" "$DETAIL" >> "$LOGF"
