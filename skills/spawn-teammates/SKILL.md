---
name: spawn-teammates
description: >
  Reproducible teammate creation during Sprint Planning.
  Reads Sprint and Backlog state, spawns Developer teammates
  via Agent Teams with consistent naming and assignment.
disable-model-invocation: false
---

## Inputs

- `sprint.json` → `pbi_ids`, `developer_count`
- `backlog.json` → `items[]` (PBIs assigned to this Sprint)

## Outputs

- `sprint.json` → `developers[]` populated with:
  - `id` (consistent naming with Sprint suffix: `dev-001-s3`, `dev-002-s3`, ...)
  - `assigned_work.implement[]` (PBI IDs)
  - `assigned_work.review[]` (PBI IDs, round-robin, no self-review)
  - `status: "active"`
  - `sub_agents: []` (empty, populated at runtime)
- `sprint.json` → `status: "active"`
- Agent Teams teammates spawned

## Preconditions

- `state.json` exists with `phase: "sprint_planning"` or `"integration_sprint"`
- `sprint.json` exists with `status: "planning"` and `pbi_ids` populated
- `backlog.json` contains PBIs with `status: "refined"` matching `pbi_ids`
- Sprint Planning has been completed (implementer/reviewer assignments made)

## Steps

1. Read `sprint.json` to get `developer_count` and `pbi_ids`.
2. Read `backlog.json` to get PBI details for the Sprint.
3. Calculate developer count: `min(number of refined PBIs in Sprint, 6)`.
   **Each Developer owns exactly ONE PBI** — this is a 1:1 mapping.
   `developer_count` MUST equal the number of PBIs in the Sprint (capped at 6).
4. Extract the Sprint number `N` from `sprint.json` → `id` (e.g., `"sprint-001"` → `1`, `"sprint-002"` → `2`).
5. For each Developer (1 to `developer_count`):
   a. Assign a consistent ID using this **exact** format — zero-padded,
      with Sprint suffix: `dev-001-s{N}`, `dev-002-s{N}`, etc.
      Examples: `dev-001-s1`, `dev-002-s1` (Sprint 1); `dev-001-s3`, `dev-002-s3` (Sprint 3).
      **Do NOT use short forms** like `dev-1` or `dev-2` — always include
      the zero-padded number and `-s{N}` suffix.
   b. Determine implementation assignment from `backlog.json` →
      `items[].implementer_id`.
   c. Determine review assignment (round-robin):
      - Each Developer reviews the next Developer's PBI(s).
      - No Developer reviews their own work.
      - In a single-PBI Sprint (one Developer), `reviewer_id` is
        `"scrum-master"` — the Scrum Master performs the review.
   d. Create Developer entry:
      ```json
      {
        "id": "dev-001-s3",
        "assigned_work": {
          "implement": ["pbi-001"],
          "review": ["pbi-002"]
        },
        "status": "active",
        "sub_agents": []
      }
      ```
6. **Reconcile `backlog.json` assignments**: After determining developer IDs,
   update every selected PBI in `backlog.json` so that `implementer_id` and
   `reviewer_id` match the **exact** developer IDs created above. This step
   is critical — sprint-planning may have used placeholder IDs that differ
   from the final `dev-NNN-sN` format.
7. Update `sprint.json` → `developers[]` with all Developer entries and
   set `developer_count` to the number of developers. The TUI dashboard
   reads both `developers[]` and `developer_count` from `sprint.json` to
   display the Agents section — if these fields are missing, the dashboard
   will show nothing.
8. Spawn Agent Teams teammates using `agents/developer.md` template:
   - Each teammate receives their PBI assignment via task list.
   - Teammates **MUST** be named with the exact ID from step 5a
     (e.g., `dev-001-s1`, `dev-002-s1`). Do NOT use short names.
   - The task assignment MUST include explicit skill invocation instructions:
     ```
     Execute these skills in order for your assigned PBIs:
     1. Invoke the `design` skill — author design docs and user-facing documentation
     2. Invoke the `implementation` skill — implement code and tests per design
     3. Invoke the `cross-review` skill — review your assigned peer's work
     Do NOT skip or reorder these steps.
     ```
9. Verify all teammates are active and have received their assignments
   including the skill invocation sequence.
10. Update `sprint.json` → `status: "active"` to mark the Sprint as in progress.

Reference: FR-007

## Exit Criteria

- `sprint.json` → `developers[]` is populated with `developer_count` entries
- All Developers have non-empty `assigned_work.implement[]`
- All Developers have non-empty `assigned_work.review[]` (or reviewer is
  `"scrum-master"` for single-PBI Sprints)
- No Developer reviews their own implementation
- All Agent Teams teammates are spawned and active
- `sprint.json` → `status: "active"`
