#!/usr/bin/env bats
# tests/unit/hooks/test_autonomy_lib.bats — unit tests for hooks/lib/autonomy.sh.
#
# Strategy: each test cd's into a fresh tmp dir, materialises a controlled
# .scrum/config.json + .scrum/autonomy.json fixture (or omits them to verify
# fail-open behaviour), then sources the lib and asserts return codes / stdout.

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  LIB="$PROJECT_ROOT/hooks/lib/autonomy.sh"
  TEST_TMP="$(mktemp -d /tmp/claude/autonomy-lib.XXXXXX 2>/dev/null || mktemp -d "${TMPDIR:-/tmp}/autonomy-lib.XXXXXX")"
  cd "$TEST_TMP" || exit 1
  mkdir -p .scrum
  # Each test starts with a clean _AUTONOMY_SH_LOADED state so re-sourcing
  # inside subshells is straightforward.
  unset _AUTONOMY_SH_LOADED || true
}

teardown() {
  if [ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ]; then
    rm -rf "$TEST_TMP"
  fi
}

# Helper: write a minimal autonomy.json fixture.
write_autonomy() {
  local lead="${1:-null}"
  local phase="${2:-idle}"
  local count="${3:-0}"
  cat > .scrum/autonomy.json <<EOF
{
  "run_id": "run-test",
  "started_at": "2026-06-12T00:00:00Z",
  "lead_session_id": $(if [ "$lead" = "null" ]; then printf 'null'; else printf '"%s"' "$lead"; fi),
  "iteration": 0,
  "total_cost_usd": 0,
  "stop_blocks": {"phase": "$phase", "count": $count},
  "circuit_breaker_tripped": null,
  "last_failure": null
}
EOF
}

write_config_mode() {
  local mode="$1"
  cat > .scrum/config.json <<EOF
{"po_mode": "$mode"}
EOF
}

# ------------------------------------------------------------------
# autonomy_enabled
# ------------------------------------------------------------------

@test "autonomy_enabled: returns 1 when config.json missing" {
  rm -f .scrum/config.json .scrum/autonomy.json
  run bash -c ". $LIB && autonomy_enabled"
  [ "$status" -eq 1 ]
}

@test "autonomy_enabled: returns 1 when autonomy.json missing" {
  write_config_mode agent
  rm -f .scrum/autonomy.json
  run bash -c ". $LIB && autonomy_enabled"
  [ "$status" -eq 1 ]
}

@test "autonomy_enabled: returns 1 when po_mode=human" {
  write_config_mode human
  write_autonomy
  run bash -c ". $LIB && autonomy_enabled"
  [ "$status" -eq 1 ]
}

@test "autonomy_enabled: returns 0 when po_mode=agent and autonomy.json exists" {
  write_config_mode agent
  write_autonomy
  run bash -c ". $LIB && autonomy_enabled"
  [ "$status" -eq 0 ]
}

@test "autonomy_enabled: fail-open on malformed config.json" {
  printf 'not json' > .scrum/config.json
  write_autonomy
  run bash -c ". $LIB && autonomy_enabled"
  # Malformed JSON → mode defaults to "human" → not enabled
  [ "$status" -eq 1 ]
}

# ------------------------------------------------------------------
# is_lead_session
# ------------------------------------------------------------------

@test "is_lead_session: returns 1 when autonomy.json missing" {
  rm -f .scrum/autonomy.json
  run bash -c ". $LIB && is_lead_session sess-123"
  [ "$status" -eq 1 ]
}

@test "is_lead_session: returns 1 when lead_session_id is null" {
  write_autonomy null
  run bash -c ". $LIB && is_lead_session sess-123"
  [ "$status" -eq 1 ]
}

@test "is_lead_session: returns 1 when called with empty session id" {
  write_autonomy sess-abc
  run bash -c ". $LIB && is_lead_session ''"
  [ "$status" -eq 1 ]
}

@test "is_lead_session: returns 0 when ids match" {
  write_autonomy sess-abc
  run bash -c ". $LIB && is_lead_session sess-abc"
  [ "$status" -eq 0 ]
}

@test "is_lead_session: returns 1 when ids differ" {
  write_autonomy sess-abc
  run bash -c ". $LIB && is_lead_session sess-xyz"
  [ "$status" -eq 1 ]
}

# ------------------------------------------------------------------
# bump_stop_block_counter
# ------------------------------------------------------------------

