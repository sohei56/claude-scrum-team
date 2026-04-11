# Claude Code New Features Adoption — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Adopt Claude Code v2.1.69–v2.1.101 features to improve hook efficiency, agent governance, context resilience, and developer isolation.

**Architecture:** Update agent frontmatter for platform-level enforcement, add new hook events to settings.json template, create a StopFailure hook script, and investigate worktree isolation compatibility with Agent Teams.

**Tech Stack:** Bash 3.2+, YAML frontmatter, JSON (jq), bats-core tests

---

### Task 1: Add `matcher` to PreToolUse Hook in settings.json Template

**Files:**
- Modify: `scripts/setup-user.sh:139-148` (PreToolUse section of settings.json template)

- [ ] **Step 1: Write the failing test**

Add a test to `tests/unit/hooks.bats` that verifies the generated settings.json has a matcher on the PreToolUse hook.

```bash
# Add to tests/unit/hooks.bats at the end

# ---------------------------------------------------------------------------
# settings.json template validation
# ---------------------------------------------------------------------------

@test "setup-user.sh generates PreToolUse with Write|Edit matcher" {
  setup_temp_dir
  cd "$TEMP_DIR"
  git init --quiet
  mkdir -p .scrum

  run bash "$PROJECT_ROOT/scripts/setup-user.sh"
  assert_success

  # PreToolUse hook must have a matcher field
  run jq -r '.hooks.PreToolUse[0].matcher' .claude/settings.json
  assert_output "Write|Edit"
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `bats tests/unit/hooks.bats --filter "PreToolUse with Write"`
Expected: FAIL — current template has no matcher on PreToolUse

- [ ] **Step 3: Update settings.json template in setup-user.sh**

In `scripts/setup-user.sh`, change the PreToolUse section from:

```json
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/phase-gate.sh"
          }
        ]
      }
    ],
```

to:

```json
    "PreToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/phase-gate.sh"
          }
        ]
      }
    ],
```

- [ ] **Step 4: Run test to verify it passes**

Run: `bats tests/unit/hooks.bats --filter "PreToolUse with Write"`
Expected: PASS

- [ ] **Step 5: Run all existing tests to check for regressions**

Run: `bats tests/unit/ tests/lint/`
Expected: All tests pass

- [ ] **Step 6: Commit**

```bash
git add scripts/setup-user.sh tests/unit/hooks.bats
git commit -m "perf: add Write|Edit matcher to PreToolUse hook to reduce unnecessary invocations"
```

---

### Task 2: Enhance Scrum Master Agent Frontmatter

**Files:**
- Modify: `agents/scrum-master.md:1-23` (YAML frontmatter)
- Modify: `tests/lint/agent-frontmatter.bats` (add frontmatter field tests)

- [ ] **Step 1: Write the failing tests**

Add tests to `tests/lint/agent-frontmatter.bats`:

```bash
# Add after the existing scrum-master.md tests

@test "scrum-master.md has effort field set to high" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/scrum-master.md' | yq -r '.effort'"
  assert_success
  assert_output "high"
}

@test "scrum-master.md has maxTurns field" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/scrum-master.md' | yq -r '.maxTurns'"
  assert_success
  assert_output "300"
}

@test "scrum-master.md has disallowedTools including Write and Edit" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/scrum-master.md' | yq '.disallowedTools | length'"
  assert_success
  assert_output "2"
}

@test "scrum-master.md has keep-coding-instructions set to true" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/scrum-master.md' | yq -r '.\"keep-coding-instructions\"'"
  assert_success
  assert_output "true"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/lint/agent-frontmatter.bats --filter "scrum-master.md has effort"`
Expected: FAIL

- [ ] **Step 3: Update scrum-master.md frontmatter**

Change the frontmatter from:

```yaml
---
name: scrum-master
description: >
  Scrum Master — Agent Teams team lead in Delegate mode.
  Coordinates Sprint ceremonies, manages the Product Backlog,
  spawns Developer teammates, and orchestrates the full Scrum
  workflow. Cannot write code, run tests, or perform implementation.
skills:
  - requirements-sprint
  ...
---
```

to:

```yaml
---
name: scrum-master
description: >
  Scrum Master — Agent Teams team lead in Delegate mode.
  Coordinates Sprint ceremonies, manages the Product Backlog,
  spawns Developer teammates, and orchestrates the full Scrum
  workflow. Cannot write code, run tests, or perform implementation.
effort: high
maxTurns: 300
keep-coding-instructions: true
disallowedTools:
  - Write
  - Edit
skills:
  - requirements-sprint
  ...
---
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/lint/agent-frontmatter.bats`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add agents/scrum-master.md tests/lint/agent-frontmatter.bats
git commit -m "feat: add effort, maxTurns, disallowedTools, keep-coding-instructions to scrum-master agent"
```

