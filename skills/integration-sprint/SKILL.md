---
name: integration-sprint
description: >
  Integration Sprint — product-wide quality assurance with integration,
  E2E, regression testing, and user acceptance testing. Triggered when
  the Product Goal is achieved.
disable-model-invocation: true
---

## Inputs (required state)

- `state.json` → `phase: "retrospective"` (after last Development Sprint)
- User confirmation that the Product Goal is achieved

## Outputs (files/keys updated)

- Integration test results
- E2E test results
- Regression test results
- Documentation consistency checks
- `state.json` → `phase: "integration_sprint"` → `"complete"` when user
  confirms release-ready

## Preconditions

- At least one Development Sprint has been completed
- User has confirmed the Product Goal is sufficiently achieved
- `.scrum/requirements.md` exists for requirements tracing

## Steps

1. **Transition**: Update `state.json` → `phase: "integration_sprint"`.
2. **Integration Testing**: Run integration tests to verify components
   work together across Sprint boundaries.
3. **End-to-End Testing**: Execute E2E tests covering the full user
   workflows defined in `requirements.md`.
4. **Regression Testing**: Re-run all existing tests to confirm no
   regressions introduced across Sprints.
5. **Documentation Consistency**: Verify design documents match the
   implemented code. Check for stale or contradictory documentation.
6. **User Acceptance Testing**:
   a. Prepare the product for hands-on use (launch locally, provide
      start command or URL).
   b. Provide a guided testing flow covering key user workflows.
   c. Collect user feedback at each step.
7. **Defect Handling**:
   - **Minor defects**: Fix within the Integration Sprint.
   - **Major defects**: Add to Product Backlog as new PBIs → return to
     Development Sprints.
8. **Release Decision**: Ask the user if the product is release-ready.
   - If yes: Update `state.json` → `phase: "complete"`.
   - If no: Identify remaining work, return to Development Sprint cycle.

## Exit Criteria

- All test categories executed (integration, E2E, regression)
- Documentation consistency verified
- User acceptance testing completed with feedback collected
- User has confirmed release-ready OR new PBIs created for remaining work
- `state.json` → `phase: "complete"` (if release-ready)
