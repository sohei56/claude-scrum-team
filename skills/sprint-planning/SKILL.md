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
- `backlog.json` -> oversized PBIs split into child PBIs with `parent_pbi_id` set
- `state.json` -> `phase: sprint_planning`

## Preconditions

- `state.json` exists with `phase` set to `backlog_created` or `retrospective`
- `backlog.json` exists with at least one PBI having `status: refined`
- No active Sprint is already in progress

## Steps

1. Propose a Sprint Goal summarizing the work to be done. Present it to the user for approval before proceeding.
2. Select refined PBIs for the Sprint. Avoid placing dependent PBIs in the same Sprint (per FR-008) to enable parallel development.
3. **Evaluate PBI size and split if needed**: For each selected PBI, assess
   whether its scope is too large for a single developer to complete within
   the Sprint. Indicators of an oversized PBI include: multiple distinct
   features bundled together, changes spanning many unrelated modules, or
   acceptance criteria that cover several independent behaviors.
   - If a PBI is too large, the Scrum Master MUST split it into smaller
     child PBIs before proceeding. For each child PBI:
     - Create a new PBI in `backlog.json` with `status: "refined"`.
     - Copy relevant acceptance criteria from the parent (split them, do
       not duplicate).
     - Set `parent_pbi_id` to the original PBI's ID.
     - Copy `design_doc_paths` and `ux_change` as appropriate.
   - Update the parent PBI's `status` to `"refined"` and remove it from
     the Sprint selection — replace it with its child PBIs.
   - Present the split to the user for confirmation before proceeding.
4. Calculate `developer_count = min(number of refined PBIs selected for sprint, 6)`.
5. Assign implementers: one developer per PBI, distributing evenly across the developer pool.
6. Assign reviewers using round-robin allocation:
   - No self-review: a developer cannot review their own PBI.
   - Single-PBI Sprint: set `reviewer_id` to `"scrum-master"` since no peer is available.
7. Create `sprint.json` with fields: `id`, `goal`, `type: development`, `status: planning`, `pbi_ids`, `developer_count`.
8. Update `backlog.json`: set `sprint_id`, `implementer_id`, and `reviewer_id` on each selected PBI.
9. Update `state.json` to `phase: sprint_planning`.
10. **Present Sprint summary and options**: After completing the Sprint
    Planning, present a clear summary of the Sprint plan to the user,
    then offer these options:
    - **1. Start Sprint** — Proceed to the design/implementation phase
    - **2. Adjust Sprint Goal** — Modify the Sprint Goal
    - **3. Change PBI selection** — Add or remove PBIs from this Sprint
    - **4. Re-assign developers** — Change PBI assignments
    - **5. View backlog** — Show the full Product Backlog with priorities
    - **6. Other** — Free-form input

    Wait for the user to select an option before proceeding.

11. **Enable design catalog entries and scaffold stubs** (when user selects "Start Sprint"):
    Before spawning teammates, the Scrum Master MUST:
    a. Review the PBIs selected for this Sprint and determine which design
       document types are needed (e.g., Screen/Page Design for UI PBIs,
       API Specification for backend PBIs, Data Model for schema changes).
    b. Update `.design/catalog.md` — flip relevant entries from `disabled`
       to `enabled` if they are not already enabled.
    c. Invoke the `scaffold-design-spec` skill to create stub files for any
       newly enabled entries that do not yet have files.
    d. Only after stubs are created, proceed to `spawn-teammates`.

    This step ensures Developers have design document stubs ready to
    populate when they enter the Design Phase.

Reference: FR-004, FR-005, FR-006, FR-007, FR-008

## Exit Criteria

- `sprint.json` exists with `status: planning` and all required fields populated
- All selected PBIs in `backlog.json` have `implementer_id` and `reviewer_id` assigned
- No PBI has the same `implementer_id` and `reviewer_id` (no self-review)
- `state.json` phase is `sprint_planning`
