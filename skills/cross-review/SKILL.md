---
name: cross-review
description: Cross-review process — Developers review each other's work
disable-model-invocation: false
---

## Inputs

- `state.json` → `phase: implementation | review`
- `backlog.json` → all PBIs in the current Sprint with `status: in_progress` and implementation complete
- `.scrum/requirements.md` and relevant design docs for each PBI

## Outputs

- `.scrum/reviews/<pbi-id>-review.md` (created per PBI)
- `backlog.json` → `items[].status: in_progress → review` (set at start of review)
- `backlog.json` → `items[].status: review → done` (set after passing review)
- `backlog.json` → `items[].review_doc_path` set to the review file path
- In single-PBI Sprint: `reviewer_id = "scrum-master"`, Scrum Master performs review
- `state.json` → `phase: review`
- `sprint.json` → `status: "cross_review"`

## Preconditions

- `state.json` exists with `phase: "implementation"` or `"review"`
- `backlog.json` exists and contains PBIs in the current Sprint with implementation complete
- `.scrum/requirements.md` exists and is readable
- Relevant design docs referenced by PBIs exist

## Steps

1. **Transition state**: Update `state.json` → `phase: "review"` (if not already set by the Scrum Master).
   Update `sprint.json` → `status: "cross_review"`.
2. **Mark PBIs as under review**: Update `backlog.json` → `items[].status`
   from `in_progress` to `review` for all PBIs in the current Sprint.
   Use this command for each PBI (replace `pbi-001` with the PBI ID):
   ```bash
   jq '(.items[] | select(.id == "pbi-001")).status = "review"' .scrum/backlog.json > .scrum/backlog.json.tmp && mv .scrum/backlog.json.tmp .scrum/backlog.json
   ```
   **You MUST run this command** — the TUI dashboard reads status from
   `backlog.json` and will not update without it.
3. **Read context**: For each PBI in the current Sprint, the assigned reviewer
   reads `requirements.md` and the relevant design documents referenced in
   the PBI's `design_doc_paths`.
4. **Examine implementation**: Reviewer examines the implementation against
   the design document and the PBI's acceptance criteria. Check for
   correctness, completeness, and adherence to requirements.
5. **Produce review document**: Reviewer creates
   `.scrum/reviews/<pbi-id>-review.md` with findings including: summary,
   items checked, issues found (if any), and pass/fail verdict.
6. **Single-PBI Sprint**: If the Sprint contains only one PBI, the Scrum
   Master performs the review instead of a peer Developer
   (`reviewer_id = "scrum-master"`).
7. **Handle issues**: If issues are found, attempt to fix them within the
   current Sprint. If the issue cannot be resolved within the Sprint, log
   it as a new PBI in `backlog.json` with `status: "draft"`.
8. **Update PBI status**: For PBIs that pass review, update
   `backlog.json` → `items[].status` from `review` to `done`.
   Use this command for each passing PBI (replace `pbi-001`):
   ```bash
   jq '(.items[] | select(.id == "pbi-001")).status = "done"' .scrum/backlog.json > .scrum/backlog.json.tmp && mv .scrum/backlog.json.tmp .scrum/backlog.json
   ```
9. **Set review path**: Set `items[].review_doc_path` in `backlog.json`
   to the path of the created review document.

Reference: FR-009

## Exit Criteria

- All PBIs in the current Sprint have been reviewed
- `.scrum/reviews/<pbi-id>-review.md` exists for each reviewed PBI
- All passing PBIs have `status: "done"` in `backlog.json`
- Each reviewed PBI has `review_doc_path` set in `backlog.json`
- Any unresolvable issues have been logged as new PBIs
- `state.json` → `phase: "review"`
