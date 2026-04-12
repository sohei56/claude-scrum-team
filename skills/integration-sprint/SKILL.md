---
name: integration-sprint
description: >
  Integration Sprint — product-wide quality assurance with integration,
  E2E, regression testing, and user acceptance testing. Triggered when
  the Product Goal is achieved.
disable-model-invocation: false
---

## Inputs

- state.json → phase: "retrospective"
- User confirmation Product Goal achieved

## Outputs

- `.scrum/test-results.json`
- state.json → phase: "integration_sprint"→"complete" when release-ready

## Preconditions

- ≥1 Development Sprint completed
- User confirmed Product Goal sufficiently achieved
- requirements.md exists

## Steps

1. state.json → phase: "integration_sprint"
2. Spawn 1-2 Developer teammates for testing (spawn-teammates skill)
3. Delegate smoke-test skill→**wait for completion** (do NOT proceed early)
4. **Quality gate — test-results.json**:
   - passed→step 5
   - passed_with_skips→inform user which categories skipped + why→step 5 (note skipped areas in UAT checklist)
   - failed→review errors→self-review related code→present all failures→ask user for additional issues→create PBI per confirmed failure→step 8 (Development Sprint)→re-enter Integration Sprint after fix
   - **Block UAT until automated tests pass**
   - **No fix without assigned PBI**
5. **UAT (mandatory)**:
   a. Verify app running (re-launch if stopped)→tell user access point
   b. Build verification checklist from requirements.md key workflows (specific behaviors)
   c. Walk through each item→ask user "works as expected?"→wait→next
   d. Record results→issues go to step 6
6. **Defect collection (no fixing yet)**:
   a. Present UAT failures→"any other issues?"→repeat until user says "that's all"
   b. SM self-review: related code, adjacent features, shared components→propose additional fixes→user confirmation
   c. Consolidate full defect list→user confirms complete
7. **Defect→PBI**: Each confirmed defect→backlog.json PBI (status: draft→immediately refined, acceptance_criteria: expected vs actual, priority by severity). **No fix without assigned PBI — non-negotiable**
8. **Return to Development Sprint**: state.json → phase: "backlog_created"→normal Sprint cycle (Refinement→Planning→Design→Implementation→Review→Sprint Review→Retrospective)→after fix Sprint→re-evaluate Product Goal→re-enter Integration Sprint
9. **Release decision**: User confirms release-ready→state.json phase: "complete". Not ready→identify remaining work→Development Sprint

Ref: FR-013

## Exit Criteria

- test-results.json exists (passed or passed_with_skips)
- All test categories executed or skipped
- UAT completed with feedback
- Release confirmed→phase: "complete" OR new PBIs created
