---
name: sprint-planning
description: Sprint Planning ceremony — select PBIs, assign developers, create Sprint
disable-model-invocation: true
---

## Inputs

- `state.json` -> `phase: backlog_created | retrospective`
- `backlog.json` -> PBIs with `status: refined`

## Outputs

- `sprint.json` created with `id`, `goal`, `type: development`, `status: planning`, `pbi_ids`, `developer_count`
- `backlog.json` -> `items[].sprint_id` assigned
- `backlog.json` -> `items[].implementer_id` assigned (one developer per PBI)
- `backlog.json` -> `items[].reviewer_id` assigned (round-robin, no self-review; single-PBI Sprint: `reviewer_id = "scrum-master"`)
- `state.json` -> `phase: sprint_planning`

## Preconditions

- `state.json` exists with `phase` set to `backlog_created` or `retrospective`
- `backlog.json` exists with at least one PBI having `status: refined`
- No active Sprint is already in progress

## Steps

1. Propose a Sprint Goal summarizing the work to be done. Present it to the user for approval before proceeding.
2. Select refined PBIs for the Sprint. Avoid placing dependent PBIs in the same Sprint (per FR-008) to enable parallel development.
3. Calculate `developer_count = min(number of refined PBIs selected for sprint, 6)`.
4. Assign implementers: one developer per PBI, distributing evenly across the developer pool.
5. Assign reviewers using round-robin allocation:
   - No self-review: a developer cannot review their own PBI.
   - Single-PBI Sprint: set `reviewer_id` to `"scrum-master"` since no peer is available.
6. Create `sprint.json` with fields: `id`, `goal`, `type: development`, `status: planning`, `pbi_ids`, `developer_count`.
7. Update `backlog.json`: set `sprint_id`, `implementer_id`, and `reviewer_id` on each selected PBI.
8. Update `state.json` to `phase: sprint_planning`.
9. **Present Sprint summary and options**: After completing the Sprint
   Planning, present a clear summary of the Sprint plan to the user,
   then offer these options:
   - **1. Start Sprint** — Proceed to the design/implementation phase
   - **2. Adjust Sprint Goal** — Modify the Sprint Goal
   - **3. Change PBI selection** — Add or remove PBIs from this Sprint
   - **4. Re-assign developers** — Change PBI assignments
   - **5. View backlog** — Show the full Product Backlog with priorities
   - **6. Other** — Free-form input

   Wait for the user to select an option before proceeding.

Reference: FR-005, FR-006, FR-007, FR-008

## Exit Criteria

- `sprint.json` exists with `status: planning` and all required fields populated
- All selected PBIs in `backlog.json` have `implementer_id` and `reviewer_id` assigned
- No PBI has the same `implementer_id` and `reviewer_id` (no self-review)
- `state.json` phase is `sprint_planning`