---

### Task 3: Enhance Developer Agent Frontmatter

**Files:**
- Modify: `agents/developer.md:1-15` (YAML frontmatter)
- Modify: `tests/lint/agent-frontmatter.bats` (add developer frontmatter tests)

- [ ] **Step 1: Write the failing tests**

Add tests to `tests/lint/agent-frontmatter.bats`:

```bash
# Add after the existing developer.md tests

@test "developer.md has effort field set to high" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/developer.md' | yq -r '.effort'"
  assert_success
  assert_output "high"
}

@test "developer.md has maxTurns field" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/developer.md' | yq -r '.maxTurns'"
  assert_success
  assert_output "200"
}

@test "developer.md has disallowedTools including WebFetch and WebSearch" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/developer.md' | yq '.disallowedTools | length'"
  assert_success
  assert_output "2"
}

@test "developer.md has keep-coding-instructions set to true" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/developer.md' | yq -r '.\"keep-coding-instructions\"'"
  assert_success
  assert_output "true"
}

@test "developer.md has memory field set to project" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/developer.md' | yq -r '.memory'"
  assert_success
  assert_output "project"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/lint/agent-frontmatter.bats --filter "developer.md has effort"`
Expected: FAIL

- [ ] **Step 3: Update developer.md frontmatter**

Change the frontmatter from:

```yaml
---
name: developer
description: >
  Developer teammate — implements PBIs, produces design documents,
  writes tests, performs cross-review. Spawned per Sprint by the
  Scrum Master via Agent Teams.
skills:
  - requirements-sprint
  - design
  - implementation
  - cross-review
  - install-subagents
  - smoke-test
---
```

to:

```yaml
---
name: developer
description: >
  Developer teammate — implements PBIs, produces design documents,
  writes tests, performs cross-review. Spawned per Sprint by the
  Scrum Master via Agent Teams.
effort: high
maxTurns: 200
keep-coding-instructions: true
memory: project
disallowedTools:
  - WebFetch
  - WebSearch
skills:
  - requirements-sprint
  - design
  - implementation
  - cross-review
  - install-subagents
  - smoke-test
---
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/lint/agent-frontmatter.bats`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add agents/developer.md tests/lint/agent-frontmatter.bats
git commit -m "feat: add effort, maxTurns, disallowedTools, memory, keep-coding-instructions to developer agent"
```

---

### Task 4: Create StopFailure Hook Script

**Files:**
- Create: `hooks/stop-failure.sh`
- Modify: `tests/unit/hooks.bats` (add StopFailure tests)

- [ ] **Step 1: Write the failing test**

Add to `tests/unit/hooks.bats`:

```bash
# ---------------------------------------------------------------------------
# stop-failure.sh
# ---------------------------------------------------------------------------

@test "stop-failure.sh logs rate_limit failure to dashboard.json" {
  mkdir -p .scrum

  local event_json
  event_json='{"hook_event_name":"StopFailure","reason":"rate_limit","agent_id":"dev-001"}'

  run bash -c "echo '$event_json' | bash '$PROJECT_ROOT/hooks/stop-failure.sh'"
  assert_success

  [ -f ".scrum/dashboard.json" ]
  jq -e '.events[-1].type == "stop_failure"' .scrum/dashboard.json
  jq -e '.events[-1].detail | test("rate_limit")' .scrum/dashboard.json
}

