#!/usr/bin/env bats
# migration-v1-to-v2.bats — verify scripts/migrate-status-v2.sh.
#
# Spawns a sandbox .scrum/ from legacy-v1 fixtures, exercises every
# row of the v1->v2 mapping table, runs migrate-status-v2.sh, then
# asserts: backlog.json is schema-valid against the v2 schema and
# every PBI ended up with the expected new status; pbi-state.json
# files no longer carry the `phase` key.

load '../test_helper/common-setup'

setup() {
  setup_temp_dir
  export SCRUM_VALIDATOR_OVERRIDE=jsonschema-cli
  cd "$TEMP_DIR"
  mkdir -p .scrum
  cp "$FIXTURES_DIR/legacy-v1-backlog.json" .scrum/backlog.json
}

teardown() {
  teardown_temp_dir
}

# write_legacy_state <pbi_id> <phase> [extra-jq-filter]
# Materializes a legacy pbi-state.json (with phase) for the given PBI.
write_legacy_state() {
  local pbi_id="$1" phase="$2" extra="${3:-.}"
  mkdir -p ".scrum/pbi/$pbi_id"
  jq --arg id "$pbi_id" --arg ph "$phase" \
    ".pbi_id = \$id | .phase = \$ph | $extra" \
    "$FIXTURES_DIR/legacy-v1-pbi-state.json" \
    > ".scrum/pbi/$pbi_id/state.json"
}

# --- mapping coverage ---

@test "migrate-status-v2: full mapping table produces v2-valid backlog" {
  # Seed phase-bearing state for every PBI that needs phase context.
  write_legacy_state pbi-102 design
  write_legacy_state pbi-103 impl_ut
  write_legacy_state pbi-104 complete
  write_legacy_state pbi-105 ready_to_merge
  write_legacy_state pbi-106 merged
  write_legacy_state pbi-107 merge_conflict
  write_legacy_state pbi-108 review_complete
  write_legacy_state pbi-110 escalated
  # pbi-100/101/109/111 deliberately have no state.json (legacy projects do this).

  run bash "$PROJECT_ROOT/scripts/migrate-status-v2.sh"
  [ "$status" -eq 0 ]

  # Backlog now satisfies the v2 schema.
  run jsonschema --instance .scrum/backlog.json \
       "$PROJECT_ROOT/docs/contracts/scrum-state/backlog.schema.json"
  [ "$status" -eq 0 ]

  # Per-PBI status assertions (full mapping table).
  assert_status() {
    local pbi="$1" expected="$2"
    local actual
    actual="$(jq -r --arg id "$pbi" '.items[] | select(.id==$id).status' .scrum/backlog.json)"
    [ "$actual" = "$expected" ] || {
      echo "status mismatch for $pbi: expected=$expected actual=$actual"
      return 1
    }
  }

  assert_status pbi-100 draft
  assert_status pbi-101 refined
  assert_status pbi-102 in_progress_design
  assert_status pbi-103 in_progress_impl
  assert_status pbi-104 in_progress_pbi_review
  assert_status pbi-105 in_progress_merge
  assert_status pbi-106 awaiting_cross_review
  assert_status pbi-107 escalated
  assert_status pbi-108 done
  assert_status pbi-109 blocked
  assert_status pbi-110 escalated
  assert_status pbi-111 done

  # phase key is stripped from every state.json that has one, and
  # the resulting state.json validates against the v2 pbi-state schema.
  for pbi in pbi-102 pbi-103 pbi-104 pbi-105 pbi-106 pbi-107 pbi-108 pbi-110; do
    [ -f ".scrum/pbi/$pbi/state.json" ]
    run jq -r 'has("phase")' ".scrum/pbi/$pbi/state.json"
    [ "$output" = "false" ]
    run jsonschema --instance ".scrum/pbi/$pbi/state.json" \
         "$PROJECT_ROOT/docs/contracts/scrum-state/pbi-state.schema.json"
    [ "$status" -eq 0 ]
  done

  # Backup directory was created and contains the original backlog.
  run bash -c 'ls .scrum/backups/ | head -1'
  [ -n "$output" ]
  backup_dir=".scrum/backups/$output"
  [ -f "$backup_dir/backlog.json" ]
  # Backup retains original (legacy) status.
  run jq -r '.items[] | select(.id=="pbi-104").status' "$backup_dir/backlog.json"
  [ "$output" = "review" ]
}

# --- merge_artifact_missing & merge_regression also map to escalated ---

