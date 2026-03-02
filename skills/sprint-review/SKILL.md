---
name: sprint-review
description: Sprint Review ceremony — present Increment to user
disable-model-invocation: true
---

## Inputs

- `state.json` → `phase: review`
- `sprint.json` (current Sprint data: id, goal, type, started_at)
- `backlog.json` (PBI statuses and completion data)

## Outputs

- `sprint-history.json` → `sprints[]` (SprintSummary appended with: id,
  goal, type, pbis_completed, pbis_total, started_at, completed_at)
- `state.json` → `phase: sprint_review`

## Preconditions

- `state.json` exists with `phase: "review"`
- `sprint.json` exists and contains current Sprint data
- `backlog.json` exists and contains PBIs for the current Sprint

## Steps

1. **Transition state**: Update `state.json` → `phase: "sprint_review"`.
2. **Present change summary**: Present to the user what was accomplished
   during the Sprint, including: the Sprint Goal, which PBIs were completed
   (`status: "done"`), and which PBIs remain incomplete (if any).
3. **Live demo**: If any completed PBI has `ux_change: true`, perform a
   live demo of the user-facing changes for the user.
4. **Report scope**: Report the remaining backlog scope and progress toward
   the Product Goal.
5. **Append SprintSummary**: Append a SprintSummary entry to
   `sprint-history.json` → `sprints[]` with:
   - `id`: Sprint identifier from `sprint.json`
   - `goal`: Sprint Goal
   - `type`: Sprint type (e.g., `requirements`, `design`, `implementation`)
   - `pbis_completed`: count of PBIs with `status: "done"`
   - `pbis_total`: total count of PBIs in the Sprint
   - `started_at`: Sprint start timestamp from `sprint.json`
   - `completed_at`: current timestamp
6. **Get user feedback**: Solicit feedback from the user on the Increment
   and any adjustments needed for upcoming work.

Reference: FR-010, FR-011

## Exit Criteria

- SprintSummary has been appended to `sprint-history.json` → `sprints[]`
- User has reviewed the Increment and provided feedback
- `state.json` → `phase: "sprint_review"`
