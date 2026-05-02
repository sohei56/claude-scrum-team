#!/usr/bin/env bash
# fake-codex.sh — test stub mimicking `codex review` for integration tests.
# Usage:
#   fake-codex.sh review --uncommitted --ephemeral \
#     --instructions <file> -o <output_file>
# Behavior: writes a deterministic PASS verdict to the output file.
# Override behavior via FAKE_CODEX_VERDICT (PASS or FAIL) and
# FAKE_CODEX_FINDINGS (newline-separated "signature|severity|criterion|description").
set -euo pipefail

# Find the -o flag value
output=""
prev=""
for arg in "$@"; do
  if [ "$prev" = "-o" ]; then
    output="$arg"
    break
  fi
  prev="$arg"
done
[ -n "$output" ] || { echo "fake-codex: missing -o" >&2; exit 1; }

verdict="${FAKE_CODEX_VERDICT:-PASS}"

{
  echo "## Review: fake-codex stub"
  echo ""
  echo "**Verdict: $verdict**"
  echo ""
  echo "### Findings"
  if [ -n "${FAKE_CODEX_FINDINGS:-}" ]; then
    n=0
    while IFS='|' read -r _sig sev crit desc; do
      n=$((n+1))
      echo "- #$n [$sev] [stub] [$crit] — $desc"
    done <<< "$FAKE_CODEX_FINDINGS"
  else
    echo "No findings."
  fi
  echo ""
  echo "### Summary"
  echo "Stub review: $verdict"
  echo ""
  echo '```json'
  if [ -n "${FAKE_CODEX_FINDINGS:-}" ]; then
    findings_json="$(echo "$FAKE_CODEX_FINDINGS" | jq -Rsn '
      [inputs | select(. != "") | split("|") | {
        signature: .[0], severity: .[1], criterion_key: .[2],
        file_path: (.[0] | split(":")[0]),
        line_start: 1, line_end: 1,
        description: .[3]
      }]
    ')"
  else
    findings_json="[]"
  fi
  jq -n --arg v "$verdict" --argjson findings "$findings_json" '{
    status: (if $v == "PASS" then "pass" else "fail" end),
    summary: ("Stub review: " + $v),
    verdict: $v,
    findings: $findings,
    next_actions: [],
    artifacts: []
  }'
  echo '```'
} > "$output"

exit 0
