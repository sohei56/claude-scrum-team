#!/usr/bin/env bats
# hooks.bats — Tests each hook script with mock .scrum/ state files.

load '../test_helper/common-setup'

# ---------------------------------------------------------------------------
# Setup / Teardown
# ---------------------------------------------------------------------------

setup() {
  setup_temp_dir
  # Hooks resolve paths relative to cwd, so we work inside TEMP_DIR
  cd "$TEMP_DIR"
}

teardown() {
  teardown_temp_dir
}

# ---------------------------------------------------------------------------
# session-context.sh
# ---------------------------------------------------------------------------

@test "session-context.sh outputs valid JSON for new project" {
  # No .scrum/ directory — brand-new project
  run bash "$PROJECT_ROOT/hooks/session-context.sh"
  assert_success

  # Output must be valid JSON
  echo "$output" | jq empty
  [ $? -eq 0 ]

  # Must contain additionalContext key
  local ctx
  ctx="$(echo "$output" | jq -r '.additionalContext')"
  [ -n "$ctx" ]
  [[ "$ctx" == *"New project"* ]]
}

@test "session-context.sh outputs phase context for existing project" {
  # Set up a .scrum/state.json with design phase
  mkdir -p .scrum
  cp "$FIXTURES_DIR/hook-state-design.json" .scrum/state.json

  run bash "$PROJECT_ROOT/hooks/session-context.sh"
  assert_success

  # Output must be valid JSON
  echo "$output" | jq empty
  [ $? -eq 0 ]

  # additionalContext must mention the phase
  local ctx
  ctx="$(echo "$output" | jq -r '.additionalContext')"
  [[ "$ctx" == *"design"* ]]
}

# ---------------------------------------------------------------------------
# dashboard-event.sh
# ---------------------------------------------------------------------------

@test "dashboard-event.sh creates dashboard.json if missing" {
  mkdir -p .scrum

  # Pipe a PostToolUse event with a Write tool into the hook
  local event_json
  event_json='{"hook_type":"PostToolUse","agent_id":"dev-001","tool_name":"Write","tool_input":{"file_path":"src/main.py"}}'

  run bash -c "echo '$event_json' | bash '$PROJECT_ROOT/hooks/dashboard-event.sh'"
  assert_success

  # dashboard.json must have been created
  [ -f ".scrum/dashboard.json" ]

  # It must be valid JSON with an events array
  jq -e '.events | type == "array"' .scrum/dashboard.json
}

@test "dashboard-event.sh creates communications.json if missing" {
  mkdir -p .scrum

  # Pipe a TeammateIdle event into the hook
  local event_json
  event_json='{"hook_type":"TeammateIdle","teammate_id":"dev-001","teammate_role":"Developer","message":"Waiting for review"}'

  run bash -c "echo '$event_json' | bash '$PROJECT_ROOT/hooks/dashboard-event.sh'"
  assert_success

  # communications.json must have been created
  [ -f ".scrum/communications.json" ]

  # It must be valid JSON with a messages array
  jq -e '.messages | type == "array"' .scrum/communications.json
}

# ---------------------------------------------------------------------------
# phase-gate.sh
# ---------------------------------------------------------------------------

@test "phase-gate.sh allows Edit during implementation" {
  mkdir -p .scrum
  cp "$FIXTURES_DIR/valid-state.json" .scrum/state.json  # phase=implementation

  # Simulate an Edit tool event on a source file
  local event_json
  event_json='{"tool_name":"Edit","tool_input":{"file_path":"src/main.py"}}'

  run bash -c "echo '$event_json' | bash '$PROJECT_ROOT/hooks/phase-gate.sh'"
  assert_success

  # Decision should be allow
  local decision
  decision="$(echo "$output" | jq -r '.decision')"
  [ "$decision" = "allow" ]
}

@test "phase-gate.sh denies source Edit during design" {
  mkdir -p .scrum
  cp "$FIXTURES_DIR/hook-state-design.json" .scrum/state.json  # phase=design

  # Simulate an Edit tool event on a source file
  local event_json
  event_json='{"tool_name":"Edit","tool_input":{"file_path":"src/main.py"}}'

  run bash -c "echo '$event_json' | bash '$PROJECT_ROOT/hooks/phase-gate.sh'"
  assert_success

  # Decision should be deny
  local decision
  decision="$(echo "$output" | jq -r '.decision')"
  [ "$decision" = "deny" ]
}

