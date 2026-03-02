#!/usr/bin/env bats
# script-compose.bats — Integration tests for script composition
# Tests scrum-start.sh prerequisite checking, setup-user.sh file copying,
# and statusline.sh output format.

load '../test_helper/common-setup'

setup() {
  setup_temp_dir
  export PROJECT_ROOT
}

teardown() {
  teardown_temp_dir
}

# --- scrum-start.sh prerequisite checks ---

@test "scrum-start.sh exits 1 when claude is not on PATH" {
  # Create a restricted PATH without claude
  run env PATH="/usr/bin:/bin" bash "$PROJECT_ROOT/scrum-start.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"Claude Code CLI not found"* ]]
}

@test "scrum-start.sh sets Agent Teams flag process-scoped (no global export needed)" {
  # Agent Teams env var is set inline by scrum-start.sh when launching claude,
  # so the script no longer checks for or requires a global export.
  # This test verifies the inline env var pattern is present in the script.
  run grep -c "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude" "$PROJECT_ROOT/scrum-start.sh"
  [ "$output" -ge 1 ]
}

# --- setup-user.sh file copying ---

@test "setup-user.sh copies agent definitions to .claude/agents/" {
  skip "requires full prerequisites (claude, python, textual, watchdog)"
  cd "$TEMP_DIR"
  run bash "$PROJECT_ROOT/scripts/setup-user.sh"
  [ -f ".claude/agents/scrum-master.md" ]
  [ -f ".claude/agents/developer.md" ]
}

@test "setup-user.sh copies skill definitions to .claude/skills/" {
  skip "requires full prerequisites"
  cd "$TEMP_DIR"
  run bash "$PROJECT_ROOT/scripts/setup-user.sh"
  [ -f ".claude/skills/sprint-planning/SKILL.md" ]
  [ -f ".claude/skills/spawn-teammates/SKILL.md" ]
  [ -f ".claude/skills/requirements-sprint/SKILL.md" ]
}

@test "setup-user.sh creates settings.json with hook config" {
  skip "requires full prerequisites"
  cd "$TEMP_DIR"
  run bash "$PROJECT_ROOT/scripts/setup-user.sh"
  [ -f ".claude/settings.json" ]
  run jq '.hooks.SessionStart' ".claude/settings.json"
  assert_success
}

# --- statusline.sh output format ---

@test "statusline.sh outputs 3 lines with no state files" {
  cd "$TEMP_DIR"
  run bash "$PROJECT_ROOT/scripts/statusline.sh" < /dev/null
  assert_success
  # Should have 3 lines
  line_count="$(echo "$output" | wc -l | tr -d ' ')"
  [ "$line_count" -eq 3 ]
}

@test "statusline.sh shows 'No active Sprint' when no sprint file" {
  cd "$TEMP_DIR"
  mkdir -p .scrum
  cat > .scrum/state.json << 'EOF'
{
  "product_goal": "Test",
  "current_sprint_id": null,
  "phase": "backlog_created",
  "created_at": "2026-03-01T10:00:00Z",
  "updated_at": "2026-03-01T10:00:00Z"
}
EOF
  run bash "$PROJECT_ROOT/scripts/statusline.sh" < /dev/null
  assert_success
  [[ "$output" == *"No active Sprint"* ]]
}

@test "statusline.sh shows backlog info when backlog exists" {
  cd "$TEMP_DIR"
  mkdir -p .scrum
  cat > .scrum/state.json << 'EOF'
{
  "product_goal": "Test",
  "current_sprint_id": null,
  "phase": "backlog_created",
  "created_at": "2026-03-01T10:00:00Z",
  "updated_at": "2026-03-01T10:00:00Z"
}
EOF
  cat > .scrum/backlog.json << 'EOF'
{
  "product_goal": "Test",
  "items": [
    {"id": "pbi-001", "title": "Test PBI", "description": "", "acceptance_criteria": "", "status": "draft", "priority": 1, "sprint_id": null, "implementer_id": null, "reviewer_id": null, "design_doc_paths": [], "review_doc_path": null, "depends_on_pbi_ids": [], "ux_change": false, "parent_pbi_id": null, "created_at": "2026-03-01T10:00:00Z", "updated_at": "2026-03-01T10:00:00Z"}
  ],
  "next_pbi_id": 2
}
EOF
  run bash "$PROJECT_ROOT/scripts/statusline.sh" < /dev/null
  assert_success
  [[ "$output" == *"Backlog: 1 items"* ]]
  [[ "$output" == *"1 draft"* ]]
}
