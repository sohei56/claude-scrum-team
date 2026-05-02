---
name: implementation
description: Implementation phase — Developers implement PBIs per design documents
disable-model-invocation: false
---

## Inputs

- state.json → phase: design | implementation
- sprint.json (developer assignments)
- `docs/design/specs/**/*.md` (design docs + user-facing docs)
- requirements.md

## Outputs

- Source code + test files
- backlog.json → items[].status: in_progress
- state.json → phase: implementation

## Preconditions

- state.json phase: design or implementation
- sprint.json with developer assignments
- Design docs populated
- requirements.md, backlog.json exist

## Steps

1. state.json → phase: implementation (if not set by SM)
2. Read improvements.json→apply relevant improvements
3. Read design docs + user-facing docs→implementation must match (docs = secondary spec)
4. Implement PBIs: source code per design specs, follow existing code conventions
5. Write unit tests: cover all acceptance criteria, runnable + passing
6. Linter/formatter pass→fix violations
7. **Build verification (mandatory)**: Start app→confirm no errors→run full test suite→fix failures→stop app. Prevents build errors reaching Sprint Review
8. **Update design docs**: Implementation diverged from design→update docs + user-facing docs to match actual build. Reviewers use docs as source of truth→outdated docs cause false findings
9. Update backlog.json status:
   ```bash
   jq '(.items[] | select(.id == "pbi-001")).status = "in_progress"' .scrum/backlog.json > .scrum/backlog.json.tmp && mv .scrum/backlog.json.tmp .scrum/backlog.json
   ```
   **Must run** — TUI dashboard reads backlog.json
10. Report to SM: implementation summary, test coverage, build verification results, blockers

Ref: FR-017

## Exit Criteria

- All Sprint PBIs status: in_progress
- Implementation matches design docs
- App builds + starts successfully
- Unit tests written + all pass
- Linter/formatter pass
- Design docs + user-facing docs match implementation (no stale docs)
