---
name: design
description: Design phase — Developers author design documents and user-facing documentation
disable-model-invocation: false
---

## Inputs

- `state.json` -> `phase: sprint_planning | design`
- `sprint.json` -> `developers[]` (developer assignments)
- `.design/catalog.md` (reference list of design document types — read-only)
- `.design/catalog-config.json` (list of enabled spec IDs)
- Existing `.design/specs/**/*.md` stubs (created by scaffold-design-spec skill)
- `requirements.md` (source requirements for reference)

## Outputs

- Populated design documents (architecture, internals) with detailed content
- Populated user-facing documentation (README feature specs, API reference,
  usage guides) as `.design/specs/docs/*.md` entries
- `revision_history` entries in each document including `pbis` field
- `backlog.json` -> `items[].design_doc_paths` updated with paths to all
  design and documentation files
- `state.json` -> `phase: design`

## Preconditions

- `state.json` exists with `phase: sprint_planning` or `design`
- `sprint.json` exists with developer assignments
- `.design/specs/**/*.md` stub files exist (created by scaffold-design-spec)
- `backlog.json` exists with PBIs assigned to the current Sprint
- `requirements.md` exists for reference

## Steps

1. Transition `state.json` to `phase: design` (if not already set by the Scrum Master).
2. Each Developer MUST read ALL existing design documents and user-facing
   documentation from previous Sprints before writing their own. This ensures
   consistency across the system's design and prevents contradictions or
   duplicated patterns.
3. Developers populate their assigned stubs with detailed content — both
   architecture/design specs AND user-facing documentation:
   - **Design documents**: Replace placeholder sections (Overview, Design
     Details, Constraints, References) with substantive technical content.
     Design must align with `requirements.md` and existing designs.
   - **User-facing documentation** (`.design/specs/docs/*.md`): Author
     README feature descriptions, API reference, usage guides, CLI
     documentation, and configuration reference for all PBIs that introduce
     or change public interfaces or user-visible behavior. Write from the
     user's perspective — explain what the feature does, how to use it,
     parameters, return values, and include examples.
4. If any requirements or design decisions are unclear during authoring, the
   Developer MUST raise the question to the Scrum Master, who will consult
   the Product Owner (user) for clarification. Do NOT guess or make
   assumptions on ambiguous points — wait for the PO's answer before
   proceeding with that section.
5. Each document receives a `revision_history` entry with:
   - `sprint`: current Sprint ID
   - `author`: developer ID who wrote the content
   - `date`: today's date
   - `summary`: description of design decisions or documentation authored
   - `pbis`: array of PBI IDs addressed by this document
6. Update `backlog.json` -> `items[].design_doc_paths` with the file paths
   of all design and documentation files each PBI relates to.
7. Verify all assigned design stubs and user-facing documentation files have
   been populated with substantive content before considering the phase
   complete. Every documentation file must correspond to an enabled entry
   in `.design/catalog-config.json` — do not create documentation for spec IDs
  not listed in the enabled array.

Reference: FR-004

## Exit Criteria

- All design stubs assigned to this Sprint are populated with substantive
  content (no remaining placeholder text)
- User-facing documentation is authored for all PBIs that introduce or change
  public interfaces or user-visible behavior
- Every populated document has a `revision_history` entry for the current
  Sprint with `author`, `date`, `summary`, and `pbis` fields
- `backlog.json` -> `items[].design_doc_paths` is set for every PBI in the
  Sprint (includes both design and documentation paths)
- `state.json` phase is `design`
