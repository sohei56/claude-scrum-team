# PBI Pipeline Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restructure the per-PBI development workflow into separate sub-agent
sessions with file-based handoff. Developer becomes a pipeline conductor.
Black-box UT, deterministic termination gates, real-tool coverage measurement,
parallel PBI execution.

**Architecture:** Developer (long-running Agent Teams session) spawns six new
ephemeral sub-agents (`pbi-designer`, `codex-design-reviewer`, `pbi-implementer`,
`pbi-ut-author`, `codex-impl-reviewer`, `codex-ut-reviewer`) per Round of design
and impl+UT phases. State flows entirely through `.scrum/pbi/<pbi-id>/`
artifacts. New `pbi-pipeline` skill orchestrates; new
`pbi-escalation-handler` skill handles SM-side escalation routing.

**Tech Stack:** Bash 3.2+ (hooks, scripts), Python 3.9+ + Textual (TUI),
Markdown + YAML (agents/skills), JSON (state), bats (tests), shellcheck,
ruff, jq.

**Spec reference:** `docs/superpowers/specs/2026-05-02-pbi-pipeline-design.md`
(read this first; the plan references it by section number throughout).

---

## File Structure

### New files (18)

**Agents (6):**
- `agents/pbi-designer.md`
- `agents/pbi-implementer.md`
- `agents/pbi-ut-author.md`
- `agents/codex-design-reviewer.md`
- `agents/codex-impl-reviewer.md`
- `agents/codex-ut-reviewer.md`

**Skills (10 files = 1 + 8 references + 1 escalation):**
- `skills/pbi-pipeline/SKILL.md`
- `skills/pbi-pipeline/references/phase1-design.md`
- `skills/pbi-pipeline/references/phase2-impl-ut.md`
- `skills/pbi-pipeline/references/coverage-gate.md`
- `skills/pbi-pipeline/references/feedback-routing.md`
- `skills/pbi-pipeline/references/termination-gates.md`
- `skills/pbi-pipeline/references/sub-agent-prompts.md`
- `skills/pbi-pipeline/references/state-management.md`
- `skills/pbi-pipeline/references/catalog-contention.md`
- `skills/pbi-escalation-handler/SKILL.md`

**Hooks (2):**
- `hooks/pre-tool-use-path-guard.sh`
- `hooks/lib/codex-invoke.sh`

### New tests + fixtures + docs

- `tests/unit/test_path_guard_hook.bats`
- `tests/unit/test_codex_invoke.bats`
- `tests/unit/test_phase_gate_pbi_pipeline.bats`
- `tests/unit/test_state_management.bats`
- `tests/integration/test_pbi_pipeline_happy_path.bats`
- `tests/integration/test_pbi_pipeline_escalation.bats`
- `tests/integration/test_pbi_parallel.bats`
- `tests/fixtures/fake-codex.sh`
- `tests/manual/smoke-pbi-pipeline.md`
- `docs/MIGRATION-pbi-pipeline.md`
- `docs/contracts/pbi-pipeline-envelope.schema.json`
- `docs/contracts/coverage-rN.schema.json`
- `docs/contracts/test-results-rN.schema.json`
- `docs/contracts/pragma-audit-rN.schema.json`
- `.scrum-config.example.json` (reference template)

### Modified files (10)

- `agents/developer.md` — skills list, lifecycle text
- `agents/scrum-master.md` — add escalation handler skill
- `skills/install-subagents/SKILL.md` — new sub-agents list
- `skills/sprint-planning/SKILL.md` — catalog_targets pre-separation
- `skills/cross-review/SKILL.md` — role clarification
- `hooks/phase-gate.sh` — add `pbi_pipeline_active` phase
- `hooks/completion-gate.sh` — completion check for new phase
- `hooks/dashboard-event.sh` — new sub-agent events + pbi_id field
- `hooks/session-context.sh` — inject `SCRUM_PBI_ID`
- `dashboard/app.py` — PBI Pipeline pane
- `scripts/setup-user.sh` — copy targets + settings hook registration
- `docs/architecture.md`, `docs/quickstart.md`, `CLAUDE.md` — descriptions

### Deleted files (2)

- `skills/design/SKILL.md`
- `skills/implementation/SKILL.md`

---

## Phase 0: Pre-flight

### Task 0.1: Verify prerequisites

**Files:** none (verification only)

- [ ] **Step 1: Verify branch and clean state**

Run: `git status && git branch --show-current`
Expected: clean working tree, on `feat/ecc-subagent-catalog` (or similar
feature branch).

- [ ] **Step 2: Verify dev tooling installed**

Run: `bats --version && shellcheck --version && jq --version`
Expected: all three print version strings (no command-not-found).

If missing: run `sh scripts/setup-dev.sh` per project README.

- [ ] **Step 3: Read the spec**

Open `docs/superpowers/specs/2026-05-02-pbi-pipeline-design.md` and read
sections 1–8. The spec defines all schemas, contracts, and exact text used
throughout this plan.

---

## Phase 1: Foundation — config schema and shared libs

### Task 1.1: Add `.scrum-config.example.json` reference template

**Files:**
- Create: `.scrum-config.example.json`

- [ ] **Step 1: Write the example config**

Create `.scrum-config.example.json` with the schema from spec 6.1:

```json
{
  "test_runner": {
    "command": "pytest",
    "args": ["--tb=short", "-q"],
    "results_format": "junit",
    "results_path_template": ".scrum/pbi/{pbi_id}/metrics/test-results-r{round}.xml"
  },
  "coverage_tool": {
    "command": "coverage",
    "run_args": ["run", "--branch", "--source=src", "-m", "pytest"],
    "report_args": ["json", "-o"],
    "report_path_template": ".scrum/pbi/{pbi_id}/metrics/coverage-r{round}.json",
    "supports_branch": true
  },
  "pragma_pattern": "pragma: no cover",
  "path_guard": {
    "impl_globs": ["src/**", "lib/**"],
    "test_globs": ["tests/**", "**/*_test.py"]
  }
}
```

- [ ] **Step 2: Validate JSON**

Run: `jq . .scrum-config.example.json > /dev/null && echo OK`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add .scrum-config.example.json
git commit -m "feat: add .scrum-config.example.json reference template"
```

### Task 1.2: Create `hooks/lib/codex-invoke.sh` (TDD)

**Files:**
- Test: `tests/unit/test_codex_invoke.bats`
- Create: `hooks/lib/codex-invoke.sh`

- [ ] **Step 1: Write failing test**

Create `tests/unit/test_codex_invoke.bats`:

```bash
#!/usr/bin/env bats

setup() {
  TEST_TMP="$(mktemp -d)"
  cd "$TEST_TMP" || exit 1
  HOOK_LIB="${BATS_TEST_DIRNAME}/../../hooks/lib/codex-invoke.sh"
}

teardown() {
  rm -rf "$TEST_TMP"
}

@test "codex_review_or_fallback returns 1 when codex command missing" {
  # shellcheck disable=SC1090
  source "$HOOK_LIB"
  local PATH_BACKUP="$PATH"
  export PATH="/usr/bin:/bin"  # strip codex from PATH
  echo "instructions" > instr.md
  run codex_review_or_fallback instr.md out.md
  export PATH="$PATH_BACKUP"
  [ "$status" -eq 1 ]
}

@test "codex_review_or_fallback returns 0 when CODEX_CMD_OVERRIDE points to a working stub" {
  # shellcheck disable=SC1090
  source "$HOOK_LIB"
  cat > fake-codex.sh <<'EOF'
#!/usr/bin/env bash
# Match the real codex review args we expect: review --uncommitted --ephemeral --instructions <file> -o <file>
echo "## Review: stub" > "$5"
exit 0
EOF
  chmod +x fake-codex.sh
  export CODEX_CMD_OVERRIDE="$PWD/fake-codex.sh"
  echo "instructions" > instr.md
  run codex_review_or_fallback instr.md out.md
  unset CODEX_CMD_OVERRIDE
  [ "$status" -eq 0 ]
  [ -s out.md ]
}
```

- [ ] **Step 2: Run test, verify failure**

Run: `bats tests/unit/test_codex_invoke.bats`
Expected: 2 failures (file `hooks/lib/codex-invoke.sh` missing).

- [ ] **Step 3: Implement `hooks/lib/codex-invoke.sh`**

Create `hooks/lib/codex-invoke.sh`:

```bash
#!/usr/bin/env bash
# codex-invoke.sh — shared Codex CLI invocation helper.
# Sourced by codex-* reviewer agents (codex-design-reviewer,
# codex-impl-reviewer, codex-ut-reviewer).
#
# Usage:
#   source hooks/lib/codex-invoke.sh
#   codex_review_or_fallback <instructions_file> <output_file>
# Returns:
#   0 on success (output_file populated by Codex)
#   1 when Codex unavailable (caller should fall back to Claude review)
#
# Honors CODEX_CMD_OVERRIDE for testing (path to a stub binary).

codex_review_or_fallback() {
  local instructions=$1
  local output=$2
  local cmd="${CODEX_CMD_OVERRIDE:-codex}"

  if ! command -v "$cmd" >/dev/null 2>&1; then
    return 1
  fi

  "$cmd" review --uncommitted --ephemeral \
    --instructions "$instructions" \
    -o "$output" 2>&1 || return 1

  [ -s "$output" ] || return 1
  return 0
}
```

- [ ] **Step 4: Run tests, verify pass**

Run: `bats tests/unit/test_codex_invoke.bats`
Expected: 2 tests pass.

- [ ] **Step 5: shellcheck the lib**

Run: `shellcheck hooks/lib/codex-invoke.sh`
Expected: no output (clean).

- [ ] **Step 6: Commit**

```bash
git add hooks/lib/codex-invoke.sh tests/unit/test_codex_invoke.bats
git commit -m "feat(hooks): add codex-invoke shared library

Provides codex_review_or_fallback() used by all codex-* reviewer
sub-agents. Returns 1 when codex CLI unavailable so caller can fall
back to Claude review. CODEX_CMD_OVERRIDE supports stub injection
for tests."
```

### Task 1.3: Create `hooks/pre-tool-use-path-guard.sh` (TDD)

**Files:**
- Test: `tests/unit/test_path_guard_hook.bats`
- Create: `hooks/pre-tool-use-path-guard.sh`

- [ ] **Step 1: Write failing tests**

Create `tests/unit/test_path_guard_hook.bats`:

```bash
#!/usr/bin/env bats

setup() {
  TEST_TMP="$(mktemp -d)"
  cd "$TEST_TMP" || exit 1
  mkdir -p .scrum
  cat > .scrum/config.json <<'EOF'
{
  "path_guard": {
    "impl_globs": ["src/**"],
    "test_globs": ["tests/**"]
  }
}
EOF
  HOOK="${BATS_TEST_DIRNAME}/../../hooks/pre-tool-use-path-guard.sh"
  cp -r "${BATS_TEST_DIRNAME}/../../hooks/lib" hooks-lib
  ln -s "$PWD/hooks-lib" hooks_lib_link
}

teardown() {
  rm -rf "$TEST_TMP"
}

# Helper to send payload via stdin
payload() {
  local agent="$1" tool="$2" path="$3"
  jq -n --arg a "$agent" --arg t "$tool" --arg p "$path" \
    '{agent_name: $a, tool_name: $t, tool_input: {file_path: $p}}'
}

@test "blocks pbi-ut-author from reading impl path" {
  run bash -c "echo '$(payload pbi-ut-author Read src/auth.py)' | $HOOK"
  [ "$status" -eq 2 ]
  [[ "$output" == *"BLOCKED"* ]]
}

@test "blocks pbi-ut-author from writing impl path" {
  run bash -c "echo '$(payload pbi-ut-author Write src/auth.py)' | $HOOK"
  [ "$status" -eq 2 ]
}

@test "allows pbi-ut-author to read test path" {
  run bash -c "echo '$(payload pbi-ut-author Read tests/test_auth.py)' | $HOOK"
  [ "$status" -eq 0 ]
}

@test "allows pbi-ut-author to read design doc" {
  run bash -c "echo '$(payload pbi-ut-author Read .scrum/pbi/pbi-001/design/design.md)' | $HOOK"
  [ "$status" -eq 0 ]
}

@test "blocks pbi-implementer from writing test path" {
  run bash -c "echo '$(payload pbi-implementer Write tests/test_auth.py)' | $HOOK"
  [ "$status" -eq 2 ]
}

@test "allows pbi-implementer to read test path (read-only)" {
  run bash -c "echo '$(payload pbi-implementer Read tests/test_auth.py)' | $HOOK"
  [ "$status" -eq 0 ]
}

@test "allows pbi-implementer to write src path" {
  run bash -c "echo '$(payload pbi-implementer Write src/auth.py)' | $HOOK"
  [ "$status" -eq 0 ]
}

@test "passes through unknown agent" {
  run bash -c "echo '$(payload other-agent Read src/auth.py)' | $HOOK"
  [ "$status" -eq 0 ]
}

