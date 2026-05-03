#!/usr/bin/env bats
# tests/unit/scrum-state/test_update-pbi-state-projection.bats —
# verifies that update-pbi-state.sh projects pbi/state.json.phase to
# backlog.json items[].status atomically (the SSOT bridge in C-mode).

setup() {
  export SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  TEST_TMP="$(mktemp -d /tmp/claude/pbi-state-projection.XXXXXX 2>/dev/null \
    || mktemp -d "${TMPDIR:-/tmp}/pbi-state-projection.XXXXXX")"
  cd "$TEST_TMP" || exit 1

  mkdir -p .scrum/pbi/pbi-001 docs/contracts/scrum-state
  cp "$PROJECT_ROOT/docs/contracts/scrum-state/pbi-state.schema.json" docs/contracts/scrum-state/
  cp "$PROJECT_ROOT/docs/contracts/scrum-state/backlog.schema.json"   docs/contracts/scrum-state/

  cat > .scrum/pbi/pbi-001/state.json <<'EOF'
{
  "pbi_id": "pbi-001",
  "phase": "design",
  "design_round": 0,
  "impl_round": 0,
  "design_status": "pending",
  "impl_status": "pending",
  "ut_status": "pending",
  "coverage_status": "pending",
  "escalation_reason": null,
  "started_at": "2026-05-02T12:00:00Z",
  "updated_at": "2026-05-02T12:00:00Z"
}
EOF

  cp "$PROJECT_ROOT/tests/fixtures/valid-backlog.json" .scrum/backlog.json
}

teardown() {
  if [ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ]; then
    rm -rf "$TEST_TMP"
  fi
}

backlog_status_of() {
  jq -r --arg id "$1" '.items[] | select(.id==$id).status' "$TEST_TMP/.scrum/backlog.json"
}

@test "projection: phase=impl_ut sets backlog.status=in_progress" {
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-pbi-state.sh" pbi-001 phase impl_ut
  [ "$status" -eq 0 ]
  [ "$(backlog_status_of pbi-001)" = "in_progress" ]
}

@test "projection: phase=complete sets backlog.status=review" {
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-pbi-state.sh" pbi-001 phase complete
  [ "$status" -eq 0 ]
  [ "$(backlog_status_of pbi-001)" = "review" ]
}

@test "projection: phase=review_complete sets backlog.status=done" {
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-pbi-state.sh" pbi-001 phase review_complete
  [ "$status" -eq 0 ]
  [ "$(backlog_status_of pbi-001)" = "done" ]
}

@test "projection: phase=escalated sets backlog.status=blocked" {
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-pbi-state.sh" pbi-001 phase escalated escalation_reason stagnation
  [ "$status" -eq 0 ]
  [ "$(backlog_status_of pbi-001)" = "blocked" ]
}

@test "projection: no phase change → backlog.status untouched" {
  before="$(backlog_status_of pbi-001)"
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-pbi-state.sh" pbi-001 design_round 1
  [ "$status" -eq 0 ]
  [ "$(backlog_status_of pbi-001)" = "$before" ]
}

@test "projection: missing backlog entry is silently skipped (no error)" {
  # Replace backlog with one that has no pbi-001 entry.
  jq 'del(.items[] | select(.id=="pbi-001"))' .scrum/backlog.json > .scrum/backlog.json.tmp \
    && mv .scrum/backlog.json.tmp .scrum/backlog.json
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-pbi-state.sh" pbi-001 phase impl_ut
  [ "$status" -eq 0 ]
}

@test "projection: missing backlog.json is silently skipped (no error)" {
  rm -f .scrum/backlog.json
  run env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli "$PROJECT_ROOT/scripts/scrum/update-pbi-state.sh" pbi-001 phase impl_ut
  [ "$status" -eq 0 ]
}
