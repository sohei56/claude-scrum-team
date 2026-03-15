# Spec-Kit Removal Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove all spec-kit infrastructure and migrate documentation to self-managed `docs/` directory.

**Architecture:** Delete `.specify/`, `.claude/commands/speckit.*.md`, and `specs/`. Migrate valuable content from `specs/001-ai-scrum-team/` to `docs/`. Update all references in hooks, CLAUDE.md, README.md, and CONTRIBUTING.md.

**Tech Stack:** Bash, Markdown, JSON

**Spec:** `docs/superpowers/specs/2026-03-16-speckit-removal-design.md`

---

## Chunk 1: Migrate Documentation

### Task 1: Create `docs/requirements.md`

**Files:**
- Create: `docs/requirements.md`
- Reference: `specs/001-ai-scrum-team/spec.md`

- [ ] **Step 1: Create requirements.md from spec.md**

Migrate content from `specs/001-ai-scrum-team/spec.md` with the following transformations:
- Remove spec-kit header metadata: `Feature Branch`, `Created`, `Status`, `Input`
- Remove `*(mandatory)*` annotations from section headings
- Remove `Why this priority:` paragraphs from each User Story
- Rename `Independent Test:` to `Verification:` in each User Story
- Simplify Clarifications headers: `### Session YYYY-MM-DD` → `### YYYY-MM-DD`
- Restructure into: Overview, User Stories, Functional Requirements, Key Entities, Success Criteria, Edge Cases, Assumptions, Out of Scope, Clarifications

- [ ] **Step 2: Verify requirements.md**

Confirm all FR-001 through FR-022 are present, all SC-001 through SC-009 are present, all 5 User Stories are present, and all Edge Cases are preserved.

- [ ] **Step 3: Commit**

```bash
git add docs/requirements.md
git commit -m "docs: create requirements.md from spec.md"
```

---

### Task 2: Create `docs/architecture.md`

**Files:**
- Create: `docs/architecture.md`
- Reference: `specs/001-ai-scrum-team/research.md`

- [ ] **Step 1: Create architecture.md from research.md**

Migrate content from `specs/001-ai-scrum-team/research.md` with the following transformations:
- Remove header: `**Branch**: ... | **Date**: ... | **Spec**: [spec.md](spec.md)`
- Add `## Overview` section before the decisions, summarizing the 9 decisions and their relationships
- Update internal links: `[spec.md](spec.md)` → `[requirements.md](requirements.md)`, `[data-model.md](data-model.md)` → `[data-model.md](data-model.md)` (same name, now relative within `docs/`), `agent-interfaces.md` → `contracts/agent-interfaces.md`
- Retain all R1-R9 decision records with their Decision/Rationale/Alternatives Considered/Key Technical Details structure unchanged

- [ ] **Step 2: Verify architecture.md**

Confirm all 9 decisions (R1-R9) are present with their full content.

- [ ] **Step 3: Commit**

```bash
git add docs/architecture.md
git commit -m "docs: create architecture.md from research.md"
```

---

### Task 3: Create `docs/data-model.md`

**Files:**
- Create: `docs/data-model.md`
- Reference: `specs/001-ai-scrum-team/data-model.md`

- [ ] **Step 1: Create data-model.md**

Migrate content from `specs/001-ai-scrum-team/data-model.md` with the following transformations:
- Remove header: `**Branch**: ... | **Date**: ...`
- Remove `**Source**: [spec.md](spec.md) Key Entities + [research.md](research.md) R2, R4, R8`
- Content otherwise unchanged (all entities, state transitions, validation rules, file relationships)

- [ ] **Step 2: Commit**

```bash
git add docs/data-model.md
git commit -m "docs: create data-model.md from specs"
```

---

### Task 4: Create `docs/contracts/`

**Files:**
- Create: `docs/contracts/agent-interfaces.md`
- Create: `docs/contracts/state-schemas.json`
- Reference: `specs/001-ai-scrum-team/contracts/agent-interfaces.md`
- Reference: `specs/001-ai-scrum-team/contracts/state-schemas.json`

- [ ] **Step 1: Create docs/contracts/agent-interfaces.md**

Migrate from `specs/001-ai-scrum-team/contracts/agent-interfaces.md`:
- Remove header: `**Branch**: ... | **Date**: ...`
- Content otherwise unchanged

- [ ] **Step 2: Copy docs/contracts/state-schemas.json**

Copy `specs/001-ai-scrum-team/contracts/state-schemas.json` as-is (no changes needed).

- [ ] **Step 3: Commit**

```bash
git add docs/contracts/
git commit -m "docs: create contracts from specs"
```

---

### Task 5: Create `docs/quickstart.md`

**Files:**
- Create: `docs/quickstart.md`
- Reference: `specs/001-ai-scrum-team/quickstart.md`

- [ ] **Step 1: Create quickstart.md**

Migrate from `specs/001-ai-scrum-team/quickstart.md`:
- Remove header: `**Branch**: ... | **Date**: ...`
- In Repository Layout section: remove `├── specs/  # Feature specifications` and `└── .specify/  # Speckit tooling` lines, add `├── docs/  # Project documentation (requirements, architecture, data model, contracts, quickstart)`
- In Development Workflow section: update `specs/001-ai-scrum-team/spec.md` → `docs/requirements.md`, `specs/001-ai-scrum-team/data-model.md` → `docs/data-model.md`, `specs/001-ai-scrum-team/contracts/` → `docs/contracts/`

