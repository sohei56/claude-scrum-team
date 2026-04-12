---
name: design
description: Design phase — Developers author design documents and user-facing documentation
disable-model-invocation: false
---

## Inputs

- state.json → phase: sprint_planning | design
- sprint.json → developer assignments
- `.design/specs/**/*.md` stubs (from scaffold-design-spec)
- `.design/catalog.md` (read-only), catalog-config.json
- requirements.md

## Outputs

- Populated design docs (architecture, internals)
- User-facing docs (README specs, API ref, usage guides) at `.design/specs/docs/*.md`
- revision_history entries with pbis field
- backlog.json → items[].design_doc_paths updated
- state.json → phase: design

## Preconditions

- state.json phase: sprint_planning or design
- sprint.json with developer assignments
- Stub files exist
- backlog.json, requirements.md exist

## Steps

1. state.json → phase: design (if not set by SM)
2. **Read ALL existing design docs + user-facing docs first** (consistency, prevent contradictions)
3. Populate assigned stubs:
   - **Design docs**: Replace placeholders with technical content. Align with requirements.md + existing designs
   - **User-facing docs** (docs/*.md): For PBIs changing public interfaces/user-visible behavior→write README, API ref, usage guides, examples
4. Unclear requirements→raise to SM→SM consults PO. Do NOT guess (wait for answer)
5. Add revision_history entry: sprint, author, date, summary, pbis
6. Update backlog.json → items[].design_doc_paths
7. Verify all assigned stubs + user-facing docs have substantive content. Only for entries enabled in catalog-config.json

Ref: FR-004

## Exit Criteria

- All Sprint-assigned stubs populated (no placeholder text remaining)
- User-facing docs authored for PBIs changing public interfaces
- All docs have revision_history (author, date, summary, pbis)
- backlog.json design_doc_paths set for every Sprint PBI
- state.json phase: design
