# Reviewer Sub-Agent and Internal Agent Catalog

**Date**: 2026-04-11
**Status**: Implemented
**Scope**: Replace cross-review with independent code-reviewer sub-agent, introduce project-managed sub-agent catalog, remove external catalog dependencies.

## Background

The current cross-review process has Developer teammates review each other's work. This creates bias — reviewers share context with the implementer. Anthropic's official best practices recommend the Writer/Reviewer pattern: a fresh context reviewer that only sees design docs and code, without implementation history.

Additionally, the project currently depends on external catalogs (awesome-claude-code-subagents, ECC plugins) for sub-agent definitions. This introduces fragility and version drift. Moving to project-managed sub-agents simplifies setup and ensures consistency.

## Changes

### 1. New Sub-Agent: `agents/code-reviewer.md`

Independent code reviewer sub-agent spawned by the Scrum Master after implementation completes.

**Frontmatter:**
```yaml
name: code-reviewer
description: >
  Independent code reviewer — receives only design docs and source code paths.
  Reviews without implementation context for unbiased quality assessment. Read-only.
tools: [Read, Grep, Glob, Bash]
effort: high
maxTurns: 50
```

**Information asymmetry (intentional):**
- Receives: design doc paths, source code paths, requirements.md path
- Does NOT receive: PBI details, developer communications, `.scrum/` internal state, implementation history

**Output format:**
- Verdict: PASS or FAIL
- Findings list with severity (Critical/High/Medium/Low)
- Each finding: file path, line range, description, recommendation

**Review re-loop:** If FAIL, Scrum Master relays issues to Developer → Developer fixes → Scrum Master spawns code-reviewer again for re-review. Loop until PASS.

### 2. New Sub-Agent: `agents/security-reviewer.md`

Security-focused reviewer spawned by the Scrum Master alongside code-reviewer (parallel domain-split review per Anthropic best practices).

**Frontmatter:**
```yaml
name: security-reviewer
description: >
  Security vulnerability scanner — checks for OWASP Top 10, hardcoded secrets,
  injection risks, and authentication issues. Read-only.
tools: [Read, Grep, Glob, Bash]
effort: high
maxTurns: 50
```

**Scope:** OWASP Top 10 (injection, auth, XSS, CSRF), hardcoded secrets/keys, path traversal, error messages leaking sensitive data.

**Output format:** Same as code-reviewer (PASS/FAIL + severity-rated findings).

### 3. New Sub-Agent: `agents/tdd-guide.md`

TDD workflow assistant spawned by Developers during implementation.

**Frontmatter:**
```yaml
name: tdd-guide
description: >
  TDD coach — guides test-first development. Helps write failing tests before
  implementation, verifies test quality, enforces RED-GREEN-REFACTOR cycle.
tools: [Read, Grep, Glob, Bash]
model: haiku
effort: medium
maxTurns: 30
```

**Read-only.** Provides guidance and checks — does not write code.

### 4. New Sub-Agent: `agents/build-error-resolver.md`

Build/lint error resolver spawned by Developers when builds fail.

**Frontmatter:**
```yaml
name: build-error-resolver
description: >
  Build error diagnostician — analyzes build failures, lint errors, and test
  failures. Proposes targeted fixes without restructuring.
tools: [Read, Grep, Glob, Bash]
model: haiku
effort: medium
maxTurns: 30
```

**Read-only.** Diagnoses and proposes fixes — does not apply them.

### 5. Modify: `skills/cross-review/SKILL.md`

Replace Developer cross-review with Scrum Master-driven sub-agent review.

**Key changes:**
- Remove round-robin peer review assignment
- Remove single-PBI-Sprint Scrum Master review (now all reviews use sub-agent)
- New workflow:
  1. Scrum Master transitions to review phase
  2. For each PBI, Scrum Master spawns `code-reviewer` and `security-reviewer` in parallel
  3. Passes only: design doc paths, source file paths, requirements.md
  4. Collects results; if FAIL → relays to Developer → Developer fixes → re-review
  5. Both pass → writes `.scrum/reviews/<pbi-id>-review.md` → marks PBI done

### 6. Modify: `agents/scrum-master.md`

- Update workflow section: replace "delegate cross-review to Developers" with "spawn code-reviewer and security-reviewer sub-agents"
- Add re-review loop instructions
- No changes to frontmatter (already has correct settings)

### 7. Modify: `agents/developer.md`

- Remove `cross-review` from `skills` list in frontmatter (5 skills remain)
- Remove "Review" step from lifecycle section
- Developer lifecycle becomes: Install sub-agents → Design → Implement → (done, review handled by Scrum Master)

### 8. Modify: `skills/install-subagents/SKILL.md`

Simplify to use project-local agents only:
- Remove references to awesome-claude-code-subagents catalog
- Remove references to ECC plugin agents
- New workflow: scan `agents/` directory for available sub-agents (code-reviewer, security-reviewer, tdd-guide, build-error-resolver), select relevant ones based on PBI requirements
- No external clone/fetch needed

### 9. Modify: `scripts/setup-user.sh`

- Remove the awesome-claude-code-subagents clone/update section (lines 84-99)
- Remove creation of `.claude/subagents-catalog/` directory
- The existing `cp agents/*.md .claude/agents/` already copies all agent definitions including new sub-agents

### 10. Update: `tests/lint/agent-frontmatter.bats`

- Add frontmatter tests for code-reviewer.md, security-reviewer.md, tdd-guide.md, build-error-resolver.md
- Update developer.md skills count test (14 → 5 skills after removing cross-review)

### 11. Modify: `CLAUDE.md`

- Update project structure to reflect new agents
- Remove `.claude/subagents-catalog/` from structure description

## Test Plan

- All existing bats tests pass after changes
- New agent frontmatter lint tests for 4 new sub-agents
- Developer skills count test updated (6 → 5)
- setup-user.sh no longer clones external catalog
- Manual test: run setup-user.sh and verify all 6 agents copied to `.claude/agents/`

## Out of Scope

- Test-writer sub-agent (deferred per user decision)
- Performance reviewer (YAGNI)
- Documentation writer (existing workflow sufficient)
- Architect sub-agent (design phase handled by Developers)
