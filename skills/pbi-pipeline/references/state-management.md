# State Management Reference

How the Developer (conductor) manages PBI internal state.

## Schema: `.scrum/pbi/<pbi-id>/state.json`

```json
{
  "pbi_id": "pbi-001",
  "phase": "design | impl_ut | complete | escalated",
  "design_round": 0,
  "impl_round": 0,
  "design_status": "pending | in_review | fail | pass",
  "impl_status": "pending | in_review | fail | pass",
  "ut_status": "pending | in_review | fail | pass",
  "coverage_status": "pending | fail | pass",
  "escalation_reason": null,
  "started_at": "2026-05-02T12:00:00+09:00",
  "updated_at": "2026-05-02T12:00:00+09:00"
}
```

`escalation_reason` enum (only set when `phase == escalated`):

```text
stagnation | divergence | max_rounds | budget_exhausted |
requirements_unclear | coverage_tool_error | coverage_tool_unavailable |
catalog_lock_timeout
```

## Initialization

```bash
PBI_DIR=".scrum/pbi/${PBI_ID}"
mkdir -p "$PBI_DIR"/{design,impl,ut,metrics,feedback}
NOW="$(date -Iseconds)"
jq -n --arg id "$PBI_ID" --arg now "$NOW" '{
  pbi_id: $id, phase: "design",
  design_round: 0, impl_round: 0,
  design_status: "pending", impl_status: "pending",
  ut_status: "pending", coverage_status: "pending",
  escalation_reason: null,
  started_at: $now, updated_at: $now
}' > "$PBI_DIR/state.json"
```

## Atomic update helper

ALWAYS write via temp + rename (never partial write):

```bash
update_state() {
  local pbi_dir="$1"; shift
  local jq_expr="$1"; shift
  local now; now="$(date -Iseconds)"
  jq --arg now "$now" "$jq_expr | .updated_at = \$now" \
    "$pbi_dir/state.json" > "$pbi_dir/state.json.tmp"
  mv "$pbi_dir/state.json.tmp" "$pbi_dir/state.json"
}
# Examples:
update_state "$PBI_DIR" '.design_round = 1 | .design_status = "in_review"'
update_state "$PBI_DIR" '.phase = "complete"'
update_state "$PBI_DIR" \
  '.phase = "escalated" | .escalation_reason = "stagnation"'
```

## pipeline.log format

One line per phase event, append-only:

```text
<ISO8601>\t<phase>\t<round>\t<event>\t<detail>
```

Examples:

```text
2026-05-02T12:00:00+09:00	init	0	created	.scrum/pbi/pbi-001/
2026-05-02T12:01:00+09:00	design	1	spawn	pbi-designer
2026-05-02T12:05:00+09:00	design	1	spawn	codex-design-reviewer
2026-05-02T12:06:00+09:00	design	1	gate	success → impl_ut
2026-05-02T12:06:30+09:00	impl_ut	1	spawn	pbi-implementer + pbi-ut-author
2026-05-02T12:20:00+09:00	impl_ut	1	measure	coverage c0=87 c1=72
2026-05-02T12:25:00+09:00	impl_ut	1	gate	fail → round 2 (test_failures=2)
```

Append helper:

```bash
log_event() {
  local pbi_dir="$1" phase="$2" round="$3" event="$4" detail="$5"
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$(date -Iseconds)" "$phase" "$round" "$event" "$detail" \
    >> "$pbi_dir/pipeline.log"
}
```

## Sprint-level state side-effects

When a PBI starts pipeline:
- Append PBI id to `.scrum/state.json.active_pbi_pipelines[]`
- Set `.scrum/sprint.json.developers[<dev>].current_pbi = "<pbi_id>"`
- Set `.scrum/sprint.json.developers[<dev>].current_pbi_phase` to track

When a PBI completes or escalates:
- Remove from `active_pbi_pipelines[]`
- Update backlog.json status to `done` or `blocked`
- Add `pipeline_summary` to backlog.json item (rounds, final coverage)
