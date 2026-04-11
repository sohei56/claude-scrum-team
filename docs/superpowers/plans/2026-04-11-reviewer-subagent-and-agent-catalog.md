# Reviewer Sub-Agent and Internal Agent Catalog — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace cross-review with independent reviewer sub-agents, introduce 4 project-managed sub-agents, and remove external catalog dependencies.

**Architecture:** Create 4 new agent definition files (code-reviewer, security-reviewer, tdd-guide, build-error-resolver), update cross-review skill to use Scrum Master-driven sub-agent review, simplify install-subagents skill, remove awesome-claude-code-subagents clone from setup.

**Tech Stack:** Markdown with YAML frontmatter, Bash 3.2+, bats-core tests

---

### Task 1: Create `agents/code-reviewer.md`

**Files:**
- Create: `agents/code-reviewer.md`
- Modify: `tests/lint/agent-frontmatter.bats`

- [ ] **Step 1: Write failing tests**

Add to `tests/lint/agent-frontmatter.bats` after the developer.md section:

```bash
# ---------------------------------------------------------------------------
# code-reviewer.md
# ---------------------------------------------------------------------------

@test "code-reviewer.md has valid YAML frontmatter" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/code-reviewer.md' | yq '.' > /dev/null 2>&1"
  assert_success
}

@test "code-reviewer.md has required name field" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/code-reviewer.md' | yq -r '.name'"
  assert_success
  assert_output "code-reviewer"
}

@test "code-reviewer.md has tools restricted to read-only" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/code-reviewer.md' | yq '.tools | length'"
  assert_success
  assert_output "4"
}

@test "code-reviewer.md has maxTurns field" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/code-reviewer.md' | yq -r '.maxTurns'"
  assert_success
  assert_output "50"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/lint/agent-frontmatter.bats --filter "code-reviewer"`
Expected: FAIL — file does not exist

- [ ] **Step 3: Create `agents/code-reviewer.md`**

```markdown
---
name: code-reviewer
description: >
  Independent code reviewer — receives only design docs and source code
  paths. Reviews without implementation context for unbiased quality
  assessment. Read-only.
tools:
  - Read
  - Grep
  - Glob
  - Bash
effort: high
maxTurns: 50
---

# Code Reviewer

You are an **independent code reviewer**. You receive design documents and
source code paths, and you review the implementation without knowing the
implementation history or developer discussions.

## What You Receive

- Paths to design documents (`.design/specs/`)
- Paths to source code files
- Path to `requirements.md`

## What You Do NOT Receive (Intentional)

- PBI details or descriptions from `.scrum/`
- Developer communications or implementation history
- Sprint context or backlog state

This information asymmetry is intentional. You review purely based on
whether the code fulfills the design specification.

## Review Process

1. **Read design documents** — understand the intended behavior, interfaces,
   and constraints specified in the design.
2. **Read source code** — examine the implementation files provided.
3. **Read requirements** — cross-reference with the requirements document.
4. **Compare** — verify the implementation matches the design specification:
   - Are all design requirements implemented? (completeness)
   - Is anything implemented that was NOT in the design? (scope creep)
   - Does the code correctly implement the specified behavior? (correctness)
5. **Assess code quality**:
   - Readability and naming
   - Error handling
   - Test coverage (do tests exist and are they meaningful?)
   - Security concerns (defer to security-reviewer for deep analysis)
6. **Produce verdict**

## Output Format

```
## Review: [brief description]

**Verdict: PASS | FAIL**

### Findings

| # | Severity | File | Lines | Description |
|---|----------|------|-------|-------------|
| 1 | Critical | path/to/file.py | 42-45 | Description of issue |
| 2 | High | path/to/other.py | 10 | Description of issue |

### Summary

[2-3 sentences summarizing the review]
```

**Severity levels:**
- **Critical** — Must fix. Incorrect behavior, security vulnerability, data loss risk.
- **High** — Should fix. Missing requirement, significant quality issue.
- **Medium** — Consider fixing. Maintainability concern, unclear naming.
- **Low** — Optional. Style suggestion, minor improvement.

**Verdict rules:**
- **PASS** — No Critical or High findings.
- **FAIL** — One or more Critical or High findings.

## Strict Rules

- **DO NOT** modify any files. You are read-only.
- **DO NOT** suggest fixes. Only describe the problem.
- **DO NOT** assess based on information you were not given.
- If you cannot determine correctness from the provided documents, say so
  explicitly rather than guessing.
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/lint/agent-frontmatter.bats --filter "code-reviewer"`
Expected: PASS