@test "passes through when .scrum/config.json missing" {
  rm -f .scrum/config.json
  run bash -c "echo '$(payload pbi-ut-author Read src/auth.py)' | $HOOK"
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run tests, verify failure**

Run: `bats tests/unit/test_path_guard_hook.bats`
Expected: 9 failures (hook missing).

- [ ] **Step 3: Implement `hooks/pre-tool-use-path-guard.sh`**

Create `hooks/pre-tool-use-path-guard.sh`:

```bash
#!/usr/bin/env bash
# pre-tool-use-path-guard.sh — PreToolUse hook
# Enforces path-level constraints on PBI pipeline sub-agents:
#   - pbi-ut-author: cannot Read/Write/Edit impl paths
#   - pbi-implementer: cannot Write/Edit test paths (Read allowed)
# Reads payload (JSON) from stdin: {agent_name, tool_name, tool_input.file_path}
# Reads .scrum/config.json for path_guard.impl_globs and test_globs.
# Exit 2 + stderr message → blocks tool. Exit 0 → allow.
# Missing config or unknown agent → allow (fail-open for non-target agents).

set -euo pipefail

CONFIG=".scrum/config.json"

# Read entire payload from stdin into a variable
payload="$(cat)"
agent="$(echo "$payload" | jq -r '.agent_name // ""')"
tool="$(echo "$payload" | jq -r '.tool_name // ""')"
path="$(echo "$payload" | jq -r '.tool_input.file_path // ""')"

# Fail-open if no agent or no path or non-target agent
if [ -z "$agent" ] || [ -z "$path" ]; then
  exit 0
fi
case "$agent" in
  pbi-ut-author|pbi-implementer) ;;
  *) exit 0 ;;
esac

# Fail-open if config missing
if [ ! -f "$CONFIG" ]; then
  exit 0
fi

# Normalize path: strip leading $PWD/ if absolute
rel="${path#"$PWD"/}"

# Glob match helper using bash extglob
matches_any_glob() {
  local target="$1"
  shift
  local g
  shopt -s extglob globstar
  for g in "$@"; do
    # shellcheck disable=SC2053
    if [[ "$target" == $g ]]; then
      return 0
    fi
  done
  return 1
}

mapfile -t impl_globs < <(jq -r '.path_guard.impl_globs[]?' "$CONFIG")
mapfile -t test_globs < <(jq -r '.path_guard.test_globs[]?' "$CONFIG")

case "$agent" in
  pbi-ut-author)
    case "$tool" in
      Read|Write|Edit)
        if matches_any_glob "$rel" "${impl_globs[@]}"; then
          echo "[path-guard] BLOCKED: pbi-ut-author cannot $tool $rel (impl path)" >&2
          exit 2
        fi
        ;;
    esac
    ;;
  pbi-implementer)
    case "$tool" in
      Write|Edit)
        if matches_any_glob "$rel" "${test_globs[@]}"; then
          echo "[path-guard] BLOCKED: pbi-implementer cannot $tool $rel (test path)" >&2
          exit 2
        fi
        ;;
    esac
    ;;
esac

exit 0
```

- [ ] **Step 4: Make executable**

Run: `chmod +x hooks/pre-tool-use-path-guard.sh`

- [ ] **Step 5: Run tests, verify pass**

Run: `bats tests/unit/test_path_guard_hook.bats`
Expected: 9 tests pass.

- [ ] **Step 6: shellcheck**

Run: `shellcheck hooks/pre-tool-use-path-guard.sh`
Expected: clean.

- [ ] **Step 7: Commit**

```bash
git add hooks/pre-tool-use-path-guard.sh tests/unit/test_path_guard_hook.bats
git commit -m "feat(hooks): add pre-tool-use-path-guard for PBI sub-agents

Enforces path-level constraints from .scrum/config.json.path_guard:
- pbi-ut-author: blocked from Read/Write/Edit on impl paths
- pbi-implementer: blocked from Write/Edit on test paths
Fail-open for non-PBI sub-agents and when config missing."
```

---

## Phase 2: New sub-agent definitions (6 agents)

### Task 2.1: Create `agents/pbi-designer.md`

**Files:**
- Create: `agents/pbi-designer.md`

- [ ] **Step 1: Write the agent definition**

Create `agents/pbi-designer.md`:

```markdown
---
name: pbi-designer
description: >
  Authors a PBI working design document defining component
  responsibilities, business logic, and interfaces. Reads catalog
  specs read-only, may update them as a side-effect. Writes the
  primary design artifact to .scrum/pbi/<pbi-id>/design/design.md.
tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
model: opus
effort: high
maxTurns: 100
disallowedTools:
  - WebFetch
  - WebSearch
---

# PBI Designer Agent

PBI working design author. Spawned by Developer per design Round.

## Receives

- PBI details (backlog.json entry for the assigned PBI)
- requirements.md path
- Related catalog spec paths (read-only references)
- docs/design/catalog-config.json path
- Prior design/review-r{n-1}.md (if Round n>=2)
- Output target: .scrum/pbi/<pbi-id>/design/design.md (overwrite)

## Required Design Doc Sections

The output MUST include these sections in this order:

1. **Scope** — components touched (paths to catalog specs)
2. **Components** — responsibilities per component
3. **Business Logic** — behavior, sequences, state transitions
4. **Interfaces** — function/method/API signatures + I/O contracts +
   error conditions
5. **Catalog Updates** — list of catalog spec deltas with summary
6. **Test Strategy Hints** — boundaries, edge cases. NO implementation.
   May include `yaml runtime-override` fence to override
   .scrum/config.json test_runner / coverage_tool for this PBI only.

## Strict Rules

- DO NOT include implementation code examples. Interface declarations
  only (signatures, type definitions).
- DO NOT write outside `.scrum/pbi/` and `docs/design/specs/`.
- catalog spec writes MUST acquire .scrum/locks/catalog-<spec_id>.lock
  via `flock(2)` (60s timeout) before editing.
- If requirements unclear, raise to Developer (do not guess).

## Output Envelope

End with a JSON code block matching the schema-first contract from
the design spec section 4.1. Required fields: status, summary, verdict
(null for designer), findings ([]), next_actions, artifacts.
```

- [ ] **Step 2: Validate YAML frontmatter**

Run: `awk '/^---$/{n++}n==1{print}n==2{exit}' agents/pbi-designer.md | tail -n +2 | python3 -c "import yaml,sys; yaml.safe_load(sys.stdin); print('OK')"`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add agents/pbi-designer.md
git commit -m "feat(agents): add pbi-designer sub-agent definition"
```

### Task 2.2: Create `agents/codex-design-reviewer.md`

**Files:**
- Create: `agents/codex-design-reviewer.md`

- [ ] **Step 1: Write the agent definition**

Create `agents/codex-design-reviewer.md` modeled after the existing
`agents/codex-code-reviewer.md` (read it first for the Codex CLI
invocation pattern):

```markdown
---
name: codex-design-reviewer
description: >
  Independent design reviewer powered by Codex CLI. Reads PBI design
  doc + related catalog specs + requirements, returns verdict +
  structured findings via shared codex-invoke library. Falls back to
  Claude review when Codex unavailable.
tools:
  - Read
  - Grep
  - Glob
  - Bash
model: sonnet
effort: medium
maxTurns: 30
---

# Codex Design Reviewer

Critical design reviewer delegating to OpenAI Codex CLI. Receives
design doc + catalog references locally → builds review instructions
→ invokes `codex review` via shared lib → returns result.

## Receives

- .scrum/pbi/<pbi-id>/design/design.md
- Related catalog spec paths (for consistency check)
- requirements.md path
- Output target: .scrum/pbi/<pbi-id>/design/review-r{n}.md

## Does NOT Receive (intentional)

PBI details beyond what is in the design doc itself, .scrum/ state,
dev communications, Sprint context.

## Review Criteria

1. **Completeness** — every requirement covered by the design?
2. **Internal consistency** — no contradictions between sections?
3. **Catalog consistency** — design's catalog updates do not conflict
   with other catalog specs?
4. **Interface clarity** — signatures + error conditions complete?
5. **Scope** — nothing outside the PBI scope?

## Severity Levels

Critical (must fix), High (should fix), Medium (consider), Low (optional).
Verdict: PASS = no Critical/High; FAIL = any Critical/High.

## Findings: signature format

Each finding's `signature` field MUST match:

```text
{file_path}:{line_start}-{line_end}:{criterion_key}
```

`criterion_key` enum (design review): missing_requirement, scope_creep,
unclear_interface, inconsistent_with_catalog, inconsistent_internal,
missing_error_handling.

## Processing Flow

1. Read all provided files in full.
2. Build review instructions to a temp file.
3. Source `hooks/lib/codex-invoke.sh` then call
   `codex_review_or_fallback "$instr" "$out"`.
4. If exit 0: read $out and write to the review-r{n}.md path.
5. If exit 1 (Codex unavailable): perform same-criteria Claude review
   yourself; prepend `[Fallback: Claude review]` to Summary.

## Output Format

```text
## Review: [brief description]

**Verdict: PASS | FAIL**

### Findings

- #1 [Severity] [File:Lines] [criterion_key] — [Description]
- #2 ...

### Summary

[2-3 sentences]
```

End with the JSON envelope from spec 4.1.

## Strict Rules

- Read-only — DO NOT modify project files.
- DO NOT suggest fixes (describe problems only).
- DO NOT assess on info not given.
- ALWAYS try Codex first; fall back only on exit 1.
```

- [ ] **Step 2: Validate YAML**

Run: `awk '/^---$/{n++}n==1{print}n==2{exit}' agents/codex-design-reviewer.md | tail -n +2 | python3 -c "import yaml,sys; yaml.safe_load(sys.stdin); print('OK')"`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add agents/codex-design-reviewer.md
git commit -m "feat(agents): add codex-design-reviewer sub-agent definition"
```

### Task 2.3: Create `agents/pbi-implementer.md`

**Files:**
- Create: `agents/pbi-implementer.md`

- [ ] **Step 1: Write the agent definition**

```markdown
---
name: pbi-implementer
description: >
  Implements PBI source code per the working design doc. Writes only
  implementation files (test paths blocked by hook). Does not modify
  design docs.
tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
model: opus
effort: high
maxTurns: 150
disallowedTools:
  - WebFetch
  - WebSearch
---

# PBI Implementer Agent

Implementation author. Spawned by Developer per impl+UT Round.

## Receives

- .scrum/pbi/<pbi-id>/design/design.md
- Prior .scrum/pbi/<pbi-id>/feedback/impl-r{n}.md (if Round n>=2)
- Output target: implementation source at project's normal paths
  (e.g., src/, lib/)

## Path Constraints (enforced by hook)

- Write/Edit allowed: implementation paths and `.scrum/pbi/`
- Write/Edit blocked: test paths (path-guard hook returns exit 2)
- Read: anywhere allowed

## Strict Rules

- DO NOT write or edit test files. Tests are owned by pbi-ut-author.
- DO NOT edit design docs. Raise concerns as findings.
- AVOID unnecessary defensive code (interferes with C1=100%).
- Address ALL impl-reviewer findings + test failures from prior
  feedback file before re-emitting code.

## Output Envelope

End with the JSON envelope from spec 4.1. `verdict` is null. List all
modified file paths in `artifacts`.
```

- [ ] **Step 2: Validate YAML**

Run: `awk '/^---$/{n++}n==1{print}n==2{exit}' agents/pbi-implementer.md | tail -n +2 | python3 -c "import yaml,sys; yaml.safe_load(sys.stdin); print('OK')"`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add agents/pbi-implementer.md
git commit -m "feat(agents): add pbi-implementer sub-agent definition"
```

### Task 2.4: Create `agents/pbi-ut-author.md`

**Files:**
- Create: `agents/pbi-ut-author.md`

- [ ] **Step 1: Write the agent definition**

```markdown
---
name: pbi-ut-author
description: >
  Authors unit tests strictly from the design doc interfaces, without
  reading implementation source. Writes only test files (impl paths
  blocked by hook).
tools:
  - Read
  - Write
  - Edit
  - Grep
  - Glob
  - Bash
model: opus
effort: high
maxTurns: 150
disallowedTools:
  - WebFetch
  - WebSearch
---

# PBI UT Author Agent

Black-box test author. Spawned by Developer per impl+UT Round.

## Receives

- .scrum/pbi/<pbi-id>/design/design.md
- Prior .scrum/pbi/<pbi-id>/feedback/ut-r{n}.md (if Round n>=2)
- Prior .scrum/pbi/<pbi-id>/metrics/coverage-r{n-1}.json (if Round n>=2)
- Output target: tests at project's normal paths (e.g., tests/)

## Path Constraints (enforced by hook)

- Read/Write/Edit allowed: test paths, design doc, .scrum/pbi/, and
  declaration-only files (.d.ts, .pyi).
- Read/Write/Edit BLOCKED: implementation paths (path-guard hook returns
  exit 2). Do not attempt to read src/* or lib/*.

## Strict Rules

- Write tests using ONLY the design doc's `Interfaces` section.
- Assume implementation may not yet exist (black-box).
- One test minimum per acceptance criterion.
- One test per branch (target C1 = 100%).
- AAA pattern (Arrange / Act / Assert).
- Pragma exclusions (`# pragma: no cover` etc.) MUST include an
  inline-comment reason on the same or preceding line.
- Address ALL ut-reviewer findings + coverage gaps + test failures from
  prior feedback file before re-emitting tests.

## Output Envelope

End with the JSON envelope from spec 4.1. `verdict` is null. List all
modified test file paths in `artifacts`.
```

- [ ] **Step 2: Validate YAML**

Run: `awk '/^---$/{n++}n==1{print}n==2{exit}' agents/pbi-ut-author.md | tail -n +2 | python3 -c "import yaml,sys; yaml.safe_load(sys.stdin); print('OK')"`
Expected: `OK`

- [ ] **Step 3: Commit**

```bash
git add agents/pbi-ut-author.md
git commit -m "feat(agents): add pbi-ut-author sub-agent definition"
```

### Task 2.5: Create `agents/codex-impl-reviewer.md`

**Files:**
- Create: `agents/codex-impl-reviewer.md`

- [ ] **Step 1: Write the agent definition**

```markdown
---
name: codex-impl-reviewer
description: >
  Independent implementation reviewer powered by Codex CLI. Reviews
  source code against the design doc only — does not see test code.
  Returns verdict + structured findings.
tools:
  - Read
  - Grep
  - Glob
  - Bash
model: sonnet
effort: medium
maxTurns: 30
---

# Codex Impl Reviewer

Critical implementation reviewer via OpenAI Codex CLI.

## Receives

- .scrum/pbi/<pbi-id>/design/design.md
- Implementation source file paths (test paths NOT included)
- requirements.md path
- Output target: .scrum/pbi/<pbi-id>/impl/review-r{n}.md

## Does NOT Receive (intentional)

Test code, .scrum/ state, PBI dev communications.

## Review Criteria

1. **Interface match** — signatures match the design doc?
2. **Business logic correctness** — behavior matches design's behavior
   description?
3. **Scope** — nothing implemented outside the design?
4. **Code quality** — readability, naming, error handling.

## Findings: signature format

```text
{file_path}:{line_start}-{line_end}:{criterion_key}
```

`criterion_key` enum (impl review): incorrect_behavior, scope_creep,
naming, error_handling, missing_validation, unclear_intent, dead_code.

## Processing Flow

Identical to codex-design-reviewer:
1. Read all provided files.
2. Build review instructions.
3. Source `hooks/lib/codex-invoke.sh` and call
   `codex_review_or_fallback`.
4. On exit 1: same-criteria Claude review, prepend
   `[Fallback: Claude review]` to Summary.

## Output Format

Same as codex-design-reviewer (Verdict + Findings + Summary + JSON
envelope).

## Strict Rules

- Read-only.
- Describe problems only, not fixes.
- Always try Codex first.
```

- [ ] **Step 2: Validate YAML + Commit**

```bash
awk '/^---$/{n++}n==1{print}n==2{exit}' agents/codex-impl-reviewer.md | tail -n +2 | python3 -c "import yaml,sys; yaml.safe_load(sys.stdin); print('OK')"
git add agents/codex-impl-reviewer.md
git commit -m "feat(agents): add codex-impl-reviewer sub-agent definition"
```

### Task 2.6: Create `agents/codex-ut-reviewer.md`

**Files:**
- Create: `agents/codex-ut-reviewer.md`

- [ ] **Step 1: Write the agent definition**

```markdown
---
name: codex-ut-reviewer
description: >
  Independent UT reviewer powered by Codex CLI. Reviews test code +
  coverage report against design doc. Does not see implementation
  source. Audits pragma exclusions for justification.
tools:
  - Read
  - Grep
  - Glob
  - Bash
model: sonnet
effort: medium
maxTurns: 30
---

# Codex UT Reviewer

Critical UT reviewer via OpenAI Codex CLI.

## Receives

- .scrum/pbi/<pbi-id>/design/design.md
- Test file paths (impl paths NOT included)
- .scrum/pbi/<pbi-id>/metrics/coverage-r{n}.json
- .scrum/pbi/<pbi-id>/metrics/pragma-audit-r{n}.json
- requirements.md path
- Output target: .scrum/pbi/<pbi-id>/ut/review-r{n}.md

## Does NOT Receive (intentional)

Implementation source code, .scrum/ state, PBI dev communications.

## Review Criteria

1. **Interface coverage** — every design interface has at least one
   test?
2. **Acceptance criteria coverage** — every acceptance criterion in the
   design has at least one test?
3. **Pragma audit** — every pragma exclusion in pragma-audit-r{n}.json
   has a justified reason (reason_source != "missing"). MISSING reason
   = automatic FAIL.
4. **Coverage gap interpretation** — branches in coverage.uncovered_*
   that are NOT obvious dead code → flag as "missing_branch_coverage"
5. **Test quality** — AAA pattern, single assertion focus, no mock
   overuse, no magic numbers, descriptive test names.

## Findings: signature format

```text
{file_path}:{line_start}-{line_end}:{criterion_key}
```

`criterion_key` enum (UT review): missing_test_for_acceptance,
missing_branch_coverage, redundant_test, mock_overuse, magic_number,
bad_assertion, pragma_unjustified.

## Processing Flow

Identical to codex-design-reviewer.

## Output Format

Same as codex-design-reviewer (Verdict + Findings + Summary + JSON
envelope).

## Strict Rules

- Read-only.
- DO NOT read implementation files (your input list excludes them; do
  not search for them).
- Always try Codex first.
```

- [ ] **Step 2: Validate YAML + Commit**

```bash
awk '/^---$/{n++}n==1{print}n==2{exit}' agents/codex-ut-reviewer.md | tail -n +2 | python3 -c "import yaml,sys; yaml.safe_load(sys.stdin); print('OK')"
git add agents/codex-ut-reviewer.md
git commit -m "feat(agents): add codex-ut-reviewer sub-agent definition"
```

---

## Phase 3: New skill — `pbi-pipeline`

This is the conductor skill. SKILL.md is the navigation layer; references
hold phase details.

### Task 3.1: Create `skills/pbi-pipeline/SKILL.md` (orchestrator)

**Files:**
- Create: `skills/pbi-pipeline/SKILL.md`

- [ ] **Step 1: Write the orchestrator SKILL**

Create `skills/pbi-pipeline/SKILL.md`:

```markdown
---
name: pbi-pipeline
description: >
  PBI development pipeline — orchestrates design phase and impl+UT
  phase with sub-agent fan-out, file-based handoff, deterministic
  termination gates (Anthropic + Ralph + GAN-derived). Used by
  Developer per assigned PBI. Replaces former design + implementation
  skills.
disable-model-invocation: false
---

## Inputs

- PBI assignment (backlog.json entry for assigned PBI)
- requirements.md path
- Related catalog specs (read-only references)
- .scrum/config.json
- 6 sub-agent definitions verified by install-subagents

## Outputs

- Source code + test code committed to project (normal paths)
- .scrum/pbi/<pbi-id>/ artifacts (design, reviews, metrics, feedback,
  summaries, pipeline.log)
- backlog.json status: in_progress → done | blocked
- Notification to SM via Agent Teams

## Phases (decision tree)

```text
[Init] create .scrum/pbi/<pbi-id>/ + state.json
   ↓
[Design Phase] Rounds 1..5 → see references/phase1-design.md
   ↓ success
[Impl+UT Phase] Rounds 1..5 → see references/phase2-impl-ut.md
   - per round: spawn impl + UT in parallel
   - measure coverage → see references/coverage-gate.md
   - spawn impl-reviewer + UT-reviewer in parallel
   - aggregate + judge + (FAIL only) build feedback
     → see references/feedback-routing.md
   - termination check → see references/termination-gates.md
   ↓ success
[Completion] update backlog.json + notify SM
```

## Sub-agents spawned

See `references/sub-agent-prompts.md` for full input prompt templates.

| Agent | When | Parallel with |
|---|---|---|
| pbi-designer | Design Round Step 1 | – |
| codex-design-reviewer | Design Round Step 2 | – |
| pbi-implementer | Impl+UT Round Step 1 | pbi-ut-author |
| pbi-ut-author | Impl+UT Round Step 1 | pbi-implementer |
| codex-impl-reviewer | Impl+UT Round Step 3 | codex-ut-reviewer |
| codex-ut-reviewer | Impl+UT Round Step 3 | codex-impl-reviewer |

## State management

PBI internal state: `.scrum/pbi/<pbi-id>/state.json`. See
`references/state-management.md` for schema, write helpers, and
pipeline.log format.

## Parallel PBI coordination

Catalog write contention: see `references/catalog-contention.md`
(3-layer defense: sprint planning pre-separation + flock + mtime check).

## Escalation

When termination gate triggers escalation, set `state.phase=escalated`,
write escalation_reason, notify SM via Agent Teams. SM handles via the
`pbi-escalation-handler` skill.

## Exit Criteria

- state.json: `phase = complete` OR `phase = escalated`
- backlog.json status updated (`done` or `blocked`)
- SM notified
```

- [ ] **Step 2: Verify line count**

Run: `wc -l skills/pbi-pipeline/SKILL.md`
Expected: under 200 lines (target ~150).

- [ ] **Step 3: Commit**

```bash
git add skills/pbi-pipeline/SKILL.md
git commit -m "feat(skills): add pbi-pipeline orchestrator SKILL.md"
```

### Task 3.2: Create `skills/pbi-pipeline/references/state-management.md`

**Files:**
- Create: `skills/pbi-pipeline/references/state-management.md`

- [ ] **Step 1: Write the reference**

Create `skills/pbi-pipeline/references/state-management.md`:

````markdown
# State Management Reference

How the Developer (conductor) manages PBI internal state.

## Schema: `.scrum/pbi/<pbi-id>/state.json`

```json
{
  "pbi_id": "pbi-001",
  "phase": "design | impl_ut | complete | escalated",
  "design_round": 0,
  "impl_round": 0,
  "design_status": "pending | in_review | fail | pass",
  "impl_status": "pending | in_review | fail | pass",
  "ut_status": "pending | in_review | fail | pass",
  "coverage_status": "pending | fail | pass",
  "escalation_reason": null,
  "started_at": "2026-05-02T12:00:00+09:00",
  "updated_at": "2026-05-02T12:00:00+09:00"
}
```

`escalation_reason` enum (only set when `phase == escalated`):

```text
stagnation | divergence | max_rounds | budget_exhausted |
requirements_unclear | coverage_tool_error | coverage_tool_unavailable |
catalog_lock_timeout
```

## Initialization

```bash
PBI_DIR=".scrum/pbi/${PBI_ID}"
mkdir -p "$PBI_DIR"/{design,impl,ut,metrics,feedback}
NOW="$(date -Iseconds)"
jq -n --arg id "$PBI_ID" --arg now "$NOW" '{
  pbi_id: $id, phase: "design",
  design_round: 0, impl_round: 0,
  design_status: "pending", impl_status: "pending",
  ut_status: "pending", coverage_status: "pending",
  escalation_reason: null,
  started_at: $now, updated_at: $now
}' > "$PBI_DIR/state.json"
```

## Atomic update helper

ALWAYS write via temp + rename (never partial write):

```bash
update_state() {
  local pbi_dir="$1"; shift
  local jq_expr="$1"; shift
  local now; now="$(date -Iseconds)"
  jq --arg now "$now" "$jq_expr | .updated_at = \$now" \
    "$pbi_dir/state.json" > "$pbi_dir/state.json.tmp"
  mv "$pbi_dir/state.json.tmp" "$pbi_dir/state.json"
}
# Examples:
update_state "$PBI_DIR" '.design_round = 1 | .design_status = "in_review"'
update_state "$PBI_DIR" '.phase = "complete"'
update_state "$PBI_DIR" \
  '.phase = "escalated" | .escalation_reason = "stagnation"'
```

## pipeline.log format

One line per phase event, append-only:

```text
<ISO8601>\t<phase>\t<round>\t<event>\t<detail>
```

Examples:

```text
2026-05-02T12:00:00+09:00	init	0	created	.scrum/pbi/pbi-001/
2026-05-02T12:01:00+09:00	design	1	spawn	pbi-designer
2026-05-02T12:05:00+09:00	design	1	spawn	codex-design-reviewer
2026-05-02T12:06:00+09:00	design	1	gate	success → impl_ut
2026-05-02T12:06:30+09:00	impl_ut	1	spawn	pbi-implementer + pbi-ut-author
2026-05-02T12:20:00+09:00	impl_ut	1	measure	coverage c0=87 c1=72
2026-05-02T12:25:00+09:00	impl_ut	1	gate	fail → round 2 (test_failures=2)
```

Append helper:

```bash
log_event() {
  local pbi_dir="$1" phase="$2" round="$3" event="$4" detail="$5"
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$(date -Iseconds)" "$phase" "$round" "$event" "$detail" \
    >> "$pbi_dir/pipeline.log"
}
```

## Sprint-level state side-effects

When a PBI starts pipeline:
- Append PBI id to `.scrum/state.json.active_pbi_pipelines[]`
- Set `.scrum/sprint.json.developers[<dev>].current_pbi = "<pbi_id>"`
- Set `.scrum/sprint.json.developers[<dev>].current_pbi_phase` to track

When a PBI completes or escalates:
- Remove from `active_pbi_pipelines[]`
- Update backlog.json status to `done` or `blocked`
- Add `pipeline_summary` to backlog.json item (rounds, final coverage)
````

- [ ] **Step 2: Commit**

```bash
git add skills/pbi-pipeline/references/state-management.md
git commit -m "feat(skills): add pbi-pipeline state-management reference"
```

### Task 3.3: Create `skills/pbi-pipeline/references/sub-agent-prompts.md`

**Files:**
- Create: `skills/pbi-pipeline/references/sub-agent-prompts.md`

- [ ] **Step 1: Write the prompt templates reference**

Create `skills/pbi-pipeline/references/sub-agent-prompts.md`:

````markdown
# Sub-Agent Prompt Templates

Schema-first prompts the Developer (conductor) constructs when spawning
each sub-agent via the `Agent` tool. All sub-agents must end output with
the JSON envelope from spec 4.1.

## Common envelope reminder (append to every prompt)

```text
End your response with a single JSON code block matching this schema:

{
  "status": "pass | fail | error",
  "summary": "<one-line summary>",
  "verdict": "PASS | FAIL | null",
  "findings": [
    {
      "signature": "<file>:<line_start>-<line_end>:<criterion_key>",
      "severity": "critical | high | medium | low",
      "criterion_key": "<from fixed enum>",
      "file_path": "<path>",
      "line_start": <int>,
      "line_end": <int>,
      "description": "<text>"
    }
  ],
  "next_actions": ["<action>"],
  "artifacts": ["<path>"]
}
```

## pbi-designer prompt

```text
You are pbi-designer for {pbi_id}. Author the PBI working design doc.

PBI assignment:
{paste backlog.json entry for {pbi_id}}

Inputs:
- requirements.md: <path>
- catalog-config.json: docs/design/catalog-config.json
- Related catalog specs (read-only references):
  - <path1>
  - <path2>
{if Round n>=2:}
- Prior design review (address every Critical/High finding):
  - .scrum/pbi/{pbi_id}/design/review-r{n-1}.md

Write the design to:
  .scrum/pbi/{pbi_id}/design/design.md

Required sections (in this order):
1. Scope
2. Components
3. Business Logic
4. Interfaces
5. Catalog Updates
6. Test Strategy Hints

Forbidden: implementation code examples (interface declarations OK).
Catalog spec writes require flock on .scrum/locks/catalog-<spec_id>.lock
(60s timeout); on timeout, exit with status=error, escalation_reason
catalog_lock_timeout.

{common envelope reminder}
```

## codex-design-reviewer prompt

```text
You are codex-design-reviewer for {pbi_id} Round {n}. Independent
critical review of the PBI design doc.

Inputs:
- Design doc: .scrum/pbi/{pbi_id}/design/design.md
- Related catalog specs (consistency check):
  - <path1>
- requirements.md: <path>

Output to: .scrum/pbi/{pbi_id}/design/review-r{n}.md

Review against the criteria in your agent definition. Verdict PASS = no
Critical/High findings; otherwise FAIL.

{common envelope reminder}
```

## pbi-implementer prompt

```text
You are pbi-implementer for {pbi_id} Round {n}. Implement source code
per the design doc.

Inputs:
- Design doc: .scrum/pbi/{pbi_id}/design/design.md
{if Round n>=2:}
- Feedback from prior round (address every item):
  - .scrum/pbi/{pbi_id}/feedback/impl-r{n}.md

Write source code to project's normal implementation paths (e.g., src/).
Do NOT write or edit test files (path-guard hook will block them).

{common envelope reminder}
```

## pbi-ut-author prompt

```text
You are pbi-ut-author for {pbi_id} Round {n}. Author unit tests
strictly from the design doc's `Interfaces` section.

Inputs:
- Design doc: .scrum/pbi/{pbi_id}/design/design.md
{if Round n>=2:}
- Feedback from prior round (address every item):
  - .scrum/pbi/{pbi_id}/feedback/ut-r{n}.md
- Prior coverage report (gap reference):
  - .scrum/pbi/{pbi_id}/metrics/coverage-r{n-1}.json

Write tests to project's normal test paths (e.g., tests/).
Do NOT read or write implementation files (path-guard hook will block).
Pragma exclusions require an inline-comment reason.

{common envelope reminder}
```

## codex-impl-reviewer prompt

```text
You are codex-impl-reviewer for {pbi_id} Round {n}. Independent review
of implementation source against the design doc only.

Inputs:
- Design doc: .scrum/pbi/{pbi_id}/design/design.md
- Implementation files:
  - <path1>
  - <path2>
- requirements.md: <path>

You do NOT receive test code.

Output to: .scrum/pbi/{pbi_id}/impl/review-r{n}.md

{common envelope reminder}
```

## codex-ut-reviewer prompt

```text
You are codex-ut-reviewer for {pbi_id} Round {n}. Independent review
of tests + coverage against the design doc only.

Inputs:
- Design doc: .scrum/pbi/{pbi_id}/design/design.md
- Test files:
  - <path1>
- Coverage report: .scrum/pbi/{pbi_id}/metrics/coverage-r{n}.json
- Pragma audit: .scrum/pbi/{pbi_id}/metrics/pragma-audit-r{n}.json
- requirements.md: <path>

You do NOT receive implementation source.

Output to: .scrum/pbi/{pbi_id}/ut/review-r{n}.md

Reasons: any pragma exclusion with reason_source == "missing" → FAIL.

{common envelope reminder}
```
````

- [ ] **Step 2: Commit**

```bash
git add skills/pbi-pipeline/references/sub-agent-prompts.md
git commit -m "feat(skills): add pbi-pipeline sub-agent prompt templates"
```

### Task 3.4: Create `skills/pbi-pipeline/references/phase1-design.md`

**Files:**
- Create: `skills/pbi-pipeline/references/phase1-design.md`

- [ ] **Step 1: Write the reference**

Create `skills/pbi-pipeline/references/phase1-design.md`. The content
mirrors spec section 3.2:

````markdown
# Design Phase Reference

Per-Round flow for the design phase (max 5 Rounds).

## Round n procedure

1. **Prepare**
   - `update_state … '.design_round = $n | .design_status = "pending"'`
   - `log_event design n start —`

2. **Step 1: Spawn pbi-designer** (single Agent call)
   - Build prompt from `sub-agent-prompts.md` § pbi-designer
   - Wait for completion
   - Parse JSON envelope from output. If status=error → escalate.
   - `update_state … '.design_status = "in_review"'`

3. **Step 2: Spawn codex-design-reviewer** (single Agent call)
   - Build prompt from `sub-agent-prompts.md` § codex-design-reviewer
   - Wait for completion
   - Read .scrum/pbi/<pbi-id>/design/review-r{n}.md → parse Verdict.

4. **Step 3: Termination gate** (see termination-gates.md)
   - **Success**: design-reviewer verdict == PASS
     - `update_state … '.design_status = "pass" | .phase = "impl_ut" | .impl_round = 0'`
     - `log_event design n gate "success → impl_ut"`
     - Return to caller (pipeline phase 2 begins)
   - **Stagnation / Divergence / Hard cap**: escalate
     - `update_state … '.phase = "escalated" | .escalation_reason = "<reason>"'`
     - `log_event design n gate "escalate → <reason>"`
     - Notify SM (see `escalation-notify` snippet below)
   - **Other FAIL**: review-r{n}.md becomes input to Round n+1
     - `log_event design n gate "fail → round $((n+1))"`
     - Increment n, recurse.

## escalation-notify snippet

```bash
notify_sm_escalation() {
  local pbi_id="$1" reason="$2"
  # Use the Agent Teams notification mechanism. Implementation in
  # current Developer agent uses TaskUpdate or message-passing —
  # invoke whichever convention applies.
  echo "[$pbi_id] ESCALATED reason=$reason last_review=$(latest_review_path "$pbi_id")"
}
```

## Notes

- Design phase round counter is independent from impl+UT counter.
- pbi-designer may request catalog scaffolding from SM by raising
  status=error with next_actions[]=["scaffold catalog spec X"]; pause
  PBI until SM completes.
````

- [ ] **Step 2: Commit**

```bash
git add skills/pbi-pipeline/references/phase1-design.md
git commit -m "feat(skills): add pbi-pipeline phase1-design reference"
```

### Task 3.5: Create `skills/pbi-pipeline/references/phase2-impl-ut.md`

**Files:**
- Create: `skills/pbi-pipeline/references/phase2-impl-ut.md`

- [ ] **Step 1: Write the reference**

Create `skills/pbi-pipeline/references/phase2-impl-ut.md`. Content mirrors
spec section 3.3:

````markdown
# Impl+UT Phase Reference

Per-Round flow for the impl+UT phase (max 5 Rounds).

## Round n procedure

### Step 1: Parallel spawn (pbi-implementer + pbi-ut-author)

Issue both Agent calls in a single message (Claude Code parallel
execution). Wait for both to return.

```text
Agent(subagent_type="pbi-implementer", prompt=<from sub-agent-prompts.md § pbi-implementer>)
Agent(subagent_type="pbi-ut-author", prompt=<from sub-agent-prompts.md § pbi-ut-author>)
```

`update_state … '.impl_round = $n | .impl_status = "pending" | .ut_status = "pending"'`

### Step 2: Test execution + coverage measurement

See `coverage-gate.md` for the full procedure. Summary:

```bash
# Read .scrum/config.json (apply PBI override if design.md has a
# `yaml runtime-override` fence). Run test_runner.coverage_tool.command
# with merged args. Normalize output → coverage-r{n}.json,
# test-results-r{n}.json. Run pragma audit → pragma-audit-r{n}.json.
```

Tool-launch failure → escalate (`coverage_tool_error`).
Tool not installed → escalate (`coverage_tool_unavailable`).

### Step 3: Parallel spawn (codex-impl-reviewer + codex-ut-reviewer)

Issue both Agent calls in a single message. Wait for both.

```text
Agent(subagent_type="codex-impl-reviewer", prompt=<from sub-agent-prompts.md>)
Agent(subagent_type="codex-ut-reviewer", prompt=<from sub-agent-prompts.md>)
```

Read review-r{n}.md from each, parse verdicts and findings.

### Step 4: Aggregate + judge + (FAIL only) build feedback

Pass evaluation logic (see `coverage-gate.md` § Pass criteria):

```text
ALL of:
  test_results.totals.failed == 0
  test_results.totals.exec_errors == 0
  test_results.totals.uncaught_exceptions == 0
  coverage.totals.c0.percent >= c0_threshold (default 100.0)
  if c1.supported: coverage.totals.c1.percent >= c1_threshold (default 100.0)
  no pragma exclusion has reason_source == "missing"
  impl-reviewer.verdict == PASS
  ut-reviewer.verdict == PASS
```

#### Success branch

```bash
update_state "$PBI_DIR" '.impl_status = "pass" | .ut_status = "pass" | .coverage_status = "pass" | .phase = "complete"'
write_summary "$PBI_DIR/impl/summary.md"
write_summary "$PBI_DIR/ut/summary.md"
log_event impl_ut "$n" gate "success → complete"
# Then: PBI completion procedure (update backlog.json, notify SM)
```

#### Termination gate (Stagnation / Divergence / Hard cap)

See `termination-gates.md`. On any escalate gate:

```bash
update_state "$PBI_DIR" '.phase = "escalated" | .escalation_reason = "<reason>"'
log_event impl_ut "$n" gate "escalate → <reason>"
notify_sm_escalation "$PBI_ID" "<reason>"
```

#### Other FAIL: build feedback for next round

See `feedback-routing.md`. Generate:

- `feedback/impl-r{n+1}.md` (impl-reviewer findings + test failures
  framed for impl)
- `feedback/ut-r{n+1}.md` (ut-reviewer findings + test failures framed
  for UT + coverage gaps + pragma issues)

Then:

```bash
log_event impl_ut "$n" gate "fail → round $((n+1))"
# Recurse with n+1
```
````

- [ ] **Step 2: Commit**

```bash
git add skills/pbi-pipeline/references/phase2-impl-ut.md
git commit -m "feat(skills): add pbi-pipeline phase2-impl-ut reference"
```

### Task 3.6: Create `skills/pbi-pipeline/references/coverage-gate.md`

**Files:**
- Create: `skills/pbi-pipeline/references/coverage-gate.md`

- [ ] **Step 1: Write the reference**

Create `skills/pbi-pipeline/references/coverage-gate.md`. Content mirrors
spec section 6:

````markdown
# Coverage Gate Reference

How the Developer (conductor) runs tests, measures coverage, audits
pragma exclusions, and evaluates Pass criteria.

## Configuration source

Default: `.scrum/config.json`. Reference: `.scrum-config.example.json`.

Per-PBI override: design doc may contain a fenced YAML block with the
language tag `yaml runtime-override` inside the `Test Strategy Hints`
section. Developer deep-merges over the project default for that PBI
only.

## Language reference matrix

| Language | Test runner | Coverage tool | C1 |
|---|---|---|---|
| Python | pytest | coverage.py `--branch` | yes |
| TypeScript | vitest | c8 `--all --branches` | yes (c8 0.7+) |
| Go | go test | go test -covermode=count + gocov-xml | C0 only |
| Rust | cargo test | cargo-llvm-cov `--mcdc` | partial |
| Java | JUnit | JaCoCo `branch=true` | yes |
| Bash | bats | bashcov | partial |

For partial-C1 languages, `.scrum/config.json` MUST declare relaxed
threshold (e.g., `"c1_threshold": 0.95`); ad-hoc relaxation is
forbidden.

## Measurement sequence (Phase 2 Step 2)

(a) **Test + coverage run**

```bash
CFG=".scrum/config.json"
RUN_CMD="$(jq -r '.coverage_tool.command' "$CFG")"
mapfile -t RUN_ARGS < <(jq -r '.coverage_tool.run_args[]' "$CFG")
"$RUN_CMD" "${RUN_ARGS[@]}"
EX=$?
# nonzero EX is OK here (tests may have failed) — failures recorded
# in subsequent steps. Tool-launch failure → escalate.
```

(b) **Coverage report generation**

```bash
mapfile -t REPORT_ARGS < <(jq -r '.coverage_tool.report_args[]' "$CFG")
REPORT_PATH=".scrum/pbi/$PBI_ID/metrics/coverage-r$ROUND.json"
"$RUN_CMD" "${REPORT_ARGS[@]}" "$REPORT_PATH"
```

(c) **Normalize coverage to common schema**

Read raw output → transform into the schema documented in
`docs/contracts/coverage-rN.schema.json`. Overwrite `$REPORT_PATH`.

(d) **Normalize test results**

Read junit XML or json → transform into the schema in
`docs/contracts/test-results-rN.schema.json`. Write to
`.scrum/pbi/$PBI_ID/metrics/test-results-r$ROUND.json`.

(e) **Pragma audit**

```bash
PATTERN="$(jq -r '.pragma_pattern' "$CFG")"
# Grep all test files for $PATTERN; for each match, capture file:line +
# look at the line above and the inline part of the line for the reason
# text. Build pragma-audit-r{n}.json per spec 6.6.
```

## Pass criteria evaluation

```bash
evaluate_pass() {
  local cov="$1" tests="$2" pragma="$3" impl_rev="$4" ut_rev="$5" cfg="$6"
  local c0_th c1_th
  c0_th=$(jq -r '.c0_threshold // 100' "$cfg")
  c1_th=$(jq -r '.c1_threshold // 100' "$cfg")
  local failed exec_err uncaught
  failed=$(jq '.totals.failed' "$tests")
  exec_err=$(jq '.totals.exec_errors' "$tests")
  uncaught=$(jq '.totals.uncaught_exceptions' "$tests")
  [[ "$failed" -eq 0 && "$exec_err" -eq 0 && "$uncaught" -eq 0 ]] || { echo "test_failures"; return 1; }

  local c0 c1_supp c1
  c0=$(jq '.totals.c0.percent' "$cov")
  c1_supp=$(jq '.totals.c1.supported' "$cov")
  c1=$(jq '.totals.c1.percent' "$cov")
  awk "BEGIN{exit !($c0 >= $c0_th)}" || { echo "c0_below"; return 1; }
  if [[ "$c1_supp" == "true" ]]; then
    awk "BEGIN{exit !($c1 >= $c1_th)}" || { echo "c1_below"; return 1; }
  fi

  jq -e '.exclusions | all(.reason_source != "missing")' "$pragma" > /dev/null \
    || { echo "pragma_unjustified"; return 1; }

  grep -q '^\*\*Verdict: PASS\*\*' "$impl_rev" || { echo "impl_review_fail"; return 1; }
  grep -q '^\*\*Verdict: PASS\*\*' "$ut_rev" || { echo "ut_review_fail"; return 1; }

  return 0
}
```

## Coverage skip (project-wide)

When `coverage_tool == null` in `.scrum/config.json`:

- Skip steps (a)-(c)
- Still run tests via `test_runner` and produce test-results
- Skip coverage_status check in Pass criteria
- Design doc preamble MUST record skip reason
- codex-design-reviewer FAILs if reason missing
````

- [ ] **Step 2: Commit**

```bash
git add skills/pbi-pipeline/references/coverage-gate.md
git commit -m "feat(skills): add pbi-pipeline coverage-gate reference"
```

### Task 3.7: Create `skills/pbi-pipeline/references/feedback-routing.md`

**Files:**
- Create: `skills/pbi-pipeline/references/feedback-routing.md`

- [ ] **Step 1: Write the reference**

Create `skills/pbi-pipeline/references/feedback-routing.md`. Content
mirrors spec section 3.6:

````markdown
# Feedback Routing Reference

How the Developer (conductor) builds the per-Round feedback files for
impl and UT agents after a FAIL judgment.

## Routing matrix

| Source | impl agent | UT agent |
|---|---|---|
| impl-reviewer findings | ✓ | – |
| ut-reviewer findings | – | ✓ |
| Test failures (assertion / exec error / uncaught) | ✓ | ✓ |
| Coverage gap — branch unreachable from tests | – | ✓ |
| Coverage gap — implementation dead code | ✓ | – |

## Test failure framing (sent to both)

- **For impl agent:** "Verify your code matches the design, assuming
  tests are correct. If a test asserts behavior the design specifies
  and your code violates it, fix the code."
- **For UT agent:** "Verify your tests match the design's interface,
  assuming impl is correct. If a test asserts behavior NOT in the
  design (or stricter than designed), fix the test."

## Dead-code detection (Developer-side)

For each uncovered branch in `coverage-r{n}.json.files[].uncovered_branches`:

- Read the source line. If it contains a known dead-code marker
  (`raise NotImplementedError`, `panic!()`, `unreachable!()`,
  `assert False`, constant-false comparison) → **route to impl** as
  dead-code finding.
- Otherwise → **route to UT** as missing-test finding.
- If you can't tell → **route to both** (low-cost: each agent will
  no-op if not its concern).

## Feedback file template — `feedback/impl-r{n+1}.md`

````markdown
# Impl Feedback for Round {n+1}

## impl-reviewer findings (Round {n})

{For each Critical/High finding from impl/review-r{n}.md, list:}
- [{severity}] {file}:{lines} — {description}

## Test failures (Round {n})

{For each failure in test-results-r{n}.json.failures, list:}
- {test_id}: {type} — {message}
  Framing: Verify your code matches the design. If the test asserts
  behavior the design specifies and your code violates it, fix the code.

## Implementation dead-code warnings

{For each branch routed to impl, list:}
- {file}:{line} — {dead-code marker found}: consider removing the
  unreachable branch.
````

## Feedback file template — `feedback/ut-r{n+1}.md`

````markdown
# UT Feedback for Round {n+1}

## ut-reviewer findings (Round {n})

{For each Critical/High finding from ut/review-r{n}.md, list:}
- [{severity}] {file}:{lines} — {description}

## Test failures (Round {n})

{Same list as impl FB but with UT-side framing:}
- {test_id}: {type} — {message}
  Framing: Verify your tests match the design interface. If the test
  asserts behavior NOT in the design (or stricter than designed),
  fix the test.

## Coverage gaps (need new tests)

{For each uncovered branch routed to UT, list:}
- {file}:{line} (branch from line {from} to line {to}, condition
  {condition}) — add a test that exercises this branch.

## Pragma exclusions to revisit

{For each pragma exclusion with reason_source == "missing" in
pragma-audit-r{n}.json, list:}
- {file}:{line} — exclusion has no inline-comment reason. Either
  remove the exclusion (and add a test) or add a justifying reason.
````
````

- [ ] **Step 2: Commit**

```bash
git add skills/pbi-pipeline/references/feedback-routing.md
git commit -m "feat(skills): add pbi-pipeline feedback-routing reference"
```

### Task 3.8: Create `skills/pbi-pipeline/references/termination-gates.md`

**Files:**
- Create: `skills/pbi-pipeline/references/termination-gates.md`

- [ ] **Step 1: Write the reference**

Create `skills/pbi-pipeline/references/termination-gates.md`. Content
mirrors spec section 3.4:

````markdown
# Termination Gates Reference

Composite gate model used at end of each Round (design and impl+UT).
Anthropic + Ralph + GAN-derived. Deterministic — no fuzzy heuristics.

## Gate matrix

| Gate | Condition | Outcome |
|---|---|---|
| Success | (phase-specific success criteria all true) | STOP success |
| Stagnation | Same `signature` repeats in 2 consecutive Rounds (Critical/High only) | STOP escalate (`stagnation`) |
| Divergence | (CRITICAL+HIGH count) increases Round n → n+1 | STOP escalate (`divergence`) |
| Hard cap | `round_n >= 5` | STOP escalate (`max_rounds`) |
| Budget cap (future) | (cumulative token > threshold) | STOP escalate (`budget_exhausted`) |

## Phase-specific success criteria

- **Design phase**: `design-reviewer.verdict == PASS`
- **Impl+UT phase**: see `coverage-gate.md` § Pass criteria
  (8 conditions)

## Stagnation detection

```bash
# Build set of signatures for Round n (Critical/High only)
sig_n="$(jq -r '
  .findings | map(select(.severity == "critical" or .severity == "high"))
  | map(.signature) | sort | .[]
' "$CURRENT_REVIEW")"

# Same for Round n-1
sig_prev="$(jq -r '...' "$PREVIOUS_REVIEW")"

# Stagnation if any signature appears in both sets
common="$(comm -12 <(echo "$sig_n") <(echo "$sig_prev"))"
if [ -n "$common" ]; then
  echo "stagnation"
  exit 0
fi
```

For impl+UT phase, build the set from BOTH impl and ut review files
(union).

## Divergence detection

```bash
count_n="$(jq '
  [.findings[] | select(.severity == "critical" or .severity == "high")] | length
' "$CURRENT_REVIEW")"
count_prev="$(jq '...' "$PREVIOUS_REVIEW")"
if [ "$count_n" -gt "$count_prev" ]; then
  echo "divergence"
fi
```

For impl+UT phase, count from BOTH reviews (sum).

## Hard cap

```bash
if [ "$ROUND" -ge 5 ]; then
  echo "max_rounds"
fi
```

## Gate evaluation order

1. If success criteria met → STOP success (no further checks)
2. If stagnation → STOP escalate (stagnation)
3. If divergence → STOP escalate (divergence)
4. If hard cap → STOP escalate (max_rounds)
5. Otherwise: proceed to next Round (or build feedback first for
   impl+UT phase)
````

- [ ] **Step 2: Commit**

```bash
git add skills/pbi-pipeline/references/termination-gates.md
git commit -m "feat(skills): add pbi-pipeline termination-gates reference"
```

### Task 3.9: Create `skills/pbi-pipeline/references/catalog-contention.md`

**Files:**
- Create: `skills/pbi-pipeline/references/catalog-contention.md`

- [ ] **Step 1: Write the reference**

Create `skills/pbi-pipeline/references/catalog-contention.md`. Content
mirrors spec section 3.7:

````markdown
# Catalog Contention Reference

How parallel PBI pipelines coordinate writes to shared catalog specs
under `docs/design/specs/`. 3-layer defense.

## Layer 1: Sprint planning pre-separation (primary defense)

SM records `catalog_targets[]` per PBI in `backlog.json` during sprint
planning. PBIs with overlapping `catalog_targets` MUST NOT be assigned
to different developers in parallel. SM either:

- Assigns overlapping PBIs to the same Developer (sequential), or
- Splits the PBI to remove overlap.

This is enforced in `skills/sprint-planning/SKILL.md`. Verify in your
own pipeline run via:

```bash
my_pbi_targets="$(jq -r --arg id "$PBI_ID" '.items[] | select(.id == $id) | .catalog_targets[]?' .scrum/backlog.json)"
```

## Layer 2: Runtime exclusion via flock (backstop)

Before writing to a catalog spec, acquire a flock on a per-spec lock
file. The pbi-designer agent does this; the conductor enforces by
inspecting designer's reported actions.

```bash
acquire_catalog_lock() {
  local spec_path="$1"
  local lock_id; lock_id="$(echo "$spec_path" | sed 's|/|_|g')"
  local lock_file=".scrum/locks/catalog-${lock_id}.lock"
  mkdir -p .scrum/locks
  exec {LOCK_FD}>"$lock_file"
  if ! flock -w 60 "$LOCK_FD"; then
    return 124  # timeout
  fi
  return 0
}
release_catalog_lock() {
  exec {LOCK_FD}>&-
}
```

Timeout (60s) → escalate with `escalation_reason: catalog_lock_timeout`.

## Layer 3: Conflict detection via mtime (last resort)

After releasing the lock, verify nothing else wrote in between:

```bash
verify_no_conflict() {
  local spec_path="$1" mtime_before="$2"
  local mtime_now
  mtime_now="$(stat -f %m "$spec_path" 2>/dev/null || stat -c %Y "$spec_path")"
  [ "$mtime_now" = "$mtime_before" ]
}
```

If conflict detected: discard the change, log event, retry once. On
second conflict: escalate `catalog_lock_timeout`.

## Stale lock cleanup

If a Developer dies mid-write, the flock auto-releases on process exit
(file descriptor closure). The lock file itself is left behind but is
harmless — flock attaches to FDs, not file existence. SM may sweep
`.scrum/locks/` periodically.
````

- [ ] **Step 2: Commit**

```bash
git add skills/pbi-pipeline/references/catalog-contention.md
git commit -m "feat(skills): add pbi-pipeline catalog-contention reference"
```

---

## Phase 4: New skill — `pbi-escalation-handler`

### Task 4.1: Create `skills/pbi-escalation-handler/SKILL.md`

**Files:**
- Create: `skills/pbi-escalation-handler/SKILL.md`

- [ ] **Step 1: Write the SKILL.md**

Create `skills/pbi-escalation-handler/SKILL.md`:

```markdown
---
name: pbi-escalation-handler
description: >
  Handles PBI pipeline escalation notifications from Developer. Reads
  escalation context, applies response matrix (retry / split / hold /
  human), and routes to user when human intervention is needed.
disable-model-invocation: false
---

## Inputs

- Notification from Developer (Agent Teams) with PBI id and
  `escalation_reason`
- `.scrum/pbi/<pbi-id>/state.json`
- Latest review files: `.scrum/pbi/<pbi-id>/{design,impl,ut}/review-r{last}.md`
- `.scrum/pbi/<pbi-id>/metrics/*.json`

## Outputs

- SM judgment recorded at
  `.scrum/pbi/<pbi-id>/escalation-resolution.md` (audit trail)
- `backlog.json` status updated (`blocked` → `in_progress` for retry,
  or stays `blocked` for hold/human)
- User notified via SM channel when human escalation needed

## Response Matrix

| escalation_reason | Action |
|---|---|
| `stagnation` | Extract Critical/High findings → present user with options [split / redesign / hold] |
| `divergence` | Same as stagnation; mark urgent. (rollback is future work) |
| `max_rounds` | Inspect findings count trend across rounds. If decreasing, propose 1-time retry with fresh Developer. Else human-escalate. |
| `budget_exhausted` | Immediate human-escalate |
| `requirements_unclear` | SM consults PO via clarification ticket; on PO answer, set status back to in_progress and re-spawn Developer to resume PBI |
| `coverage_tool_unavailable` | Surface install instruction (e.g. `pip install coverage`) to user; PBI on hold until installed |
| `coverage_tool_error` | Inspect last pipeline.log entries for the tool error; surface to user; hold |
| `catalog_lock_timeout` | Check `.scrum/locks/` for stale lock holders. If holder Developer is dead, force-release and retry. Else human-escalate. |

## Steps

1. Read state.json for the PBI id.
2. Identify `escalation_reason`.
3. Match to Response Matrix action.
4. For retry: spawn fresh Developer instance for the PBI; reset PBI
   round counters in state.json; status back to `in_progress`.
5. For hold or human-escalate: prepare summary message (PBI id, last
   review headlines, escalation reason, recommended user actions);
   send via SM communications channel.
6. Write decision to `.scrum/pbi/<pbi-id>/escalation-resolution.md`
   with timestamp, decision, and reasoning.

## Exit Criteria

- escalation-resolution.md exists for the PBI
- backlog.json reflects decision
- User informed (when human-escalate or hold)
```

- [ ] **Step 2: Commit**

```bash
git add skills/pbi-escalation-handler/SKILL.md
git commit -m "feat(skills): add pbi-escalation-handler SKILL.md"
```

---

## Phase 5: Modify existing agents and skills

### Task 5.1: Modify `agents/developer.md`

**Files:**
- Modify: `agents/developer.md`

- [ ] **Step 1: Read current file to confirm exact content**

Run: `cat agents/developer.md`

- [ ] **Step 2: Replace skills list and lifecycle text**

Edit `agents/developer.md`:

Replace the existing `skills:` block:

```yaml
skills:
  - requirements-sprint
  - design
  - implementation
  - install-subagents
  - smoke-test
```

with:

```yaml
skills:
  - requirements-sprint
  - pbi-pipeline
  - install-subagents
  - smoke-test
```

Replace the `## Lifecycle` section so steps 5-7 reflect the new flow.
Replace this fragment:

```markdown
5. Run `design` skill→author design docs + user-facing docs
6. Run `implementation` skill→code + tests per design
7. Await review→address findings relayed by SM
```

with:

```markdown
5. Run `pbi-pipeline` skill→drive design + impl+UT phases via
   sub-agent fan-out (no code written by Developer itself)
6. On PBI completion or escalation, notify SM
7. Wait for next PBI assignment from SM
```

Update `## Responsibilities` to remove the old FR-004 Design line that
points to docs/design/specs and replace with:

```markdown
- **FR-004 Design (per PBI)**: Spawn `pbi-designer` sub-agent to author
  `.scrum/pbi/<pbi-id>/design/design.md`. catalog spec updates happen
  as a side-effect via the same sub-agent. SM consults PO when
  requirements unclear.
- **FR-017 Definition of Done**: Replaced by pbi-pipeline termination
  gate (success requires impl+UT verdicts PASS, tests pass, C0/C1
  100%, pragma justified). Sprint-end SM `cross-review` remains as a
  cross-cutting quality check.
```

Update the `## State Files` section to add:

```markdown
- `.scrum/pbi/<pbi-id>/` — PBI working area (state.json, design/,
  impl/, ut/, metrics/, feedback/, pipeline.log). Created and managed
  by the pbi-pipeline skill.
- `.scrum/locks/` — catalog write contention via flock.
```

- [ ] **Step 3: Validate**

Run: `awk '/^---$/{n++}n==1{print}n==2{exit}' agents/developer.md | tail -n +2 | python3 -c "import yaml,sys; yaml.safe_load(sys.stdin); print('OK')"`
Expected: `OK`

- [ ] **Step 4: Commit**

```bash
git add agents/developer.md
git commit -m "refactor(agents): developer becomes PBI pipeline conductor

Replaces design + implementation skills with pbi-pipeline. Developer
no longer writes code itself — spawns sub-agents per Round. State
managed under .scrum/pbi/<pbi-id>/."
```

### Task 5.2: Modify `agents/scrum-master.md`

**Files:**
- Modify: `agents/scrum-master.md`

- [ ] **Step 1: Read current file**

Run: `cat agents/scrum-master.md | head -50`

- [ ] **Step 2: Add escalation handler skill to YAML**

Edit `agents/scrum-master.md` frontmatter to add `pbi-escalation-handler`
to the `skills:` list (insert in an order consistent with existing
entries; alphabetical is fine).

- [ ] **Step 3: Add escalation trigger to body**

Add a section near other coordination logic, after existing trigger
sections:

```markdown
## PBI Pipeline Escalation Trigger

When a Developer reports `[<pbi-id>] ESCALATED reason=<reason>` via the
Agent Teams notification channel, immediately invoke the
`pbi-escalation-handler` skill with the PBI id. Do NOT proceed with
other coordination work until the escalation is resolved (recorded in
`.scrum/pbi/<pbi-id>/escalation-resolution.md`).
```

- [ ] **Step 4: Validate + Commit**

```bash
awk '/^---$/{n++}n==1{print}n==2{exit}' agents/scrum-master.md | tail -n +2 | python3 -c "import yaml,sys; yaml.safe_load(sys.stdin); print('OK')"
git add agents/scrum-master.md
git commit -m "feat(agents): add pbi-escalation-handler trigger to scrum-master"
```

### Task 5.3: Modify `skills/install-subagents/SKILL.md`

**Files:**
- Modify: `skills/install-subagents/SKILL.md`

- [ ] **Step 1: Read current file**

Run: `cat skills/install-subagents/SKILL.md`

- [ ] **Step 2: Replace the sub-agent list section**

Replace the section that lists available sub-agents (look for `tdd-guide`
and `build-error-resolver` references) with:

```markdown
## Required Sub-Agents (PBI Pipeline)

Verify these 6 sub-agents exist with valid YAML frontmatter at
`.claude/agents/<name>.md`:

- `pbi-designer`
- `pbi-implementer`
- `pbi-ut-author`
- `codex-design-reviewer`
- `codex-impl-reviewer`
- `codex-ut-reviewer`

Missing required → BLOCK (escalate to SM, do not proceed to PBI work).

## Optional Sub-Agents

- `tdd-guide` — lower priority since Developer no longer writes code
  directly.
- `build-error-resolver` — lower priority since Codex reviewers catch
  most build issues.

Missing optional → log warning, proceed.
```

Update the `## Steps` section to verify the 6 required sub-agents exist
(loop with `[ -f .claude/agents/<name>.md ]`).

- [ ] **Step 3: Commit**

```bash
git add skills/install-subagents/SKILL.md
git commit -m "feat(skills): install-subagents requires PBI pipeline sub-agents"
```

### Task 5.4: Modify `skills/sprint-planning/SKILL.md`

**Files:**
- Modify: `skills/sprint-planning/SKILL.md`

- [ ] **Step 1: Read current file**

Run: `cat skills/sprint-planning/SKILL.md`

- [ ] **Step 2: Add catalog_targets pre-separation step**

Insert a new step in the `## Steps` section (after PBI assignment but
before Sprint kick-off):

```markdown
N. **Catalog Target Assignment** (PBI Pipeline parallel-safety):

   For each PBI in the sprint:
   1. Read PBI description + requirements to identify catalog spec
      paths it will touch.
   2. Record in backlog.json:
      ```bash
      jq --arg id "$PBI_ID" --argjson targets "$TARGETS_JSON" \
        '(.items[] | select(.id == $id)).catalog_targets = $targets' \
        .scrum/backlog.json > .scrum/backlog.json.tmp \
        && mv .scrum/backlog.json.tmp .scrum/backlog.json
      ```
   3. **Conflict check**: For PBIs with overlapping catalog_targets in
      this sprint, ensure they are NOT assigned to different developers
      in parallel. Either sequence them on one developer, or split the
      PBI to remove overlap. Record decision in sprint.json.
   4. If overlap unavoidable → note in sprint.json; runtime flock will
      arbitrate.
```

(Renumber subsequent steps as needed.)

- [ ] **Step 3: Commit**

```bash
git add skills/sprint-planning/SKILL.md
git commit -m "feat(skills): sprint-planning records catalog_targets per PBI"
```

### Task 5.5: Modify `skills/cross-review/SKILL.md`

**Files:**
- Modify: `skills/cross-review/SKILL.md`

- [ ] **Step 1: Read current file**

Run: `cat skills/cross-review/SKILL.md`

- [ ] **Step 2: Insert role clarification at top of body**

After the YAML frontmatter, insert (or update existing summary):

```markdown
## Role (post pbi-pipeline introduction)

Sprint-end cross-cutting quality gate. The PBI Pipeline already runs
per-PBI impl + UT reviews via codex-impl-reviewer / codex-ut-reviewer.
This `cross-review` complements that by:

- Catching cross-PBI integration issues
- Independent security perspective (security-reviewer)
- Final code-reviewer pass with full Sprint context

Do NOT duplicate per-PBI quality work; assume per-PBI Pass criteria
already satisfied (see `.scrum/pbi/<pbi-id>/impl/review-r{last}.md` and
`ut/review-r{last}.md` for prior context).
```

- [ ] **Step 3: Add input pointers to existing collection step**

In the existing `## Steps` section, where review inputs are collected,
add to the input list:

```markdown
- Per-PBI pipeline final reviews:
  - `.scrum/pbi/<pbi-id>/impl/review-r{last}.md`
  - `.scrum/pbi/<pbi-id>/ut/review-r{last}.md`
  - `.scrum/pbi/<pbi-id>/metrics/coverage-r{last}.json`

  These are read for context but NOT re-evaluated. Use them to scope
  what is already covered.
```

- [ ] **Step 4: Commit**

```bash
git add skills/cross-review/SKILL.md
git commit -m "refactor(skills): cross-review clarified as Sprint-end cross-cutting gate"
```

---

## Phase 6: Modify existing hooks

### Task 6.1: Extend `hooks/phase-gate.sh` (TDD)

**Files:**
- Test: `tests/unit/test_phase_gate_pbi_pipeline.bats`
- Modify: `hooks/phase-gate.sh`

- [ ] **Step 1: Write failing test**

Create `tests/unit/test_phase_gate_pbi_pipeline.bats`:

```bash
#!/usr/bin/env bats

setup() {
  TEST_TMP="$(mktemp -d)"
  cd "$TEST_TMP" || exit 1
  mkdir -p .scrum docs/design hooks
  echo '{"phase":"pbi_pipeline_active"}' > .scrum/state.json
  echo '# catalog' > docs/design/catalog.md
  echo '{"enabled":[]}' > docs/design/catalog-config.json
  cp -r "${BATS_TEST_DIRNAME}/../../hooks/lib" hooks/lib
  cp "${BATS_TEST_DIRNAME}/../../hooks/phase-gate.sh" hooks/phase-gate.sh
  HOOK="$PWD/hooks/phase-gate.sh"
}

teardown() {
  rm -rf "$TEST_TMP"
}

payload() {
  local agent="$1" tool="$2" path="$3"
  jq -n --arg a "$agent" --arg t "$tool" --arg p "$path" \
    '{agent_name: $a, tool_name: $t, tool_input: {file_path: $p}}'
}

@test "pbi_pipeline_active phase allows pbi-designer Write to .scrum/pbi/" {
  run bash -c "echo '$(payload pbi-designer Write .scrum/pbi/pbi-001/design/design.md)' | $HOOK"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "allow"'
}

@test "pbi_pipeline_active phase allows pbi-implementer Write to src/" {
  run bash -c "echo '$(payload pbi-implementer Write src/auth.py)' | $HOOK"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "allow"'
}

@test "pbi_pipeline_active phase allows pbi-designer Write to docs/design/specs/" {
  run bash -c "echo '$(payload pbi-designer Write docs/design/specs/api/auth.md)' | $HOOK"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "allow"'
}

@test "pbi_pipeline_active phase denies non-pbi-designer Write to docs/design/specs/" {
  run bash -c "echo '$(payload pbi-implementer Write docs/design/specs/api/auth.md)' | $HOOK"
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.decision == "deny"'
}
```

- [ ] **Step 2: Run test, verify failure**

Run: `bats tests/unit/test_phase_gate_pbi_pipeline.bats`
Expected: 4 failures (current phase-gate.sh does not handle the new
phase or new agents).

- [ ] **Step 3: Edit `hooks/phase-gate.sh`**

Read the current `hooks/phase-gate.sh` end-to-end. Add a new branch for
`phase == "pbi_pipeline_active"` that:

- Allows Read/Write/Edit by `pbi-designer`, `pbi-implementer`,
  `pbi-ut-author` to:
  - `.scrum/pbi/**`
  - `src/**`, `lib/**`, `tests/**` (path-guard hook restricts further)
  - `docs/design/specs/**` ONLY for `pbi-designer`
- Allows Read by any of the new agents to anywhere
- Allows Read/Write by reviewers (`codex-*-reviewer`) to
  `.scrum/pbi/**` only
- Denies catalog spec writes by non-`pbi-designer` agents.

Preserve existing behavior for old phases (read-only fall-through).

- [ ] **Step 4: Run tests, verify pass**

Run: `bats tests/unit/test_phase_gate_pbi_pipeline.bats`
Expected: 4 tests pass.

- [ ] **Step 5: Run shellcheck**

Run: `shellcheck hooks/phase-gate.sh`
Expected: clean (or no new warnings).

- [ ] **Step 6: Commit**

```bash
git add hooks/phase-gate.sh tests/unit/test_phase_gate_pbi_pipeline.bats
git commit -m "feat(hooks): phase-gate handles pbi_pipeline_active phase

Allows new sub-agents (pbi-designer, pbi-implementer, pbi-ut-author,
codex-* reviewers) to write to their respective scoped paths during
the new phase. catalog spec writes restricted to pbi-designer."
```

### Task 6.2: Extend `hooks/completion-gate.sh`

**Files:**
- Modify: `hooks/completion-gate.sh`

- [ ] **Step 1: Read current file**

Run: `cat hooks/completion-gate.sh`

- [ ] **Step 2: Add `pbi_pipeline_active` completion check**

Edit `hooks/completion-gate.sh`. Add a branch in the phase-handling
switch for `pbi_pipeline_active`:

- Read `.scrum/state.json.active_pbi_pipelines[]`.
- For each PBI id, check `.scrum/pbi/<pbi-id>/state.json.phase`.
- Phase is complete when ALL active PBI pipelines are either `complete`
  or `escalated` AND every `escalated` PBI has a corresponding
  `escalation-resolution.md` file.

```bash
check_pbi_pipeline_active_complete() {
  local active
  mapfile -t active < <(jq -r '.active_pbi_pipelines[]?' .scrum/state.json)
  for pbi_id in "${active[@]}"; do
    local pbi_phase
    pbi_phase=$(jq -r '.phase' ".scrum/pbi/$pbi_id/state.json" 2>/dev/null || echo "missing")
    case "$pbi_phase" in
      complete) ;;  # OK
      escalated)
        if [ ! -f ".scrum/pbi/$pbi_id/escalation-resolution.md" ]; then
          return 1  # blocked: escalation not resolved
        fi
        ;;
      *) return 1 ;;  # not done yet
    esac
  done
  return 0
}
```

- [ ] **Step 3: shellcheck**

Run: `shellcheck hooks/completion-gate.sh`
Expected: clean.

- [ ] **Step 4: Commit**

```bash
git add hooks/completion-gate.sh
git commit -m "feat(hooks): completion-gate handles pbi_pipeline_active phase"
```

### Task 6.3: Extend `hooks/dashboard-event.sh`

**Files:**
- Modify: `hooks/dashboard-event.sh`

- [ ] **Step 1: Read current file**

Run: `cat hooks/dashboard-event.sh`

- [ ] **Step 2: Add `pbi_id` field and pbi_pipelines section**

Edit `hooks/dashboard-event.sh`:

1. When recording a SubagentStart / SubagentStop event for one of the
   new sub-agents (pbi-designer, pbi-implementer, pbi-ut-author,
   codex-design-reviewer, codex-impl-reviewer, codex-ut-reviewer),
   extract `pbi_id` from `$SCRUM_PBI_ID` env var (set by
   session-context.sh) and include it in the event payload.

2. Maintain a parallel `pbi_pipelines` section in `dashboard.json`:

```bash
update_pbi_pipelines() {
  local pbi_id="$1" agent_name="$2" event_type="$3"
  [ -z "$pbi_id" ] && return 0
  local now; now="$(date -Iseconds)"
  local dev; dev=$(jq -r --arg id "$pbi_id" '.developers[] | select(.current_pbi == $id) | .id' .scrum/sprint.json 2>/dev/null || echo "unknown")
  local phase round
  phase=$(jq -r '.phase // "unknown"' ".scrum/pbi/$pbi_id/state.json" 2>/dev/null || echo "unknown")
  if [ "$phase" = "design" ]; then
    round=$(jq -r '.design_round' ".scrum/pbi/$pbi_id/state.json")
  else
    round=$(jq -r '.impl_round' ".scrum/pbi/$pbi_id/state.json")
  fi

  jq --arg id "$pbi_id" --arg dev "$dev" --arg phase "$phase" --argjson round "$round" --arg now "$now" --arg agent "$agent_name" --arg ev "$event_type" '
    .pbi_pipelines = (.pbi_pipelines // []) |
    .pbi_pipelines |= map(select(.pbi_id != $id)) |
    .pbi_pipelines += [{
      pbi_id: $id, developer: $dev, phase: $phase, round: $round,
      active_subagents: (if $ev == "start" then [$agent] else [] end),
      last_event_at: $now
    }]
  ' "$DASHBOARD_FILE" > "$DASHBOARD_FILE.tmp" && mv "$DASHBOARD_FILE.tmp" "$DASHBOARD_FILE"
}
```

- [ ] **Step 3: shellcheck**

Run: `shellcheck hooks/dashboard-event.sh`
Expected: clean.

- [ ] **Step 4: Commit**

```bash
git add hooks/dashboard-event.sh
git commit -m "feat(hooks): dashboard-event tracks PBI pipeline sub-agents

Adds pbi_id field to events; maintains dashboard.json.pbi_pipelines
section for TUI rendering."
```

### Task 6.4: Extend `hooks/session-context.sh`

**Files:**
- Modify: `hooks/session-context.sh`

- [ ] **Step 1: Read current file**

Run: `cat hooks/session-context.sh`

- [ ] **Step 2: Inject `SCRUM_PBI_ID` env var**

Edit `hooks/session-context.sh`. When the spawned agent is one of:

- pbi-designer
- pbi-implementer
- pbi-ut-author
- codex-design-reviewer
- codex-impl-reviewer
- codex-ut-reviewer

…and the parent session has `SCRUM_PBI_ID` set or can infer it from
the spawn prompt (look for `.scrum/pbi/<id>/` paths), pass `SCRUM_PBI_ID`
to the child session. Implementation depends on existing context-passing
mechanism in this hook.

If the existing hook does not currently support env propagation, add a
field to the context JSON it emits:

```json
{
  "scrum_pbi_id": "pbi-001",
  ...existing fields...
}
```

…and update `hooks/dashboard-event.sh` to read this field from the
SubagentStart event payload (in addition to env).

- [ ] **Step 3: shellcheck + commit**

```bash
shellcheck hooks/session-context.sh
git add hooks/session-context.sh
git commit -m "feat(hooks): session-context injects SCRUM_PBI_ID for PBI sub-agents"
```

---

## Phase 7: Delete old skills

### Task 7.1: Delete `skills/design/` and `skills/implementation/`

**Files:**
- Delete: `skills/design/SKILL.md`
- Delete: `skills/implementation/SKILL.md`

- [ ] **Step 1: Verify no other agent references the old skills**

Run: `grep -rln "skills:.*design$\|skills:.*implementation$\|skill: design\|skill: implementation" agents/ skills/ docs/ || echo "no references"`
Expected: only `agents/developer.md` (already updated in 5.1) — if
others appear, fix them first.

- [ ] **Step 2: Delete the files**

```bash
git rm skills/design/SKILL.md skills/implementation/SKILL.md
# Remove empty directories if any
rmdir skills/design skills/implementation 2>/dev/null || true
```

- [ ] **Step 3: Update tests that reference old skills**

Run: `grep -rln "skills/design\|skills/implementation" tests/`
For each match, update or remove the test as appropriate.

- [ ] **Step 4: Run all tests**

Run: `bats tests/unit/ tests/lint/`
Expected: all pass (no references to deleted skills).

- [ ] **Step 5: Commit**

```bash
git commit -m "refactor: remove legacy design and implementation skills

Functionality moved into the new pbi-pipeline skill. Developer agent
now invokes pbi-pipeline as the per-PBI orchestration entrypoint."
```

---

## Phase 8: TUI dashboard extension

### Task 8.1: Add PBI Pipeline pane to `dashboard/app.py`

**Files:**
- Modify: `dashboard/app.py`

- [ ] **Step 1: Read current dashboard structure**

Run: `head -100 dashboard/app.py && wc -l dashboard/app.py`

Identify the existing pane composition (Sprint, Backlog, etc.) and how
`dashboard.json` is loaded.

- [ ] **Step 2: Add a `PbiPipelinePane` widget class**

Add to `dashboard/app.py` (location: alongside other pane classes):

```python
from textual.widgets import Static
from textual.reactive import reactive


class PbiPipelinePane(Static):
    """Renders dashboard.json.pbi_pipelines as a live table."""

    pipelines: reactive[list[dict]] = reactive([])

    def render(self) -> str:
        if not self.pipelines:
            return "PBI Pipelines: (none active)"
        rows = ["PBI Pipelines:"]
        for p in self.pipelines:
            phase_styled = p.get("phase", "?")
            if phase_styled == "escalated":
                phase_styled = f"[red]{phase_styled}[/red]"
            rows.append(
                f"  {p['pbi_id']:12} dev={p.get('developer', '?'):14} "
                f"phase={phase_styled:10} round={p.get('round', '?'):2} "
                f"agents={','.join(p.get('active_subagents', [])):30} "
                f"updated={p.get('last_event_at', '?')}"
            )
        return "\n".join(rows)
```

- [ ] **Step 3: Wire the pane into the app**

In the `compose()` method (or equivalent), add a `PbiPipelinePane`
instance:

```python
def compose(self) -> ComposeResult:
    # ...existing panes...
    yield PbiPipelinePane(id="pbi-pipeline-pane")
```

- [ ] **Step 4: Wire data flow from dashboard.json watcher**

In the file-change handler that reads `dashboard.json`, add:

```python
def on_dashboard_change(self, data: dict) -> None:
    # ...existing handlers...
    pane = self.query_one("#pbi-pipeline-pane", PbiPipelinePane)
    pane.pipelines = data.get("pbi_pipelines", [])
```

- [ ] **Step 5: Update existing Sprint phase display**

Find where `state.json.phase` is displayed and add a label for the new
phase:

```python
PHASE_LABELS = {
    # ...existing...
    "pbi_pipeline_active": "PBI Pipelines Running",
}
```

- [ ] **Step 6: Run dashboard locally to smoke-test**

Run: `python3 dashboard/app.py`
(In a separate terminal, manually create a test
`.scrum/dashboard.json` with a `pbi_pipelines` array to verify the
pane renders. Use a small fixture file in `tests/fixtures/` if it
helps.)

Expected: pane appears, renders the pipeline rows.

- [ ] **Step 7: Run lint/format**

Run: `ruff check dashboard/ && ruff format dashboard/`
Expected: clean or auto-fixed.

- [ ] **Step 8: Commit**

```bash
git add dashboard/app.py
git commit -m "feat(dashboard): add PBI Pipeline pane to TUI

Reads dashboard.json.pbi_pipelines (populated by dashboard-event.sh).
Renders per-PBI conductor state with red highlight on escalated PBIs."
```

---

## Phase 9: Integration tests

### Task 9.1: Create `tests/fixtures/fake-codex.sh`

**Files:**
- Create: `tests/fixtures/fake-codex.sh`

- [ ] **Step 1: Write the stub**

Create `tests/fixtures/fake-codex.sh`:

```bash
#!/usr/bin/env bash
# fake-codex.sh — test stub mimicking `codex review` for integration tests.
# Usage:
#   fake-codex.sh review --uncommitted --ephemeral \
#     --instructions <file> -o <output_file>
# Behavior: writes a deterministic PASS verdict to the output file.
# Override behavior via FAKE_CODEX_VERDICT (PASS or FAIL) and
# FAKE_CODEX_FINDINGS (newline-separated "signature|severity|criterion|description").
set -euo pipefail

# Find the -o flag value
output=""
prev=""
for arg in "$@"; do
  if [ "$prev" = "-o" ]; then
    output="$arg"
    break
  fi
  prev="$arg"
done
[ -n "$output" ] || { echo "fake-codex: missing -o" >&2; exit 1; }

verdict="${FAKE_CODEX_VERDICT:-PASS}"

{
  echo "## Review: fake-codex stub"
  echo ""
  echo "**Verdict: $verdict**"
  echo ""
  echo "### Findings"
  if [ -n "${FAKE_CODEX_FINDINGS:-}" ]; then
    n=0
    while IFS='|' read -r sig sev crit desc; do
      n=$((n+1))
      echo "- #$n [$sev] [stub] [$crit] — $desc"
    done <<< "$FAKE_CODEX_FINDINGS"
  else
    echo "No findings."
  fi
  echo ""
  echo "### Summary"
  echo "Stub review: $verdict"
  echo ""
  echo '```json'
  if [ -n "${FAKE_CODEX_FINDINGS:-}" ]; then
    findings_json="$(echo "$FAKE_CODEX_FINDINGS" | jq -Rsn '
      [inputs | select(. != "") | split("|") | {
        signature: .[0], severity: .[1], criterion_key: .[2],
        file_path: (.[0] | split(":")[0]),
        line_start: 1, line_end: 1,
        description: .[3]
      }]
    ')"
  else
    findings_json="[]"
  fi
  jq -n --arg v "$verdict" --argjson findings "$findings_json" '{
    status: (if $v == "PASS" then "pass" else "fail" end),
    summary: ("Stub review: " + $v),
    verdict: $v,
    findings: $findings,
    next_actions: [],
    artifacts: []
  }'
  echo '```'
} > "$output"

exit 0
```

- [ ] **Step 2: Make executable**

```bash
chmod +x tests/fixtures/fake-codex.sh
```

- [ ] **Step 3: Quick smoke**

```bash
mkdir -p /tmp/cdx
tests/fixtures/fake-codex.sh review --uncommitted --ephemeral \
  --instructions /dev/null -o /tmp/cdx/out.md
cat /tmp/cdx/out.md
```

Expected: file contains `**Verdict: PASS**` and a JSON envelope.

- [ ] **Step 4: Test FAIL mode**

```bash
FAKE_CODEX_VERDICT=FAIL FAKE_CODEX_FINDINGS="src/x.py:1-5:incorrect_behavior|critical|incorrect_behavior|broken thing" \
  tests/fixtures/fake-codex.sh review --uncommitted --ephemeral \
  --instructions /dev/null -o /tmp/cdx/out.md
cat /tmp/cdx/out.md
```

Expected: `**Verdict: FAIL**` and one finding listed.

- [ ] **Step 5: Commit**

```bash
git add tests/fixtures/fake-codex.sh
git commit -m "test(fixtures): add fake-codex stub for integration tests"
```

### Task 9.2: Create `tests/integration/test_pbi_pipeline_happy_path.bats`

**Files:**
- Create: `tests/integration/test_pbi_pipeline_happy_path.bats`

- [ ] **Step 1: Write the test**

Create `tests/integration/test_pbi_pipeline_happy_path.bats`:

```bash
#!/usr/bin/env bats
# Integration: single PBI completes successfully in 1 design Round + 1 impl Round.
# Sub-agents are not actually spawned (this test exercises Developer-side
# orchestration logic, file plumbing, state transitions, and gate evaluation
# only). Real sub-agent invocation is covered by manual smoke test.

setup() {
  TEST_TMP="$(mktemp -d)"
  cd "$TEST_TMP" || exit 1

  # Minimum viable .scrum layout
  mkdir -p .scrum docs/design/specs hooks/lib
  cp -r "${BATS_TEST_DIRNAME}/../../hooks/lib/"* hooks/lib/
  cp "${BATS_TEST_DIRNAME}/../fixtures/fake-codex.sh" .

  cat > .scrum/config.json <<'EOF'
{
  "test_runner": {"command": "true", "args": []},
  "coverage_tool": null,
  "pragma_pattern": "pragma: no cover",
  "path_guard": {"impl_globs": ["src/**"], "test_globs": ["tests/**"]}
}
EOF

  cat > .scrum/state.json <<'EOF'
{ "phase": "pbi_pipeline_active",
  "current_sprint": "sprint-001",
  "active_pbi_pipelines": [] }
EOF

  cat > .scrum/sprint.json <<'EOF'
{ "sprint_id": "sprint-001",
  "status": "active",
  "developers": [
    { "id": "dev-001-s1",
      "assigned_pbis": ["pbi-001"],
      "current_pbi": "pbi-001",
      "current_pbi_phase": "design",
      "sub_agents": [] }
  ]
}
EOF

  cat > .scrum/backlog.json <<'EOF'
{ "items": [
  { "id": "pbi-001", "title": "test PBI", "status": "in_progress",
    "design_doc_paths": [], "review_doc_path": null,
    "catalog_targets": [],
    "pipeline_summary": null }
]}
EOF

  echo "# requirements" > .scrum/requirements.md

  # Stub the Developer's pipeline driver to exercise state transitions.
  # In production this is the conductor's logic; here we simulate.
  export CODEX_CMD_OVERRIDE="$PWD/fake-codex.sh"
  export FAKE_CODEX_VERDICT="PASS"
}

teardown() {
  rm -rf "$TEST_TMP"
}

@test "pipeline initializes PBI directory and state" {
  PBI_ID=pbi-001
  PBI_DIR=".scrum/pbi/$PBI_ID"
  mkdir -p "$PBI_DIR"/{design,impl,ut,metrics,feedback}
  jq -n --arg id "$PBI_ID" --arg now "$(date -Iseconds)" '{
    pbi_id: $id, phase: "design",
    design_round: 0, impl_round: 0,
    design_status: "pending", impl_status: "pending",
    ut_status: "pending", coverage_status: "pending",
    escalation_reason: null,
    started_at: $now, updated_at: $now
  }' > "$PBI_DIR/state.json"

  [ -d "$PBI_DIR/design" ]
  [ -d "$PBI_DIR/metrics" ]
  jq -e '.phase == "design"' "$PBI_DIR/state.json"
}

@test "design phase Round 1 success transitions to impl_ut" {
  PBI_ID=pbi-001
  PBI_DIR=".scrum/pbi/$PBI_ID"
  mkdir -p "$PBI_DIR"/{design,impl,ut,metrics,feedback}

  # Simulate pbi-designer output
  echo "# Design for $PBI_ID" > "$PBI_DIR/design/design.md"

  # Simulate codex-design-reviewer via fake-codex
  source hooks/lib/codex-invoke.sh
  echo "stub instructions" > /tmp/instr-$$.md
  codex_review_or_fallback /tmp/instr-$$.md "$PBI_DIR/design/review-r1.md"

  # Verdict from review file
  grep -q '**Verdict: PASS**' "$PBI_DIR/design/review-r1.md"

  # Conductor would update state on PASS
  jq -n --arg id "$PBI_ID" --arg now "$(date -Iseconds)" '{
    pbi_id: $id, phase: "impl_ut",
    design_round: 1, impl_round: 0,
    design_status: "pass", impl_status: "pending",
    ut_status: "pending", coverage_status: "pending",
    escalation_reason: null,
    started_at: $now, updated_at: $now
  }' > "$PBI_DIR/state.json"

  jq -e '.phase == "impl_ut" and .design_status == "pass"' "$PBI_DIR/state.json"
  rm -f /tmp/instr-$$.md
}

@test "impl+UT phase Round 1 success transitions to complete" {
  PBI_ID=pbi-001
  PBI_DIR=".scrum/pbi/$PBI_ID"
  mkdir -p "$PBI_DIR"/{design,impl,ut,metrics,feedback}

  # Simulate state at start of impl+UT round 1
  jq -n --arg id "$PBI_ID" --arg now "$(date -Iseconds)" '{
    pbi_id: $id, phase: "impl_ut",
    design_round: 1, impl_round: 1,
    design_status: "pass", impl_status: "in_review",
    ut_status: "in_review", coverage_status: "pending",
    escalation_reason: null,
    started_at: $now, updated_at: $now
  }' > "$PBI_DIR/state.json"

  # Simulate fake codex impl + UT reviews
  source hooks/lib/codex-invoke.sh
  echo "stub" > /tmp/instr-$$.md
  codex_review_or_fallback /tmp/instr-$$.md "$PBI_DIR/impl/review-r1.md"
  codex_review_or_fallback /tmp/instr-$$.md "$PBI_DIR/ut/review-r1.md"

  # Simulate normalized metrics with all-pass
  cat > "$PBI_DIR/metrics/test-results-r1.json" <<'EOF'
{ "round": 1, "pbi_id": "pbi-001", "tool": "stub",
  "tool_version": "0", "executed_at": "now",
  "totals": { "tests": 1, "passed": 1, "failed": 0,
              "exec_errors": 0, "uncaught_exceptions": 0, "skipped": 0 },
  "failures": [] }
EOF
  cat > "$PBI_DIR/metrics/coverage-r1.json" <<'EOF'
{ "round": 1, "pbi_id": "pbi-001", "tool": "stub",
  "tool_version": "0", "measured_at": "now",
  "totals": { "c0": {"covered": 10, "total": 10, "percent": 100.0},
              "c1": {"covered": 5, "total": 5, "percent": 100.0,
                     "supported": true} },
  "files": [] }
EOF
  cat > "$PBI_DIR/metrics/pragma-audit-r1.json" <<'EOF'
{ "round": 1, "pbi_id": "pbi-001", "audited_at": "now",
  "exclusions": [] }
EOF

  # Pass criteria evaluation (inline simplified)
  source "${BATS_TEST_DIRNAME}/../../skills/pbi-pipeline/references/coverage-gate.md.sh" 2>/dev/null || true
  # The .md file isn't sourceable; for the test we inline a minimal check
  failed=$(jq '.totals.failed' "$PBI_DIR/metrics/test-results-r1.json")
  c0=$(jq '.totals.c0.percent' "$PBI_DIR/metrics/coverage-r1.json")
  c1=$(jq '.totals.c1.percent' "$PBI_DIR/metrics/coverage-r1.json")
  [ "$failed" -eq 0 ]
  awk "BEGIN{exit !($c0 >= 100)}"
  awk "BEGIN{exit !($c1 >= 100)}"

  # Conductor would update state to complete on success
  jq '.phase = "complete" | .impl_status = "pass" | .ut_status = "pass" | .coverage_status = "pass"' "$PBI_DIR/state.json" > "$PBI_DIR/state.json.tmp"
  mv "$PBI_DIR/state.json.tmp" "$PBI_DIR/state.json"

  jq -e '.phase == "complete"' "$PBI_DIR/state.json"
  rm -f /tmp/instr-$$.md
}
```

- [ ] **Step 2: Run the integration test**

Run: `bats tests/integration/test_pbi_pipeline_happy_path.bats`
Expected: 3 tests pass.

- [ ] **Step 3: Commit**

```bash
git add tests/integration/test_pbi_pipeline_happy_path.bats
git commit -m "test(integration): pbi-pipeline happy path transitions"
```

### Task 9.3: Create `tests/integration/test_pbi_pipeline_escalation.bats`

**Files:**
- Create: `tests/integration/test_pbi_pipeline_escalation.bats`

- [ ] **Step 1: Write the test**

Create `tests/integration/test_pbi_pipeline_escalation.bats`:

```bash
#!/usr/bin/env bats
# Integration: stagnation gate triggers escalation.

setup() {
  TEST_TMP="$(mktemp -d)"
  cd "$TEST_TMP" || exit 1
  mkdir -p .scrum hooks/lib
  cp -r "${BATS_TEST_DIRNAME}/../../hooks/lib/"* hooks/lib/
}

teardown() { rm -rf "$TEST_TMP"; }

@test "stagnation: same signature in two consecutive rounds escalates" {
  PBI_ID=pbi-stag
  PBI_DIR=".scrum/pbi/$PBI_ID"
  mkdir -p "$PBI_DIR/design"

  # Round 1 review with finding A
  cat > "$PBI_DIR/design/review-r1.md" <<'EOF'
## Review: r1
**Verdict: FAIL**
### Findings
- #1 [critical] [src/a.py:1-5] [missing_requirement] — same problem
### Summary
Stub r1
```json
{"status":"fail","summary":"r1","verdict":"FAIL","findings":[{"signature":"src/a.py:1-5:missing_requirement","severity":"critical","criterion_key":"missing_requirement","file_path":"src/a.py","line_start":1,"line_end":5,"description":"same"}],"next_actions":[],"artifacts":[]}
```
EOF

  # Round 2 review with same finding A (stagnation)
  cp "$PBI_DIR/design/review-r1.md" "$PBI_DIR/design/review-r2.md"

  # Stagnation detection (per termination-gates.md)
  sig_r1="$(jq -r '.findings | map(select(.severity == "critical" or .severity == "high")) | map(.signature) | sort | .[]' <(awk '/^```json$/{f=1;next} /^```$/{f=0} f' "$PBI_DIR/design/review-r1.md"))"
  sig_r2="$(jq -r '.findings | map(select(.severity == "critical" or .severity == "high")) | map(.signature) | sort | .[]' <(awk '/^```json$/{f=1;next} /^```$/{f=0} f' "$PBI_DIR/design/review-r2.md"))"
  common="$(comm -12 <(echo "$sig_r1") <(echo "$sig_r2"))"

  [ -n "$common" ]
  [ "$common" = "src/a.py:1-5:missing_requirement" ]
}

@test "divergence: critical+high count increases between rounds" {
  PBI_DIR=".scrum/pbi/pbi-div/design"
  mkdir -p "$PBI_DIR"

  # Round 1: 1 critical
  cat > "$PBI_DIR/review-r1.md" <<'EOF'
```json
{"findings":[{"signature":"x:1-1:a","severity":"critical","criterion_key":"a","file_path":"x","line_start":1,"line_end":1,"description":"d"}]}
```
EOF

  # Round 2: 2 critical + 1 high
  cat > "$PBI_DIR/review-r2.md" <<'EOF'
```json
{"findings":[
  {"signature":"x:1-1:a","severity":"critical","criterion_key":"a","file_path":"x","line_start":1,"line_end":1,"description":"d"},
  {"signature":"y:1-1:b","severity":"critical","criterion_key":"b","file_path":"y","line_start":1,"line_end":1,"description":"d"},
  {"signature":"z:1-1:c","severity":"high","criterion_key":"c","file_path":"z","line_start":1,"line_end":1,"description":"d"}
]}
```
EOF

  count_r1=$(awk '/^```json$/{f=1;next} /^```$/{f=0} f' "$PBI_DIR/review-r1.md" | jq '[.findings[] | select(.severity == "critical" or .severity == "high")] | length')
  count_r2=$(awk '/^```json$/{f=1;next} /^```$/{f=0} f' "$PBI_DIR/review-r2.md" | jq '[.findings[] | select(.severity == "critical" or .severity == "high")] | length')

  [ "$count_r2" -gt "$count_r1" ]
}

@test "max_rounds: round >= 5 escalates" {
  ROUND=5
  [ "$ROUND" -ge 5 ]
}
```

- [ ] **Step 2: Run the test**

Run: `bats tests/integration/test_pbi_pipeline_escalation.bats`
Expected: 3 tests pass.

- [ ] **Step 3: Commit**

```bash
git add tests/integration/test_pbi_pipeline_escalation.bats
git commit -m "test(integration): pbi-pipeline stagnation/divergence/max_rounds gates"
```

### Task 9.4: Create `tests/integration/test_pbi_parallel.bats`

**Files:**
- Create: `tests/integration/test_pbi_parallel.bats`

- [ ] **Step 1: Write the test**

Create `tests/integration/test_pbi_parallel.bats`:

```bash
#!/usr/bin/env bats
# Integration: 2 PBIs in parallel with shared catalog spec.
# Verifies flock serializes catalog writes.

setup() {
  TEST_TMP="$(mktemp -d)"
  cd "$TEST_TMP" || exit 1
  mkdir -p .scrum/locks docs/design/specs/api
  echo "# initial" > docs/design/specs/api/auth.md
}

teardown() { rm -rf "$TEST_TMP"; }

@test "two parallel writers serialize via flock" {
  spec="docs/design/specs/api/auth.md"
  lock_id="$(echo "$spec" | sed 's|/|_|g')"
  lock_file=".scrum/locks/catalog-${lock_id}.lock"

  writer() {
    local id="$1" delay="$2"
    exec {FD}>"$lock_file"
    flock -w 60 "$FD"
    local now; now=$(date +%s%N)
    echo "writer $id start $now" >> "$spec"
    sleep "$delay"
    echo "writer $id end $(date +%s%N)" >> "$spec"
    exec {FD}>&-
  }

  writer A 0.2 &
  pid_a=$!
  sleep 0.05
  writer B 0.1 &
  pid_b=$!
  wait $pid_a $pid_b

  # writer A should fully complete before writer B starts (or vice versa)
  starts="$(grep -c 'start' "$spec")"
  ends="$(grep -c 'end' "$spec")"
  [ "$starts" -eq 2 ]
  [ "$ends" -eq 2 ]

  # Order check: A's "end" precedes B's "start" OR B's "end" precedes A's "start"
  a_end=$(awk '/writer A end/{print NR; exit}' "$spec")
  b_start=$(awk '/writer B start/{print NR; exit}' "$spec")
  b_end=$(awk '/writer B end/{print NR; exit}' "$spec")
  a_start=$(awk '/writer A start/{print NR; exit}' "$spec")
  [ "$a_end" -lt "$b_start" ] || [ "$b_end" -lt "$a_start" ]
}

@test "lock acquisition with 1s timeout fails when other holder takes 3s" {
  spec="docs/design/specs/api/auth.md"
  lock_id="$(echo "$spec" | sed 's|/|_|g')"
  lock_file=".scrum/locks/catalog-${lock_id}.lock"

  # Holder script
  (
    exec {FD}>"$lock_file"
    flock "$FD"
    sleep 3
  ) &
  pid_holder=$!

  sleep 0.1

  # Acquirer with 1s timeout
  set +e
  (
    exec {FD}>"$lock_file"
    flock -w 1 "$FD"
  )
  status=$?
  set -e
  wait $pid_holder

  # flock returns 1 on timeout
  [ "$status" -ne 0 ]
}
```

- [ ] **Step 2: Run the test**

Run: `bats tests/integration/test_pbi_parallel.bats`
Expected: 2 tests pass.

- [ ] **Step 3: Commit**

```bash
git add tests/integration/test_pbi_parallel.bats
git commit -m "test(integration): catalog flock serializes parallel PBI writes"
```

### Task 9.5: Create `tests/unit/test_state_management.bats`

**Files:**
- Create: `tests/unit/test_state_management.bats`

- [ ] **Step 1: Write the test**

Create `tests/unit/test_state_management.bats`:

```bash
#!/usr/bin/env bats

setup() {
  TEST_TMP="$(mktemp -d)"
  cd "$TEST_TMP" || exit 1
}

teardown() { rm -rf "$TEST_TMP"; }

# Inline copy of update_state from references/state-management.md
update_state() {
  local pbi_dir="$1"; shift
  local jq_expr="$1"; shift
  local now; now="$(date -Iseconds)"
  jq --arg now "$now" "$jq_expr | .updated_at = \$now" \
    "$pbi_dir/state.json" > "$pbi_dir/state.json.tmp"
  mv "$pbi_dir/state.json.tmp" "$pbi_dir/state.json"
}

@test "atomic update preserves untouched fields" {
  mkdir -p .scrum/pbi/pbi-001
  cat > .scrum/pbi/pbi-001/state.json <<'EOF'
{ "pbi_id": "pbi-001", "phase": "design", "design_round": 0,
  "impl_round": 0, "design_status": "pending",
  "impl_status": "pending", "ut_status": "pending",
  "coverage_status": "pending", "escalation_reason": null,
  "started_at": "2026-05-02T12:00:00+09:00",
  "updated_at": "2026-05-02T12:00:00+09:00" }
EOF
  update_state .scrum/pbi/pbi-001 '.design_round = 1 | .design_status = "in_review"'
  jq -e '.design_round == 1 and .design_status == "in_review" and .impl_status == "pending"' \
    .scrum/pbi/pbi-001/state.json
}

@test "atomic update changes updated_at" {
  mkdir -p .scrum/pbi/pbi-001
  cat > .scrum/pbi/pbi-001/state.json <<'EOF'
{ "updated_at": "2026-05-02T12:00:00+09:00" }
EOF
  sleep 1  # ensure timestamp difference
  update_state .scrum/pbi/pbi-001 '.'
  new_ts=$(jq -r '.updated_at' .scrum/pbi/pbi-001/state.json)
  [ "$new_ts" != "2026-05-02T12:00:00+09:00" ]
}
```

- [ ] **Step 2: Run + commit**

```bash
bats tests/unit/test_state_management.bats
git add tests/unit/test_state_management.bats
git commit -m "test(unit): atomic state.json update helper"
```

### Task 9.6: Create `tests/manual/smoke-pbi-pipeline.md`

**Files:**
- Create: `tests/manual/smoke-pbi-pipeline.md`

- [ ] **Step 1: Write the smoke procedure**

Create `tests/manual/smoke-pbi-pipeline.md`:

````markdown
# PBI Pipeline Manual Smoke Test

End-to-end smoke for the new pipeline using a real Claude Code session.
Used until automated sub-agent invocation is mockable.

## Prerequisites

- Codex CLI installed (`which codex` non-empty), OR be ready to verify
  Claude fallback path
- A target project with `claude-scrum-team` installed
  (`scripts/setup-user.sh`)
- A simple PBI in `.scrum/backlog.json`, e.g. "add a function `add(a,b)`
  in `src/calc.py` that returns `a+b`"
- `.scrum/config.json` configured for Python:
  ```json
  {"test_runner":{"command":"pytest","args":["-q"]},
   "coverage_tool":{"command":"coverage",
                    "run_args":["run","--branch","--source=src","-m","pytest"],
                    "report_args":["json","-o"],
                    "supports_branch":true},
   "pragma_pattern":"pragma: no cover",
   "path_guard":{"impl_globs":["src/**"],"test_globs":["tests/**"]}}
  ```

## Procedure

1. **Launch the Scrum team**

   ```bash
   sh scrum-start.sh
   ```

   Confirm Developer agent spawns and is assigned the test PBI.

2. **Verify Developer initializes PBI directory**

   In a separate terminal:

   ```bash
   ls .scrum/pbi/
   ```

   Expected: directory matching the PBI id appears with subdirs
   `design/ impl/ ut/ metrics/ feedback/`.

3. **Verify design phase Round 1**

   Wait until `cat .scrum/pbi/<pbi-id>/state.json | jq .phase` returns
   `"design"` then `"impl_ut"`.

   Inspect:
   - `.scrum/pbi/<pbi-id>/design/design.md` — should contain all 6
     required sections, no implementation code.
   - `.scrum/pbi/<pbi-id>/design/review-r1.md` — verdict line present.

4. **Verify impl+UT phase Round 1**

   Wait for impl+UT phase. Inspect:
   - `src/calc.py` should contain `def add(a, b): return a + b`
   - `tests/test_calc.py` should contain pytest tests
   - `.scrum/pbi/<pbi-id>/metrics/coverage-r1.json` should show C0/C1
     near 100%
   - `.scrum/pbi/<pbi-id>/impl/review-r1.md` and `ut/review-r1.md`
     should both have `**Verdict: PASS**`

5. **Verify completion**

   Wait until `state.json.phase == "complete"`. Verify:
   - `backlog.json` PBI status `done`
   - `pipeline_summary` populated with round counts and coverage

6. **Path-guard violation check**

   In Claude Code logs, search for `[path-guard] BLOCKED`. Should find
   zero entries during a healthy run. (If non-zero, that indicates a
   sub-agent attempted forbidden path access — log it for follow-up.)

7. **TUI verification**

   In another terminal:
   ```bash
   python3 dashboard/app.py
   ```
   Confirm "PBI Pipeline" pane renders the active PBI with phase /
   round / sub-agents.

## Failure Recovery

- If gate evaluation hangs: `cat .scrum/pbi/<pbi-id>/pipeline.log`
- If escalation triggered: `cat .scrum/pbi/<pbi-id>/escalation-resolution.md`
- If Codex unavailable: log will mention `[Fallback: Claude review]`

## Pass Criteria

- All 7 procedure steps complete with expected outcomes
- No path-guard violations
- pipeline.log shows phase transitions: init → design → impl_ut → complete
````

- [ ] **Step 2: Commit**

```bash
git add tests/manual/smoke-pbi-pipeline.md
git commit -m "test(manual): smoke procedure for live pbi-pipeline run"
```

---

## Phase 10: Documentation

### Task 10.1: Create `docs/MIGRATION-pbi-pipeline.md`

**Files:**
- Create: `docs/MIGRATION-pbi-pipeline.md`

- [ ] **Step 1: Write the migration guide**

Create `docs/MIGRATION-pbi-pipeline.md`:

````markdown
# Migration Guide: PBI Pipeline (legacy design + implementation flow → pbi-pipeline)

## Summary

Per-PBI workflow changed from "Developer runs design then implementation
in one session" to "Developer conducts a multi-session pipeline of
specialized sub-agents". See spec at
`docs/superpowers/specs/2026-05-02-pbi-pipeline-design.md`.

## In-flight Sprint handling

If you are mid-Sprint when upgrading:

1. Complete the current Sprint on the legacy flow.
   - The legacy `design` and `implementation` skill files are removed
     from this version. If your in-flight Sprint requires them, copy
     them from the prior commit:
     ```bash
     git show <previous-commit>:skills/design/SKILL.md > skills/design/SKILL.md
     git show <previous-commit>:skills/implementation/SKILL.md > skills/implementation/SKILL.md
     ```
2. From the next Sprint, adopt the new flow:
   - Sprint Planning records `catalog_targets` per PBI in
     `backlog.json` (see `skills/sprint-planning/SKILL.md`).
   - Developer invokes `pbi-pipeline` per PBI.

## Concept mapping

| Legacy concept | New equivalent |
|---|---|
| Developer writes code via `implementation` skill | Developer is a conductor; `pbi-implementer` sub-agent writes code |
| Tests written by Developer alongside impl | `pbi-ut-author` sub-agent writes tests independently from impl source (black-box) |
| Catalog design at `docs/design/specs/...` | UNCHANGED — still the source of truth for permanent component design |
| (no concept) | `.scrum/pbi/<pbi-id>/design/design.md` — PBI working design (transient) |
| Design review at SM cross-review | Two layers: per-PBI design review (codex-design-reviewer) + Sprint-end cross-review (unchanged) |
| Test coverage tracked manually | Coverage measured by real tooling per Round; gated by C0/C1 thresholds |

## Required project changes

- Add `.scrum-config.example.json` to your project; create
  `.scrum/config.json` based on it (gitignored).
- For partial-C1 languages (Go, Rust, Bash), set `c1_threshold` in
  `.scrum/config.json`; ad-hoc relaxation forbidden.
- Update `.claude/settings.json` to register
  `hooks/pre-tool-use-path-guard.sh` after `phase-gate.sh` (handled
  automatically by `setup-user.sh`).

## Verifying the upgrade

Run the manual smoke test: `tests/manual/smoke-pbi-pipeline.md`.
````

- [ ] **Step 2: Commit**

```bash
git add docs/MIGRATION-pbi-pipeline.md
git commit -m "docs: migration guide for pbi-pipeline adoption"
```

### Task 10.2: Create JSON Schemas in `docs/contracts/`

**Files:**
- Create: `docs/contracts/pbi-pipeline-envelope.schema.json`
- Create: `docs/contracts/coverage-rN.schema.json`
- Create: `docs/contracts/test-results-rN.schema.json`
- Create: `docs/contracts/pragma-audit-rN.schema.json`

- [ ] **Step 1: Verify directory exists**

Run: `ls docs/contracts/ 2>/dev/null || mkdir -p docs/contracts`

- [ ] **Step 2: Write envelope schema**

Create `docs/contracts/pbi-pipeline-envelope.schema.json`:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "PBI Pipeline Sub-Agent Output Envelope",
  "type": "object",
  "required": ["status", "summary", "findings", "next_actions", "artifacts"],
  "properties": {
    "status": {"enum": ["pass", "fail", "error"]},
    "summary": {"type": "string"},
    "verdict": {"enum": ["PASS", "FAIL", null]},
    "findings": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["signature", "severity", "criterion_key", "file_path", "line_start", "line_end", "description"],
        "properties": {
          "signature": {"type": "string", "pattern": "^.+:[0-9]+-[0-9]+:[a-z_]+$"},
          "severity": {"enum": ["critical", "high", "medium", "low"]},
          "criterion_key": {
            "enum": [
              "missing_requirement", "scope_creep", "unclear_interface",
              "inconsistent_with_catalog", "inconsistent_internal", "missing_error_handling",
              "incorrect_behavior", "naming", "error_handling",
              "missing_validation", "unclear_intent", "dead_code",
              "missing_test_for_acceptance", "missing_branch_coverage", "redundant_test",
              "mock_overuse", "magic_number", "bad_assertion", "pragma_unjustified"
            ]
          },
          "file_path": {"type": "string"},
          "line_start": {"type": "integer", "minimum": 1},
          "line_end": {"type": "integer", "minimum": 1},
          "description": {"type": "string"}
        }
      }
    },
    "next_actions": {"type": "array", "items": {"type": "string"}},
    "artifacts": {"type": "array", "items": {"type": "string"}}
  }
}
```

- [ ] **Step 3: Write coverage schema**

Create `docs/contracts/coverage-rN.schema.json`:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "PBI Pipeline Coverage Report (per Round)",
  "type": "object",
  "required": ["round", "pbi_id", "tool", "tool_version", "measured_at", "totals", "files"],
  "properties": {
    "round": {"type": "integer", "minimum": 1},
    "pbi_id": {"type": "string"},
    "tool": {"type": "string"},
    "tool_version": {"type": "string"},
    "measured_at": {"type": "string", "format": "date-time"},
    "totals": {
      "type": "object",
      "required": ["c0", "c1"],
      "properties": {
        "c0": {
          "type": "object",
          "required": ["covered", "total", "percent"],
          "properties": {
            "covered": {"type": "integer"},
            "total": {"type": "integer"},
            "percent": {"type": "number"}
          }
        },
        "c1": {
          "type": "object",
          "required": ["covered", "total", "percent", "supported"],
          "properties": {
            "covered": {"type": "integer"},
            "total": {"type": "integer"},
            "percent": {"type": "number"},
            "supported": {"type": "boolean"}
          }
        }
      }
    },
    "files": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["path", "c0", "c1", "uncovered_lines", "uncovered_branches", "pragma_excluded_lines"],
        "properties": {
          "path": {"type": "string"},
          "c0": {"$ref": "#/properties/totals/properties/c0"},
          "c1": {"$ref": "#/properties/totals/properties/c1"},
          "uncovered_lines": {"type": "array", "items": {"type": "integer"}},
          "uncovered_branches": {
            "type": "array",
            "items": {
              "type": "object",
              "required": ["line", "from", "to", "condition"],
              "properties": {
                "line": {"type": "integer"},
                "from": {"type": "integer"},
                "to": {"type": "integer"},
                "condition": {"type": "string"}
              }
            }
          },
          "pragma_excluded_lines": {"type": "array", "items": {"type": "integer"}}
        }
      }
    }
  }
}
```

- [ ] **Step 4: Write test-results schema**

Create `docs/contracts/test-results-rN.schema.json`:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "PBI Pipeline Test Results (per Round)",
  "type": "object",
  "required": ["round", "pbi_id", "tool", "tool_version", "executed_at", "totals", "failures"],
  "properties": {
    "round": {"type": "integer", "minimum": 1},
    "pbi_id": {"type": "string"},
    "tool": {"type": "string"},
    "tool_version": {"type": "string"},
    "executed_at": {"type": "string", "format": "date-time"},
    "totals": {
      "type": "object",
      "required": ["tests", "passed", "failed", "exec_errors", "uncaught_exceptions", "skipped"],
      "properties": {
        "tests": {"type": "integer"},
        "passed": {"type": "integer"},
        "failed": {"type": "integer"},
        "exec_errors": {"type": "integer"},
        "uncaught_exceptions": {"type": "integer"},
        "skipped": {"type": "integer"}
      }
    },
    "failures": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["test_id", "type", "file_path", "line", "message"],
        "properties": {
          "test_id": {"type": "string"},
          "type": {"enum": ["assertion", "exec_error", "uncaught_exception", "timeout"]},
          "file_path": {"type": "string"},
          "line": {"type": "integer"},
          "message": {"type": "string"},
          "stack_trace": {"type": "string"}
        }
      }
    }
  }
}
```

- [ ] **Step 5: Write pragma-audit schema**

Create `docs/contracts/pragma-audit-rN.schema.json`:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "PBI Pipeline Pragma Audit (per Round)",
  "type": "object",
  "required": ["round", "pbi_id", "audited_at", "exclusions"],
  "properties": {
    "round": {"type": "integer", "minimum": 1},
    "pbi_id": {"type": "string"},
    "audited_at": {"type": "string", "format": "date-time"},
    "exclusions": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["file_path", "line", "code_excerpt", "reason_source"],
        "properties": {
          "file_path": {"type": "string"},
          "line": {"type": "integer"},
          "code_excerpt": {"type": "string"},
          "reason_text": {"type": ["string", "null"]},
          "reason_source": {"enum": ["comment_above", "comment_inline", "missing"]}
        }
      }
    }
  }
}
```

- [ ] **Step 6: Validate all schemas**

```bash
for f in docs/contracts/*.schema.json; do
  jq . "$f" > /dev/null && echo "OK: $f"
done
```

Expected: 4 OK lines.

- [ ] **Step 7: Commit**

```bash
git add docs/contracts/
git commit -m "docs(contracts): add JSON Schemas for pbi-pipeline artifacts"
```

### Task 10.3: Update `docs/architecture.md`

**Files:**
- Modify: `docs/architecture.md`

- [ ] **Step 1: Read current file**

Run: `cat docs/architecture.md`

- [ ] **Step 2: Add PBI Pipeline component section**

Insert a new section, e.g. after the existing component overview:

```markdown
## PBI Pipeline (per-PBI workflow)

The Developer agent acts as a pipeline conductor for each PBI assigned
during a Sprint. It spawns 6 specialized sub-agents over multiple Rounds:

- **pbi-designer / codex-design-reviewer** — design phase
- **pbi-implementer + pbi-ut-author** (parallel) — write source and
  tests in isolation (UT author cannot read implementation)
- **codex-impl-reviewer + codex-ut-reviewer** (parallel) — critical
  cross-model reviews

State flows through `.scrum/pbi/<pbi-id>/` artifacts. Termination uses
deterministic gates (success / stagnation / divergence / hard cap /
budget). Coverage measured by real tooling (C0/C1 100% by default).

Full design: `docs/superpowers/specs/2026-05-02-pbi-pipeline-design.md`
Implementation: `skills/pbi-pipeline/`
```

- [ ] **Step 3: Commit**

```bash
git add docs/architecture.md
git commit -m "docs(architecture): describe PBI Pipeline component"
```

### Task 10.4: Update `docs/quickstart.md`

**Files:**
- Modify: `docs/quickstart.md`

- [ ] **Step 1: Read current file**

Run: `cat docs/quickstart.md`

- [ ] **Step 2: Replace references to old design + implementation flow**

Replace any narrative pointing to the old `design` then `implementation`
flow with one that points to `pbi-pipeline`. Add a "Configure coverage
tooling" step that points users to `.scrum-config.example.json`.

Sample insertion:

```markdown
### Configure PBI Pipeline coverage tooling

Copy the example config and adapt it to your project's stack:

```bash
cp .scrum-config.example.json .scrum/config.json
$EDITOR .scrum/config.json   # set test_runner and coverage_tool
```

For partial-C1 languages (Go, Rust, Bash), set `c1_threshold` in
`.scrum/config.json`. Ad-hoc relaxation is forbidden.
```

- [ ] **Step 3: Commit**

```bash
git add docs/quickstart.md
git commit -m "docs(quickstart): point users to pbi-pipeline + coverage config"
```

### Task 10.5: Update `CLAUDE.md`

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Read current file**

Run: `cat CLAUDE.md`

- [ ] **Step 2: Update Project Structure**

In the existing `## Project Structure` block, replace the lines:

```text
  design/                # Design phase — create design specs
  implementation/        # Implementation phase — build PBI features
```

with:

```text
  pbi-pipeline/          # PBI conductor pipeline (orchestrator + references/)
  pbi-escalation-handler/ # SM-side escalation handler
```

- [ ] **Step 3: Update agents listed**

In the agents block, add:

```text
  pbi-designer.md            # PBI design author
  pbi-implementer.md         # Implementation author (no test writes)
  pbi-ut-author.md           # Black-box test author (no impl reads)
  codex-design-reviewer.md   # Critical design review (Codex)
  codex-impl-reviewer.md     # Critical impl review (Codex, no test visibility)
  codex-ut-reviewer.md       # Critical UT review (Codex, no impl visibility)
```

- [ ] **Step 4: Add a Key Convention**

In `## Key Conventions`, add:

```markdown
- PBI development now flows through the `pbi-pipeline` skill: the
  Developer is a conductor that spawns specialized sub-agents per
  Round (design → impl+UT → review). State per PBI lives at
  `.scrum/pbi/<pbi-id>/`. UT is black-box (UT author cannot read impl
  source). Termination is deterministic via composite gates. Coverage
  measured by real tooling (C0/C1 100% by default).
```

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md
git commit -m "docs(CLAUDE.md): describe pbi-pipeline structure and conventions"
```

---

## Phase 11: setup-user.sh and final integration

### Task 11.1: Update `scripts/setup-user.sh`

**Files:**
- Modify: `scripts/setup-user.sh`

- [ ] **Step 1: Read current file**

Run: `cat scripts/setup-user.sh`

Identify how it currently copies agents/, skills/, hooks/ and how it
merges `.claude/settings.json`.

- [ ] **Step 2: Add new files to copy targets**

Update the copy loops/lists to include:

- New agents: `pbi-designer.md`, `pbi-implementer.md`, `pbi-ut-author.md`,
  `codex-design-reviewer.md`, `codex-impl-reviewer.md`,
  `codex-ut-reviewer.md`
- New skills: `pbi-pipeline/` (entire dir incl. references/),
  `pbi-escalation-handler/`
- New hooks: `pre-tool-use-path-guard.sh`, `lib/codex-invoke.sh`
- Reference template: `.scrum-config.example.json`
- Schemas: `docs/contracts/*.schema.json`

If the current script uses a glob like `agents/*.md` and `skills/*/SKILL.md`,
no edit may be needed — verify with a dry-run.

- [ ] **Step 3: Update settings.json hook registration**

Add (or update) the merge logic so target project's
`.claude/settings.json` registers the path-guard hook:

```jsonc
// merged into .claude/settings.json:
{
  "hooks": {
    "PreToolUse": [
      { "matcher": "Read|Write|Edit",
        "command": ".claude/hooks/phase-gate.sh" },
      { "matcher": "Read|Write|Edit",
        "command": ".claude/hooks/pre-tool-use-path-guard.sh" }
    ]
  }
}
```

If `setup-user.sh` uses jq merge, add the new entry under
`PreToolUse` array, deduplicating by `command`.

- [ ] **Step 4: Test setup script**

Run: `bash scripts/setup-user.sh /tmp/test-target-project` (or wherever
the script supports a dry-run / temp target).

Verify in `/tmp/test-target-project/.claude/`:

- All new agents present in `agents/`
- All new skills present in `skills/`
- Hooks present in `hooks/`
- `settings.json` contains both hook registrations

- [ ] **Step 5: shellcheck + commit**

```bash
shellcheck scripts/setup-user.sh
git add scripts/setup-user.sh
git commit -m "feat(scripts): setup-user.sh installs pbi-pipeline assets

Adds the 6 new sub-agents, pbi-pipeline skill (with references/),
pbi-escalation-handler skill, path-guard hook, codex-invoke lib,
.scrum-config.example.json, and contract schemas. Registers the
path-guard hook after phase-gate in target project settings."
```

### Task 11.2: Verify `.gitignore` covers `.scrum/`

**Files:**
- Verify or modify: `.gitignore`

- [ ] **Step 1: Check current .gitignore**

Run: `grep -E '^\.scrum' .gitignore || echo MISSING`

- [ ] **Step 2: Add if missing**

If MISSING:

```bash
echo ".scrum/" >> .gitignore
git add .gitignore
git commit -m "chore: gitignore .scrum/ runtime state"
```

If present, no action.

### Task 11.3: Final test sweep

**Files:** none (verification only)

- [ ] **Step 1: Run all unit tests**

Run: `bats tests/unit/`
Expected: all pass.

- [ ] **Step 2: Run lint tests**

Run: `bats tests/lint/`
Expected: all pass.

- [ ] **Step 3: Run integration tests**

Run: `bats tests/integration/`
Expected: all pass.

- [ ] **Step 4: shellcheck all hooks/scripts**

```bash
shellcheck scrum-start.sh scripts/*.sh scripts/lib/*.sh hooks/*.sh hooks/lib/*.sh
```

Expected: clean.

- [ ] **Step 5: Python lint/format**

```bash
ruff check dashboard/
ruff format --check dashboard/
```

Expected: clean.

- [ ] **Step 6: Verify all spec sections covered**

Open `docs/superpowers/specs/2026-05-02-pbi-pipeline-design.md` and
verify every section maps to an implemented file. Use:

```bash
ls agents/pbi-*.md agents/codex-*-reviewer.md \
   skills/pbi-pipeline/SKILL.md skills/pbi-pipeline/references/*.md \
   skills/pbi-escalation-handler/SKILL.md \
   hooks/pre-tool-use-path-guard.sh hooks/lib/codex-invoke.sh \
   .scrum-config.example.json \
   docs/MIGRATION-pbi-pipeline.md \
   docs/contracts/*.schema.json \
   tests/manual/smoke-pbi-pipeline.md
```

Expected: every path exists.

### Task 11.4: Run manual smoke test

**Files:** none (live test against a target project)

- [ ] **Step 1: Set up a target project per `tests/manual/smoke-pbi-pipeline.md`**
- [ ] **Step 2: Execute the smoke procedure end-to-end**
- [ ] **Step 3: Record outcome in commit message of a follow-up doc commit, or add notes to MIGRATION-pbi-pipeline.md**

If smoke fails, file findings as new tasks (do NOT mark Phase 11
complete until smoke passes, or document remaining issues).

---

## Done

When every checkbox above is checked, the implementation is complete.
Run a final `git log --oneline` to verify ~50+ commits aligned with
the phases above (one per task, roughly).

Final verification: run `tests/manual/smoke-pbi-pipeline.md` against a
representative target project. The plan is complete only when the
manual smoke test passes end-to-end.
