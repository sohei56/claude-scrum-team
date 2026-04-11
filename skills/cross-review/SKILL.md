---
name: cross-review
description: >
  Independent code review — Scrum Master spawns code-reviewer and
  security-reviewer sub-agents for unbiased, design-driven review.
disable-model-invocation: false
---

## Inputs

- `state.json` → `phase: implementation | review`
- `backlog.json` → all PBIs in the current Sprint with implementation complete
- `.scrum/requirements.md` and relevant design docs for each PBI
- `agents/code-reviewer.md` and `agents/security-reviewer.md` available

## Outputs

- `.scrum/reviews/<pbi-id>-review.md` (created per PBI)
- `backlog.json` → `items[].status: in_progress → review` (set at start)
- `backlog.json` → `items[].status: review → done` (set after PASS)
- `backlog.json` → `items[].review_doc_path` set to the review file path
- `state.json` → `phase: review`
- `sprint.json` → `status: "cross_review"`

## Preconditions

- `state.json` exists with `phase: "implementation"` or `"review"`
- `backlog.json` exists and contains PBIs with implementation complete
- `.scrum/requirements.md` exists and is readable
- Relevant design docs referenced by PBIs exist

## Steps

1. **Transition state**: Update `state.json` → `phase: "review"` (if not
   already set by the Scrum Master). Update `sprint.json` →
   `status: "cross_review"`.
2. **Mark PBIs as under review**: Update `backlog.json` → `items[].status`
   from `in_progress` to `review` for all PBIs in the current Sprint.
   Use this command for each PBI (replace `pbi-001` with the PBI ID):
   ```bash
   jq '(.items[] | select(.id == "pbi-001")).status = "review"' .scrum/backlog.json > .scrum/backlog.json.tmp && mv .scrum/backlog.json.tmp .scrum/backlog.json
   ```
   **You MUST run this command** — the TUI dashboard reads status from
   `backlog.json` and will not update without it.
3. **Collect review inputs**: For each PBI, gather:
   - Design document paths from PBI's `design_doc_paths`
   - Source code file paths (implementation files for this PBI)
   - Path to `.scrum/requirements.md`
4. **Spawn reviewers**: For each PBI, spawn two sub-agents in parallel
   via the Agent tool:
   - `code-reviewer` — pass design doc paths, source file paths,
     and requirements.md path. Do NOT pass PBI descriptions,
     developer communications, or `.scrum/` state files.
   - `security-reviewer` — pass source file paths and requirements.md
     path only.
5. **Collect results**: Read the review output from both sub-agents.
6. **Handle FAIL results**: If either reviewer returns FAIL:
   - Relay the specific findings to the Developer who implemented the PBI
   - Developer fixes the issues
   - Re-spawn the failing reviewer(s) for re-review
   - Repeat until both reviewers return PASS
7. **Write review document**: Combine both review outputs into
   `.scrum/reviews/<pbi-id>-review.md` with sections for code review
   and security review.
8. **Update PBI status**: For PBIs where both reviews PASS, update
   `backlog.json` → `items[].status` from `review` to `done`.
   Use this command for each passing PBI (replace `pbi-001`):
   ```bash
   jq '(.items[] | select(.id == "pbi-001")).status = "done"' .scrum/backlog.json > .scrum/backlog.json.tmp && mv .scrum/backlog.json.tmp .scrum/backlog.json
   ```
9. **Set review path**: Set `items[].review_doc_path` in `backlog.json`
   to the path of the created review document.

Reference: FR-009

## Exit Criteria

- All PBIs in the current Sprint have been reviewed by both
  code-reviewer and security-reviewer sub-agents
- `.scrum/reviews/<pbi-id>-review.md` exists for each reviewed PBI
- All passing PBIs have `status: "done"` in `backlog.json`
- Each reviewed PBI has `review_doc_path` set in `backlog.json`
- Any unresolvable issues have been logged as new PBIs
- `state.json` → `phase: "review"`