- [ ] **Step 5: Run all tests**

Run: `bats tests/unit/ tests/lint/`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add agents/code-reviewer.md tests/lint/agent-frontmatter.bats
git commit -m "feat: add independent code-reviewer sub-agent"
```

---

### Task 2: Create `agents/security-reviewer.md`

**Files:**
- Create: `agents/security-reviewer.md`
- Modify: `tests/lint/agent-frontmatter.bats`

- [ ] **Step 1: Write failing tests**

Add to `tests/lint/agent-frontmatter.bats` after the code-reviewer section:

```bash
# ---------------------------------------------------------------------------
# security-reviewer.md
# ---------------------------------------------------------------------------

@test "security-reviewer.md has valid YAML frontmatter" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/security-reviewer.md' | yq '.' > /dev/null 2>&1"
  assert_success
}

@test "security-reviewer.md has required name field" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/security-reviewer.md' | yq -r '.name'"
  assert_success
  assert_output "security-reviewer"
}

@test "security-reviewer.md has tools restricted to read-only" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/security-reviewer.md' | yq '.tools | length'"
  assert_success
  assert_output "4"
}

@test "security-reviewer.md has maxTurns field" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/security-reviewer.md' | yq -r '.maxTurns'"
  assert_success
  assert_output "50"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/lint/agent-frontmatter.bats --filter "security-reviewer"`
Expected: FAIL

- [ ] **Step 3: Create `agents/security-reviewer.md`**

```markdown
---
name: security-reviewer
description: >
  Security vulnerability scanner — checks for OWASP Top 10, hardcoded
  secrets, injection risks, and authentication issues. Read-only.
tools:
  - Read
  - Grep
  - Glob
  - Bash
effort: high
maxTurns: 50
---

# Security Reviewer

You are a **security-focused code reviewer**. You scan source code for
security vulnerabilities without knowing the implementation history.

## What You Receive

- Paths to source code files
- Path to `requirements.md` (for auth/data handling context)

## Security Checklist

### OWASP Top 10

1. **Injection** — SQL injection, command injection, XSS
   - String concatenation in queries
   - Unsanitized user input in shell commands
   - Unescaped output in HTML templates
2. **Broken Authentication** — weak auth patterns
   - Hardcoded credentials or API keys
   - Missing session management
   - Weak password handling
3. **Sensitive Data Exposure**
   - Secrets in source code (grep for patterns: `password`, `secret`,
     `api_key`, `token`, `private_key`)
   - Sensitive data in logs or error messages
   - Missing encryption for sensitive data
4. **Security Misconfiguration**
   - Debug mode enabled in production config
   - Default credentials
   - Overly permissive CORS
5. **Cross-Site Scripting (XSS)**
   - `innerHTML` / `dangerouslySetInnerHTML` usage
   - Template injection
6. **Insecure Deserialization** — pickle, eval, exec usage
7. **Using Components with Known Vulnerabilities** — outdated dependencies
8. **Insufficient Logging** — missing audit trails for auth events

### Additional Checks

- Path traversal (unsanitized file paths from user input)
- CSRF protection on state-changing endpoints
- Rate limiting on auth endpoints
- Proper error handling that does not leak stack traces

## Output Format

```
## Security Review

**Verdict: PASS | FAIL**

### Findings

| # | Severity | Category | File | Lines | Description |
|---|----------|----------|------|-------|-------------|
| 1 | Critical | Injection | path/file.py | 42 | Description |

### Summary

[2-3 sentences]
```

**Verdict rules:**
- **PASS** — No Critical or High findings.
- **FAIL** — One or more Critical or High findings.

## Strict Rules

- **DO NOT** modify any files. You are read-only.
- **DO NOT** suggest fixes. Only describe the vulnerability.
- Focus exclusively on security. Leave code quality to the code-reviewer.
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/lint/agent-frontmatter.bats --filter "security-reviewer"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add agents/security-reviewer.md tests/lint/agent-frontmatter.bats
git commit -m "feat: add security-reviewer sub-agent"
```

---

### Task 3: Create `agents/tdd-guide.md`

**Files:**
- Create: `agents/tdd-guide.md`
- Modify: `tests/lint/agent-frontmatter.bats`

- [ ] **Step 1: Write failing tests**

Add to `tests/lint/agent-frontmatter.bats`:

```bash
# ---------------------------------------------------------------------------
# tdd-guide.md
# ---------------------------------------------------------------------------

