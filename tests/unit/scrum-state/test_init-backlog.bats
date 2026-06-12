#!/usr/bin/env bats
# tests/unit/scrum-state/test_init-backlog.bats — bootstrap .scrum/backlog.json.

setup() {
  export SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  TEST_TMP="$(mktemp -d /tmp/claude/init-backlog.XXXXXX 2>/dev/null || mktemp -d "${TMPDIR:-/tmp}/init-backlog.XXXXXX")"
  cd "$TEST_TMP" || exit 1
  mkdir -p docs/contracts/scrum-state
  cp "$PROJECT_ROOT/docs/contracts/scrum-state/backlog.schema.json" docs/contracts/scrum-state/
}

teardown() {
  if [ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ]; then
    rm -rf "$TEST_TMP"
  fi
}

@test "init-backlog: creates backlog.json with empty items and next_pbi_id=1" {
  run "$PROJECT_ROOT/scripts/scrum/init-backlog.sh"
  [ "$status" -eq 0 ]
  [ -f "$TEST_TMP/.scrum/backlog.json" ]
  run jq -r '.items | length' "$TEST_TMP/.scrum/backlog.json"
  [ "$output" = "0" ]
  run jq -r '.next_pbi_id' "$TEST_TMP/.scrum/backlog.json"
  [ "$output" = "1" ]
  run jq -r '.product_goal' "$TEST_TMP/.scrum/backlog.json"
  [ "$output" = "null" ]
}

@test "init-backlog: --product-goal sets the field" {
  run "$PROJECT_ROOT/scripts/scrum/init-backlog.sh" --product-goal "Build an e-commerce platform"
  [ "$status" -eq 0 ]
  run jq -r '.product_goal' "$TEST_TMP/.scrum/backlog.json"
  [ "$output" = "Build an e-commerce platform" ]
}

@test "init-backlog: output is schema-valid (add-backlog-item succeeds afterwards)" {
  run "$PROJECT_ROOT/scripts/scrum/init-backlog.sh" --product-goal "x"
  [ "$status" -eq 0 ]
  run "$PROJECT_ROOT/scripts/scrum/add-backlog-item.sh" --title "first PBI"
  [ "$status" -eq 0 ]
  [ "$output" = "pbi-001" ]
  run jq -r '.next_pbi_id' "$TEST_TMP/.scrum/backlog.json"
  [ "$output" = "2" ]
}

@test "init-backlog: idempotent — second run exits 0 and does not overwrite" {
  "$PROJECT_ROOT/scripts/scrum/init-backlog.sh" --product-goal "first"
  before="$(cat "$TEST_TMP/.scrum/backlog.json")"
  run "$PROJECT_ROOT/scripts/scrum/init-backlog.sh" --product-goal "second"
  [ "$status" -eq 0 ]
  after="$(cat "$TEST_TMP/.scrum/backlog.json")"
  [ "$before" = "$after" ]
  [[ "$output" == *"already exists"* ]]
}

@test "init-backlog: never overwrites an existing file with different content" {
  mkdir -p .scrum
  cat > .scrum/backlog.json <<'JSON'
{
  "items": [
    {"id": "pbi-007", "title": "preserved", "status": "refined"}
  ],
  "next_pbi_id": 8,
  "product_goal": "do not clobber"
}
JSON
  before="$(cat .scrum/backlog.json)"
  run "$PROJECT_ROOT/scripts/scrum/init-backlog.sh" --product-goal "ignored"
  [ "$status" -eq 0 ]
  after="$(cat .scrum/backlog.json)"
  [ "$before" = "$after" ]
}

@test "init-backlog: rejects unknown flag with E_INVALID_ARG" {
  run "$PROJECT_ROOT/scripts/scrum/init-backlog.sh" --bogus value
  [ "$status" -eq 64 ]
}

@test "init-backlog: --product-goal without value fails E_INVALID_ARG" {
  run "$PROJECT_ROOT/scripts/scrum/init-backlog.sh" --product-goal
  [ "$status" -eq 64 ]
}
