#!/usr/bin/env bash
# tests/unit/scrum-state/lib/helpers.bash
# Shared bats setup/teardown for scrum-state wrapper tests.
# Source via:  load lib/helpers.bash

# Initialize a sandbox dir, copy a schema and seed fixture into .scrum/.
# Usage: scrum_state_setup <schema_basename> <fixture_basename> <state_basename> <tmp_prefix>
#   schema_basename:   e.g. sprint.schema.json
#   fixture_basename:  e.g. valid-sprint.json
#   state_basename:    e.g. sprint.json (placed at .scrum/<state_basename>)
#   tmp_prefix:        directory prefix for mktemp -d
scrum_state_setup() {
  local schema="$1"
  local fixture="$2"
  local state="$3"
  local prefix="$4"

  export SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  export PROJECT_ROOT
  TEST_TMP="$(mktemp -d "/tmp/claude/${prefix}.XXXXXX" 2>/dev/null \
    || mktemp -d "${TMPDIR:-/tmp}/${prefix}.XXXXXX")"
  export TEST_TMP
  cd "$TEST_TMP" || exit 1
  mkdir -p .scrum docs/contracts/scrum-state
  cp "$PROJECT_ROOT/docs/contracts/scrum-state/$schema" docs/contracts/scrum-state/
  cp "$PROJECT_ROOT/tests/fixtures/$fixture" ".scrum/$state"
}

scrum_state_teardown() {
  if [ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ]; then
    rm -rf "$TEST_TMP"
  fi
}
