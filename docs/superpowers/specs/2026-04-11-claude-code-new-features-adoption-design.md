# Claude Code New Features Adoption

**Date**: 2026-04-11
**Status**: Implemented
**Scope**: Adopt Claude Code v2.1.69–v2.1.101 features to improve hook efficiency, agent governance, context resilience, and developer isolation.

## Background

The project was created ~1 month ago. Since then, Claude Code has shipped ~30 releases with significant new capabilities in hooks, agent frontmatter, and subagent fields. This spec covers adopting the most impactful features.

## Changes

### 1. Hook `if` Field for PreToolUse (High Priority)

**Problem**: `phase-gate.sh` fires on every PreToolUse event (Read, Grep, Glob, etc.) even though it only gates Write/Edit operations. Each unnecessary invocation spawns a shell process, parses JSON, and reads state files.

**Solution**: Add `matcher: "Write|Edit"` to the PreToolUse hook entry in the settings.json template inside `setup-user.sh`.

**Files**: `scripts/setup-user.sh` (settings.json template)

### 2. Agent Frontmatter Enhancement (High Priority)

**Problem**: Agent constraints (Delegate mode for Scrum Master, resource limits for Developers) are only enforced via prose instructions in the agent markdown. Claude can violate these under context pressure.

**Solution**: Add frontmatter fields that Claude Code enforces at the platform level.

**scrum-master.md frontmatter additions**:
- `effort: high`
- `maxTurns: 300`
- `disallowedTools: [Write, Edit]` — enforces Delegate mode at platform level
- `keep-coding-instructions: true`

**developer.md frontmatter additions**:
- `effort: high`
- `maxTurns: 200`
- `disallowedTools: [WebFetch, WebSearch]` — keeps Developers focused on implementation
- `keep-coding-instructions: true`
- `memory: project` — persists learnings across Sprints (see item 4)

### 3. New Hook Events (High Priority)

#### PostCompact Hook

**Problem**: When context is compacted during long sessions, agents lose awareness of current phase, Sprint ID, and Sprint Goal.

**Solution**: Register `session-context.sh` as a PostCompact hook in the settings.json template. The existing script already outputs the right `additionalContext` JSON format — no code changes needed.

**Files**: `scripts/setup-user.sh` (settings.json template)

#### StopFailure Hook

**Problem**: When a session fails (rate limit, auth error), there is no record in the dashboard.

**Solution**: Create `hooks/stop-failure.sh` that logs failure events to `.scrum/dashboard.json` via the same `append_dashboard_event` pattern used by `dashboard-event.sh`. Register it for the `StopFailure` event in settings.json.

**Files**: `hooks/stop-failure.sh` (new), `scripts/setup-user.sh` (settings.json template)

### 4. Subagent `memory` Field (Medium Priority)

**Problem**: Retrospective improvements are stored in `.scrum/improvements.json` and Developers must manually read them. Cross-Sprint learning is fragile.

**Solution**: Add `memory: project` to `developer.md` frontmatter. Claude Code persists agent learnings to `.claude/agent-memory/developer/` automatically. Combined with the existing `improvements.json` workflow, this provides two complementary learning channels.

**Files**: `agents/developer.md`

### 5. `keep-coding-instructions` Field (Medium Priority)

**Problem**: Long ceremony sessions (design, implementation) risk losing critical agent instructions during context compaction.

**Solution**: Add `keep-coding-instructions: true` to both agent frontmatter. Claude Code preserves the agent's initial instructions through compaction events.

**Files**: `agents/scrum-master.md`, `agents/developer.md`

### 6. Subagent `isolation: worktree` Investigation (Medium Priority)

**Problem**: Multiple Developers working on the same repo can have file conflicts.

**Solution**: Add `isolation: worktree` to `developer.md` frontmatter. Each Developer gets an isolated git worktree copy.

**Caveat**: The `isolation` field may not be applied when agents run as Agent Teams teammates (teammates load settings differently from subagents). This needs verification. If it does not work with Agent Teams, document the limitation and skip.

**Investigation Result**: Skipped. Official docs only confirm `tools` and `model` are applied to teammates; `skills` and `mcpServers` are explicitly excluded. `isolation` is not mentioned for teammates at all. Since teammates are already independent Claude Code sessions, worktree isolation at the frontmatter level likely has no effect. Manual git worktrees remain the recommended approach for parallel developer work.

**Files**: None (no code changes)

### 7. Plugin Packaging (Low Priority — Deferred)

**Rationale**: The Claude Code plugin specification is still evolving (v2.1.69–v2.1.101 had multiple plugin-related changes). Packaging as a plugin now would require ongoing maintenance as the spec changes. The current `setup-user.sh` approach is stable and well-tested. Revisit when the plugin spec stabilizes.

**Action**: No code changes. Document decision.

### 8. FileChanged Hook for Dashboard (Low Priority)

**Problem**: The watchdog-based dashboard monitoring is reliable but may miss rapid file changes or changes made outside Claude Code tools.

**Solution**: Add a `FileChanged` hook entry in settings.json that calls `dashboard-event.sh`. This supplements (not replaces) the existing watchdog.

**Files**: `scripts/setup-user.sh` (settings.json template)

### 9. PostCompact for Session Context (Low Priority)

**Covered by item 3.** Registering `session-context.sh` for PostCompact eliminates the need for any changes to the script itself. The existing SessionStart registration remains.

### 10. `TMUX` Unset Investigation (Low Priority)

**Problem**: `scrum-start.sh` uses `unset TMUX` to prevent Agent Teams from creating split panes that would destroy the dashboard pane. The `teammateMode` setting may provide a cleaner solution.

**Solution**: Investigate whether `teammateMode: "in-process"` in settings.json achieves the same effect. If confirmed, replace the `unset TMUX` hack. If not, keep the current approach with a comment explaining why.

**Files**: `scrum-start.sh` (conditional), `scripts/setup-user.sh` (settings.json template, conditional)

## Test Plan

- Existing bats tests must pass after all changes
- New test for `stop-failure.sh`: verify JSON output format
- Lint tests: verify updated YAML frontmatter in agent files
- Manual verification: launch scrum-start.sh in a test project and confirm hooks fire correctly

## Out of Scope

- Migrating from tmux orchestration to native Agent Teams (still experimental, known limitations)
- Replacing watchdog with hook-only dashboard events (current approach is stable)
- Plugin packaging (deferred until spec stabilizes)
