---
name: sprint-review
description: Sprint Review ceremony — present Increment to user
disable-model-invocation: false
---

## Inputs

- state.json → phase: review
- sprint.json (Sprint data)
- backlog.json (PBI statuses)

## Outputs

- sprint-history.json → sprints[] (SprintSummary appended)
- state.json → phase: sprint_review
- sprint.json → status: "sprint_review"

## Preconditions

- state.json phase: "review"
- sprint.json, backlog.json exist

## Steps

1. state.json → phase: "sprint_review", sprint.json → status: "sprint_review"
2. **Present change summary**: Sprint Goal, completed PBIs (status: done), incomplete PBIs
3. **Launch app (mandatory)**: Detect start command (package.json/Makefile/docker-compose etc)→start→confirm running→fail→fix+retry (never skip demo)→tell user access URL/port
4. **Demo EVERY completed PBI (mandatory)**:
   a. State PBI name
   b. Show it working (navigate/call API/run command)
   c. Point out what to verify (be specific: "login form with email + password fields")
   d. Ask user to confirm→wait→next PBI. Skip only if user explicitly says no need
5. **Doc-implementation consistency**: For every completed PBI→compare docs vs code→mismatch→create draft PBI in backlog.json
6. Report remaining backlog scope + Product Goal progress
7. Append SprintSummary to sprint-history.json: id, goal, type, pbis_completed, pbis_total, started_at, completed_at
8. Get user feedback
9. **Defect/change handling**:
   a. **NEVER fix during Sprint Review** (not even quick fixes — inspection ceremony only)
   b. Each defect/change→new PBI in backlog.json (status: draft)
   c. "Will be prioritized in next Sprint via Backlog Refinement→Sprint Planning"
   d. After user confirms "that's all"→proceed
10. **Commit Sprint deliverables**: git status→stage relevant files (exclude temp/artifacts/.DS_Store)→commit:
    ```
    feat(sprint-N): <Sprint Goal>

    Completed PBIs:
    - PBI-XXX: <title>

    Co-Authored-By: <contributing developers>
    ```
    Report commit hash. Do NOT push.

Ref: FR-010, FR-011

## Exit Criteria

- SprintSummary appended to sprint-history.json
- User reviewed Increment + gave feedback
- Doc-implementation consistency checked
- Inconsistencies→draft PBIs created
- Defects/changes→new PBIs (NOT fixed directly)
- Sprint deliverables committed
- state.json phase: "sprint_review"