@test "stop-failure.sh logs authentication_failed to dashboard.json" {
  mkdir -p .scrum

  local event_json
  event_json='{"hook_event_name":"StopFailure","reason":"authentication_failed","agent_id":"scrum-master"}'

  run bash -c "echo '$event_json' | bash '$PROJECT_ROOT/hooks/stop-failure.sh'"
  assert_success

  [ -f ".scrum/dashboard.json" ]
  jq -e '.events[-1].type == "stop_failure"' .scrum/dashboard.json
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/unit/hooks.bats --filter "stop-failure"`
Expected: FAIL — script does not exist

- [ ] **Step 3: Create hooks/stop-failure.sh**

```bash
#!/usr/bin/env bash
# stop-failure.sh — StopFailure hook
# Logs session failure events (rate_limit, authentication_failed, etc.)
# to the dashboard for visibility. Reads hook event JSON from stdin.
set -euo pipefail

HOOK_DIR="$(cd "$(dirname "$0")" && pwd)"
# shellcheck source=lib/validate.sh
. "$HOOK_DIR/lib/validate.sh"

DASHBOARD_FILE=".scrum/dashboard.json"
MAX_EVENTS=100

# Initialize dashboard.json if it does not exist
ensure_dashboard_file() {
  ensure_scrum_dir
  if [ ! -f "$DASHBOARD_FILE" ]; then
    jq -n --argjson max "$MAX_EVENTS" '{"events": [], "max_events": $max}' > "$DASHBOARD_FILE"
  fi
}

# Append an event to dashboard.json, trimming oldest if over cap
append_dashboard_event() {
  local event_json="$1"
  ensure_dashboard_file

  local tmp_file
  tmp_file="${DASHBOARD_FILE}.tmp.$$"

  local file_max
  file_max="$(jq '.max_events // 100' "$DASHBOARD_FILE" 2>/dev/null || echo "$MAX_EVENTS")"

  jq --argjson evt "$event_json" --argjson max "$file_max" '
    .events += [$evt] |
    if (.events | length) > $max then
      .events = .events[(.events | length) - $max:]
    else
      .
    end
  ' "$DASHBOARD_FILE" > "$tmp_file" && mv "$tmp_file" "$DASHBOARD_FILE"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

hook_event="$(cat)"

reason="$(echo "$hook_event" | jq -r '.reason // "unknown"')"
agent_id="$(echo "$hook_event" | jq -r '.agent_id // .session_id // "unknown"')"
timestamp="$(get_timestamp)"

log_hook "stop-failure" "ERROR" "Session failed: $reason (agent: $agent_id)"

event_json="$(jq -n \
  --arg ts "$timestamp" \
  --arg agent "$agent_id" \
  --arg reason "$reason" \
  --arg detail "Session failed: ${reason}" \
  '{
    "timestamp": $ts,
    "type": "stop_failure",
    "agent_id": $agent,
    "file_path": null,
    "change_type": null,
    "detail": $detail
  }')"

append_dashboard_event "$event_json"

exit 0
```

- [ ] **Step 4: Make the script executable**

Run: `chmod +x hooks/stop-failure.sh`

- [ ] **Step 5: Run tests to verify they pass**

Run: `bats tests/unit/hooks.bats --filter "stop-failure"`
Expected: PASS

- [ ] **Step 6: Run shellcheck**

Run: `shellcheck hooks/stop-failure.sh`
Expected: No errors

- [ ] **Step 7: Commit**

```bash
git add hooks/stop-failure.sh tests/unit/hooks.bats
git commit -m "feat: add StopFailure hook script for dashboard failure logging"
```

---

### Task 5: Add PostCompact, StopFailure, and FileChanged Hooks to settings.json Template

**Files:**
- Modify: `scripts/setup-user.sh:113-220` (settings.json template)

- [ ] **Step 1: Write the failing test**

Add to `tests/unit/hooks.bats`:

```bash
@test "setup-user.sh generates PostCompact hook" {
  setup_temp_dir
  cd "$TEMP_DIR"
  git init --quiet
  mkdir -p .scrum

  run bash "$PROJECT_ROOT/scripts/setup-user.sh"
  assert_success

  run jq -r '.hooks.PostCompact[0].hooks[0].command' .claude/settings.json
  assert_output ".claude/hooks/session-context.sh"
}

@test "setup-user.sh generates StopFailure hook" {
  setup_temp_dir
  cd "$TEMP_DIR"
  git init --quiet
  mkdir -p .scrum

  run bash "$PROJECT_ROOT/scripts/setup-user.sh"
  assert_success

  run jq -r '.hooks.StopFailure[0].hooks[0].command' .claude/settings.json
  assert_output ".claude/hooks/stop-failure.sh"
}

@test "setup-user.sh generates FileChanged hook" {
  setup_temp_dir
  cd "$TEMP_DIR"
  git init --quiet
  mkdir -p .scrum

  run bash "$PROJECT_ROOT/scripts/setup-user.sh"
  assert_success

  run jq -r '.hooks.FileChanged[0].hooks[0].command' .claude/settings.json
  assert_output ".claude/hooks/dashboard-event.sh"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bats tests/unit/hooks.bats --filter "generates PostCompact"`
Expected: FAIL

- [ ] **Step 3: Add new hook events to settings.json template in setup-user.sh**

Add the following entries to the `hooks` object in the heredoc, after the existing `SubagentStop` block:

```json
    "PostCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/session-context.sh"
          }
        ]
      }
    ],
    "StopFailure": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/stop-failure.sh"
          },
          {
            "type": "command",
            "command": ".claude/hooks/dashboard-event.sh"
          }
        ]
      }
    ],
    "FileChanged": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/dashboard-event.sh"
          }
        ]
      }
    ]
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `bats tests/unit/hooks.bats --filter "generates PostCompact|generates StopFailure|generates FileChanged"`
Expected: All PASS

- [ ] **Step 5: Run all tests**

Run: `bats tests/unit/ tests/lint/`
Expected: All pass

- [ ] **Step 6: Commit**

