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
- `sprint.json` → `status: "sprint_review"`

## Preconditions

- `state.json` exists with `phase: "review"`
- `sprint.json` exists and contains current Sprint data
- `backlog.json` exists and contains PBIs for the current Sprint

## Steps

1. **Transition state**: Update `state.json` → `phase: "sprint_review"`.
   Update `sprint.json` → `status: "sprint_review"`.
2. **Present change summary**: Present to the user what was accomplished
   during the Sprint, including: the Sprint Goal, which PBIs were completed
   (`status: "done"`), and which PBIs remain incomplete (if any).
3. **Launch the application**: This is mandatory — you MUST launch the app
   locally before presenting any PBI demos. Do NOT skip this step.
   a. Detect the start command: check `package.json` scripts (`dev`,
      `start`), `Makefile`, `docker-compose.yml`, `manage.py runserver`,
      `cargo run`, or similar. If unsure, read the project README.
   b. Run the start command and confirm the app is running (e.g., server
      listening on a port, UI accessible at a URL, CLI producing output).
   c. If the app fails to start, troubleshoot the error, fix it, and
      retry. Do NOT skip the demo because of a startup failure.
   d. Tell the user the app is running and where to access it (URL, port,
      or command).
4. **Demo each completed PBI**: For EVERY completed PBI, demonstrate what
   was built. This is mandatory — demos are the core of Sprint Review.
   For each PBI:
   a. **State the PBI**: "Now demonstrating PBI-XXX: <title>".
   b. **Show it working**: Perform the concrete action that proves the PBI
      is done — navigate to a page, call an endpoint, run a command, or
      trigger the feature.
   c. **Point out what to verify**: Tell the user exactly what behavior
      they should see. Be specific:
      - "You should see a login form with email and password fields"
      - "The API should return a 200 with a JSON array of items"
      - "The config file should now include the new database section"
   d. **Ask the user to confirm**: "Can you confirm this is working as
      expected?" — wait for their response before moving to the next PBI.
   - Skip the demo for a PBI ONLY if the user explicitly says they don't
     need to see it.
5. **Report scope**: Report the remaining backlog scope and progress toward
   the Product Goal.
6. **Append SprintSummary**: Append a SprintSummary entry to
   `sprint-history.json` → `sprints[]` with:
   - `id`: Sprint identifier from `sprint.json`
   - `goal`: Sprint Goal
   - `type`: Sprint type (e.g., `requirements`, `design`, `implementation`)
   - `pbis_completed`: count of PBIs with `status: "done"`
   - `pbis_total`: total count of PBIs in the Sprint
   - `started_at`: Sprint start timestamp from `sprint.json`
   - `completed_at`: current timestamp
7. **Get user feedback**: Solicit feedback from the user on the Increment
   and any adjustments needed for upcoming work.
8. **Handle defects and feedback**: If the user reports bugs, defects,
   or requests changes:
   a. **Do NOT fix anything directly** — the Scrum Master operates in
      Delegate mode and must never write code or make implementation
      changes during Sprint Review.
   b. **Create a new PBI** in `backlog.json` for EACH reported defect or
      change request, with `status: "draft"` and a clear title/description
      of the issue.
   c. Acknowledge each item and confirm it has been added to the backlog.
   d. After the user confirms "that's all" or indicates they have no more
      feedback, proceed to the next step.
   e. These new PBIs will be addressed in the next Sprint through the
      normal Backlog Refinement → Sprint Planning workflow.
9. **Commit Sprint deliverables**: Once the user approves the Sprint
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
- Any reported defects/changes have been created as new PBIs in `backlog.json` (NOT fixed directly)
- Sprint deliverables have been committed to Git
- `state.json` → `phase: "sprint_review"`