# ---------------------------------------------------------------------------
# completion-gate.sh
# ---------------------------------------------------------------------------

@test "completion-gate.sh allows stop when no state file exists" {
  # No .scrum/ directory at all
  run bash "$PROJECT_ROOT/hooks/completion-gate.sh"
  assert_success
}

@test "completion-gate.sh allows stop in ungated phase" {
  mkdir -p .scrum
  # Create a state file with a phase that has no exit criteria
  jq -n '{"phase": "sprint_planning", "current_sprint_id": "sprint-001"}' > .scrum/state.json

  run bash "$PROJECT_ROOT/hooks/completion-gate.sh"
  assert_success
}

@test "completion-gate.sh blocks stop when PBIs still refined in implementation" {
  mkdir -p .scrum
  cp "$FIXTURES_DIR/valid-state.json" .scrum/state.json   # phase=implementation
  cp "$FIXTURES_DIR/valid-sprint.json" .scrum/sprint.json  # pbi_ids=["pbi-001"]
  cp "$FIXTURES_DIR/valid-backlog.json" .scrum/backlog.json # pbi-001 status=refined

  run bash "$PROJECT_ROOT/hooks/completion-gate.sh"
  [ "$status" -eq 2 ]
}

@test "completion-gate.sh allows stop when PBIs started in implementation" {
  mkdir -p .scrum
  cp "$FIXTURES_DIR/valid-state.json" .scrum/state.json
  cp "$FIXTURES_DIR/valid-sprint.json" .scrum/sprint.json

  # Create backlog with PBI status=in_progress (not refined)
  jq '.items[0].status = "in_progress"' "$FIXTURES_DIR/valid-backlog.json" > .scrum/backlog.json

  run bash "$PROJECT_ROOT/hooks/completion-gate.sh"
  assert_success
}

@test "completion-gate.sh allows stop when state files missing in implementation" {
  mkdir -p .scrum
  cp "$FIXTURES_DIR/valid-state.json" .scrum/state.json
  # Intentionally do NOT create sprint.json or backlog.json

  run bash "$PROJECT_ROOT/hooks/completion-gate.sh"
  assert_success
}

@test "completion-gate.sh blocks stop when PBIs not done in review" {
  mkdir -p .scrum
  jq '.phase = "review"' "$FIXTURES_DIR/valid-state.json" > .scrum/state.json
  cp "$FIXTURES_DIR/valid-sprint.json" .scrum/sprint.json
  jq '.items[0].status = "in_progress"' "$FIXTURES_DIR/valid-backlog.json" > .scrum/backlog.json

  run bash "$PROJECT_ROOT/hooks/completion-gate.sh"
  [ "$status" -eq 2 ]
}

@test "completion-gate.sh allows stop when all PBIs done in review" {
  mkdir -p .scrum
  jq '.phase = "review"' "$FIXTURES_DIR/valid-state.json" > .scrum/state.json
  cp "$FIXTURES_DIR/valid-sprint.json" .scrum/sprint.json
  jq '.items[0].status = "done"' "$FIXTURES_DIR/valid-backlog.json" > .scrum/backlog.json

  run bash "$PROJECT_ROOT/hooks/completion-gate.sh"
  assert_success
}

# ---------------------------------------------------------------------------
# quality-gate.sh
# ---------------------------------------------------------------------------

@test "quality-gate.sh skips checks when no PBI ID in event" {
  mkdir -p .scrum

  local event_json='{"hook_type":"TaskCompleted"}'

  run bash -c "echo '$event_json' | bash '$PROJECT_ROOT/hooks/quality-gate.sh'"
  assert_success
}

@test "quality-gate.sh skips checks when no backlog exists" {
  mkdir -p .scrum

  local event_json='{"hook_type":"TaskCompleted","pbi_id":"pbi-001"}'

  run bash -c "echo '$event_json' | bash '$PROJECT_ROOT/hooks/quality-gate.sh'"
  assert_success
}

@test "quality-gate.sh runs DoD checks and always exits 0" {
  mkdir -p .scrum
  cp "$FIXTURES_DIR/valid-backlog.json" .scrum/backlog.json

  local event_json='{"hook_type":"TaskCompleted","pbi_id":"pbi-001"}'

  run bash -c "echo '$event_json' | bash '$PROJECT_ROOT/hooks/quality-gate.sh'"
  assert_success
}