@test "tdd-guide.md has valid YAML frontmatter" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/tdd-guide.md' | yq '.' > /dev/null 2>&1"
  assert_success
}

@test "tdd-guide.md has required name field" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/tdd-guide.md' | yq -r '.name'"
  assert_success
  assert_output "tdd-guide"
}

@test "tdd-guide.md has model set to haiku" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/tdd-guide.md' | yq -r '.model'"
  assert_success
  assert_output "haiku"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/lint/agent-frontmatter.bats --filter "tdd-guide"`
Expected: FAIL

- [ ] **Step 3: Create `agents/tdd-guide.md`**

```markdown
---
name: tdd-guide
description: >
  TDD coach — guides test-first development. Helps write failing tests
  before implementation, verifies test quality, enforces RED-GREEN-REFACTOR.
tools:
  - Read
  - Grep
  - Glob
  - Bash
model: haiku
effort: medium
maxTurns: 30
---

# TDD Guide

You are a **test-driven development coach**. You help developers write
tests first and implement code to pass them.

## Your Role

- Review the design document to understand what needs to be tested
- Suggest test cases that cover the acceptance criteria
- Verify tests are meaningful (not just testing mocks)
- Enforce the RED-GREEN-REFACTOR cycle:
  1. **RED** — Write a failing test
  2. **GREEN** — Write minimal code to pass
  3. **REFACTOR** — Clean up without changing behavior

## What You Check

- Do tests exist for the feature?
- Do tests cover edge cases and error paths?
- Are tests isolated (no hidden dependencies)?
- Do tests verify behavior, not implementation details?
- Is test coverage adequate (aim for 80%+)?

## Output Format

```
## TDD Assessment

### Test Coverage

| Requirement | Test Exists | Test Quality |
|-------------|------------|--------------|
| Feature A | Yes | Good — tests behavior |
| Feature B | No | — |
| Error path C | Yes | Weak — only tests happy path |

### Suggested Test Cases

1. [description of missing test case]
2. [description of missing test case]

### Summary

[2-3 sentences]
```

## Strict Rules

- **DO NOT** write code or tests. Only advise.
- **DO NOT** modify any files. You are read-only.
- Keep suggestions concise and actionable.
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/lint/agent-frontmatter.bats --filter "tdd-guide"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add agents/tdd-guide.md tests/lint/agent-frontmatter.bats
git commit -m "feat: add tdd-guide sub-agent"
```

---

### Task 4: Create `agents/build-error-resolver.md`

**Files:**
- Create: `agents/build-error-resolver.md`
- Modify: `tests/lint/agent-frontmatter.bats`

- [ ] **Step 1: Write failing tests**

Add to `tests/lint/agent-frontmatter.bats`:

```bash
# ---------------------------------------------------------------------------
# build-error-resolver.md
# ---------------------------------------------------------------------------

@test "build-error-resolver.md has valid YAML frontmatter" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/build-error-resolver.md' | yq '.' > /dev/null 2>&1"
  assert_success
}

@test "build-error-resolver.md has required name field" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/build-error-resolver.md' | yq -r '.name'"
  assert_success
  assert_output "build-error-resolver"
}

@test "build-error-resolver.md has model set to haiku" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/build-error-resolver.md' | yq -r '.model'"
  assert_success
  assert_output "haiku"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/lint/agent-frontmatter.bats --filter "build-error-resolver"`
Expected: FAIL

- [ ] **Step 3: Create `agents/build-error-resolver.md`**

```markdown
---
name: build-error-resolver
description: >
  Build error diagnostician — analyzes build failures, lint errors, and
  test failures. Proposes targeted fixes without restructuring.
tools:
  - Read
  - Grep
  - Glob
  - Bash
model: haiku
effort: medium
maxTurns: 30
---

# Build Error Resolver

You are a **build error diagnostician**. When a developer encounters
build failures, lint errors, or test failures, you analyze the error
and propose a targeted fix.

## Your Role

1. Read the error message provided by the developer
2. Locate the relevant source file and line
3. Understand the root cause
4. Propose a minimal, targeted fix

## Error Categories

