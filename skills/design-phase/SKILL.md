---
name: design-phase
description: Design phase orchestration — Developers populate design document stubs
disable-model-invocation: true
---

## Inputs

- `state.json` -> `phase: sprint_planning`
- `sprint.json` -> `developers[]` (developer assignments)
- `.design/catalog.md` (catalog of design topics)
- Existing `.design/specs/**/*.md` stubs (created by scaffold-design-spec skill)

## Outputs

- Populated design documents with detailed design content replacing placeholder sections
- `revision_history` entries in each document including `pbis` field
- `backlog.json` -> `items[].design_doc_paths` updated with paths to design documents
- `state.json` -> `phase: design`

## Preconditions

- `state.json` exists with `phase: sprint_planning`
- `sprint.json` exists with developer assignments
- `.design/specs/**/*.md` stub files exist (created by scaffold-design-spec)
- `backlog.json` exists with PBIs assigned to the current Sprint

## Steps

1. Transition `state.json` to `phase: design`.
2. Each Developer MUST read ALL existing design documents from previous Sprints before writing their own. This ensures consistency across the system's design and prevents contradictions or duplicated patterns.
3. Developers populate their assigned design document stubs with detailed design content:
   - Replace placeholder sections (Overview, Design Details, Constraints, References) with substantive content.
   - Design must align with `requirements.md` and existing designs.
4. Each document receives a `revision_history` entry with:
   - `sprint`: current Sprint ID
   - `author`: developer ID who wrote the content
   - `date`: today's date
   - `summary`: description of design decisions made
   - `pbis`: array of PBI IDs addressed by this design
5. Update `backlog.json` -> `items[].design_doc_paths` with the file paths of the design documents each PBI relates to.
6. Verify all assigned design stubs have been populated with substantive content before considering the phase complete.

Reference: FR-004

## Exit Criteria

- All design stubs assigned to this Sprint are populated with substantive content (no remaining placeholder text)
- Every populated design document has a `revision_history` entry for the current Sprint with `author`, `date`, `summary`, and `pbis` fields
- `backlog.json` -> `items[].design_doc_paths` is set for every PBI in the Sprint
- `state.json` phase is `design`
