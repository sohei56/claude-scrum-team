---
name: sprint-planning
description: Sprint Planning ceremony — select PBIs, assign developers, create Sprint
disable-model-invocation: false
---

## Inputs

- `state.json` → phase: backlog_created | retrospective
- `backlog.json` → PBIs with status: refined

## Outputs

- `sprint.json`: id, goal, type: development, status: planning, pbi_ids, developer_count
- `backlog.json` → items[].sprint_id, implementer_id, reviewer_id assigned
- Oversized PBIs split into children (parent_pbi_id set)
- `state.json` → phase: sprint_planning

## Preconditions

- state.json phase: "backlog_created" or "retrospective"
- backlog.json has ≥1 refined PBI
- No active Sprint in progress

## Steps

1. **Transition state (first action)**: state.json → phase: "sprint_planning" (TUI reflects immediately)
2. Propose Sprint Goal→user approval before proceeding
3. Select refined PBIs. Avoid dependent PBIs in same Sprint (FR-008)
4. **Evaluate + split oversized PBIs**: Too large→create child PBIs (status: "refined", parent_pbi_id set, split acceptance_criteria, copy design_doc_paths/ux_change)→remove parent from Sprint→replace with children→user confirmation
5. developer_count = min(selected PBI count, 6). **1 Developer = 1 PBI (hard constraint).** >6 PBIs→select 6, defer rest
6. Assign implementers: format `dev-001-s{N}`, `dev-002-s{N}` (zero-pad mandatory, -s{N} suffix mandatory, no short forms)
7. Assign reviewers: round-robin (no self-review). Single-PBI Sprint→reviewer_id: "scrum-master"
8. Create sprint.json
9. Update backlog.json: sprint_id, implementer_id, reviewer_id
10. **Present Sprint summary + options**:
    - 1. Start Sprint
    - 2. Adjust Sprint Goal
    - 3. Change PBI selection
    - 4. Re-assign developers
    - 5. View backlog
    - 6. Other
    → Wait for user selection
11. **On "Start Sprint"**: Enable catalog-config.json entries→run scaffold-design-spec→spawn-teammates

Ref: FR-004, FR-005, FR-006, FR-007, FR-008

## Exit Criteria

- sprint.json exists (status: planning, all fields set)
- All PBIs: implementer_id + reviewer_id assigned
- 1 Developer = 1 PBI (1:1)
- No self-review
- state.json phase: sprint_planning