- [ ] **Step 2: Commit**

```bash
git add docs/quickstart.md
git commit -m "docs: create quickstart.md from specs"
```

---

## Chunk 2: Delete Spec-Kit Infrastructure

### Task 6: Delete `.specify/` directory

**Files:**
- Delete: `.specify/` (entire directory)

- [ ] **Step 1: Delete .specify/**

```bash
git rm -r .specify/
```

- [ ] **Step 2: Commit**

```bash
git commit -m "chore: remove spec-kit .specify/ infrastructure"
```

---

### Task 7: Delete `.claude/commands/speckit.*.md`

**Files:**
- Delete: `.claude/commands/speckit.analyze.md`
- Delete: `.claude/commands/speckit.checklist.md`
- Delete: `.claude/commands/speckit.clarify.md`
- Delete: `.claude/commands/speckit.constitution.md`
- Delete: `.claude/commands/speckit.implement.md`
- Delete: `.claude/commands/speckit.plan.md`
- Delete: `.claude/commands/speckit.specify.md`
- Delete: `.claude/commands/speckit.tasks.md`
- Delete: `.claude/commands/speckit.taskstoissues.md`

- [ ] **Step 1: Delete speckit commands**

```bash
git rm .claude/commands/speckit.*.md
```

- [ ] **Step 2: Commit**

```bash
git commit -m "chore: remove spec-kit Claude Code commands"
```

---

### Task 8: Delete `specs/` directory

**Files:**
- Delete: `specs/` (entire directory)

- [ ] **Step 1: Delete specs/**

```bash
git rm -r specs/
```

- [ ] **Step 2: Commit**

```bash
git commit -m "chore: remove specs/ directory (content migrated to docs/)"
```

---

## Chunk 3: Update References

### Task 9: Update `hooks/phase-gate.sh`

**Files:**
- Modify: `hooks/phase-gate.sh:41-47`

- [ ] **Step 1: Update is_source_file exclusion patterns**

Line 41 comment — remove `specs/` from the list:
```
# Source files live outside .scrum/, .design/, docs/, agents/, skills/,
# hooks/, scripts/, dashboard/, tests/, and common dot-directories.
```

Line 46 — replace `specs/*` with `docs/*` and remove `.specify/*`:
```bash
    .scrum/*|.design/*|docs/*|agents/*|skills/*|hooks/*|scripts/*|dashboard/*|tests/*) return 1 ;;
    .git/*|.claude/*|.github/*) return 1 ;;
```

- [ ] **Step 2: Run shellcheck**

```bash
shellcheck hooks/phase-gate.sh
```
Expected: no errors

- [ ] **Step 3: Run hook tests**

```bash
bats tests/unit/hooks.bats
```
Expected: all tests pass

- [ ] **Step 4: Commit**

```bash
git add hooks/phase-gate.sh
git commit -m "refactor: update phase-gate.sh exclusion patterns for docs/ migration"
```

---

### Task 10: Update `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md:39`

- [ ] **Step 1: Update project structure**

Replace line 39:
```
specs/                   # Feature specifications and data model
```
with:
```
docs/                    # Project documentation (requirements, architecture, data model, contracts)
```

- [ ] **Step 2: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update CLAUDE.md project structure for docs/ migration"
```

---

### Task 11: Update `README.md`

**Files:**
- Modify: `README.md:135`

- [ ] **Step 1: Update quickstart link**

Replace line 135:
```markdown
For detailed setup instructions, see [quickstart.md](specs/001-ai-scrum-team/quickstart.md).
```
with:
```markdown
For detailed setup instructions, see [quickstart.md](docs/quickstart.md).
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: update README.md quickstart link to docs/"
```

---

### Task 12: Update `CONTRIBUTING.md`

**Files:**
- Modify: `CONTRIBUTING.md:98,107`

- [ ] **Step 1: Update project structure**

Replace line 98:
```
specs/                   # Feature specifications
```
with:
```
docs/                    # Project documentation
```

- [ ] **Step 2: Update Key Files section**

Replace line 107:
```markdown
- `specs/001-ai-scrum-team/` — Feature specification and design docs
```
with:
```markdown
- `docs/` — Project documentation (requirements, architecture, data model, contracts, quickstart)
```

- [ ] **Step 3: Commit**

```bash
git add CONTRIBUTING.md
git commit -m "docs: update CONTRIBUTING.md references from specs/ to docs/"
```

---

## Chunk 4: Verification

### Task 13: Post-implementation verification

- [ ] **Step 1: Run verification grep**

```bash
git grep -l '\.specify\|speckit\|specs/001-' -- ':!docs/superpowers/'
```
Expected: no output (no remaining references)

- [ ] **Step 2: Run all tests**

```bash
bats tests/unit/ tests/lint/
```
Expected: all tests pass

- [ ] **Step 3: Run shellcheck on all hooks**

```bash
shellcheck hooks/*.sh hooks/lib/*.sh
```
Expected: no errors

- [ ] **Step 4: Verify docs/ structure is complete**

```bash
ls -la docs/requirements.md docs/architecture.md docs/data-model.md docs/contracts/agent-interfaces.md docs/contracts/state-schemas.json docs/quickstart.md
```
Expected: all 6 files exist
