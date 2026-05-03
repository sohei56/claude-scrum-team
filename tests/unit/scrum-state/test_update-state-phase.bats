#!/usr/bin/env bats
# tests/unit/scrum-state/test_update-state-phase.bats

setup() {
  export SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  TEST_TMP="$(mktemp -d /tmp/claude/upd-state-phase.XXXXXX 2>/dev/null || mktemp -d "${TMPDIR:-/tmp}/upd-state-phase.XXXXXX")"
  cd "$TEST_TMP" || exit 1
  mkdir -p .scrum docs/contracts/scrum-state
  cp "$PROJECT_ROOT/docs/contracts/scrum-state/state.schema.json" docs/contracts/scrum-state/
  cp "$PROJECT_ROOT/tests/fixtures/valid-state.json" .scrum/state.json
}

teardown() {
  if [ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ]; then
    rm -rf "$TEST_TMP"
  fi
}

@test "update-state-phase: implementation → review" {
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-state-phase.sh" review
  [ "$status" -eq 0 ]
  run jq -r '.phase' "$TEST_TMP/.scrum/state.json"
  [ "$output" = "review" ]
}

@test "update-state-phase: accepts pbi_pipeline_active" {
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-state-phase.sh" pbi_pipeline_active
  [ "$status" -eq 0 ]
  run jq -r '.phase' "$TEST_TMP/.scrum/state.json"
  [ "$output" = "pbi_pipeline_active" ]
}

@test "update-state-phase: rejects bogus phase" {
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-state-phase.sh" giga_review
  [ "$status" -eq 64 ]
}

@test "update-state-phase: requires exactly one arg" {
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-state-phase.sh"
  [ "$status" -eq 64 ]
}
