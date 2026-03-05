---
name: implementation
description: Implementation phase — Developers implement PBIs per design documents
disable-model-invocation: false
---

## Inputs

- `state.json` -> `phase: design | implementation`
- `sprint.json` (current Sprint with developer assignments)
- `.design/specs/**/*.md` (populated design documents and user-facing docs)
- `requirements.md` (source requirements for reference)

## Outputs

- Source code files implementing the PBIs
- Test files (unit tests for implemented code)
- `backlog.json` -> `items[].status: in_progress`
- `state.json` -> `phase: implementation`

## Preconditions

- `state.json` exists with `phase: design` or `implementation`
- `sprint.json` exists with developer assignments
- Design documents in `.design/specs/**/*.md` are populated (design phase is
  complete), including user-facing documentation
- `requirements.md` exists for reference
- `backlog.json` exists with PBIs assigned to the current Sprint

## Steps

1. Transition `state.json` to `phase: implementation` (if not already set by the Scrum Master).
2. Each Developer reads the improvement log (if it exists from prior
   retrospectives) and applies any relevant improvements to their workflow
   and coding practices.
3. Each Developer reads the design documents AND user-facing documentation
   authored during the design phase. The implementation must match what was
   documented — the docs serve as a secondary specification.
4. Developers implement their assigned PBIs following the design documents:
   - Implement source code according to the design specifications.
   - Follow existing code conventions and patterns in the repository.
5. Write unit tests for all implemented code:
   - Tests must cover the acceptance criteria defined in the PBI.
   - Tests must be runnable and passing.
6. Ensure code passes the project's linter/formatter:
   - Run linting and formatting checks.
   - Fix any violations before marking implementation as complete.
7. Update `backlog.json` → `items[].status` to `in_progress` for each PBI
   being implemented. Use this command (replace `pbi-001` with your PBI ID):
   ```bash
   jq '(.items[] | select(.id == "pbi-001")).status = "in_progress"' .scrum/backlog.json > .scrum/backlog.json.tmp && mv .scrum/backlog.json.tmp .scrum/backlog.json
   ```
   **You MUST run this command** — the TUI dashboard reads status from
   `backlog.json` and will not update without it.
8. Report progress to Scrum Master: summarize what was implemented, test
   coverage, and any blockers encountered.

Reference: FR-017

## Exit Criteria

- All PBIs in the Sprint have `status: in_progress` in `backlog.json`
- Implementation is complete for all assigned PBIs (source code written per
  design documents)
- Implementation matches the user-facing documentation authored in design phase
- Unit tests are written for all implemented code
- All tests pass
- Code passes the project's linter/formatter checks