@test "bump_stop_block_counter: first call on matching phase increments from 0 to 1" {
  write_autonomy null pbi_pipeline_active 0
  run bash -c ". $LIB && bump_stop_block_counter pbi_pipeline_active"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
  run jq -r '.stop_blocks.count' .scrum/autonomy.json
  [ "$output" = "1" ]
  run jq -r '.stop_blocks.phase' .scrum/autonomy.json
  [ "$output" = "pbi_pipeline_active" ]
}

@test "bump_stop_block_counter: same-phase call increments existing count" {
  write_autonomy null pbi_pipeline_active 4
  run bash -c ". $LIB && bump_stop_block_counter pbi_pipeline_active"
  [ "$status" -eq 0 ]
  [ "$output" = "5" ]
}

@test "bump_stop_block_counter: phase change resets counter to 1" {
  write_autonomy null pbi_pipeline_active 7
  run bash -c ". $LIB && bump_stop_block_counter sprint_review"
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
  run jq -r '.stop_blocks.phase' .scrum/autonomy.json
  [ "$output" = "sprint_review" ]
}

@test "bump_stop_block_counter: fail-open when autonomy.json missing" {
  rm -f .scrum/autonomy.json
  run bash -c ". $LIB && bump_stop_block_counter pbi_pipeline_active"
  [ "$status" -eq 1 ]
  [ "$output" = "0" ]
}

@test "bump_stop_block_counter: fail-open on malformed JSON" {
  printf 'not json' > .scrum/autonomy.json
  run bash -c ". $LIB && bump_stop_block_counter pbi_pipeline_active"
  [ "$status" -eq 1 ]
  [ "$output" = "0" ]
}

@test "bump_stop_block_counter: empty phase arg returns 0 and 1" {
  write_autonomy null pbi_pipeline_active 0
  run bash -c ". $LIB && bump_stop_block_counter ''"
  [ "$status" -eq 1 ]
  [ "$output" = "0" ]
}

# ------------------------------------------------------------------
# record_circuit_breaker
# ------------------------------------------------------------------

@test "record_circuit_breaker: stamps phase + at on autonomy.json" {
  write_autonomy null idle 0
  run bash -c ". $LIB && record_circuit_breaker pbi_pipeline_active"
  [ "$status" -eq 0 ]
  run jq -r '.circuit_breaker_tripped.phase' .scrum/autonomy.json
  [ "$output" = "pbi_pipeline_active" ]
  run jq -r '.circuit_breaker_tripped.at' .scrum/autonomy.json
  [[ "$output" =~ ^20[0-9]{2}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

@test "record_circuit_breaker: fail-open when autonomy.json missing" {
  rm -f .scrum/autonomy.json
  run bash -c ". $LIB && record_circuit_breaker pbi_pipeline_active"
  [ "$status" -eq 1 ]
}

# ------------------------------------------------------------------
# autonomy_config_int
# ------------------------------------------------------------------

@test "autonomy_config_int: returns default when config.json missing" {
  rm -f .scrum/config.json
  run bash -c ". $LIB && autonomy_config_int '.autonomous.max_iterations' 50"
  [ "$status" -eq 0 ]
  [ "$output" = "50" ]
}

@test "autonomy_config_int: returns default when key missing" {
  cat > .scrum/config.json <<'EOF'
{"autonomous": {}}
EOF
  run bash -c ". $LIB && autonomy_config_int '.autonomous.max_iterations' 50"
  [ "$status" -eq 0 ]
  [ "$output" = "50" ]
}

@test "autonomy_config_int: returns configured value when present" {
  cat > .scrum/config.json <<'EOF'
{"autonomous": {"max_iterations": 123}}
EOF
  run bash -c ". $LIB && autonomy_config_int '.autonomous.max_iterations' 50"
  [ "$status" -eq 0 ]
  [ "$output" = "123" ]
}

@test "autonomy_config_int: fail-open on malformed JSON returns default" {
  printf 'not json' > .scrum/config.json
  run bash -c ". $LIB && autonomy_config_int '.autonomous.max_iterations' 7"
  [ "$status" -eq 0 ]
  [ "$output" = "7" ]
}

@test "autonomy_config_int: returns default when value is non-integer" {
  cat > .scrum/config.json <<'EOF'
{"autonomous": {"max_iterations": "abc"}}
EOF
  run bash -c ". $LIB && autonomy_config_int '.autonomous.max_iterations' 9"
  [ "$status" -eq 0 ]
  [ "$output" = "9" ]
}
