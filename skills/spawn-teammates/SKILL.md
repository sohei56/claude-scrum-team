---
name: spawn-teammates
description: >
  Reproducible teammate creation during Sprint Planning.
  Reads Sprint and Backlog state, spawns Developer teammates
  via Agent Teams with consistent naming and assignment.
disable-model-invocation: true
---

## Inputs (required state)

- `sprint.json` → `pbi_ids`, `developer_count`
- `backlog.json` → `items[]` (PBIs assigned to this Sprint)

## Outputs (files/keys updated)

- `sprint.json` → `developers[]` populated with:
  - `id` (consistent naming: `dev-001`, `dev-002`, ...)
  - `assigned_work.implement[]` (PBI IDs)
  - `assigned_work.review[]` (PBI IDs, round-robin, no self-review)
  - `status: "active"`
  - `sub_agents: []` (empty, populated at runtime)
- Agent Teams teammates spawned

## Preconditions

- `sprint.json` exists with `status: "planning"` and `pbi_ids` populated
- `backlog.json` contains PBIs with `status: "refined"` matching `pbi_ids`
- Sprint Planning has been completed (implementer/reviewer assignments made)

## Steps

1. Read `sprint.json` to get `developer_count` and `pbi_ids`.
2. Read `backlog.json` to get PBI details for the Sprint.
3. Calculate developer count: `min(number of refined PBIs in Sprint, 6)`.
4. For each Developer (1 to `developer_count`):
   a. Assign a consistent ID: `dev-001`, `dev-002`, etc.
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
        "id": "dev-001",
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
   - Teammates are named consistently (`Dev-001`, `Dev-002`, ...).
7. Verify all teammates are active and have received their assignments.

## Exit Criteria

- `sprint.json` → `developers[]` is populated with `developer_count` entries
- All Developers have non-empty `assigned_work.implement[]`
- All Developers have non-empty `assigned_work.review[]` (or reviewer is
  `"scrum-master"` for single-PBI Sprints)
- No Developer reviews their own implementation
- All Agent Teams teammates are spawned and active
