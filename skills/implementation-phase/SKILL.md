---
name: implementation-phase
description: Implementation phase — Developers implement PBIs per design documents
disable-model-invocation: true
---

## Inputs

- `state.json` -> `phase: design`
- `sprint.json` (current Sprint with developer assignments)
- `.design/specs/**/*.md` (populated design documents)
- `requirements.md` (source requirements for reference)

## Outputs

- Source code files implementing the PBIs
- Test files (unit tests for implemented code)
- `backlog.json` -> `items[].status: in_progress`
- `state.json` -> `phase: implementation`

## Preconditions

- `state.json` exists with `phase: design`
- `sprint.json` exists with developer assignments
- Design documents in `.design/specs/**/*.md` are populated (design phase is complete)
- `requirements.md` exists for reference
- `backlog.json` exists with PBIs assigned to the current Sprint

## Steps

1. Transition `state.json` to `phase: implementation`.
2. Each Developer reads the improvement log (if it exists from prior retrospectives) and applies any relevant improvements to their workflow and coding practices.
3. Developers implement their assigned PBIs following the design documents:
   - Read the assigned design document(s) thoroughly before coding.
   - Implement source code according to the design specifications.
   - Follow existing code conventions and patterns in the repository.
4. Write unit tests for all implemented code:
   - Tests must cover the acceptance criteria defined in the PBI.
   - Tests must be runnable and passing.
5. Ensure code passes the project's linter/formatter:
   - Run linting and formatting checks.
   - Fix any violations before marking implementation as complete.
6. Update `backlog.json` -> `items[].status` to `in_progress` for each PBI being implemented.
7. Report progress to Scrum Master: summarize what was implemented, test coverage, and any blockers encountered.

Reference: FR-017

## Exit Criteria

- All PBIs in the Sprint have `status: in_progress` in `backlog.json`
- Implementation is complete for all assigned PBIs (source code written per design documents)
- Unit tests are written for all implemented code
- All tests pass
- Code passes the project's linter/formatter checks
