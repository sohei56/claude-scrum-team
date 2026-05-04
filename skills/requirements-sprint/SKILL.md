---
name: requirements-sprint
description: >
  Requirements Sprint ceremony. Spawns a single Developer to elicit
  requirements from the user through natural language dialogue,
  producing a requirements document and initial Product Backlog.
disable-model-invocation: false
---

## Inputs

- `state.json` → `phase: "new"` or `"requirements_sprint"`

## Outputs

- `docs/requirements.md` — business, functional, non-functional requirements (committed to repo)
- `state.json` → new→requirements_sprint→backlog_created
- `backlog.json` — initial coarse-grained PBIs + `next_pbi_id`

## Preconditions

- state.json phase: "new" or "requirements_sprint"
- No existing requirements.md (new) or incomplete (resume)

## Steps

1. Update `state.json` → `phase: "requirements_sprint"`
2. Spawn 1 Developer for requirements interview
3. Developer engages user in natural language:
   - Business: problem, users, goals
   - Functional: features, key workflows
   - Non-functional: performance, security, scalability, platform constraints
   - Constraints: tech preferences, limitations
4. Unclear/incomplete→follow-up questions. Do not proceed until sufficiently clear
5. Produce `docs/requirements.md` with structured sections (create `docs/` dir if missing)
6. SM creates `backlog.json`: coarse PBIs (status: "draft"), set `next_pbi_id`, set `product_goal`
7. Present requirements summary + initial backlog→user confirmation
8. Update `state.json` → `phase: "backlog_created"`. Terminate Requirements Sprint Developer

Ref: FR-002

## Exit Criteria

- `requirements.md` exists (business + functional + non-functional covered)
- `backlog.json` exists (≥1 draft PBI)
- state.json phase: "backlog_created"
- User confirmed
