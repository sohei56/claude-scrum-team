#!/usr/bin/env bats
# tests/unit/scrum-state/test_update-sprint-status.bats

load lib/helpers.bash

setup() {
  scrum_state_setup sprint.schema.json valid-sprint.json sprint.json upd-sprint-status
}

teardown() {
  scrum_state_teardown
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
