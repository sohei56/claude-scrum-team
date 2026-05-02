---
name: scaffold-design-spec
description: Create template stub files for newly enabled catalog entries, including user-facing documentation
disable-model-invocation: false
---

## Inputs

- `docs/design/catalog.md` (doc type reference)
- `docs/design/catalog-config.json` (enabled spec IDs)
- `sprint.json` → id
- `backlog.json` → PBI IDs for related_pbis

## Outputs

- `docs/design/specs/{category}/{id}-{slug}.md` stub files
- YAML frontmatter: catalog_id, created_sprint, last_updated_sprint, related_pbis, frozen: false, revision_history

## Preconditions

- state.json phase: "sprint_planning"
- catalog.md, catalog-config.json, sprint.json, backlog.json exist

## Steps

1. Read catalog-config.json→enabled IDs. Cross-reference catalog.md→get category/name/granularity
2. Each enabled entry without existing file:
   a. Create `docs/design/specs/{category}/{id}-{slug}.md` (auto-create dirs)
   b. YAML frontmatter: catalog_id, created_sprint, last_updated_sprint (same), related_pbis, frozen: false, revision_history (initial entry: sprint, author: "scrum-master", date, summary: "Initial stub created", pbis)
   c. Placeholder sections: Overview, Design Details, Constraints, References
   d. Category `docs/`→doc placeholders: Overview, Usage, API Reference, Examples
3. Skip existing stubs (idempotent)
4. Report: count created, new file paths

Ref: FR-004

## Exit Criteria

- Every enabled catalog entry has stub file
- All stubs: valid YAML frontmatter with all required fields
- docs/ category→doc-oriented placeholders
- No duplicate stubs
