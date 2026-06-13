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
- backlog.json → new draft PBIs for every leftover (carry-over / doc mismatch / defect / change)
- state.json → phase: sprint_review
- sprint.json → status: "sprint_review"

## Preconditions

- state.json phase: "review"
- sprint.json, backlog.json exist

## PO Mode (po_mode: "agent")

When `.scrum/config.json.po_mode == "agent"`, the human user is not
the PO seat — the `product-owner` teammate is. The ceremony shape is
unchanged; only the destination of PO-approval prompts is re-targeted.
Apply the following overrides to the Steps below; everything not in
this table runs verbatim.

| Step                             | Override (po_mode=agent)                                                                                                                                                                                                                                                                                                                                                  |
|----------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 3. Launch app                    | The PO (not SM) launches the app as part of `po-acceptance`. SM still emits the access URL/port observation to the main session for the watching human, but does not wait on a human reply. App-launch failure is `fail`, not skip (the `po-acceptance` skill enforces this in step 1.4).                                                                                  |
| 4. Demo EVERY completed PBI      | SM sends `[sprint-<N>] PO_DECISION_REQUEST kind=demo_acceptance options=[pass,fail,waive] recommendation=pass` with the completed-PBI list; the PO teammate then runs the `po-acceptance` skill (`mode=demo`) on its own (the skill lives in the PO's `skills:` allowlist, not the SM's). The PO launches and operates the app, verifies each AC by runnable command, and returns one `kind=demo_acceptance` decision per PBI. `fail` routes to step 9. |
| 5. Doc-implementation consistency | Unchanged — engineering quality, owned by SM/Developer (the PO cannot lower this gate).                                                                                                                                                                                                                                                                                   |
| 8. Get user feedback             | Replaced by a single structured pass — see step 9 override. No human-input wait.                                                                                                                                                                                                                                                                                          |
| 9. Defect/change handling        | The "repeat until user says that's all" loop collapses to **one** structured PO pass: the PO returns a single message listing (a) gaps against `docs/product/vision.md` and (b) defects observed during the demo, terminated by `FEEDBACK_COMPLETE`. Each defect is recorded as `kind=defect_triage` with priority; each becomes a draft PBI exactly as in human mode.     |
| 11. Leftover Summary             | Include any `assumption=true` PO decisions (from `.scrum/po/decisions.json` written this Sprint) as a fourth group: `Assumed decisions to re-examine: <dec-id> <kind> <rationale>`. These are surfaced for next-Sprint Refinement.                                                                                                                                         |

The "Ask user to confirm" / "Get user feedback" / "user says that's
all" phrases in the Steps below are mode-agnostic: under
`po_mode=agent` they resolve to `PO_DECISION_REQUEST` / structured
PO reply per the table above, not to human prompts. SM never blocks
on `read` from stdin in this mode.

## Steps

1. state.json → phase: "sprint_review", sprint.json → status: "sprint_review":
   ```bash
   .scrum/scripts/update-state-phase.sh sprint_review
   .scrum/scripts/update-sprint-status.sh sprint_review
   ```
2. **Present change summary**: Sprint Goal, completed PBIs (status: done), incomplete PBIs (carry-over candidates)
3. **Launch app (mandatory)**: Detect start command (package.json/Makefile/docker-compose etc)→start→confirm running→fail→fix+retry (never skip demo)→tell user access URL/port
   - **po_mode=agent**: do not launch the app from SM; the `po-acceptance` skill (mode=demo) launches it. SM still announces access URL/port observed in `_app.log` for the watching human (observation only, no wait). Launch failure is `fail`, not skip.
