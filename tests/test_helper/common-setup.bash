#!/usr/bin/env bash
# common-setup.bash — Shared helpers for bats tests

# Load bats-support and bats-assert
load "$(dirname "$BATS_TEST_FILENAME")/../test_helper/bats-support/load"
load "$(dirname "$BATS_TEST_FILENAME")/../test_helper/bats-assert/load"

# Path to project root
PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

# Path to test fixtures
FIXTURES_DIR="$PROJECT_ROOT/tests/fixtures"

# Create a temporary directory for test state
setup_temp_dir() {
  TEMP_DIR="$(mktemp -d)"
  export TEMP_DIR
}

# Clean up temporary directory
teardown_temp_dir() {
  if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
  fi
}

# Create a minimal .scrum/ directory with required state files
setup_scrum_dir() {
  local dir="${1:-$TEMP_DIR}"
  mkdir -p "$dir/.scrum/reviews"
}

# Assert that a JSON file matches a jq expression
# Usage: assert_json_match <file> <jq_expression> <expected_value>
assert_json_match() {
  local file="$1"
  local expr="$2"
  local expected="$3"
  local actual
  actual="$(jq -r "$expr" "$file")"
  [ "$actual" = "$expected" ] || {
    echo "JSON assertion failed:"
    echo "  File: $file"
    echo "  Expression: $expr"
    echo "  Expected: $expected"
    echo "  Actual: $actual"
    return 1
  }
}

# Assert that a file has valid JSON
assert_valid_json() {
  local file="$1"
  jq empty "$file" 2>/dev/null || {
    echo "Invalid JSON in: $file"
    return 1
  }
}

# Assert that a Markdown file has YAML frontmatter
assert_has_frontmatter() {
  local file="$1"
  local first_line
  first_line="$(head -1 "$file")"
  [ "$first_line" = "---" ] || {
    echo "Missing YAML frontmatter in: $file"
    return 1
  }
}