```bash
git add scripts/setup-user.sh tests/unit/hooks.bats
git commit -m "feat: add PostCompact, StopFailure, and FileChanged hook events to settings.json template"
```

---

### Task 6: Investigate and Apply Worktree Isolation for Developer Agent

**Files:**
- Possibly modify: `agents/developer.md:1-15` (add `isolation: worktree`)

This task is investigative. The `isolation: worktree` field may not be applied when an agent runs as an Agent Teams teammate (per official docs: "skills and mcpServers frontmatter fields are NOT applied when running as a teammate").

- [ ] **Step 1: Check official documentation for `isolation` field behavior with teammates**

Run: Fetch `https://code.claude.com/docs/en/sub-agents` and search for "isolation" and "teammate" to determine if `isolation: worktree` is applied for teammates.

- [ ] **Step 2: Decision point**

If `isolation` IS applied to teammates:
- Add `isolation: worktree` to `developer.md` frontmatter
- Add a lint test for the field
- Commit the change

If `isolation` is NOT applied to teammates:
- Document the limitation in the design spec
- Skip the code change
- Commit a docs-only update noting this limitation

- [ ] **Step 3: If applicable, update developer.md frontmatter**

Add `isolation: worktree` after the `memory` field:

```yaml
memory: project
isolation: worktree
```

- [ ] **Step 4: If applicable, add lint test**

```bash
@test "developer.md has isolation field set to worktree" {
  run bash -c "awk 'NR==1 && !/^---$/{exit} NR==1{next} /^---$/{exit} {print}' '${PROJECT_ROOT}/agents/developer.md' | yq -r '.isolation'"
  assert_success
  assert_output "worktree"
}
```

- [ ] **Step 5: Run tests and commit**

Run: `bats tests/lint/agent-frontmatter.bats`

```bash
git add agents/developer.md tests/lint/agent-frontmatter.bats
git commit -m "feat: add worktree isolation to developer agent (or docs: document worktree isolation limitation)"
```

---

### Task 7: Investigate `teammateMode` Setting as TMUX Unset Replacement

**Files:**
- Possibly modify: `scrum-start.sh:60-68` (tmux launch section)
- Possibly modify: `scripts/setup-user.sh:113-220` (settings.json template)

- [ ] **Step 1: Check official documentation for `teammateMode` setting**

Fetch `https://code.claude.com/docs/en/agent-teams` and search for "teammateMode" to understand available values and behavior.

- [ ] **Step 2: Decision point**

If `teammateMode: "in-process"` in settings.json forces in-process mode regardless of tmux:
- Remove `TMUX=` prefix from the claude launch command in `scrum-start.sh`
- Add `"teammateMode": "in-process"` to the settings.json template
- Test manually to verify the dashboard pane survives

If `teammateMode` does not override tmux detection:
- Keep the `TMUX=` approach
- Add a comment explaining that `teammateMode` was evaluated but doesn't work here

- [ ] **Step 3: If applicable, update scrum-start.sh**

Change line 68 from:

```bash
tmux send-keys -t "$session_name" "TMUX= CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude --agent scrum-master '${initial_prompt}'; tmux kill-session -t ${session_name}" C-m
```

to:

```bash
tmux send-keys -t "$session_name" "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude --agent scrum-master '${initial_prompt}'; tmux kill-session -t ${session_name}" C-m
```

And add `"teammateMode": "in-process"` to the settings.json template.

- [ ] **Step 4: If applicable, run full test suite**

Run: `bats tests/unit/ tests/lint/`
Expected: All pass

- [ ] **Step 5: Commit**

```bash
git add scrum-start.sh scripts/setup-user.sh
git commit -m "refactor: replace TMUX unset hack with teammateMode setting (or chore: document teammateMode evaluation)"
```

---

### Task 8: Final Verification and Cleanup

**Files:**
- All modified files from Tasks 1-7

- [ ] **Step 1: Run full test suite**

Run: `bats tests/unit/ tests/lint/`
Expected: All tests pass

- [ ] **Step 2: Run shellcheck on all hook scripts**

Run: `shellcheck hooks/*.sh hooks/lib/*.sh`
Expected: No errors

- [ ] **Step 3: Run lint on Python files**

Run: `ruff check dashboard/ && ruff format --check dashboard/`
Expected: No issues

- [ ] **Step 4: Verify setup-user.sh generates valid settings.json**

Run in a temp directory:
```bash
cd "$(mktemp -d)" && git init && bash /path/to/scripts/setup-user.sh && jq . .claude/settings.json
```
Expected: Valid JSON with all new hook events

- [ ] **Step 5: Update design spec status**

Mark `docs/superpowers/specs/2026-04-11-claude-code-new-features-adoption-design.md` status as "Implemented" with notes on Task 6 and Task 7 outcomes.
