# Design: Remove Spec-Kit and Migrate to Self-Managed Documentation

**Date**: 2026-03-16
**Issue**: [#6 — Concern: High maintenance cost of spec-kit generated documents](https://github.com/sohei56/claude-scrum-team/issues/6)

## Problem

Spec-kit generates a large volume of documentation artifacts during feature development. Maintaining them introduces significant overhead: staleness risk, cognitive load, sync burden, and storage bloat. The project needs to fully decouple from spec-kit and adopt a lightweight, self-managed documentation structure.

## Decision

Remove all spec-kit infrastructure and migrate valuable documentation content to a new `docs/` directory. Discard plan and task artifacts (ephemeral, implementation-phase-only value). Retain requirements, architecture decisions, data model, contracts, and quickstart guide.

## Approach: Simple Self-Managed

A flat `docs/` directory with no external tooling, governance frameworks, or catalog dependencies. Files are plain Markdown/JSON managed directly in git. The `.design/` directory (used by target projects) is unaffected.

Note: References to `.design/specs/` throughout the codebase are for target project design documents and are unrelated to the `specs/` directory being removed. No changes needed for these.

## New Structure

```
docs/
  requirements.md              # Project requirements (from specs/.../spec.md)
  architecture.md              # Architecture decisions (from specs/.../research.md)
  data-model.md                # Data model (from specs/.../data-model.md)
  contracts/
    agent-interfaces.md        # Agent interface contracts (from specs/.../contracts/)
    state-schemas.json         # State schemas (from specs/.../contracts/)
  quickstart.md                # End-user and contributor guide (from specs/.../quickstart.md)
```

## Deletions

| Target | Type | Reason |
|--------|------|--------|
| `.specify/` | Directory | Spec-kit infrastructure (templates, scripts, constitution) |
| `.claude/commands/speckit.*.md` | 9 files: `speckit.analyze.md`, `speckit.checklist.md`, `speckit.clarify.md`, `speckit.constitution.md`, `speckit.implement.md`, `speckit.plan.md`, `speckit.specify.md`, `speckit.tasks.md`, `speckit.taskstoissues.md` | Spec-kit commands |
| `specs/` | Directory | Content migrated to `docs/` |

## File Updates

| File | Change |
|------|--------|
| `hooks/phase-gate.sh` | Remove `.specify/*` and `specs/*` from exclusion patterns |
| `CLAUDE.md` | Update `specs/` references to `docs/` |
| `README.md` | Update repository structure diagram and `specs/` links to `docs/` |
| `CONTRIBUTING.md` | Update `specs/` references to `docs/` (directory tree and bullet points) |

## Migration Details

### requirements.md
- Source: `specs/001-ai-scrum-team/spec.md`
- Remove spec-kit metadata (Feature Branch, Status, Created, Input, `*(mandatory)*` annotations)
- Remove `Why this priority:` sections (priority is implicit from story ordering)
- Rename `Independent Test` to `Verification`
- Simplify Clarifications headers from `Session YYYY-MM-DD` to `YYYY-MM-DD`
- Retain: User Stories, Functional Requirements, Key Entities, Success Criteria, Edge Cases, Assumptions, Out of Scope, Clarifications

### architecture.md
- Source: `specs/001-ai-scrum-team/research.md`
- Remove `Branch: / Date: / Spec:` header
- Update internal links to `docs/` paths
- Add Overview section summarizing decision relationships
- Retain: All R1-R9 decision records with Decision/Rationale/Alternatives/Key Technical Details structure

### data-model.md
- Source: `specs/001-ai-scrum-team/data-model.md`
- Remove `Branch: / Date: / Source:` header
- Content otherwise unchanged

### contracts/agent-interfaces.md
- Source: `specs/001-ai-scrum-team/contracts/agent-interfaces.md`
- Remove `Branch: / Date:` header
- Content otherwise unchanged

### contracts/state-schemas.json
- Source: `specs/001-ai-scrum-team/contracts/state-schemas.json`
- No changes (JSON, no spec-kit metadata)

### quickstart.md
- Source: `specs/001-ai-scrum-team/quickstart.md`
- Remove `Branch: / Date:` header
- Remove `.specify/` reference from repository layout
- Update `specs/` references to `docs/`

### Discarded Files (not migrated)
- `specs/001-ai-scrum-team/plan.md` — Implementation plan; ephemeral, served only during initial development
- `specs/001-ai-scrum-team/tasks.md` — Task list; ephemeral, implementation-phase-only value
- `specs/001-ai-scrum-team/checklists/requirements.md` — Spec-kit requirements quality checklist; not needed for ongoing development

## Post-Implementation Verification

Confirm no remaining references to `.specify/`, `speckit`, or `specs/001-` exist in tracked files (excluding `docs/superpowers/` design history):
```bash
git grep -l '\.specify\|speckit\|specs/001-' -- ':!docs/superpowers/'
```
