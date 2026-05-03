#!/usr/bin/env bats
# tests/unit/scrum-state/test_derive.bats — phase → backlog.status mapping
# (the SSOT bridge between pbi/state.json and backlog.json).

setup() {
  PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
  # shellcheck source=../../../scripts/scrum/lib/derive.sh
  source "$PROJECT_ROOT/scripts/scrum/lib/derive.sh"
}

@test "derive: design → in_progress" {
  run derive_backlog_status_from_phase design
  [ "$status" -eq 0 ]
  [ "$output" = "in_progress" ]
}

@test "derive: impl_ut → in_progress" {
  run derive_backlog_status_from_phase impl_ut
  [ "$status" -eq 0 ]
  [ "$output" = "in_progress" ]
}

@test "derive: complete → review" {
  run derive_backlog_status_from_phase complete
  [ "$status" -eq 0 ]
  [ "$output" = "review" ]
}

@test "derive: review_complete → done" {
  run derive_backlog_status_from_phase review_complete
  [ "$status" -eq 0 ]
  [ "$output" = "done" ]
}

@test "derive: escalated → blocked" {
  run derive_backlog_status_from_phase escalated
  [ "$status" -eq 0 ]
  [ "$output" = "blocked" ]
}

@test "derive: unknown phase exits non-zero" {
  run derive_backlog_status_from_phase wibble
  [ "$status" -ne 0 ]
}

@test "is_post_pipeline_status: in_progress is post-pipeline" {
  run is_post_pipeline_status in_progress
  [ "$status" -eq 0 ]
}

@test "is_post_pipeline_status: review is post-pipeline" {
  run is_post_pipeline_status review
  [ "$status" -eq 0 ]
}

@test "is_post_pipeline_status: done is post-pipeline" {
  run is_post_pipeline_status done
  [ "$status" -eq 0 ]
}

@test "is_post_pipeline_status: blocked is post-pipeline" {
  run is_post_pipeline_status blocked
  [ "$status" -eq 0 ]
}

@test "is_post_pipeline_status: draft is NOT post-pipeline" {
  run is_post_pipeline_status draft
  [ "$status" -ne 0 ]
}

@test "is_post_pipeline_status: refined is NOT post-pipeline" {
  run is_post_pipeline_status refined
  [ "$status" -ne 0 ]
}
