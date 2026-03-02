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
