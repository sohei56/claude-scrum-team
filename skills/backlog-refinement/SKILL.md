---
name: backlog-refinement
description: Refine coarse-grained PBIs into implementation-ready items
disable-model-invocation: false
---

## Inputs

- `backlog.json` -> `items[]` with `status: draft`
- `requirements.md` (source requirements for context)
- Count of existing PBIs with `status: refined` (WIP check)

## Outputs

- `backlog.json` -> `items[].status: refined`
- `backlog.json` -> `items[].acceptance_criteria` (non-empty array)
- `backlog.json` -> `items[].ux_change` populated
- `backlog.json` -> `items[].design_doc_paths` populated
- Refined WIP capped at 6-12 (1-2 Sprints of capacity)

## Preconditions

- `state.json` exists with `phase: "backlog_created"` or `"retrospective"`
- `backlog.json` exists and contains at least one item with `status: draft`
- `requirements.md` exists and is readable
- Current count of `refined` PBIs is below the WIP cap (12)

## Steps

1. Read `backlog.json` and load all items.
2. Count existing PBIs with `status: refined`. If refined PBIs >= 12, skip refinement entirely and exit early with a message indicating the WIP cap has been reached.
3. For each PBI with `status: draft` (up to the WIP cap of 12 total refined):
   a. Break the PBI into implementation-ready items (one per function/screen/API endpoint/component).
   b. Fill `acceptance_criteria` with concrete, testable criteria.
   c. Determine `ux_change` (boolean or description of user-facing changes).
   d. Identify `design_doc_paths` (paths to relevant design documents that will need to be created or updated).
4. Set each refined PBI's `status` to `refined`.
5. Write updated items back to `backlog.json`.
6. Report summary: number of PBIs refined, total refined WIP count.

Reference: FR-003

## Exit Criteria

- All selected PBIs have `status: refined`
- Every refined PBI has a non-empty `acceptance_criteria` array
- Every refined PBI has `ux_change` populated
- Every refined PBI has `design_doc_paths` populated
- Total count of `refined` PBIs is within the 6-12 WIP range
