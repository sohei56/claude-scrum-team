---
name: cross-review
description: Cross-review process — Developers review each other's work
disable-model-invocation: true
---

## Inputs

- `state.json` → `phase: implementation`
- `backlog.json` → all PBIs in the current Sprint with `status: in_progress` and implementation complete
- `.scrum/requirements.md` and relevant design docs for each PBI

## Outputs

- `.scrum/reviews/<pbi-id>-review.md` (created per PBI)
- `backlog.json` → `items[].status: review → done`
- `backlog.json` → `items[].review_doc_path` set to the review file path
- In single-PBI Sprint: `reviewer_id = "scrum-master"`, Scrum Master performs review
- `state.json` → `phase: review`

## Preconditions

- `state.json` exists with `phase: "implementation"`
- `backlog.json` exists and contains PBIs in the current Sprint with implementation complete
- `.scrum/requirements.md` exists and is readable
- Relevant design docs referenced by PBIs exist

## Steps

1. **Transition state**: Update `state.json` → `phase: "review"`.
2. **Read context**: For each PBI in the current Sprint, the assigned reviewer
   reads `requirements.md` and the relevant design documents referenced in
   the PBI's `design_doc_paths`.
3. **Examine implementation**: Reviewer examines the implementation against
   the design document and the PBI's acceptance criteria. Check for
   correctness, completeness, and adherence to requirements.
4. **Produce review document**: Reviewer creates
   `.scrum/reviews/<pbi-id>-review.md` with findings including: summary,
   items checked, issues found (if any), and pass/fail verdict.
5. **Single-PBI Sprint**: If the Sprint contains only one PBI, the Scrum
   Master performs the review instead of a peer Developer
   (`reviewer_id = "scrum-master"`).
6. **Handle issues**: If issues are found, attempt to fix them within the
   current Sprint. If the issue cannot be resolved within the Sprint, log
   it as a new PBI in `backlog.json` with `status: "draft"`.
7. **Update PBI status**: For PBIs that pass review, update
   `backlog.json` → `items[].status` from `review` to `done`.
8. **Set review path**: Set `items[].review_doc_path` in `backlog.json`
   to the path of the created review document.

Reference: FR-009

## Exit Criteria

- All PBIs in the current Sprint have been reviewed
- `.scrum/reviews/<pbi-id>-review.md` exists for each reviewed PBI
- All passing PBIs have `status: "done"` in `backlog.json`
- Each reviewed PBI has `review_doc_path` set in `backlog.json`
- Any unresolvable issues have been logged as new PBIs
- `state.json` → `phase: "review"`
