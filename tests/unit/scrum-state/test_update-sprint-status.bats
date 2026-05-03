#!/usr/bin/env bats
# tests/unit/scrum-state/test_update-sprint-status.bats

setup() {
  export SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  TEST_TMP="$(mktemp -d /tmp/claude/upd-sprint-status.XXXXXX 2>/dev/null || mktemp -d "${TMPDIR:-/tmp}/upd-sprint-status.XXXXXX")"
  cd "$TEST_TMP" || exit 1
  mkdir -p .scrum docs/contracts/scrum-state
  cp "$PROJECT_ROOT/docs/contracts/scrum-state/sprint.schema.json" docs/contracts/scrum-state/
  cp "$PROJECT_ROOT/tests/fixtures/valid-sprint.json" .scrum/sprint.json
}

teardown() {
  if [ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ]; then
    rm -rf "$TEST_TMP"
  fi
}

@test "update-sprint-status: active → cross_review" {
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-sprint-status.sh" cross_review
  [ "$status" -eq 0 ]
  run jq -r '.status' "$TEST_TMP/.scrum/sprint.json"
  [ "$output" = "cross_review" ]
}

@test "update-sprint-status: accepts failed" {
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-sprint-status.sh" failed
  [ "$status" -eq 0 ]
  run jq -r '.status' "$TEST_TMP/.scrum/sprint.json"
  [ "$output" = "failed" ]
}

@test "update-sprint-status: rejects unknown status" {
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-sprint-status.sh" frobnicating
  [ "$status" -eq 64 ]
}

@test "update-sprint-status: requires exactly one arg" {
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-sprint-status.sh"
  [ "$status" -eq 64 ]
}
