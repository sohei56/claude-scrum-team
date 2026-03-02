#!/usr/bin/env bats
# state-schema.bats — Validates JSON state files against the schemas
# defined in data-model.md. Uses jq for field presence and type checks.

load '../test_helper/common-setup'

# ---------------------------------------------------------------------------
# state.json
# ---------------------------------------------------------------------------

@test "valid state.json has all required fields" {
  local file="$FIXTURES_DIR/valid-state.json"

  # Each required field must be present and non-null
  run jq -e '.product_goal' "$file"
  assert_success

  run jq -e '.current_sprint_id' "$file"
  assert_success

  run jq -e '.phase' "$file"
  assert_success

  run jq -e '.created_at' "$file"
  assert_success

  run jq -e '.updated_at' "$file"
  assert_success
}

@test "state.json phase must be a valid enum value" {
  local file="$FIXTURES_DIR/valid-state.json"

  # The phase value must be one of the allowed enum values
  run jq -e '
    .phase as $p |
    ["new","requirements_sprint","backlog_created","sprint_planning",
     "design","implementation","review","sprint_review",
     "retrospective","integration_sprint","complete"] |
    index($p) != null
  ' "$file"
  assert_success
}

@test "invalid state without phase field is detected" {
  local file="$FIXTURES_DIR/invalid-state-missing-phase.json"

  # .phase should not exist in the invalid fixture
  run jq -e '.phase' "$file"
  assert_failure
}

# ---------------------------------------------------------------------------
# backlog.json
# ---------------------------------------------------------------------------

@test "valid backlog has required fields" {
  local file="$FIXTURES_DIR/valid-backlog.json"

  run jq -e '.product_goal' "$file"
  assert_success

  run jq -e '.items | type == "array"' "$file"
  assert_success

  run jq -e '.next_pbi_id | type == "number"' "$file"
  assert_success
}

@test "PBI has required fields" {
  local file="$FIXTURES_DIR/valid-backlog.json"

  # Check every required field on the first PBI
  run jq -e '.items[0] | (
    .id != null and
    .title != null and
    .description != null and
    .acceptance_criteria != null and
    .status != null and
    .priority != null and
    has("sprint_id") and
    has("implementer_id") and
    has("reviewer_id") and
    (.design_doc_paths | type == "array") and
    has("review_doc_path") and
    (.depends_on_pbi_ids | type == "array") and
    (.ux_change | type == "boolean") and
    has("parent_pbi_id") and
    .created_at != null and
    .updated_at != null
  )' "$file"
  assert_success
}

@test "PBI id matches pattern pbi-NNN" {
  local file="$FIXTURES_DIR/valid-backlog.json"

  # Every PBI id must match pbi- followed by one or more digits
  run jq -e '
    [.items[].id] | all(test("^pbi-[0-9]+$"))
  ' "$file"
  assert_success
}

# ---------------------------------------------------------------------------
# sprint.json
# ---------------------------------------------------------------------------

@test "valid sprint has required fields" {
  local file="$FIXTURES_DIR/valid-sprint.json"

  run jq -e '.id' "$file"
  assert_success

  run jq -e '.goal' "$file"
  assert_success

  run jq -e '.type' "$file"
  assert_success

  run jq -e '.status' "$file"
  assert_success

  run jq -e '.pbi_ids | type == "array"' "$file"
  assert_success

  run jq -e '.developer_count | type == "number"' "$file"
  assert_success

  run jq -e '.developers | type == "array"' "$file"
  assert_success
}

@test "Developer has assigned_work with implement and review" {
  local file="$FIXTURES_DIR/valid-sprint.json"

  run jq -e '
    .developers[0] |
    (.assigned_work.implement | type == "array") and
    (.assigned_work.review | type == "array")
  ' "$file"
  assert_success
}

# ---------------------------------------------------------------------------
# improvements.json
# ---------------------------------------------------------------------------

@test "valid improvements has entries array" {
  local file="$FIXTURES_DIR/valid-improvements.json"

  run jq -e '.entries | type == "array"' "$file"
  assert_success
}
