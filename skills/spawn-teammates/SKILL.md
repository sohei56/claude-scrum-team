---
name: spawn-teammates
description: >
  Reproducible teammate creation during Sprint Planning.
  Reads Sprint and Backlog state, spawns Developer teammates
  via Agent Teams with consistent naming and assignment.
disable-model-invocation: false
---

## Inputs

- `sprint.json` → pbi_ids, developer_count
- `backlog.json` → Sprint PBIs

## Outputs

- `sprint.json` → developers[] populated, status: "active"
- Agent Teams teammates spawned

## Preconditions

- state.json phase: "sprint_planning" or "integration_sprint"
- sprint.json status: "planning", pbi_ids set
- backlog.json PBIs status: refined matching pbi_ids

## Steps

1. Read sprint.json→developer_count, pbi_ids
2. Read backlog.json→PBI details
3. developer_count = min(Sprint refined PBIs, 6). **1 Developer = 1 PBI**
4. Extract Sprint number N from sprint.json id (e.g., "sprint-001"→1)
5. Each Developer:
   a. ID: `dev-001-s{N}`, `dev-002-s{N}` (zero-pad + -s{N} mandatory, no short forms)
   b. Implement assignment from backlog.json implementer_id
   c. Review assignment: round-robin (no self-review, single-PBI→"scrum-master")
   d. Entry: `{"id": "dev-001-s{N}", "assigned_work": {"implement": [...], "review": [...]}, "status": "active", "sub_agents": []}`
6. **Reconcile backlog.json**: Update all PBI implementer_id/reviewer_id to match final dev-NNN-sN IDs
7. Update sprint.json→developers[] + developer_count (TUI dashboard reads both)
8. Spawn Agent Teams teammates (agents/developer.md). Name = exact ID from 5a. Task:
   ```
   Execute these skills in order for your assigned PBIs:
   1. Invoke the `design` skill
   2. Invoke the `implementation` skill
   3. Invoke the `cross-review` skill
   Do NOT skip or reorder these steps.
   ```
9. Verify all teammates active + assignments received
10. sprint.json → status: "active"

Ref: FR-007

## Exit Criteria

- sprint.json developers[] = developer_count entries
- All Developers: assigned_work.implement[] non-empty, review[] non-empty (or scrum-master)
- No self-review
- All teammates spawned + active
- sprint.json status: "active"
