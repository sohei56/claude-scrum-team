---
name: backlog-refinement
description: Refine coarse-grained PBIs into implementation-ready items
disable-model-invocation: false
---

## Inputs

- `backlog.json` → items with status: draft
- `requirements.md`
- Count of existing refined PBIs (WIP check)

## Outputs

- `backlog.json` → items[].status: refined, acceptance_criteria (non-empty), ux_change, design_doc_paths

## Preconditions

- state.json phase: "backlog_created" or "retrospective"
- backlog.json has ≥1 draft PBI
- Refined PBI count < WIP cap 12

## Steps

1. Read backlog.json
2. Count refined PBIs. If ≥12→skip (WIP cap reached)
3. Each draft PBI (up to WIP cap 12 total refined):
   a. Break into implementation-ready items (per function/screen/API/component)
   b. Fill acceptance_criteria: concrete, testable
   c. Set ux_change (user-facing changes)
   d. Set design_doc_paths (docs needing creation/update)
4. Set status→"refined"
5. Write backlog.json
6. Report: count refined, total refined WIP

Ref: FR-003

## Exit Criteria

- All selected PBIs status: refined
- Every refined PBI: non-empty acceptance_criteria, ux_change set, design_doc_paths set
- Total refined PBIs within 6-12 range
