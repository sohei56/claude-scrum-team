#!/usr/bin/env bats
# tests/unit/scrum-state/test_init-state.bats — bootstrap .scrum/state.json.

setup() {
  export SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  TEST_TMP="$(mktemp -d /tmp/claude/init-state.XXXXXX 2>/dev/null || mktemp -d "${TMPDIR:-/tmp}/init-state.XXXXXX")"
  cd "$TEST_TMP" || exit 1
  mkdir -p docs/contracts/scrum-state
  cp "$PROJECT_ROOT/docs/contracts/scrum-state/state.schema.json" docs/contracts/scrum-state/
}

teardown() {
  if [ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ]; then
    rm -rf "$TEST_TMP"
  fi
}

@test "init-state: creates state.json with phase=new and seed fields" {
  run "$PROJECT_ROOT/scripts/scrum/init-state.sh"
  [ "$status" -eq 0 ]
  [ -f "$TEST_TMP/.scrum/state.json" ]
  run jq -r '.phase, .current_sprint_id, .product_goal' "$TEST_TMP/.scrum/state.json"
  [ "${lines[0]}" = "new" ]
  [ "${lines[1]}" = "null" ]
  [ "${lines[2]}" = "null" ]
  run jq -r '.created_at == .updated_at' "$TEST_TMP/.scrum/state.json"
  [ "$output" = "true" ]
}

@test "init-state: output is schema-valid (update-state-phase succeeds afterwards)" {
  run "$PROJECT_ROOT/scripts/scrum/init-state.sh"
  [ "$status" -eq 0 ]
  run "$PROJECT_ROOT/scripts/scrum/update-state-phase.sh" requirements_sprint
  [ "$status" -eq 0 ]
  run jq -r '.phase' "$TEST_TMP/.scrum/state.json"
  [ "$output" = "requirements_sprint" ]
}

@test "init-state: idempotent — second run exits 0 and does not overwrite" {
  "$PROJECT_ROOT/scripts/scrum/init-state.sh"
  before="$(cat "$TEST_TMP/.scrum/state.json")"
  sleep 1
  run "$PROJECT_ROOT/scripts/scrum/init-state.sh"
  [ "$status" -eq 0 ]
  after="$(cat "$TEST_TMP/.scrum/state.json")"
  [ "$before" = "$after" ]
  [[ "$output" == *"already exists"* ]]
}

@test "init-state: never overwrites an existing file with different content" {
  mkdir -p .scrum
  cat > .scrum/state.json <<'JSON'
{
  "phase": "pbi_pipeline_active",
  "current_sprint_id": "sprint-001",
  "product_goal": "preserved",
  "created_at": "2026-01-01T00:00:00Z",
  "updated_at": "2026-01-02T00:00:00Z"
}
JSON
  before="$(cat .scrum/state.json)"
  run "$PROJECT_ROOT/scripts/scrum/init-state.sh"
  [ "$status" -eq 0 ]
  after="$(cat .scrum/state.json)"
  [ "$before" = "$after" ]
}

@test "init-state: rejects unexpected positional argument" {
  run "$PROJECT_ROOT/scripts/scrum/init-state.sh" stray
  [ "$status" -eq 64 ]
}

@test "update-state-phase: missing state.json produces friendly hint" {
  run "$PROJECT_ROOT/scripts/scrum/update-state-phase.sh" requirements_sprint
  [ "$status" -eq 67 ]
  [[ "$output" == *"init-state.sh"* ]]
}