4. **Demo EVERY completed PBI (mandatory)**:
   a. State PBI name
   b. Show it working (navigate/call API/run command)
   c. Point out what to verify (be specific: "login form with email + password fields")
   d. Ask user to confirm→wait→next PBI. Skip only if user explicitly says no need
   - **po_mode=agent**: skip step 4a–d. Send `[sprint-<N>] PO_DECISION_REQUEST kind=demo_acceptance options=[pass,fail,waive] recommendation=pass pbis=[<list>]`; the PO teammate runs `po-acceptance` (mode=demo) on its own — the skill is on the PO's allowlist, not the SM's. PO operates the app itself, returns one `kind=demo_acceptance` decision per PBI plus the aggregated `PO_ACCEPTANCE_REPORT`. fail → step 9 defect route.
5. **Doc-implementation consistency**: For every completed PBI→compare docs vs code→mismatch→`add-backlog-item.sh` (status: draft). Track each new pbi-id for the Leftover Summary.
6. Report remaining backlog scope + Product Goal progress
7. Append SprintSummary to sprint-history.json: id, goal, type, pbis_completed, pbis_total, started_at, completed_at
8. Get user feedback
   - **po_mode=agent**: merged into step 9's single structured PO pass; no separate prompt.
9. **Defect/change handling**:
   a. **NEVER fix during Sprint Review** (not even quick fixes — inspection ceremony only)
   b. Each defect/change/feedback item → `add-backlog-item.sh` (status: draft). Track each new pbi-id.
   c. "Will be prioritized in next Sprint via Backlog Refinement→Sprint Planning"
   d. After user confirms "that's all"→proceed
   - **po_mode=agent**: replace the "repeat until user says that's all" loop with **one** PO pass. SM sends `[sprint-<N>] PO_DECISION_REQUEST kind=defect_triage options=[high,medium,low,reject] recommendation=<...>` once; the PO returns a single message listing (a) gaps against `docs/product/vision.md` and (b) demo-observed defects, terminated by `FEEDBACK_COMPLETE`. Each listed defect produces a separate `kind=defect_triage` decision + a draft PBI via `add-backlog-item.sh`. No further round-trips.
10. **Carry-over PBIs (mandatory)**: For every PBI in this sprint where `status != "done"` (any `in_progress_*` / `awaiting_cross_review` / `cross_review` / `escalated` / `blocked` / refined-but-not-started):
    a. Create a new draft PBI capturing the remaining work via `add-backlog-item.sh` — embed origin in description (`Carry-over from <pbi-id>: <what is left>`).
    b. Original PBI keeps its current status (immutable historical record of this Sprint).
    c. Track each new pbi-id for the Leftover Summary.

    ```bash
    .scrum/scripts/add-backlog-item.sh \
      --title "Carry-over: <orig title>" \
      --description "Continuation of <pbi-id>. Remaining: <concise scope>." \
      --ac "<criterion 1>" --ac "<criterion 2>"
    ```

11. **Leftover Summary (mandatory report)**: Print to user a single consolidated list of every draft PBI created during this Sprint Review, grouped:
    - Carry-overs (from step 10): `<new-pbi-id> ← <orig-pbi-id>: <title>`
    - Doc/impl mismatches (step 5): `<new-pbi-id>: <title>`
    - Defects / changes / feedback (step 9): `<new-pbi-id>: <title>`

    State explicitly: "These N items enter the backlog as drafts and will be re-prioritized in the next Sprint's Backlog Refinement → Sprint Planning. Nothing is dropped."
    - **po_mode=agent**: add a fourth group `Assumed PO decisions to re-examine:` listing every entry from `.scrum/po/decisions.json` written this Sprint with `assumption=true` — `<dec-id> <kind> <rationale>`. These are not new PBIs; they are PO-side risk items surfaced for next-Sprint Refinement.
12. **Commit Sprint deliverables**: git status→stage relevant files (exclude temp/artifacts/.DS_Store)→commit:
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
- Every leftover (carry-over + doc mismatch + defect/change/feedback) materialised as a draft PBI in backlog.json — none dropped
- Leftover Summary reported to user
- Sprint deliverables committed
- state.json phase: "sprint_review"
