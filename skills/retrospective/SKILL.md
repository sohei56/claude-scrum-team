---
name: retrospective
description: Sprint Retrospective — record improvements, consolidate periodically
disable-model-invocation: false
---

## Inputs

- `state.json` → `phase: sprint_review`
- `improvements.json` (existing improvements and `last_consolidation_sprint`)
- `sprint.json` (current Sprint id for consolidation check)

## Outputs

- `improvements.json` → `entries[]` (new Improvement appended with: id,
  sprint_id, description, status: active, created_at)
- `improvements.json` → stale entries archived every 3 Sprints (status:
  archived, archived_at), `last_consolidation_sprint` updated
- `state.json` → `phase: retrospective`
- `sprint.json` → `status: "complete"`

## Preconditions

- `state.json` exists with `phase: "sprint_review"`
- `improvements.json` exists (or will be created on first retrospective)
- `sprint.json` exists and contains the current Sprint id

## Steps

1. **Transition state**: Update `state.json` → `phase: "retrospective"`.
2. **Reflect on Sprint**: Review the Sprint to identify what went well and
   what could be improved. Consider: process efficiency, communication,
   tooling, code quality, and team dynamics.
3. **Record improvement**: Record at least one improvement to
   `improvements.json` → `entries[]` with:
   - `id`: next available improvement id
   - `sprint_id`: current Sprint id
   - `description`: actionable improvement description
   - `status`: `"active"`
   - `created_at`: current timestamp
4. **Consolidation check**: Every 3 Sprints (check
   `last_consolidation_sprint` against current Sprint id):
   - Archive stale improvements by setting `status: "archived"` and
     `archived_at` to current timestamp
   - Update `last_consolidation_sprint` to current Sprint id
5. **Share report**: Present a brief retrospective report to the user
   summarizing: what went well, what to improve, and any archived items.
6. **Complete Sprint**: Update `sprint.json` → `status: "complete"`.

Reference: FR-012

## Exit Criteria

- At least one new improvement has been recorded in `improvements.json`
- Each new improvement has id, sprint_id, description, status, and created_at
- If consolidation is due (every 3 Sprints): stale improvements archived
  and `last_consolidation_sprint` updated
- `state.json` → `phase: "retrospective"`
- `sprint.json` → `status: "complete"`
