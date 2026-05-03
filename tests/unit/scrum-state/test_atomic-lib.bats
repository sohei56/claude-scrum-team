#!/usr/bin/env bats
# tests/unit/scrum-state/test_atomic-lib.bats — exercises atomic_write helper.

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  TEST_TMP="$(mktemp -d /tmp/claude/atomic-lib-test.XXXXXX 2>/dev/null || mktemp -d "${TMPDIR:-/tmp}/atomic-lib-test.XXXXXX")"
  cd "$TEST_TMP" || exit 1
  mkdir -p .scrum docs/contracts/scrum-state
  cp "$PROJECT_ROOT/docs/contracts/scrum-state/backlog.schema.json" docs/contracts/scrum-state/
  # Minimal valid-shape backlog for the tests
  printf '{"items":[]}\n' > .scrum/backlog.json
}

teardown() {
  if [ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ]; then
    rm -rf "$TEST_TMP"
  fi
}

@test "atomic_write writes file atomically and validates against schema" {
  run bash -c "cd '$TEST_TMP' && source '$PROJECT_ROOT/scripts/scrum/lib/errors.sh' && source '$PROJECT_ROOT/scripts/scrum/lib/atomic.sh' && atomic_write .scrum/backlog.json '.items += [{\"id\":\"pbi-001\",\"title\":\"x\",\"status\":\"draft\"}]' docs/contracts/scrum-state/backlog.schema.json"
  [ "$status" -eq 0 ]
  run jq -r '.items[0].id' "$TEST_TMP/.scrum/backlog.json"
  [ "$output" = "pbi-001" ]
}

@test "atomic_write rejects schema-invalid result and leaves file untouched" {
  cp "$TEST_TMP/.scrum/backlog.json" "$TEST_TMP/before.json"
  run bash -c "cd '$TEST_TMP' && source '$PROJECT_ROOT/scripts/scrum/lib/errors.sh' && source '$PROJECT_ROOT/scripts/scrum/lib/atomic.sh' && atomic_write .scrum/backlog.json '.items += [{\"id\":\"BAD-ID\",\"title\":\"x\",\"status\":\"draft\"}]' docs/contracts/scrum-state/backlog.schema.json"
  [ "$status" -ne 0 ]
  [[ "$output" == *"E_SCHEMA"* ]]
  run diff "$TEST_TMP/.scrum/backlog.json" "$TEST_TMP/before.json"
  [ "$status" -eq 0 ]
}

@test "atomic_write serializes concurrent writers via mkdir lock" {
  for i in 1 2 3 4 5; do
    bash -c "cd '$TEST_TMP' && source '$PROJECT_ROOT/scripts/scrum/lib/errors.sh' && source '$PROJECT_ROOT/scripts/scrum/lib/atomic.sh' && atomic_write .scrum/backlog.json \".items += [{\\\"id\\\":\\\"pbi-00${i}\\\",\\\"title\\\":\\\"x\\\",\\\"status\\\":\\\"draft\\\"}]\" docs/contracts/scrum-state/backlog.schema.json" &
  done
  wait
  run jq '.items | length' "$TEST_TMP/.scrum/backlog.json"
  [ "$output" = "5" ]
}

@test "atomic_write fails clearly when file does not exist" {
  rm -f "$TEST_TMP/.scrum/backlog.json"
  run bash -c "cd '$TEST_TMP' && source '$PROJECT_ROOT/scripts/scrum/lib/errors.sh' && source '$PROJECT_ROOT/scripts/scrum/lib/atomic.sh' && atomic_write .scrum/backlog.json '.items += []' docs/contracts/scrum-state/backlog.schema.json"
  [ "$status" -eq 67 ]
  [[ "$output" == *"E_FILE_MISSING"* ]]
}

@test "errors.sh fail emits stderr with code and fixed exit" {
  run bash -c "source '$PROJECT_ROOT/scripts/scrum/lib/errors.sh' && fail E_INVALID_ARG 'missing pbi-id'"
  [ "$status" -eq 64 ]
  [[ "$output" == *"E_INVALID_ARG"* ]]
  [[ "$output" == *"missing pbi-id"* ]]
}
