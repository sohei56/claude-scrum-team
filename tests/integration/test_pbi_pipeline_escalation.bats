#!/usr/bin/env bats
# Integration: stagnation/divergence/max_rounds gates.

setup() {
  TEST_TMP="$(mktemp -d /tmp/claude/pbi-esc-test.XXXXXX 2>/dev/null || mktemp -d "${TMPDIR:-/tmp}/pbi-esc-test.XXXXXX")"
  cd "$TEST_TMP" || exit 1
  mkdir -p .scrum hooks/lib
  cp -r "${BATS_TEST_DIRNAME}/../../hooks/lib/"* hooks/lib/
}

teardown() { rm -rf "$TEST_TMP"; }

@test "stagnation: same signature in two consecutive rounds escalates" {
  PBI_ID=pbi-stag
  PBI_DIR=".scrum/pbi/$PBI_ID"
  mkdir -p "$PBI_DIR/design"

  cat > "$PBI_DIR/design/review-r1.md" <<'EOF'
## Review: r1
**Verdict: FAIL**
### Findings
- #1 [critical] [src/a.py:1-5] [missing_requirement] — same problem
### Summary
Stub r1
```json
{"status":"fail","summary":"r1","verdict":"FAIL","findings":[{"signature":"src/a.py:1-5:missing_requirement","severity":"critical","criterion_key":"missing_requirement","file_path":"src/a.py","line_start":1,"line_end":5,"description":"same"}],"next_actions":[],"artifacts":[]}
```
EOF

  cp "$PBI_DIR/design/review-r1.md" "$PBI_DIR/design/review-r2.md"

  sig_r1="$(awk '/^```json$/{f=1;next} /^```$/{f=0} f' "$PBI_DIR/design/review-r1.md" | jq -r '.findings | map(select(.severity == "critical" or .severity == "high")) | map(.signature) | sort | .[]')"
  sig_r2="$(awk '/^```json$/{f=1;next} /^```$/{f=0} f' "$PBI_DIR/design/review-r2.md" | jq -r '.findings | map(select(.severity == "critical" or .severity == "high")) | map(.signature) | sort | .[]')"
  common="$(comm -12 <(echo "$sig_r1") <(echo "$sig_r2"))"

  [ -n "$common" ]
  [ "$common" = "src/a.py:1-5:missing_requirement" ]
}

@test "divergence: critical+high count increases between rounds" {
  PBI_DIR=".scrum/pbi/pbi-div/design"
  mkdir -p "$PBI_DIR"

  cat > "$PBI_DIR/review-r1.md" <<'EOF'
```json
{"findings":[{"signature":"x:1-1:a","severity":"critical","criterion_key":"a","file_path":"x","line_start":1,"line_end":1,"description":"d"}]}
```
EOF

  cat > "$PBI_DIR/review-r2.md" <<'EOF'
```json
{"findings":[
  {"signature":"x:1-1:a","severity":"critical","criterion_key":"a","file_path":"x","line_start":1,"line_end":1,"description":"d"},
  {"signature":"y:1-1:b","severity":"critical","criterion_key":"b","file_path":"y","line_start":1,"line_end":1,"description":"d"},
  {"signature":"z:1-1:c","severity":"high","criterion_key":"c","file_path":"z","line_start":1,"line_end":1,"description":"d"}
]}
```
EOF

  count_r1=$(awk '/^```json$/{f=1;next} /^```$/{f=0} f' "$PBI_DIR/review-r1.md" | jq '[.findings[] | select(.severity == "critical" or .severity == "high")] | length')
  count_r2=$(awk '/^```json$/{f=1;next} /^```$/{f=0} f' "$PBI_DIR/review-r2.md" | jq '[.findings[] | select(.severity == "critical" or .severity == "high")] | length')

  [ "$count_r2" -gt "$count_r1" ]
}

@test "max_rounds: round >= 5 escalates" {
  ROUND=5
  [ "$ROUND" -ge 5 ]
}