- **Build errors** — syntax errors, missing imports, type mismatches
- **Lint errors** — shellcheck, ruff, eslint violations
- **Test failures** — assertion errors, setup issues, flaky tests
- **Dependency errors** — missing packages, version conflicts

## Output Format

```
## Diagnosis

**Error:** [one-line summary]
**Root Cause:** [explanation]
**File:** [path:line]

### Proposed Fix

[describe the specific change needed — what to change, not how to
refactor the entire module]
```

## Strict Rules

- **DO NOT** modify any files. Only diagnose and propose.
- Propose the **smallest possible fix**. Do not suggest refactoring.
- If the error is ambiguous, list the most likely causes ranked by
  probability.
- If the error is outside your understanding, say so.
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/lint/agent-frontmatter.bats --filter "build-error-resolver"`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add agents/build-error-resolver.md tests/lint/agent-frontmatter.bats
git commit -m "feat: add build-error-resolver sub-agent"
```

---

### Task 5: Update `skills/cross-review/SKILL.md`

**Files:**
- Modify: `skills/cross-review/SKILL.md`

- [ ] **Step 1: Read current file**

Read: `skills/cross-review/SKILL.md` (already known from context)

- [ ] **Step 2: Rewrite the skill**

Replace the entire content of `skills/cross-review/SKILL.md` with:

```markdown
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
```

- [ ] **Step 3: Run skill lint tests**

Run: `bats tests/lint/skill-frontmatter.bats`
Expected: All pass (14 skills still present, frontmatter valid)

- [ ] **Step 4: Commit**

```bash
git add skills/cross-review/SKILL.md
git commit -m "refactor: replace peer cross-review with independent sub-agent review"
```

---

### Task 6: Update `agents/developer.md`

**Files:**
- Modify: `agents/developer.md:1-20` (frontmatter) and lifecycle/responsibilities sections

- [ ] **Step 1: Update developer.md frontmatter — remove cross-review from skills**

Change the skills list in frontmatter from:

```yaml
skills:
  - requirements-sprint
  - design
  - implementation
  - cross-review
  - install-subagents
  - smoke-test
```

to:

```yaml
skills:
  - requirements-sprint
  - design
  - implementation
  - install-subagents
  - smoke-test
```

- [ ] **Step 2: Update developer.md description**

Change the description from:

```yaml
description: >
  Developer teammate — implements PBIs, produces design documents,
  writes tests, performs cross-review. Spawned per Sprint by the
  Scrum Master via Agent Teams.
```

to:

```yaml
description: >
  Developer teammate — implements PBIs, produces design documents,
  and writes tests. Spawned per Sprint by the Scrum Master via
  Agent Teams. Code review is handled by independent sub-agents.
```

- [ ] **Step 3: Update developer.md lifecycle section**

In the `## Lifecycle` section, change step 7 from:

```markdown
7. **Review** — Invoke the `cross-review` skill: review another Developer's
   implementation against design docs and acceptance criteria (round-robin).
```

to:

```markdown
7. **Await Review** — Code review is handled by the Scrum Master using
   independent `code-reviewer` and `security-reviewer` sub-agents.
   Address any review findings relayed by the Scrum Master.
```

- [ ] **Step 4: Update mandatory skill invocation order**

Change:

```markdown
**IMPORTANT — Skill invocation order is mandatory:**
You MUST invoke the skills in this exact sequence: `design` →
`implementation` → `cross-review`. Do NOT skip phases or reorder them.
```

to:

```markdown
**IMPORTANT — Skill invocation order is mandatory:**
You MUST invoke the skills in this exact sequence: `design` →
`implementation`. Do NOT skip phases or reorder them.
Each skill has preconditions that depend on the previous skill's outputs.
```

- [ ] **Step 5: Remove FR-009 cross-review responsibility section**

Remove the entire `### FR-009: Cross-Review` section (lines about reviewing assigned PBI from another Developer, producing review results, etc.).

- [ ] **Step 6: Update the lint test for developer skills count**

In `tests/lint/agent-frontmatter.bats`, the test `"developer.md has install-subagents in skills"` still works (install-subagents remains). No skills count test exists for developer.md, so no test update needed.

- [ ] **Step 7: Run all tests**

Run: `bats tests/unit/ tests/lint/`
Expected: All pass

- [ ] **Step 8: Commit**

```bash
git add agents/developer.md
git commit -m "refactor: remove cross-review from developer agent responsibilities"
```

---

