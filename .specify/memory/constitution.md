<!--
Sync Impact Report
===================
Version change: 1.0.0 → 2.0.0
Removed principles:
  - VI. Claude Code Plugin Distribution (moved to spec.md — product requirement)
  - VII. User as Product Owner (moved to spec.md — product requirement)
Modified principles: (none — I through V unchanged)
Added sections: (none)
Removed sections: (none)
Templates checked:
  - .specify/templates/plan-template.md        ✅ compatible (no references to removed principles)
  - .specify/templates/spec-template.md         ✅ compatible (will receive removed principles as requirements)
  - .specify/templates/tasks-template.md        ✅ compatible (no references to removed principles)
  - .specify/templates/commands/               ✅ N/A (directory does not exist)
  - README.md                                   ✅ no constitution references to update
Follow-up TODOs: none
Rationale: Principles VI and VII are product requirements, not governance
  principles. They belong in spec.md, not constitution.md. Removing
  principles is a backward-incompatible change → MAJOR bump.
-->

# Claude Scrum Team Constitution

## Core Principles

### I. English Language (NON-NEGOTIABLE)

All files, documentation, code comments, commit messages, and
project artifacts MUST be written in English. No exceptions.

### II. Specification Compliance

All code MUST follow the approved specification. Implementation
that deviates from `spec.md` without an explicit amendment is a
blocker and MUST NOT be merged.

### III. SOLID Principles

Apply SOLID principles (Single Responsibility, Open/Closed,
Liskov Substitution, Interface Segregation, Dependency Inversion)
unless they conflict with higher-priority principles (I or II).
When a conflict arises, document the rationale in the plan.

### IV. Task-Based Commit Strategy (NON-NEGOTIABLE)

- One commit per completed task. No multi-task commits.
- Each commit message MUST use the project commit message template.
- Incomplete tasks MUST NOT be committed.

### V. Spec/Plan Separation

- `spec.md` MUST contain only **What** (requirements, user stories,
  acceptance criteria) and **Why** (rationale, business value).
- All technical details (architecture, data models, implementation
  approach) MUST go in `plan.md`.
- Any document violating this separation is a blocker and MUST be
  corrected before implementation proceeds.

## Governance

This constitution takes precedence over all other practices,
templates, and workflow documents. In case of conflict, the
constitution wins.

**Amendment procedure**:

1. Any amendment MUST include a documented rationale explaining
   why the change is necessary.
2. A migration plan MUST accompany the amendment, describing how
   existing artifacts and workflows adapt to the change.
3. Version increments follow semantic versioning:
   - **MAJOR**: Principle removal or backward-incompatible redefinition.
   - **MINOR**: New principle added or existing principle materially expanded.
   - **PATCH**: Clarifications, wording fixes, non-semantic refinements.

**Compliance review**: All pull requests and code reviews MUST
verify adherence to these principles. Constitutional violations
MUST be documented in the Complexity Tracking table (see
`plan-template.md`) with justification for why the violation is
needed and why simpler alternatives were rejected.

**Version**: 2.0.0 | **Ratified**: 2026-02-21 | **Last Amended**: 2026-02-21
