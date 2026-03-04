#!/usr/bin/env bats
# agent-frontmatter.bats — Validate YAML frontmatter in agent definition files

load '../test_helper/common-setup'

setup() {
  PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
}

# Helper: extract YAML frontmatter (lines between the two --- markers)
# Uses awk for macOS/Linux portability (BSD sed doesn't support this syntax)
extract_frontmatter() {
  local file="$1"
  awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' "$file"
}

# ---------------------------------------------------------------------------
# scrum-master.md
# ---------------------------------------------------------------------------

@test "scrum-master.md has valid YAML frontmatter" {
  run bash -c "extract_frontmatter() { awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' \"\$1\"; }; extract_frontmatter '${PROJECT_ROOT}/agents/scrum-master.md' | yq '.' > /dev/null 2>&1"
  assert_success
}

@test "scrum-master.md has required name field" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/scrum-master.md' | yq -r '.name'"
  assert_success
  assert_output "scrum-master"
}

@test "scrum-master.md has description field" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/scrum-master.md' | yq -r '.description'"
  assert_success
  refute_output ""
}

@test "scrum-master.md has skills field with 14 entries" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/scrum-master.md' | yq '.skills | length'"
  assert_success
  assert_output "14"
}

@test "scrum-master.md mentions Delegate mode" {
  run grep -iE 'Delegate|delegate mode' "${PROJECT_ROOT}/agents/scrum-master.md"
  assert_success
}

# ---------------------------------------------------------------------------
# developer.md
# ---------------------------------------------------------------------------

@test "developer.md has valid YAML frontmatter" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/developer.md' | yq '.' > /dev/null 2>&1"
  assert_success
}

@test "developer.md has required name field" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/developer.md' | yq -r '.name'"
  assert_success
  assert_output "developer"
}

@test "developer.md has install-subagents in skills" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/developer.md' | yq '.skills[] | select(. == \"install-subagents\")'"
  assert_success
  assert_output "install-subagents"
}
