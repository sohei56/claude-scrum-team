#!/usr/bin/env bats
# tests/integration/test_scrum_start_autonomous.bats
#
# Verifies the autonomous-PO startup path inside scrum-start.sh:
#   - --autonomous --brief on a new project copies brief, merges config,
#     initialises autonomy.json.
#   - --autonomous on a new project WITHOUT --brief is rejected (exit 2).
#   - --max-sprints CLI override propagates into .scrum/config.json.
#   - A plain `scrum-start.sh` (no flags) does NOT inject po_mode or the
#     autonomous block (regression).
#
# Uses SCRUM_START_DRY_RUN=1 to short-circuit just before the actual
# tmux / claude / watchdog launch, and a PATH shim that provides stub `claude`
# and `python3` so the prereq checks in scrum-start.sh succeed without
# touching the user's real environment.

load '../test_helper/common-setup'

setup() {
  setup_temp_dir
  export PROJECT_ROOT

  # Build a PATH shim with stub `claude` and `python3` that satisfy
  # check-python.sh. The real `jq`, `cp`, `mkdir`, etc. are inherited via
  # PATH passthrough.
  STUB_BIN="$TEMP_DIR/stub-bin"
  mkdir -p "$STUB_BIN"

  cat > "$STUB_BIN/claude" <<'EOF'
#!/usr/bin/env bash
case "${1:-}" in --version|-V) echo "stub-claude 0.0.1"; exit 0 ;; esac
exit 0
EOF
  chmod +x "$STUB_BIN/claude"

  # Wrap real python3 so the version + module checks pass without
  # auto-installing anything.
  REAL_PY="$(command -v python3 || true)"
  cat > "$STUB_BIN/python3" <<EOF
#!/usr/bin/env bash
exec "$REAL_PY" "\$@"
EOF
  chmod +x "$STUB_BIN/python3"

  # Pre-populate Python modules check by setting env to skip pip install if
  # they happen to be missing. check_python_prereqs auto-installs, but on
  # CI hosts where pip is locked, we still want the test to proceed. We
  # tolerate either branch — the test asserts only on autonomous-prep
  # behaviour, not on prereq output.
  export PATH="$STUB_BIN:$PATH"

  # Source brief used by tests that pass --brief.
  mkdir -p "$TEMP_DIR/seed"
  cat > "$TEMP_DIR/seed/brief.md" <<'EOF'
# Test product brief
Goal: ship a thing.
EOF

  # Empty target dir for the project.
  PROJ_DIR="$TEMP_DIR/proj"
  mkdir -p "$PROJ_DIR"
  cd "$PROJ_DIR" || exit 1

  export SCRUM_START_DRY_RUN=1

  # init-state.sh runs in the new-project branch and validates against the
  # state schema. Pin the validator to a locally-installed runner so the
  # test does not depend on npx fetching ajv-cli from npm.
  export SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli
}

teardown() {
  teardown_temp_dir
}

# --- (a) --autonomous --brief on a new project ------------------------------

@test "scrum-start --autonomous --brief: copies brief, merges config, inits autonomy.json" {
  run bash "$PROJECT_ROOT/scrum-start.sh" \
    --autonomous \
    --brief "$TEMP_DIR/seed/brief.md"

  [ "$status" -eq 0 ]

  # brief.md placed in canonical location
  [ -f "docs/product/brief.md" ]
  grep -q 'Test product brief' docs/product/brief.md

  # config.json has po_mode=agent + autonomous defaults
  [ -f ".scrum/config.json" ]
  run jq -r '.po_mode' .scrum/config.json
  [ "$output" = "agent" ]
  run jq -r '.autonomous.max_iterations' .scrum/config.json
  [ "$output" = "50" ]
  run jq -r '.autonomous.permission_mode' .scrum/config.json
  [ "$output" = "dontAsk" ]

  # autonomy.json initialised
  [ -f ".scrum/autonomy.json" ]
  run jq -r '.iteration' .scrum/autonomy.json
  [ "$output" = "0" ]
  run jq -r '.run_id' .scrum/autonomy.json
  [ -n "$output" ]
  [ "$output" != "null" ]

  # state.json bootstrapped via init-state.sh (new-project branch)
  [ -f ".scrum/state.json" ]
  run jq -r '.phase' .scrum/state.json
  [ "$output" = "new" ]
}

# --- (a2) Plain --no-autonomous new-project run bootstraps state.json --------

@test "scrum-start (no flags) on new project bootstraps .scrum/state.json" {
  run bash "$PROJECT_ROOT/scrum-start.sh"
  [ "$status" -eq 0 ]
  [ -f ".scrum/state.json" ]
  run jq -r '.phase' .scrum/state.json
  [ "$output" = "new" ]
  run jq -r '.current_sprint_id' .scrum/state.json
  [ "$output" = "null" ]
}

# --- (b) --autonomous without brief on a new project → exit 2 ---------------

@test "scrum-start --autonomous on new project requires --brief (exits 2)" {
  run bash "$PROJECT_ROOT/scrum-start.sh" --autonomous
  [ "$status" -eq 2 ]
  [[ "$output" == *"requires --brief"* ]]
}

# --- (c) Non-autonomous launch does NOT inject po_mode / autonomous ---------

@test "scrum-start (no flags) leaves config.json untouched (regression)" {
  # Seed a state.json so the script takes the "existing project" branch
  # (skips prompting for new project) and then enters the dry-run launch.
  mkdir -p .scrum
  cat > .scrum/state.json <<'JSON'
{
  "phase": "requirements_sprint",
  "current_sprint_id": null,
  "product_goal": "x",
  "created_at": "2026-06-12T00:00:00Z",
  "updated_at": "2026-06-12T00:00:00Z"
}
JSON

  run bash "$PROJECT_ROOT/scrum-start.sh"
  [ "$status" -eq 0 ]

  # No autonomous side effects.
  [ ! -f ".scrum/config.json" ] || {
    run jq -r '.po_mode // "absent"' .scrum/config.json
    [ "$output" = "absent" ]
    run jq -r '.autonomous // "absent"' .scrum/config.json
    [ "$output" = "absent" ]
  }
  [ ! -f ".scrum/autonomy.json" ]
}

# --- (d) --max-sprints override is reflected in config.json -----------------

@test "scrum-start --autonomous --max-sprints N overrides config" {
  run bash "$PROJECT_ROOT/scrum-start.sh" \
    --autonomous \
    --brief "$TEMP_DIR/seed/brief.md" \
    --max-sprints 12 \
    --max-hours 4 \
    --bypass-permissions

  [ "$status" -eq 0 ]
  run jq -r '.autonomous.max_sprints' .scrum/config.json
  [ "$output" = "12" ]
  run jq -r '.autonomous.max_wall_clock_hours' .scrum/config.json
  [ "$output" = "4" ]
  run jq -r '.autonomous.permission_mode' .scrum/config.json
  [ "$output" = "bypassPermissions" ]
}
