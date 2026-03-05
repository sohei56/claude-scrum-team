---
name: scaffold-design-spec
description: Create template stub files for newly enabled catalog entries, including user-facing documentation
disable-model-invocation: false
---

## Inputs

- `.design/catalog.md` (reference list of all design document types)
- `.design/catalog-config.json` (list of enabled spec IDs)
- `sprint.json` -> `id` (current Sprint ID)
- `backlog.json` -> PBI IDs for `related_pbis` linkage

## Outputs

- `.design/specs/{category}/{id}-{slug}.md` stub files for each newly enabled catalog entry
- Each stub contains YAML frontmatter with:
  - `catalog_id`
  - `created_sprint` (from `sprint.json`)
  - `last_updated_sprint` (same as `created_sprint` initially)
  - `related_pbis` (from `backlog.json`)
  - `frozen: false`
  - `revision_history` with an initial entry (sprint, author, date, summary: "Initial stub created", pbis)
- Placeholder sections in the body
- Documentation stubs (category `docs/`) use documentation-oriented placeholder
  sections: Overview, Usage, API Reference, Examples

## Preconditions

- `state.json` exists with `phase: "sprint_planning"`
- `.design/catalog.md` exists (reference document type list)
- `.design/catalog-config.json` exists with at least one ID in the `enabled` array
- `sprint.json` exists with a valid `id`
- `backlog.json` exists with PBIs that can be linked as `related_pbis`

## Steps

1. Read `.design/catalog-config.json` to get the list of enabled spec IDs. Cross-reference with `.design/catalog.md` to get the category, name, and granularity for each enabled ID.
2. For each enabled entry that does not already have a corresponding file at `.design/specs/{category}/{id}-{slug}.md`:
   a. Create the stub file at the target path, creating directories as needed.
   b. Populate YAML frontmatter:
      - `catalog_id`: the entry's ID from the catalog
      - `created_sprint`: Sprint ID from `sprint.json`
      - `last_updated_sprint`: same as `created_sprint`
      - `related_pbis`: array of relevant PBI IDs from `backlog.json`
      - `frozen: false`
      - `revision_history`: array with one entry containing `sprint`, `author: "scrum-master"`, `date` (today), `summary: "Initial stub created"`, and `pbis` (array of related PBI IDs from the catalog entry's `related_pbis`)
   c. Add placeholder sections in the document body:
      - `## Overview`
      - `## Design Details`
      - `## Constraints`
      - `## References`
   d. For entries with category `docs/`, use documentation-oriented
      placeholder sections instead:
      - `## Overview`
      - `## Usage`
      - `## API Reference`
      - `## Examples`
3. Skip any enabled entries that already have an existing stub file (idempotent behavior).
4. Report summary: number of stubs created, paths of new files.

Reference: FR-004

## Exit Criteria

- Every enabled catalog entry has a corresponding stub file at `.design/specs/{category}/{id}-{slug}.md`
- Each stub file has valid YAML frontmatter with all required fields (`catalog_id`, `created_sprint`, `last_updated_sprint`, `related_pbis`, `frozen`, `revision_history`)
- Each stub file contains placeholder sections: Overview, Design Details, Constraints, References
- No duplicate stubs are created for entries that already have files
- Documentation stubs (category `docs/`) have documentation-oriented
  placeholder sections (Overview, Usage, API Reference, Examples)
