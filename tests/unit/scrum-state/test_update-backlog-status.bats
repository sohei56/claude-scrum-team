#!/usr/bin/env bats
# tests/unit/scrum-state/test_update-backlog-status.bats

setup() {
  export SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  TEST_TMP="$(mktemp -d /tmp/claude/upd-backlog-status.XXXXXX 2>/dev/null || mktemp -d "${TMPDIR:-/tmp}/upd-backlog-status.XXXXXX")"
  cd "$TEST_TMP" || exit 1
  mkdir -p .scrum docs/contracts/scrum-state
  cp "$PROJECT_ROOT/docs/contracts/scrum-state/backlog.schema.json" docs/contracts/scrum-state/
  cp "$PROJECT_ROOT/tests/fixtures/valid-backlog.json" .scrum/backlog.json
}

teardown() {
  if [ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ]; then
    rm -rf "$TEST_TMP"
  fi
}

@test "update-backlog-status: accepts pre-pipeline status (draft)" {
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-backlog-status.sh" pbi-001 draft
  [ "$status" -eq 0 ]
  run jq -r '.items[] | select(.id=="pbi-001").status' "$TEST_TMP/.scrum/backlog.json"
  [ "$output" = "draft" ]
}

@test "update-backlog-status: accepts pre-pipeline status (refined)" {
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-backlog-status.sh" pbi-001 refined
  [ "$status" -eq 0 ]
  run jq -r '.items[] | select(.id=="pbi-001").status' "$TEST_TMP/.scrum/backlog.json"
  [ "$output" = "refined" ]
}

@test "update-backlog-status: rejects post-pipeline status (in_progress) without override" {
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-backlog-status.sh" pbi-001 in_progress
  [ "$status" -eq 64 ]
  [[ "$output" == *"post-pipeline"* ]]
  [[ "$output" == *"update-pbi-state.sh"* ]]
}

@test "update-backlog-status: rejects post-pipeline status (done) without override" {
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-backlog-status.sh" pbi-001 done
  [ "$status" -eq 64 ]
}

@test "update-backlog-status: accepts post-pipeline status with SCRUM_ALLOW_POST_PIPELINE_STATUS=1 (escape hatch)" {
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli SCRUM_ALLOW_POST_PIPELINE_STATUS=1 \
    "$PROJECT_ROOT/scripts/scrum/update-backlog-status.sh" pbi-001 in_progress
  [ "$status" -eq 0 ]
  run jq -r '.items[] | select(.id=="pbi-001").status' "$TEST_TMP/.scrum/backlog.json"
  [ "$output" = "in_progress" ]
}

@test "update-backlog-status: rejects bad status" {
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-backlog-status.sh" pbi-001 wibble
  [ "$status" -eq 64 ]
  [[ "$output" == *"E_INVALID_ARG"* ]]
}

@test "update-backlog-status: rejects bad pbi-id format" {
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-backlog-status.sh" "BAD ID" refined
  [ "$status" -eq 64 ]
}

@test "update-backlog-status: rejects nonexistent pbi-id" {
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-backlog-status.sh" pbi-999 refined
  [ "$status" -eq 64 ]
  [[ "$output" == *"not found"* ]] || [[ "$output" == *"E_INVALID_ARG"* ]]
}

@test "update-backlog-status: requires exactly two args" {
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-backlog-status.sh" pbi-001
  [ "$status" -eq 64 ]
}