### Task 7: Update `agents/scrum-master.md`

**Files:**
- Modify: `agents/scrum-master.md` (workflow section and phase transition rule)

- [ ] **Step 1: Update workflow section**

In the `## Workflow` section, change:

```markdown
   - **Transition phase** → Developers execute skills in mandatory order:
     `design` → `implementation` → `cross-review`
```

to:

```markdown
   - **Transition phase** → Developers execute: `design` → `implementation`
   - **Review phase** → Scrum Master spawns `code-reviewer` and
     `security-reviewer` sub-agents per PBI (see cross-review skill)
```

- [ ] **Step 2: Update FR-009 section**

Change the `### FR-009: Cross-Review` section from:

```markdown
### FR-009: Cross-Review
- Orchestrate cross-review after all implementations complete
- Single-PBI Sprint: perform the review yourself
```

to:

```markdown
### FR-009: Independent Code Review
- After all implementations complete, spawn `code-reviewer` and
  `security-reviewer` sub-agents per PBI via the Agent tool
- Pass only design doc paths, source file paths, and requirements.md
- Do NOT pass PBI details, developer communications, or .scrum/ state
- If review returns FAIL: relay findings to Developer, wait for fix,
  re-spawn reviewer until PASS
- Combine both review results into `.scrum/reviews/<pbi-id>-review.md`
```

- [ ] **Step 3: Update phase transition rule**

Change:

```markdown
- Before delegating `cross-review`: write `phase: "review"` to `state.json`
```

to:

```markdown
- Before spawning review sub-agents: write `phase: "review"` to `state.json`
```

- [ ] **Step 4: Run all tests**

Run: `bats tests/unit/ tests/lint/`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add agents/scrum-master.md
git commit -m "refactor: update scrum-master to use independent reviewer sub-agents"
```

---

### Task 8: Simplify `skills/install-subagents/SKILL.md`

**Files:**
- Modify: `skills/install-subagents/SKILL.md`

- [ ] **Step 1: Rewrite install-subagents skill**

Replace the entire content with:

```markdown
---
name: install-subagents
description: >
  Select and verify project-managed sub-agents for PBI work.
  Developers invoke after receiving PBI assignments.
disable-model-invocation: false
---

## Inputs

- PBI assignment (task context from `backlog.json` → assigned PBI details)
- Project sub-agents in `agents/` directory:
  - `code-reviewer.md` — independent code review (used by Scrum Master)
  - `security-reviewer.md` — security vulnerability scanning (used by Scrum Master)
  - `tdd-guide.md` — TDD workflow guidance
  - `build-error-resolver.md` — build/lint error diagnosis

## Outputs

- Confirmation that relevant sub-agents are available in `.claude/agents/`
- `sprint.json` → `developers[].sub_agents` — runtime-populated with names
  of actually-invoked sub-agents (not candidates)

## Preconditions

- Developer has received PBI assignment via Agent Teams
- `.claude/agents/` directory exists with project sub-agent definitions

## Steps

1. **Analyze PBI**: Read the assigned PBI details (title, description,
   acceptance criteria, design document paths) to understand what
   specialist skills are needed.
2. **List available sub-agents**: Read `.claude/agents/` directory and
   identify available sub-agents by reading their YAML frontmatter
   (`name`, `description`).
   Available sub-agents for Developer use:
   - `tdd-guide` — invoke for test-first development guidance
   - `build-error-resolver` — invoke when builds or tests fail
   Note: `code-reviewer` and `security-reviewer` are used by the
   Scrum Master during the review phase, not by Developers directly.
3. **Verify availability**: Confirm the sub-agent definition files exist
   and have valid YAML frontmatter with required fields.
4. **Use via Agent tool**: During implementation, invoke sub-agents via
   `Agent(subagent_type="<agent-name>")`. Only record actually-used
   agents in `sprint.json` → `developers[].sub_agents`.

## Graceful Degradation

- If sub-agent definition files are missing, proceed without them.
  Sub-agents are optional enhancements, not requirements.
- Log a brief note if expected agents are unavailable.

Reference: FR-019

## Exit Criteria

- Developer has verified which sub-agents are available
- Developer can proceed with implementation regardless of sub-agent
  availability
