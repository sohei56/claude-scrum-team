---
name: spawn-teammates
description: >
  Reproducible teammate creation during Sprint Planning.
  Reads Sprint and Backlog state, spawns Developer teammates
  via Agent Teams with consistent naming and assignment.
disable-model-invocation: true
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
4. For each Developer (1 to `developer_count`):
   a. Assign a consistent ID that includes the Sprint number as a suffix:
      `dev-001-s{N}`, `dev-002-s{N}`, etc. (e.g., `dev-001-s3` for Sprint 3).
      Extract the Sprint number from `sprint.json` → `id`.
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
5. Update `sprint.json` → `developers[]` with all Developer entries.
6. Spawn Agent Teams teammates using `agents/developer.md` template:
   - Each teammate receives their PBI assignment via task list.
   - Teammates are named consistently with Sprint suffix (`dev-001-s3`, `dev-002-s3`, ...).
   - The task assignment MUST include explicit skill invocation instructions:
     ```
     Execute these skills in order for your assigned PBIs:
     1. Invoke the `design` skill — author design docs and user-facing documentation
     2. Invoke the `implementation` skill — implement code and tests per design
     3. Invoke the `cross-review` skill — review your assigned peer's work
     Do NOT skip or reorder these steps.
     ```
7. Verify all teammates are active and have received their assignments
   including the skill invocation sequence.
8. Update `sprint.json` → `status: "active"` to mark the Sprint as in progress.

Reference: FR-007

## Exit Criteria

- `sprint.json` → `developers[]` is populated with `developer_count` entries
- All Developers have non-empty `assigned_work.implement[]`
- All Developers have non-empty `assigned_work.review[]` (or reviewer is
  `"scrum-master"` for single-PBI Sprints)
- No Developer reviews their own implementation
- All Agent Teams teammates are spawned and active
- `sprint.json` → `status: "active"`
