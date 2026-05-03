#!/usr/bin/env bats
# tests/unit/scrum-state/test_state-guard-hook.bats

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  HOOK="$PROJECT_ROOT/hooks/pre-tool-use-scrum-state-guard.sh"
  TEST_TMP="$(mktemp -d /tmp/claude/state-guard.XXXXXX 2>/dev/null || mktemp -d "${TMPDIR:-/tmp}/state-guard.XXXXXX")"
  cd "$TEST_TMP" || exit 1
}

teardown() {
  if [ -n "${TEST_TMP:-}" ] && [ -d "$TEST_TMP" ]; then
    rm -rf "$TEST_TMP"
  fi
}

# --- Block cases ---

@test "guard: blocks Edit on .scrum/backlog.json" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\".scrum/backlog.json\"}}'"
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOCKED"* ]]
}

@test "guard: blocks Write on .scrum/state.json" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\".scrum/state.json\"}}'"
  [ "$status" -eq 2 ]
}

@test "guard: blocks MultiEdit on .scrum/sprint.json" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"MultiEdit\",\"tool_input\":{\"file_path\":\".scrum/sprint.json\"}}'"
  [ "$status" -eq 2 ]
}

@test "guard: blocks Edit on .scrum/pbi/pbi-001/state.json (nested)" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\".scrum/pbi/pbi-001/state.json\"}}'"
  [ "$status" -eq 2 ]
}

@test "guard: blocks Bash with jq redirect into .scrum/" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"jq . .scrum/backlog.json > .scrum/backlog.json.tmp && mv .scrum/backlog.json.tmp .scrum/backlog.json\"}}'"
  [ "$status" -eq 2 ]
}

@test "guard: blocks Bash with tee into .scrum/" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"echo {} | tee .scrum/state.json\"}}'"
  [ "$status" -eq 2 ]
}

@test "guard: blocks Bash with jq -i" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"jq -i .scrum/backlog.json\"}}'"
  [ "$status" -eq 2 ]
}

@test "guard: blocks Bash with sed -i on .scrum/" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"sed -i s/foo/bar/ .scrum/state.json\"}}'"
  [ "$status" -eq 2 ]
}

@test "guard: blocks Bash with mv into .scrum/foo.json" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"mv /tmp/x.json .scrum/backlog.json\"}}'"
  [ "$status" -eq 2 ]
}

# --- Allow cases ---

@test "guard: allows Bash that calls scripts/scrum/" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"scripts/scrum/update-backlog-status.sh pbi-001 review\"}}'"
  [ "$status" -eq 0 ]
}

@test "guard: allows Bash with full env prefix calling scripts/scrum/" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli scripts/scrum/append-communication.sh --from a --kind info --content x\"}}'"
  [ "$status" -eq 0 ]
}

@test "guard: allows Bash that calls .scrum/scripts/ (deployed layout)" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\".scrum/scripts/update-backlog-status.sh pbi-001 review\"}}'"
  [ "$status" -eq 0 ]
}

@test "guard: allows Bash with env prefix calling .scrum/scripts/" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"env SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli .scrum/scripts/append-communication.sh --from a --kind info --content x\"}}'"
  [ "$status" -eq 0 ]
}

@test "guard: allows Bash that only reads .scrum/" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cat .scrum/backlog.json | jq .items\"}}'"
  [ "$status" -eq 0 ]
}

@test "guard: allows Bash that greps .scrum/" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"grep pbi-001 .scrum/backlog.json\"}}'"
  [ "$status" -eq 0 ]
}

@test "guard: allows Edit on non-.scrum file" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"src/foo.py\"}}'"
  [ "$status" -eq 0 ]
}

@test "guard: allows Write to .scrum/foo.txt (only .json files are guarded)" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\".scrum/notes.txt\"}}'"
  [ "$status" -eq 0 ]
}

@test "guard: allows Read on .scrum/state.json" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Read\",\"tool_input\":{\"file_path\":\".scrum/state.json\"}}'"
  [ "$status" -eq 0 ]
}

@test "guard: allows Glob, Grep, etc." {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Glob\",\"tool_input\":{\"pattern\":\".scrum/*.json\"}}'"
  [ "$status" -eq 0 ]
}

# --- Fail-open cases (malformed input) ---

@test "guard: empty payload → allow" {
  run bash -c "$HOOK <<< ''"
  [ "$status" -eq 0 ]
}

@test "guard: malformed JSON payload → allow" {
  run bash -c "$HOOK <<< 'not json {{{'"
  [ "$status" -eq 0 ]
}

@test "guard: payload with no tool_name → allow" {
  run bash -c "$HOOK <<< '{\"foo\":\"bar\"}'"
  [ "$status" -eq 0 ]
}

@test "guard: payload with empty tool_input → allow" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Edit\"}'"
  [ "$status" -eq 0 ]
}

@test "guard: comment-only Bash (no actual write) → allow" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"# this comment mentions .scrum/foo.json but does nothing\"}}'"
  [ "$status" -eq 0 ]
}
