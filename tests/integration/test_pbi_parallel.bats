#!/usr/bin/env bats
# Integration: 2 PBIs in parallel with shared catalog spec.
# Verifies flock serializes catalog writes.

setup() {
  command -v flock >/dev/null 2>&1 || skip "flock not available (macOS default)"
  TEST_TMP="$(mktemp -d /tmp/claude/pbi-parallel-test.XXXXXX 2>/dev/null || mktemp -d "${TMPDIR:-/tmp}/pbi-parallel-test.XXXXXX")"
  cd "$TEST_TMP" || exit 1
  mkdir -p .scrum/locks docs/design/specs/api
  echo "# initial" > docs/design/specs/api/auth.md
}

teardown() { rm -rf "$TEST_TMP"; }

@test "two parallel writers serialize via flock" {
  spec="docs/design/specs/api/auth.md"
  lock_id="$(echo "$spec" | sed 's|/|_|g')"
  lock_file=".scrum/locks/catalog-${lock_id}.lock"

  writer() {
    local id="$1" delay="$2"
    exec {FD}>"$lock_file"
    flock -w 60 "$FD"
    local now; now=$(date +%s%N)
    echo "writer $id start $now" >> "$spec"
    sleep "$delay"
    echo "writer $id end $(date +%s%N)" >> "$spec"
    exec {FD}>&-
  }

  writer A 0.2 &
  pid_a=$!
  sleep 0.05
  writer B 0.1 &
  pid_b=$!
  wait $pid_a $pid_b

  starts="$(grep -c 'start' "$spec")"
  ends="$(grep -c 'end' "$spec")"
  [ "$starts" -eq 2 ]
  [ "$ends" -eq 2 ]

  a_end=$(awk '/writer A end/{print NR; exit}' "$spec")
  b_start=$(awk '/writer B start/{print NR; exit}' "$spec")
  b_end=$(awk '/writer B end/{print NR; exit}' "$spec")
  a_start=$(awk '/writer A start/{print NR; exit}' "$spec")
  [ "$a_end" -lt "$b_start" ] || [ "$b_end" -lt "$a_start" ]
}

@test "lock acquisition with 1s timeout fails when other holder takes 3s" {
  spec="docs/design/specs/api/auth.md"
  lock_id="$(echo "$spec" | sed 's|/|_|g')"
  lock_file=".scrum/locks/catalog-${lock_id}.lock"

  (
    exec {FD}>"$lock_file"
    flock "$FD"
    sleep 3
  ) &
  pid_holder=$!

  sleep 0.1

  set +e
  (
    exec {FD}>"$lock_file"
    flock -w 1 "$FD"
  )
  status=$?
  set -e
  wait $pid_holder

  [ "$status" -ne 0 ]
}
