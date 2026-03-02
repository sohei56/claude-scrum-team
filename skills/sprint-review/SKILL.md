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
3. **Demo completed work**: For EVERY completed PBI, demonstrate what was
   built. This is mandatory — demos are the core of Sprint Review.
   - **UI/frontend PBIs**: Run the application and show the user the new
     screens, interactions, or visual changes. Walk through the user flow.
   - **API/backend PBIs**: Show example API calls and responses, demonstrate
     new endpoints, or run key tests to show the feature working.
   - **Infrastructure/config PBIs**: Show the configuration changes, run
     relevant commands to demonstrate the setup, or show logs/output proving
     the feature works.
   - **Always narrate**: Explain what each demo shows and how it relates to
     the PBI's acceptance criteria.
   - Skip the demo for a PBI ONLY if the user explicitly says they don't
     need to see it.
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
7. **Commit Sprint deliverables**: Once the user approves the Sprint
   Review, commit all Sprint deliverables to Git:
   - Run `git status` to see all changed/new files.
   - Stage all relevant files (source code, tests, config, design docs,
     `.scrum/` state files). Exclude temporary files, build artifacts,
     and `.DS_Store`.
   - Create a commit with a message following this format:
     ```
     feat(sprint-N): <Sprint Goal summary>

     Completed PBIs:
     - PBI-XXX: <title>
     - PBI-YYY: <title>

     Co-Authored-By: <developer teammates who contributed>
     ```
   - Report the commit hash to the user.
   - Do NOT push to a remote — leave that to the user.

Reference: FR-010, FR-011

## Exit Criteria

- SprintSummary has been appended to `sprint-history.json` → `sprints[]`
- User has reviewed the Increment and provided feedback
- Sprint deliverables have been committed to Git
- `state.json` → `phase: "sprint_review"`