@test "migrate-status-v2: merge_artifact_missing and merge_regression -> escalated" {
  # Reuse pbi-107 slot for one variant, pbi-105 slot for another.
  # Override the seeded backlog: keep only two items to keep the test focused.
  cat > .scrum/backlog.json <<'EOF'
{
  "items": [
    {"id":"pbi-200","title":"merge_artifact_missing","status":"review","created_at":"2026-04-01T10:00:00Z","updated_at":"2026-04-01T10:00:00Z"},
    {"id":"pbi-201","title":"merge_regression","status":"review","created_at":"2026-04-01T10:00:00Z","updated_at":"2026-04-01T10:00:00Z"}
  ],
  "next_pbi_id": 202
}
EOF
  write_legacy_state pbi-200 merge_artifact_missing
  write_legacy_state pbi-201 merge_regression

  run bash "$PROJECT_ROOT/scripts/migrate-status-v2.sh"
  [ "$status" -eq 0 ]

  run jq -r '.items[] | select(.id=="pbi-200").status' .scrum/backlog.json
  [ "$output" = "escalated" ]
  run jq -r '.items[] | select(.id=="pbi-201").status' .scrum/backlog.json
  [ "$output" = "escalated" ]
}

# --- non-mappable input aborts with a clear message ---

@test "migrate-status-v2: non-mappable status=in_progress without phase aborts" {
  cat > .scrum/backlog.json <<'EOF'
{
  "items": [
    {"id":"pbi-300","title":"orphan in_progress","status":"in_progress","created_at":"2026-04-01T10:00:00Z","updated_at":"2026-04-01T10:00:00Z"}
  ],
  "next_pbi_id": 301
}
EOF
  # Deliberately no state.json -> phase context unavailable.

  run bash "$PROJECT_ROOT/scripts/migrate-status-v2.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"non-mappable"* ]] || {
    echo "expected 'non-mappable' in output; got: $output"
    return 1
  }
  # backlog.json must be untouched (status still 'in_progress').
  run jq -r '.items[0].status' .scrum/backlog.json
  [ "$output" = "in_progress" ]
}

# --- unknown old status aborts ---

@test "migrate-status-v2: unknown old status aborts" {
  cat > .scrum/backlog.json <<'EOF'
{
  "items": [
    {"id":"pbi-400","title":"bogus","status":"weird_value","created_at":"2026-04-01T10:00:00Z","updated_at":"2026-04-01T10:00:00Z"}
  ],
  "next_pbi_id": 401
}
EOF

  run bash "$PROJECT_ROOT/scripts/migrate-status-v2.sh"
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown old status"* ]] || {
    echo "expected 'unknown old status' in output; got: $output"
    return 1
  }
}

# --- dry-run is idempotent: prints mapping but writes nothing ---

@test "migrate-status-v2: --dry-run does not modify backlog or state" {
  write_legacy_state pbi-104 complete
  # pbi-104 in seed backlog is status=review; full table covers it.
  # Use a slim backlog to keep the assertion simple.
  cat > .scrum/backlog.json <<'EOF'
{
  "items": [
    {"id":"pbi-104","title":"review+complete","status":"review","created_at":"2026-04-01T10:00:00Z","updated_at":"2026-04-01T10:00:00Z"}
  ],
  "next_pbi_id": 105
}
EOF

  before_backlog="$(jq -S . .scrum/backlog.json)"
  before_state="$(jq -S . .scrum/pbi/pbi-104/state.json)"

  run bash "$PROJECT_ROOT/scripts/migrate-status-v2.sh" --dry-run
  [ "$status" -eq 0 ]
  [[ "$output" == *"in_progress_pbi_review"* ]]
  [[ "$output" == *"dry-run"* ]]

  after_backlog="$(jq -S . .scrum/backlog.json)"
  after_state="$(jq -S . .scrum/pbi/pbi-104/state.json)"
  [ "$before_backlog" = "$after_backlog" ]
  [ "$before_state" = "$after_state" ]
  # No backups directory should have been created.
  [ ! -d .scrum/backups ]
}

# --- idempotency: re-running on already-migrated state is a no-op success ---

@test "migrate-status-v2: idempotent on already-migrated v2 state" {
  cat > .scrum/backlog.json <<'EOF'
{
  "items": [
    {"id":"pbi-500","title":"already v2","status":"awaiting_cross_review","created_at":"2026-04-01T10:00:00Z","updated_at":"2026-04-01T10:00:00Z"}
  ],
  "next_pbi_id": 501
}
EOF
  # No phase key on the state.json (already v2-shaped).
  mkdir -p .scrum/pbi/pbi-500
  cat > .scrum/pbi/pbi-500/state.json <<'EOF'
{
  "pbi_id": "pbi-500",
  "started_at": "2026-04-01T10:00:00Z",
  "updated_at": "2026-04-01T10:00:00Z"
}
EOF

  run bash "$PROJECT_ROOT/scripts/migrate-status-v2.sh"
  [ "$status" -eq 0 ]

  run jq -r '.items[0].status' .scrum/backlog.json
  [ "$output" = "awaiting_cross_review" ]
  run jq -r 'has("phase")' .scrum/pbi/pbi-500/state.json
  [ "$output" = "false" ]
}
