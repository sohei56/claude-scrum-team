---
name: requirements-sprint
description: >
  Requirements Sprint ceremony. Spawns a single Developer to elicit
  requirements from the user through natural language dialogue,
  producing a requirements document and initial Product Backlog.
disable-model-invocation: false
---

## Inputs

- `state.json` → `phase: "new"` (first run) or resuming from `requirements_sprint`

## Outputs

- `.scrum/requirements.md` — requirements document covering business,
  functional, and non-functional requirements
- `state.json` → `phase` transitions: `new` → `requirements_sprint` →
  `backlog_created`
- `backlog.json` — initial Product Backlog with coarse-grained PBIs
  and `next_pbi_id` set

## Preconditions

- `.scrum/state.json` exists with `phase: "new"` or `phase: "requirements_sprint"`
- No existing `requirements.md` (new project) or incomplete requirements
  (resume)

## Steps

1. **Initialize**: Update `state.json` → `phase: "requirements_sprint"`.
2. **Spawn Developer**: Create a single Developer teammate to conduct the
   requirements interview.
3. **Requirements Elicitation**: The Developer engages the user in natural
   language dialogue covering:
   - **Business requirements**: What problem does this product solve? Who
     are the users? What are the business goals?
   - **Functional requirements**: What must the product do? What are the
     key features and user workflows?
   - **Non-functional requirements**: Performance, security, scalability,
     accessibility, platform constraints?
   - **Constraints and assumptions**: What technologies are preferred?
     What limitations exist?
4. **Follow-up**: For unclear or incomplete answers, the Developer asks
   targeted follow-up questions. Do not proceed until requirements are
   sufficiently clear.
5. **Document**: The Developer produces `.scrum/requirements.md` with
   structured sections for all requirement categories.
6. **Create Initial Backlog**: The Scrum Master creates `.scrum/backlog.json`
   with coarse-grained PBIs derived from the requirements:
   - Each PBI has `status: "draft"`, a descriptive title, and brief
     description
   - PBIs are high-level groupings (e.g., "User Management", "Payment
     Processing", "CI/CD Setup")
   - Set `next_pbi_id` to the next available integer
   - Set `product_goal` from the user's stated business goal
7. **Present**: Show the user a summary of gathered requirements and the
   initial Product Backlog for confirmation.
8. **Finalize**: Update `state.json` → `phase: "backlog_created"`.
   Terminate the Requirements Sprint Developer.

Reference: FR-002

## Exit Criteria

- `.scrum/requirements.md` exists and covers business, functional, and
  non-functional requirements
- `.scrum/backlog.json` exists with at least one PBI in `status: "draft"`
- `state.json` → `phase: "backlog_created"`
- User has confirmed the requirements and initial backlog

## Variables

- `$PRODUCT_GOAL` — The user's stated desired future state of the product
- `$PBI_COUNT` — Number of initial coarse-grained PBIs created