- Only actually-invoked agents recorded in `sprint.json` (at runtime)
```

- [ ] **Step 2: Run skill lint tests**

Run: `bats tests/lint/skill-frontmatter.bats`
Expected: All pass

- [ ] **Step 3: Commit**

```bash
git add skills/install-subagents/SKILL.md
git commit -m "refactor: simplify install-subagents to use project-managed agents only"
```

---

### Task 9: Remove external catalog from `scripts/setup-user.sh`

**Files:**
- Modify: `scripts/setup-user.sh:83-99` (remove subagents catalog clone section)

- [ ] **Step 1: Remove the clone/update section**

In `scripts/setup-user.sh`, delete lines 83-99 (the entire "Clone sub-agent catalog" section):

```bash
# --- Clone sub-agent catalog (categories/ only via sparse checkout) ---
subagents_dir="$TARGET_DIR/.claude/subagents-catalog"
if [ -d "$subagents_dir/.git" ]; then
  echo "Updating sub-agent catalog..."
  git -C "$subagents_dir" pull --ff-only 2>/dev/null || echo "  Warning: catalog update failed — using existing copy." >&2
else
  echo "Cloning sub-agent catalog (awesome-claude-code-subagents)..."
  if git clone --filter=blob:none --no-checkout --depth 1 \
       git@github.com:VoltAgent/awesome-claude-code-subagents.git "$subagents_dir" 2>/dev/null && \
     git -C "$subagents_dir" sparse-checkout set categories 2>/dev/null && \
     git -C "$subagents_dir" checkout 2>/dev/null; then
    :
  else
    echo "  Warning: catalog clone failed — sub-agents will be unavailable." >&2
    rm -rf "$subagents_dir"
  fi
fi
```

- [ ] **Step 2: Update the setup complete message**

Remove the line:
```
echo "  .claude/subagents-catalog/ — Sub-agent definitions (awesome-claude-code-subagents)"
```

- [ ] **Step 3: Run shellcheck**

Run: `shellcheck scripts/setup-user.sh`
Expected: Clean

- [ ] **Step 4: Run all tests**

Run: `bats tests/unit/ tests/lint/`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add scripts/setup-user.sh
git commit -m "refactor: remove external sub-agent catalog dependency from setup"
```

---

### Task 10: Update `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Update project structure**

Change the agents section from:

```text
agents/                  # Scrum Master + Developer agent definitions
  scrum-master.md        # Team lead (Delegate mode)
  developer.md           # Developer teammate
```

to:

```text
agents/                  # Agent and sub-agent definitions
  scrum-master.md        # Team lead (Delegate mode)
  developer.md           # Developer teammate
  code-reviewer.md       # Independent code review (spawned by Scrum Master)
  security-reviewer.md   # Security vulnerability scanning (spawned by Scrum Master)
  tdd-guide.md           # TDD workflow guidance (spawned by Developer)
  build-error-resolver.md # Build error diagnosis (spawned by Developer)
```

- [ ] **Step 2: Update cross-review skill description**

Change:

```text
  cross-review/          # Cross-review between developers
```

to:

```text
  cross-review/          # Independent code review via sub-agents
```

- [ ] **Step 3: Remove subagents-catalog reference from setup-user.sh description**

Change:

```text
  setup-user.sh          # Copies agents/skills/hooks/catalog to target project
```

to:

```text
  setup-user.sh          # Copies agents/skills/hooks to target project
```

- [ ] **Step 4: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: update project structure for sub-agent catalog and cross-review changes"
```

---

### Task 11: Final Verification

**Files:**
- All modified files from Tasks 1-10

- [ ] **Step 1: Run full test suite**

Run: `bats tests/unit/ tests/lint/`
Expected: All tests pass

- [ ] **Step 2: Run shellcheck**

Run: `shellcheck scrum-start.sh scripts/*.sh scripts/lib/*.sh hooks/*.sh hooks/lib/*.sh`
Expected: Clean

- [ ] **Step 3: Verify setup-user.sh in temp directory**

```bash
cd "$(mktemp -d)" && git init && source /path/to/venv/bin/activate && bash /path/to/scripts/setup-user.sh
ls .claude/agents/
```

Expected: 6 agent files (scrum-master.md, developer.md, code-reviewer.md, security-reviewer.md, tdd-guide.md, build-error-resolver.md)

Expected: No `.claude/subagents-catalog/` directory

- [ ] **Step 4: Update design spec status**

Mark `docs/superpowers/specs/2026-04-11-reviewer-subagent-and-agent-catalog-design.md` status as "Implemented".
