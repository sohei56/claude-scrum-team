---
name: integration-sprint
description: >
  Integration Sprint — product-wide quality assurance with integration,
  E2E, regression testing, and user acceptance testing. Triggered when
  the Product Goal is achieved.
disable-model-invocation: false
---

## Inputs

- `state.json` → `phase: "retrospective"` (after last Development Sprint)
- User confirmation that the Product Goal is achieved

## Outputs

- `.scrum/test-results.json` — structured test results from automated testing
- `state.json` → `phase: "integration_sprint"` → `"complete"` when user
  confirms release-ready

## Preconditions

- At least one Development Sprint has been completed
- User has confirmed the Product Goal is sufficiently achieved
- `.scrum/requirements.md` exists for requirements tracing

## Steps

1. **Transition**: Update `state.json` → `phase: "integration_sprint"`.

2. **Spawn testing teammates**: Spawn 1-2 Developer teammates specifically
   for testing (use the `spawn-teammates` skill with integration Sprint
   context). These Developers will run the `smoke-test` skill.

3. **Delegate automated testing**: Assign the `smoke-test` skill to the
   testing teammates. The skill will:
   - Auto-detect test frameworks (npm test, pytest, cargo test, etc.)
   - Run all detected tests and record pass/fail results
   - Start the app and HTTP smoke-test every discovered endpoint
   - Run browser E2E tests via Playwright MCP (if configured)
   - Write structured results to `.scrum/test-results.json`

   **Wait for testing to complete.** Do NOT proceed until teammates report back.

4. **Quality gate — review test results**: Read `.scrum/test-results.json`.
   - If `overall_status: "passed"`: proceed to step 5.
   - If `overall_status: "passed_with_skips"`: inform the user which test
     categories were skipped and why. Proceed to step 5, but note the
     skipped categories in the UAT checklist so the user can manually
     verify those areas.
   - If `overall_status: "failed"`:
     - Review the `errors` array for each failed category
     - Self-review: check for related issues in adjacent code/endpoints
     - Present the full list of automated test failures to the user
     - Ask the user if they see additional related issues
     - Create a PBI in `backlog.json` for EACH confirmed failure
     - Transition to a Development Sprint (step 8) to fix all PBIs
     - After the fix Sprint, return to step 1 to re-run Integration Sprint
   - **BLOCK UAT until all automated tests pass.** Do NOT skip this gate.
   - **No Developer may fix code without an assigned PBI.** Do NOT
     directly assign ad-hoc fixes to teammates.

5. **User Acceptance Testing**: This is mandatory — you MUST launch the app
   and walk the user through verification. Do NOT skip this step.
   a. **Verify the application is running**: The app should already be
      running from automated testing (smoke-test). If it was shut down,
      re-launch it using the start command identified during smoke testing.
      Confirm the app is accessible and tell the user where to find it.
   b. **Build a verification checklist**: For each key user workflow from
      `requirements.md`, create a numbered checklist of specific behaviors
      the user should verify. Be concrete:
      - "1. Open http://localhost:3000 — you should see the landing page
        with a navigation bar and hero section"
      - "2. Click 'Sign Up' — a registration form with name, email, and
        password fields should appear"
      - "3. Submit with valid data — you should be redirected to the
        dashboard with a welcome message"
   c. **Walk through each item**: Present each checklist item one at a
      time. After each item, ask the user: "Does this work as expected?"
      Wait for their response before moving to the next item.
   d. **Record results**: Note which items pass and which have issues.
      Issues become defects for step 6.

6. **Defect Collection** (do NOT fix anything yet):
   Collect ALL defects before any implementation work begins.

   a. **Gather user-reported defects**: Present every UAT failure to the user
      and ask: "Are there any other issues you noticed? Any related areas
      that feel wrong?" Keep asking until the user confirms "that's all."
   b. **Scrum Master self-review**: Independently review the failing areas
      and related code. Propose additional fixes the user may not have
      noticed — similar patterns, adjacent features, related endpoints,
      shared components. Present these proposals to the user for confirmation.
   c. **Consolidate the full defect list**: Merge user-reported and
      Scrum-Master-proposed defects into a single numbered list. Present the
      consolidated list to the user and get confirmation that it is complete.

7. **Defect-to-PBI Conversion**:
   For EACH confirmed defect, create a new PBI in `backlog.json`:
   - Set `status: "draft"`, then immediately refine to `status: "refined"`
   - Write clear `acceptance_criteria` describing the expected vs. actual behavior
   - Set `priority` based on severity (user-facing breakage = high priority)

   **RULE: No Developer may implement ANY fix without an assigned PBI.**
   This is non-negotiable — ad-hoc fixes outside the PBI workflow are
   strictly forbidden.

8. **Return to Development Sprint**: Transition `state.json` →
   `phase: "backlog_created"`. Run the normal Development Sprint cycle
   (Backlog Refinement → Sprint Planning → Design → Implementation →
   Cross-Review → Sprint Review → Retrospective) to address the fix
   PBIs. After the fix Sprint completes, the Scrum Master will
   re-evaluate the Product Goal — if all PBIs are done, the workflow
   naturally re-enters Integration Sprint for re-testing.

9. **Release Decision**: Ask the user if the product is release-ready.
    - If yes: Update `state.json` → `phase: "complete"`.
    - If no: Identify remaining work, return to Development Sprint cycle.

Reference: FR-013

## Exit Criteria

- `.scrum/test-results.json` exists with `overall_status: "passed"` or `"passed_with_skips"`
- All detectable test categories executed or explicitly skipped
- User acceptance testing completed with feedback collected
- User has confirmed release-ready OR new PBIs created for remaining work
- `state.json` → `phase: "complete"` (if release-ready)
