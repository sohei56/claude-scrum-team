# `.scrum/` State Tools — Implementation Plan (Issue #18 expanded)

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace raw `jq`/Python edits of `.scrum/*.json` with a validated tool layer (write scripts + JSON Schema SSOT + PreToolUse enforcement hook), so agents cannot silently corrupt sprint-level state and dashboard readers can trust types.

**Architecture:** Three layers — (1) JSON Schemas under `docs/contracts/scrum-state/` are the SSOT for types; (2) Bash wrappers under `scripts/scrum/` validate inputs against the schemas, take an `flock` per file, write atomically (`tmp` + `mv`), and emit consistent error messages; (3) a PreToolUse hook (`hooks/pre-tool-use-scrum-state-guard.sh`) blocks agent `Write`/`Edit` and raw redirect/jq-in-place against `.scrum/**/*.json`, forcing all writes through the scripts.

**Tech Stack:** Bash 3.2+, `jq`, `flock` (util-linux on Linux; `shlock` fallback on macOS), `ajv-cli` for schema validation (Node, lightweight), bats for tests.

---

## Scope and non-goals

In scope (sprint-level state):
- `.scrum/state.json` — phase machine
- `.scrum/sprint.json` — current Sprint, developer assignments
- `.scrum/backlog.json` — PBI list and status
- `.scrum/communications.json` — agent-to-agent messages (append-heavy)
- `.scrum/dashboard.json` — TUI events (append-heavy)
- `.scrum/pbi/<pbi-id>/state.json` — PBI pipeline phase machine (introduced by PR #22)

Out of scope:
- `.scrum/sprint-history.json`, `.scrum/improvements.json`, `.scrum/test-results.json`, `.scrum/session-map.json` — append-only logs / lower-frequency writes; covered in a follow-up after MVP soaks.
- `hooks/dashboard-event.sh` write paths — these run inside hooks, not from agent tool calls. They will use the same scripts but the enforcement hook will not block them (PreToolUse fires on agent tool calls, not on hook internals).
- SQLite migration (explicitly rejected by user).
- Read-side. `cat`/`jq` reads stay free; SSOT schemas are the contract for readers.
- PBI sub-agent envelope/coverage/test-results/pragma-audit schemas — already shipped by PR #22.

Assumes PR #22 is merged before Phase B begins. The new `.scrum/pbi/<id>/state.json` and the existing `update_state()` helper inside `skills/pbi-pipeline/references/state-management.md` are inherited as-is and migrated in Phase D.

---

## File structure

Created:
```
docs/contracts/scrum-state/
  README.md                        — schema index, write-script mapping
  state.schema.json                — .scrum/state.json
  sprint.schema.json               — .scrum/sprint.json
  backlog.schema.json              — .scrum/backlog.json
  communications.schema.json       — .scrum/communications.json (array element schema + envelope)
  dashboard.schema.json            — .scrum/dashboard.json (array element schema + envelope)
  pbi-state.schema.json            — .scrum/pbi/<id>/state.json
scripts/scrum/
  lib/atomic.sh                    — flock + tmp+mv + ajv validate helper, ts utils, jq-arg builder
  lib/errors.sh                    — emit "[scrum-tool] CODE: msg" to stderr, fixed exit codes
  update-backlog-status.sh         — set PBI status (draft|refined|in_progress|review|done|blocked)
  update-sprint-status.sh          — set sprint phase (planning|active|cross_review|sprint_review|complete)
  set-sprint-developer.sh          — set sprint.developers[<id>].<field>
  update-state-phase.sh            — set top-level phase machine
  append-communication.sh          — push one message to communications.json
  append-dashboard-event.sh        — push one event to dashboard.json
  update-pbi-state.sh              — set fields on .scrum/pbi/<id>/state.json (replaces inline update_state)
hooks/pre-tool-use-scrum-state-guard.sh
                                   — denies raw .scrum/**/*.json writes from agents
docs/MIGRATION-scrum-state-tools.md
                                   — migration guide for skill authors
tests/unit/scrum-state/
  test_update-backlog-status.bats
  test_update-sprint-status.bats
  test_set-sprint-developer.bats
  test_update-state-phase.bats
  test_append-communication.bats
  test_append-dashboard-event.bats
  test_update-pbi-state.bats
  test_atomic-lib.bats
  test_state-guard-hook.bats
tests/fixtures/scrum-state/
  valid-state.json
  valid-sprint.json
  valid-backlog.json (extends existing fixture)
  valid-communications.json
  valid-dashboard.json
  valid-pbi-state.json
```

Modified:
```
.claude/settings.json              — register PreToolUse hook
skills/implementation/SKILL.md     — replace jq inline (line 39 today, post-#22 may shift)
skills/cross-review/SKILL.md       — replace jq inline (lines 36, 49 today)
skills/pbi-pipeline/references/state-management.md
                                   — replace `update_state()` helper with `scripts/scrum/update-pbi-state.sh`
skills/sprint-planning/SKILL.md    — audited for raw writes, migrated if any
skills/spawn-teammates/SKILL.md    — same
skills/sprint-review/SKILL.md      — same
skills/install-subagents/SKILL.md  — same
hooks/dashboard-event.sh           — switch internal jq writes to call scripts/scrum/append-* (optional; documented but not enforced)
CLAUDE.md                          — note state-management policy
```

---

## Self-review checklist additions

Before marking the plan complete:
- [ ] Every script has a bats test that covers (a) happy path, (b) invalid arg, (c) schema violation, (d) concurrent write race.
- [ ] Hook test covers (a) Write blocked, (b) Edit blocked, (c) `jq ... > .scrum/x.json` Bash blocked, (d) `cat .scrum/x.json` Bash allowed (read), (e) `scripts/scrum/...` Bash allowed.
- [ ] No skill still contains an inline `jq '... > .scrum/...'` after Phase D.

---

## Task 1: Create schema directory and README

**Files:**
- Create: `docs/contracts/scrum-state/README.md`
- Test: none (doc only)

- [ ] **Step 1: Write README**

```markdown
# `.scrum/` Sprint State Schemas (SSOT)

Each schema corresponds to one file under `.scrum/` and is the single source of truth for its type. Both write scripts (`scripts/scrum/*.sh`) and readers (dashboard, hooks) MUST validate against these schemas.

| File                                | Schema                                | Write script                                       |
|-------------------------------------|---------------------------------------|----------------------------------------------------|
| `.scrum/state.json`                 | `state.schema.json`                   | `scripts/scrum/update-state-phase.sh`              |
| `.scrum/sprint.json`                | `sprint.schema.json`                  | `scripts/scrum/update-sprint-status.sh`, `set-sprint-developer.sh` |
| `.scrum/backlog.json`               | `backlog.schema.json`                 | `scripts/scrum/update-backlog-status.sh`           |
| `.scrum/communications.json`        | `communications.schema.json`          | `scripts/scrum/append-communication.sh`            |
| `.scrum/dashboard.json`             | `dashboard.schema.json`               | `scripts/scrum/append-dashboard-event.sh`          |
| `.scrum/pbi/<id>/state.json`        | `pbi-state.schema.json`               | `scripts/scrum/update-pbi-state.sh`                |

## Schema versioning

Each schema declares a top-level `schema_version` integer. Bumping a schema requires:
1. New schema file `*-vN.schema.json` alongside the old.
2. Migration script under `scripts/scrum/migrations/`.
3. Update of write scripts to validate against the new version.

## Out of scope (covered elsewhere)

- PBI pipeline sub-agent envelopes — see `docs/contracts/pbi-pipeline-envelope.schema.json` and friends (PR #22).
- Append-only logs (`.scrum/hooks.log`, `.scrum/communications.log`, `.scrum/pbi/<id>/pipeline.log`) — line-formatted, no JSON schema.
```

- [ ] **Step 2: Commit**

```bash
git add docs/contracts/scrum-state/README.md
git commit -m "docs: add scrum-state schemas index"
```

---

## Task 2: Define `state.schema.json`

**Files:**
- Create: `docs/contracts/scrum-state/state.schema.json`
- Test: none yet (validated by Task 8 atomic lib tests)

- [ ] **Step 1: Read current `.scrum/state.json` shape**

Run: `git show origin/feat/pbi-pipeline-impl:hooks/session-context.sh | grep -A 20 STATE_FILE`
Then inspect any test fixtures: `cat tests/fixtures/valid-backlog.json` and search for state fixtures.
Expected: confirm fields `phase`, `current_sprint`, `created_at`, `updated_at`, plus PR #22's `active_pbi_pipelines[]`.

- [ ] **Step 2: Write the schema**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Scrum sprint-level state",
  "type": "object",
  "required": ["schema_version", "phase", "created_at", "updated_at"],
  "additionalProperties": false,
  "properties": {
    "schema_version": {"const": 1},
    "phase": {
      "enum": [
        "new", "requirements_sprint", "backlog_created",
        "sprint_planning", "design", "implementation",
        "review", "sprint_review", "retrospective",
        "integration_sprint", "complete"
      ]
    },
    "current_sprint": {"type": ["string", "null"], "pattern": "^s[0-9]+$"},
    "active_pbi_pipelines": {
      "type": "array",
      "items": {"type": "string", "pattern": "^pbi-[0-9]+$"},
      "uniqueItems": true,
      "default": []
    },
    "created_at": {"type": "string", "format": "date-time"},
    "updated_at": {"type": "string", "format": "date-time"}
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add docs/contracts/scrum-state/state.schema.json
git commit -m "docs: add .scrum/state.json schema (SSOT)"
```

---

## Task 3: Define `sprint.schema.json`

**Files:**
- Create: `docs/contracts/scrum-state/sprint.schema.json`

- [ ] **Step 1: Inspect existing `.scrum/sprint.json` shape**

Run: `grep -nE 'developers|status|sprint_id' hooks/completion-gate.sh hooks/session-context.sh skills/spawn-teammates/SKILL.md skills/sprint-planning/SKILL.md`
Expected: identify `sprint_id`, `status`, `goal`, `pbi_ids[]`, `developers{<id>: {current_pbi, current_pbi_phase, status}}`.

- [ ] **Step 2: Write the schema**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Current sprint state",
  "type": "object",
  "required": ["schema_version", "sprint_id", "status", "created_at", "updated_at"],
  "additionalProperties": false,
  "properties": {
    "schema_version": {"const": 1},
    "sprint_id": {"type": "string", "pattern": "^s[0-9]+$"},
    "status": {"enum": ["planning", "active", "cross_review", "sprint_review", "complete"]},
    "goal": {"type": ["string", "null"]},
    "pbi_ids": {"type": "array", "items": {"type": "string", "pattern": "^pbi-[0-9]+$"}, "uniqueItems": true},
    "developers": {
      "type": "object",
      "patternProperties": {
        "^dev-[0-9]+-s[0-9]+$": {
          "type": "object",
          "required": ["status"],
          "additionalProperties": false,
          "properties": {
            "current_pbi": {"type": ["string", "null"], "pattern": "^pbi-[0-9]+$"},
            "current_pbi_phase": {"type": ["string", "null"], "enum": [null, "design", "impl_ut", "complete", "escalated"]},
            "status": {"enum": ["idle", "working", "reviewing", "blocked", "terminated"]}
          }
        }
      },
      "additionalProperties": false
    },
    "created_at": {"type": "string", "format": "date-time"},
    "updated_at": {"type": "string", "format": "date-time"}
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add docs/contracts/scrum-state/sprint.schema.json
git commit -m "docs: add .scrum/sprint.json schema (SSOT)"
```

---

## Task 4: Define `backlog.schema.json`

**Files:**
- Create: `docs/contracts/scrum-state/backlog.schema.json`

- [ ] **Step 1: Inspect existing fixture**

Run: `cat tests/fixtures/valid-backlog.json`
Expected: confirm field names (`items[]`, `id`, `status`, `title`, `acceptance_criteria[]`, etc.).

- [ ] **Step 2: Write the schema**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Product backlog",
  "type": "object",
  "required": ["schema_version", "items"],
  "additionalProperties": false,
  "properties": {
    "schema_version": {"const": 1},
    "items": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["id", "title", "status"],
        "additionalProperties": false,
        "properties": {
          "id": {"type": "string", "pattern": "^pbi-[0-9]+$"},
          "title": {"type": "string", "minLength": 1},
          "status": {"enum": ["draft", "refined", "in_progress", "review", "done", "blocked"]},
          "acceptance_criteria": {"type": "array", "items": {"type": "string"}},
          "size": {"enum": ["XS", "S", "M", "L", "XL"]},
          "sprint_id": {"type": ["string", "null"], "pattern": "^s[0-9]+$"},
          "assigned_developer": {"type": ["string", "null"], "pattern": "^dev-[0-9]+-s[0-9]+$"},
          "pipeline_summary": {
            "type": "object",
            "additionalProperties": false,
            "properties": {
              "rounds_design": {"type": "integer", "minimum": 0},
              "rounds_impl": {"type": "integer", "minimum": 0},
              "final_coverage_c0": {"type": "number"},
              "final_coverage_c1": {"type": ["number", "null"]},
              "outcome": {"enum": ["complete", "escalated"]},
              "escalation_reason": {"type": ["string", "null"]}
            }
          }
        }
      }
    }
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add docs/contracts/scrum-state/backlog.schema.json
git commit -m "docs: add .scrum/backlog.json schema (SSOT)"
```

---

## Task 5: Define `communications.schema.json` and `dashboard.schema.json`

**Files:**
- Create: `docs/contracts/scrum-state/communications.schema.json`
- Create: `docs/contracts/scrum-state/dashboard.schema.json`

- [ ] **Step 1: Inspect dashboard reader**

Run: `grep -nE 'dashboard\.json|communications\.json' dashboard/app.py | head -20`
Expected: identify the array element shape used by the TUI.

- [ ] **Step 2: Write `communications.schema.json`**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Inter-agent communications",
  "type": "object",
  "required": ["schema_version", "messages"],
  "additionalProperties": false,
  "properties": {
    "schema_version": {"const": 1},
    "messages": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["ts", "from", "to", "body"],
        "additionalProperties": false,
        "properties": {
          "ts": {"type": "string", "format": "date-time"},
          "from": {"type": "string", "minLength": 1},
          "to": {"type": "string", "minLength": 1},
          "kind": {"enum": ["dispatch", "report", "review", "escalation", "info"]},
          "body": {"type": "string"},
          "pbi_id": {"type": ["string", "null"], "pattern": "^pbi-[0-9]+$"}
        }
      }
    }
  }
}
```

- [ ] **Step 3: Write `dashboard.schema.json`**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "Dashboard event log",
  "type": "object",
  "required": ["schema_version", "events"],
  "additionalProperties": false,
  "properties": {
    "schema_version": {"const": 1},
    "events": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["ts", "type"],
        "properties": {
          "ts": {"type": "string", "format": "date-time"},
          "type": {"enum": ["file_change", "tool_call", "phase_transition", "agent_spawn", "agent_terminate", "test_run", "review_verdict"]},
          "agent": {"type": ["string", "null"]},
          "pbi_id": {"type": ["string", "null"], "pattern": "^pbi-[0-9]+$"},
          "payload": {"type": "object"}
        }
      }
    }
  }
}
```

- [ ] **Step 4: Commit**

```bash
git add docs/contracts/scrum-state/communications.schema.json docs/contracts/scrum-state/dashboard.schema.json
git commit -m "docs: add communications and dashboard schemas (SSOT)"
```

---

## Task 6: Define `pbi-state.schema.json` (mirror of PR #22 inline shape)

**Files:**
- Create: `docs/contracts/scrum-state/pbi-state.schema.json`

- [ ] **Step 1: Mirror the shape documented in PR #22**

Run: `git show origin/feat/pbi-pipeline-impl:skills/pbi-pipeline/references/state-management.md | sed -n '1,40p'`
Expected: confirm fields `pbi_id`, `phase`, `design_round`, `impl_round`, status fields, `escalation_reason`.

- [ ] **Step 2: Write the schema**

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "title": "PBI pipeline internal state",
  "type": "object",
  "required": ["schema_version", "pbi_id", "phase", "started_at", "updated_at"],
  "additionalProperties": false,
  "properties": {
    "schema_version": {"const": 1},
    "pbi_id": {"type": "string", "pattern": "^pbi-[0-9]+$"},
    "phase": {"enum": ["design", "impl_ut", "complete", "escalated"]},
    "design_round": {"type": "integer", "minimum": 0},
    "impl_round": {"type": "integer", "minimum": 0},
    "design_status": {"enum": ["pending", "in_review", "fail", "pass"]},
    "impl_status": {"enum": ["pending", "in_review", "fail", "pass"]},
    "ut_status": {"enum": ["pending", "in_review", "fail", "pass"]},
    "coverage_status": {"enum": ["pending", "fail", "pass"]},
    "escalation_reason": {
      "type": ["string", "null"],
      "enum": [
        null,
        "stagnation", "divergence", "max_rounds", "budget_exhausted",
        "requirements_unclear", "coverage_tool_error", "coverage_tool_unavailable",
        "catalog_lock_timeout"
      ]
    },
    "started_at": {"type": "string", "format": "date-time"},
    "updated_at": {"type": "string", "format": "date-time"}
  }
}
```

- [ ] **Step 3: Commit**

```bash
git add docs/contracts/scrum-state/pbi-state.schema.json
git commit -m "docs: add .scrum/pbi/<id>/state.json schema (SSOT)"
```

---

## Task 7: Pick a JSON Schema validator and document the install path

**Decision needed up-front:** `ajv-cli` is the lightest dep (Node) but requires Node on the host. Alternative: `python -m jsonschema` (already required by dashboard/app.py via Textual stack? — verify).

- [ ] **Step 1: Probe both**

```bash
node --version || echo "no node"
python3 -c "import jsonschema; print(jsonschema.__version__)" 2>&1 || echo "no python jsonschema"
```

If Python `jsonschema` is already in the dev stack, prefer it (one less dep). Otherwise use ajv via `npx ajv-cli` (no global install).

- [ ] **Step 2: Write `scripts/scrum/lib/check-validator.sh`**

```bash
#!/usr/bin/env bash
# Verifies a JSON Schema validator is available. Prefers python jsonschema, falls back to ajv via npx.
# Echoes the chosen runner ("python" or "ajv"). Exits 1 if none.
set -euo pipefail
if python3 -c "import jsonschema" 2>/dev/null; then
  echo "python"
  exit 0
fi
if command -v npx >/dev/null 2>&1; then
  echo "ajv"
  exit 0
fi
echo "[scrum-tool] E_NO_VALIDATOR: install python jsonschema or node/npx" >&2
exit 1
```

- [ ] **Step 3: Document in `scripts/setup-dev.sh`**

Add a check that calls `scripts/scrum/lib/check-validator.sh` and prints the chosen runner.

- [ ] **Step 4: Commit**

```bash
git add scripts/scrum/lib/check-validator.sh scripts/setup-dev.sh
git commit -m "feat(scrum-tools): probe JSON schema validator at setup time"
```

---

## Task 8: Implement `scripts/scrum/lib/atomic.sh`

**Files:**
- Create: `scripts/scrum/lib/atomic.sh`
- Create: `scripts/scrum/lib/errors.sh`
- Test: `tests/unit/scrum-state/test_atomic-lib.bats`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bats
# tests/unit/scrum-state/test_atomic-lib.bats
load '../../test_helper/common-setup'

setup() {
  common_setup
  source "${BATS_TEST_DIRNAME}/../../../scripts/scrum/lib/atomic.sh"
  source "${BATS_TEST_DIRNAME}/../../../scripts/scrum/lib/errors.sh"
  cd "$BATS_TEST_TMPDIR"
  mkdir -p .scrum docs/contracts/scrum-state
  cp "${BATS_TEST_DIRNAME}/../../../docs/contracts/scrum-state/backlog.schema.json" docs/contracts/scrum-state/
}

@test "atomic_write writes file atomically and validates against schema" {
  echo '{"schema_version":1,"items":[]}' > .scrum/backlog.json
  run atomic_write .scrum/backlog.json '.items += [{"id":"pbi-001","title":"x","status":"draft"}]' docs/contracts/scrum-state/backlog.schema.json
  [ "$status" -eq 0 ]
  run jq -r '.items[0].id' .scrum/backlog.json
  [ "$output" = "pbi-001" ]
}

@test "atomic_write rejects schema-invalid result and leaves file untouched" {
  echo '{"schema_version":1,"items":[]}' > .scrum/backlog.json
  cp .scrum/backlog.json /tmp/before.json
  run atomic_write .scrum/backlog.json '.items += [{"id":"BAD-ID","title":"x","status":"draft"}]' docs/contracts/scrum-state/backlog.schema.json
  [ "$status" -ne 0 ]
  [[ "$output" == *"E_SCHEMA"* ]]
  run diff .scrum/backlog.json /tmp/before.json
  [ "$status" -eq 0 ]
}

@test "atomic_write serializes concurrent writers via flock" {
  echo '{"schema_version":1,"items":[]}' > .scrum/backlog.json
  for i in 1 2 3 4 5; do
    atomic_write .scrum/backlog.json \
      ".items += [{\"id\":\"pbi-00${i}\",\"title\":\"x\",\"status\":\"draft\"}]" \
      docs/contracts/scrum-state/backlog.schema.json &
  done
  wait
  run jq '.items | length' .scrum/backlog.json
  [ "$output" = "5" ]
}

@test "errors.sh fail emits stderr with code and fixed exit" {
  run bash -c 'source scripts/scrum/lib/errors.sh; fail E_INVALID_ARG "missing pbi-id"'
  [ "$status" -eq 64 ]
  [[ "$stderr" == *"[scrum-tool] E_INVALID_ARG: missing pbi-id"* ]] || [[ "$output" == *"E_INVALID_ARG"* ]]
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `bats tests/unit/scrum-state/test_atomic-lib.bats`
Expected: FAIL — `atomic_write: command not found`.

- [ ] **Step 3: Implement `scripts/scrum/lib/errors.sh`**

```bash
#!/usr/bin/env bash
# scripts/scrum/lib/errors.sh — fixed exit codes for scrum-state tools.
# Sourced by scripts/scrum/*.sh.

# Exit codes
E_OK=0
E_INVALID_ARG=64
E_SCHEMA=65
E_LOCK_TIMEOUT=66
E_FILE_MISSING=67
E_NO_VALIDATOR=68

fail() {
  local code_name="$1"; shift
  local msg="$*"
  local code
  case "$code_name" in
    E_INVALID_ARG) code=64 ;;
    E_SCHEMA)      code=65 ;;
    E_LOCK_TIMEOUT) code=66 ;;
    E_FILE_MISSING) code=67 ;;
    E_NO_VALIDATOR) code=68 ;;
    *)             code=1 ;;
  esac
  printf '[scrum-tool] %s: %s\n' "$code_name" "$msg" >&2
  exit "$code"
}
```

- [ ] **Step 4: Implement `scripts/scrum/lib/atomic.sh`**

```bash
#!/usr/bin/env bash
# scripts/scrum/lib/atomic.sh — flock + tmp+mv + schema validation helper.
# Sourced by scripts/scrum/*.sh. Requires lib/errors.sh sourced first.

LOCK_TIMEOUT_SEC="${SCRUM_LOCK_TIMEOUT:-10}"
SCRUM_LOCK_DIR=".scrum/.locks"

# atomic_write <path> <jq_expr> <schema_path>
# Applies jq_expr to <path>, validates against <schema_path>, writes atomically under flock.
# Adds .updated_at = now if the resulting object has that field.
atomic_write() {
  local path="$1" expr="$2" schema="$3"
  [ -f "$path" ] || fail E_FILE_MISSING "$path"
  [ -f "$schema" ] || fail E_FILE_MISSING "$schema"
  mkdir -p "$SCRUM_LOCK_DIR"
  local lock_file="$SCRUM_LOCK_DIR/$(basename "$path").lock"
  local tmp="${path}.tmp.$$"
  local now; now="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  (
    if command -v flock >/dev/null 2>&1; then
      flock -w "$LOCK_TIMEOUT_SEC" 9 || fail E_LOCK_TIMEOUT "$path"
    fi
    jq --arg now "$now" "$expr | (if has(\"updated_at\") then .updated_at = \$now else . end)" \
      "$path" > "$tmp" || { rm -f "$tmp"; fail E_INVALID_ARG "jq expr failed: $expr"; }
    _validate "$tmp" "$schema" || { rm -f "$tmp"; fail E_SCHEMA "result violates $schema"; }
    mv "$tmp" "$path"
  ) 9>"$lock_file"
}

# _validate <json_path> <schema_path>
_validate() {
  local json="$1" schema="$2"
  local runner; runner="$(scripts/scrum/lib/check-validator.sh)" || fail E_NO_VALIDATOR ""
  case "$runner" in
    python)
      python3 -c "
import json, sys, jsonschema
schema = json.load(open('$schema'))
data = json.load(open('$json'))
try:
    jsonschema.validate(data, schema)
except jsonschema.ValidationError as e:
    print(e.message, file=sys.stderr); sys.exit(1)
" ;;
    ajv)
      npx --yes ajv-cli validate -s "$schema" -d "$json" >/dev/null 2>&1
      ;;
  esac
}
```

- [ ] **Step 5: Run tests until green**

Run: `bats tests/unit/scrum-state/test_atomic-lib.bats`
Expected: 4/4 PASS.

- [ ] **Step 6: Commit**

```bash
git add scripts/scrum/lib/atomic.sh scripts/scrum/lib/errors.sh tests/unit/scrum-state/test_atomic-lib.bats
git commit -m "feat(scrum-tools): atomic write + flock + schema validate helper"
```

---

## Task 9: `scripts/scrum/update-backlog-status.sh` (most-frequent caller)

**Files:**
- Create: `scripts/scrum/update-backlog-status.sh`
- Test: `tests/unit/scrum-state/test_update-backlog-status.bats`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bats
load '../../test_helper/common-setup'

setup() {
  common_setup
  cd "$BATS_TEST_TMPDIR"
  mkdir -p .scrum
  cp "${BATS_TEST_DIRNAME}/../../../tests/fixtures/valid-backlog.json" .scrum/backlog.json
}

@test "update-backlog-status: sets status from draft to in_progress" {
  run "${BATS_TEST_DIRNAME}/../../../scripts/scrum/update-backlog-status.sh" pbi-001 in_progress
  [ "$status" -eq 0 ]
  run jq -r '.items[] | select(.id=="pbi-001").status' .scrum/backlog.json
  [ "$output" = "in_progress" ]
}

@test "update-backlog-status: rejects invalid status" {
  run "${BATS_TEST_DIRNAME}/../../../scripts/scrum/update-backlog-status.sh" pbi-001 wibble
  [ "$status" -eq 64 ]
  [[ "$output" == *"E_INVALID_ARG"* ]]
}

@test "update-backlog-status: rejects missing pbi-id" {
  run "${BATS_TEST_DIRNAME}/../../../scripts/scrum/update-backlog-status.sh" pbi-999 done
  [ "$status" -eq 65 ]
  [[ "$output" == *"E_SCHEMA"* ]] || [[ "$output" == *"not found"* ]]
}

@test "update-backlog-status: rejects bad pbi-id format" {
  run "${BATS_TEST_DIRNAME}/../../../scripts/scrum/update-backlog-status.sh" "BAD ID" done
  [ "$status" -eq 64 ]
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `bats tests/unit/scrum-state/test_update-backlog-status.bats`
Expected: FAIL — script not found.

- [ ] **Step 3: Implement the script**

```bash
#!/usr/bin/env bash
# scripts/scrum/update-backlog-status.sh — set a PBI's status in .scrum/backlog.json.
# Usage: update-backlog-status.sh <pbi-id> <status>
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../.." && pwd)"
# shellcheck source=lib/errors.sh
source "$HERE/lib/errors.sh"
# shellcheck source=lib/atomic.sh
source "$HERE/lib/atomic.sh"

[ "$#" -eq 2 ] || fail E_INVALID_ARG "usage: update-backlog-status.sh <pbi-id> <status>"
PBI="$1"; STATUS="$2"
case "$PBI" in pbi-[0-9]*) ;; *) fail E_INVALID_ARG "bad pbi-id: $PBI" ;; esac
case "$STATUS" in
  draft|refined|in_progress|review|done|blocked) ;;
  *) fail E_INVALID_ARG "bad status: $STATUS" ;;
esac

PATHF=".scrum/backlog.json"
SCHEMA="$ROOT/docs/contracts/scrum-state/backlog.schema.json"

# Pre-check existence of the pbi-id
jq -e --arg id "$PBI" '.items | map(select(.id==$id)) | length > 0' "$PATHF" >/dev/null \
  || fail E_INVALID_ARG "pbi not found: $PBI"

atomic_write "$PATHF" \
  "(.items[] | select(.id == \"$PBI\")).status = \"$STATUS\"" \
  "$SCHEMA"
```

- [ ] **Step 4: Run tests until green**

Run: `bats tests/unit/scrum-state/test_update-backlog-status.bats`
Expected: 4/4 PASS.

- [ ] **Step 5: Commit**

```bash
git add scripts/scrum/update-backlog-status.sh tests/unit/scrum-state/test_update-backlog-status.bats
git commit -m "feat(scrum-tools): update-backlog-status.sh"
```

---

## Task 10: `scripts/scrum/update-sprint-status.sh`

**Files:**
- Create: `scripts/scrum/update-sprint-status.sh`
- Test: `tests/unit/scrum-state/test_update-sprint-status.bats`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bats
load '../../test_helper/common-setup'

setup() {
  common_setup
  cd "$BATS_TEST_TMPDIR"
  mkdir -p .scrum
  cat > .scrum/sprint.json <<'EOF'
{"schema_version":1,"sprint_id":"s1","status":"planning","goal":null,"pbi_ids":[],"developers":{},"created_at":"2026-05-02T00:00:00Z","updated_at":"2026-05-02T00:00:00Z"}
EOF
}

@test "update-sprint-status: planning → active" {
  run "${BATS_TEST_DIRNAME}/../../../scripts/scrum/update-sprint-status.sh" active
  [ "$status" -eq 0 ]
  run jq -r '.status' .scrum/sprint.json
  [ "$output" = "active" ]
}

@test "update-sprint-status: rejects unknown status" {
  run "${BATS_TEST_DIRNAME}/../../../scripts/scrum/update-sprint-status.sh" frobnicating
  [ "$status" -eq 64 ]
}
```

- [ ] **Step 2: Run test, verify it fails**

Run: `bats tests/unit/scrum-state/test_update-sprint-status.bats`
Expected: FAIL.

- [ ] **Step 3: Implement**

```bash
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
source "$HERE/lib/errors.sh"; source "$HERE/lib/atomic.sh"

[ "$#" -eq 1 ] || fail E_INVALID_ARG "usage: update-sprint-status.sh <status>"
STATUS="$1"
case "$STATUS" in planning|active|cross_review|sprint_review|complete) ;; *) fail E_INVALID_ARG "bad status: $STATUS" ;; esac

atomic_write ".scrum/sprint.json" \
  ".status = \"$STATUS\"" \
  "$ROOT/docs/contracts/scrum-state/sprint.schema.json"
```

- [ ] **Step 4: Run, verify pass, commit**

```bash
bats tests/unit/scrum-state/test_update-sprint-status.bats
git add scripts/scrum/update-sprint-status.sh tests/unit/scrum-state/test_update-sprint-status.bats
git commit -m "feat(scrum-tools): update-sprint-status.sh"
```

---

## Task 11: `scripts/scrum/set-sprint-developer.sh`

**Files:**
- Create: `scripts/scrum/set-sprint-developer.sh`
- Test: `tests/unit/scrum-state/test_set-sprint-developer.bats`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bats
load '../../test_helper/common-setup'

setup() {
  common_setup
  cd "$BATS_TEST_TMPDIR"
  mkdir -p .scrum
  cat > .scrum/sprint.json <<'EOF'
{"schema_version":1,"sprint_id":"s1","status":"planning","pbi_ids":[],"developers":{},"created_at":"2026-05-02T00:00:00Z","updated_at":"2026-05-02T00:00:00Z"}
EOF
}

@test "set-sprint-developer: registers a new developer with idle status" {
  run "${BATS_TEST_DIRNAME}/../../../scripts/scrum/set-sprint-developer.sh" dev-001-s1 status idle
  [ "$status" -eq 0 ]
  run jq -r '.developers["dev-001-s1"].status' .scrum/sprint.json
  [ "$output" = "idle" ]
}

@test "set-sprint-developer: assigns current_pbi" {
  "${BATS_TEST_DIRNAME}/../../../scripts/scrum/set-sprint-developer.sh" dev-001-s1 status idle
  run "${BATS_TEST_DIRNAME}/../../../scripts/scrum/set-sprint-developer.sh" dev-001-s1 current_pbi pbi-007
  [ "$status" -eq 0 ]
  run jq -r '.developers["dev-001-s1"].current_pbi' .scrum/sprint.json
  [ "$output" = "pbi-007" ]
}

@test "set-sprint-developer: rejects unknown field" {
  run "${BATS_TEST_DIRNAME}/../../../scripts/scrum/set-sprint-developer.sh" dev-001-s1 wibble x
  [ "$status" -eq 64 ]
}

@test "set-sprint-developer: rejects bad dev id format" {
  run "${BATS_TEST_DIRNAME}/../../../scripts/scrum/set-sprint-developer.sh" devOne status idle
  [ "$status" -eq 64 ]
}
```

- [ ] **Step 2: Run, verify failure**

Run: `bats tests/unit/scrum-state/test_set-sprint-developer.bats`
Expected: FAIL.

- [ ] **Step 3: Implement**

```bash
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
source "$HERE/lib/errors.sh"; source "$HERE/lib/atomic.sh"

[ "$#" -eq 3 ] || fail E_INVALID_ARG "usage: set-sprint-developer.sh <dev-id> <field> <value>"
DEV="$1"; FIELD="$2"; VALUE="$3"
case "$DEV" in dev-[0-9]*-s[0-9]*) ;; *) fail E_INVALID_ARG "bad dev id: $DEV" ;; esac
case "$FIELD" in
  status)
    case "$VALUE" in idle|working|reviewing|blocked|terminated) ;; *) fail E_INVALID_ARG "bad status: $VALUE" ;; esac
    ;;
  current_pbi)
    case "$VALUE" in pbi-[0-9]*|null) ;; *) fail E_INVALID_ARG "bad pbi-id: $VALUE" ;; esac
    ;;
  current_pbi_phase)
    case "$VALUE" in design|impl_ut|complete|escalated|null) ;; *) fail E_INVALID_ARG "bad phase: $VALUE" ;; esac
    ;;
  *) fail E_INVALID_ARG "unknown field: $FIELD" ;;
esac

if [ "$VALUE" = "null" ]; then
  expr=".developers[\"$DEV\"].$FIELD = null"
else
  expr=".developers[\"$DEV\"].$FIELD = \"$VALUE\""
fi
# Ensure developer object exists with required fields
init_expr=".developers[\"$DEV\"] = (.developers[\"$DEV\"] // {\"status\":\"idle\"})"

atomic_write ".scrum/sprint.json" \
  "$init_expr | $expr" \
  "$ROOT/docs/contracts/scrum-state/sprint.schema.json"
```

- [ ] **Step 4: Run, commit**

```bash
bats tests/unit/scrum-state/test_set-sprint-developer.bats
git add scripts/scrum/set-sprint-developer.sh tests/unit/scrum-state/test_set-sprint-developer.bats
git commit -m "feat(scrum-tools): set-sprint-developer.sh"
```

---

## Task 12: `scripts/scrum/update-state-phase.sh`

**Files:**
- Create: `scripts/scrum/update-state-phase.sh`
- Test: `tests/unit/scrum-state/test_update-state-phase.bats`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bats
load '../../test_helper/common-setup'

setup() {
  common_setup
  cd "$BATS_TEST_TMPDIR"
  mkdir -p .scrum
  cat > .scrum/state.json <<'EOF'
{"schema_version":1,"phase":"sprint_planning","current_sprint":"s1","active_pbi_pipelines":[],"created_at":"2026-05-02T00:00:00Z","updated_at":"2026-05-02T00:00:00Z"}
EOF
}

@test "update-state-phase: sprint_planning → design" {
  run "${BATS_TEST_DIRNAME}/../../../scripts/scrum/update-state-phase.sh" design
  [ "$status" -eq 0 ]
  run jq -r '.phase' .scrum/state.json
  [ "$output" = "design" ]
}

@test "update-state-phase: rejects bogus phase" {
  run "${BATS_TEST_DIRNAME}/../../../scripts/scrum/update-state-phase.sh" giga_review
  [ "$status" -eq 64 ]
}
```

- [ ] **Step 2: Run, verify failure**

Run: `bats tests/unit/scrum-state/test_update-state-phase.bats`
Expected: FAIL.

- [ ] **Step 3: Implement**

```bash
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
source "$HERE/lib/errors.sh"; source "$HERE/lib/atomic.sh"

[ "$#" -eq 1 ] || fail E_INVALID_ARG "usage: update-state-phase.sh <phase>"
PHASE="$1"
case "$PHASE" in
  new|requirements_sprint|backlog_created|sprint_planning|design|implementation|review|sprint_review|retrospective|integration_sprint|complete) ;;
  *) fail E_INVALID_ARG "bad phase: $PHASE" ;;
esac

atomic_write ".scrum/state.json" \
  ".phase = \"$PHASE\"" \
  "$ROOT/docs/contracts/scrum-state/state.schema.json"
```

- [ ] **Step 4: Run, commit**

```bash
bats tests/unit/scrum-state/test_update-state-phase.bats
git add scripts/scrum/update-state-phase.sh tests/unit/scrum-state/test_update-state-phase.bats
git commit -m "feat(scrum-tools): update-state-phase.sh"
```

---

## Task 13: `scripts/scrum/append-communication.sh` (lock-critical)

**Files:**
- Create: `scripts/scrum/append-communication.sh`
- Test: `tests/unit/scrum-state/test_append-communication.bats`

- [ ] **Step 1: Write the failing test (includes a race test)**

```bash
#!/usr/bin/env bats
load '../../test_helper/common-setup'

setup() {
  common_setup
  cd "$BATS_TEST_TMPDIR"
  mkdir -p .scrum
  echo '{"schema_version":1,"messages":[]}' > .scrum/communications.json
}

@test "append-communication: appends one message" {
  run "${BATS_TEST_DIRNAME}/../../../scripts/scrum/append-communication.sh" \
    --from scrum-master --to dev-001-s1 --kind dispatch --body "start pbi-001" --pbi pbi-001
  [ "$status" -eq 0 ]
  run jq -r '.messages | length' .scrum/communications.json
  [ "$output" = "1" ]
}

@test "append-communication: 20 concurrent appends end up with 20 messages (no lost writes)" {
  for i in $(seq 1 20); do
    "${BATS_TEST_DIRNAME}/../../../scripts/scrum/append-communication.sh" \
      --from a --to b --kind info --body "m$i" &
  done
  wait
  run jq -r '.messages | length' .scrum/communications.json
  [ "$output" = "20" ]
}

@test "append-communication: rejects missing required field" {
  run "${BATS_TEST_DIRNAME}/../../../scripts/scrum/append-communication.sh" --from a --to b
  [ "$status" -eq 64 ]
}
```

- [ ] **Step 2: Run, verify failure**

Run: `bats tests/unit/scrum-state/test_append-communication.bats`
Expected: FAIL.

- [ ] **Step 3: Implement**

```bash
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
source "$HERE/lib/errors.sh"; source "$HERE/lib/atomic.sh"

FROM=""; TO=""; KIND="info"; BODY=""; PBI="null"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --from) FROM="$2"; shift 2 ;;
    --to)   TO="$2"; shift 2 ;;
    --kind) KIND="$2"; shift 2 ;;
    --body) BODY="$2"; shift 2 ;;
    --pbi)  PBI="\"$2\""; shift 2 ;;
    *) fail E_INVALID_ARG "unknown arg: $1" ;;
  esac
done
[ -n "$FROM" ] && [ -n "$TO" ] && [ -n "$BODY" ] || fail E_INVALID_ARG "--from --to --body required"
case "$KIND" in dispatch|report|review|escalation|info) ;; *) fail E_INVALID_ARG "bad kind: $KIND" ;; esac

ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
# Build the message via jq -n for proper escaping
msg_json="$(jq -n --arg ts "$ts" --arg from "$FROM" --arg to "$TO" --arg kind "$KIND" --arg body "$BODY" \
  --argjson pbi "$PBI" '{ts:$ts, from:$from, to:$to, kind:$kind, body:$body, pbi_id:$pbi}')"

atomic_write ".scrum/communications.json" \
  ".messages += [$msg_json]" \
  "$ROOT/docs/contracts/scrum-state/communications.schema.json"
```

- [ ] **Step 4: Run, verify pass, commit**

```bash
bats tests/unit/scrum-state/test_append-communication.bats
git add scripts/scrum/append-communication.sh tests/unit/scrum-state/test_append-communication.bats
git commit -m "feat(scrum-tools): append-communication.sh with race-safe append"
```

---

## Task 14: `scripts/scrum/append-dashboard-event.sh`

**Files:**
- Create: `scripts/scrum/append-dashboard-event.sh`
- Test: `tests/unit/scrum-state/test_append-dashboard-event.bats`

- [ ] **Step 1: Write failing test**

```bash
#!/usr/bin/env bats
load '../../test_helper/common-setup'

setup() {
  common_setup
  cd "$BATS_TEST_TMPDIR"
  mkdir -p .scrum
  echo '{"schema_version":1,"events":[]}' > .scrum/dashboard.json
}

@test "append-dashboard-event: file_change event recorded" {
  run "${BATS_TEST_DIRNAME}/../../../scripts/scrum/append-dashboard-event.sh" \
    --type file_change --agent dev-001-s1 --payload '{"path":"src/x.py"}'
  [ "$status" -eq 0 ]
  run jq -r '.events[0].type' .scrum/dashboard.json
  [ "$output" = "file_change" ]
}

@test "append-dashboard-event: rejects bogus type" {
  run "${BATS_TEST_DIRNAME}/../../../scripts/scrum/append-dashboard-event.sh" --type giga_event
  [ "$status" -eq 64 ]
}
```

- [ ] **Step 2: Run, verify failure**

Run: `bats tests/unit/scrum-state/test_append-dashboard-event.bats`
Expected: FAIL.

- [ ] **Step 3: Implement**

```bash
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
source "$HERE/lib/errors.sh"; source "$HERE/lib/atomic.sh"

TYPE=""; AGENT="null"; PBI="null"; PAYLOAD="{}"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --type)    TYPE="$2"; shift 2 ;;
    --agent)   AGENT="\"$2\""; shift 2 ;;
    --pbi)     PBI="\"$2\""; shift 2 ;;
    --payload) PAYLOAD="$2"; shift 2 ;;
    *) fail E_INVALID_ARG "unknown arg: $1" ;;
  esac
done
[ -n "$TYPE" ] || fail E_INVALID_ARG "--type required"
case "$TYPE" in
  file_change|tool_call|phase_transition|agent_spawn|agent_terminate|test_run|review_verdict) ;;
  *) fail E_INVALID_ARG "bad type: $TYPE" ;;
esac
ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

evt_json="$(jq -n --arg ts "$ts" --arg type "$TYPE" \
  --argjson agent "$AGENT" --argjson pbi "$PBI" --argjson payload "$PAYLOAD" \
  '{ts:$ts, type:$type, agent:$agent, pbi_id:$pbi, payload:$payload}')"

atomic_write ".scrum/dashboard.json" \
  ".events += [$evt_json]" \
  "$ROOT/docs/contracts/scrum-state/dashboard.schema.json"
```

- [ ] **Step 4: Run, commit**

```bash
bats tests/unit/scrum-state/test_append-dashboard-event.bats
git add scripts/scrum/append-dashboard-event.sh tests/unit/scrum-state/test_append-dashboard-event.bats
git commit -m "feat(scrum-tools): append-dashboard-event.sh"
```

---

## Task 15: `scripts/scrum/update-pbi-state.sh` (replaces PR #22 inline `update_state`)

**Files:**
- Create: `scripts/scrum/update-pbi-state.sh`
- Test: `tests/unit/scrum-state/test_update-pbi-state.bats`

- [ ] **Step 1: Write failing test**

```bash
#!/usr/bin/env bats
load '../../test_helper/common-setup'

setup() {
  common_setup
  cd "$BATS_TEST_TMPDIR"
  mkdir -p .scrum/pbi/pbi-001
  cat > .scrum/pbi/pbi-001/state.json <<'EOF'
{"schema_version":1,"pbi_id":"pbi-001","phase":"design","design_round":0,"impl_round":0,"design_status":"pending","impl_status":"pending","ut_status":"pending","coverage_status":"pending","escalation_reason":null,"started_at":"2026-05-02T00:00:00Z","updated_at":"2026-05-02T00:00:00Z"}
EOF
}

@test "update-pbi-state: bumps design_round" {
  run "${BATS_TEST_DIRNAME}/../../../scripts/scrum/update-pbi-state.sh" pbi-001 design_round 1
  [ "$status" -eq 0 ]
  run jq -r '.design_round' .scrum/pbi/pbi-001/state.json
  [ "$output" = "1" ]
}

@test "update-pbi-state: rejects unknown field" {
  run "${BATS_TEST_DIRNAME}/../../../scripts/scrum/update-pbi-state.sh" pbi-001 wibble 1
  [ "$status" -eq 64 ]
}

@test "update-pbi-state: escalates with reason" {
  run "${BATS_TEST_DIRNAME}/../../../scripts/scrum/update-pbi-state.sh" pbi-001 \
    phase escalated escalation_reason stagnation
  [ "$status" -eq 0 ]
  run jq -r '.phase' .scrum/pbi/pbi-001/state.json
  [ "$output" = "escalated" ]
  run jq -r '.escalation_reason' .scrum/pbi/pbi-001/state.json
  [ "$output" = "stagnation" ]
}
```

- [ ] **Step 2: Run, verify failure**

Run: `bats tests/unit/scrum-state/test_update-pbi-state.bats`
Expected: FAIL.

- [ ] **Step 3: Implement (variadic field=value)**

```bash
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"; ROOT="$(cd "$HERE/../.." && pwd)"
source "$HERE/lib/errors.sh"; source "$HERE/lib/atomic.sh"

[ "$#" -ge 3 ] || fail E_INVALID_ARG "usage: update-pbi-state.sh <pbi-id> <field> <value> [<field> <value>...]"
PBI="$1"; shift
case "$PBI" in pbi-[0-9]*) ;; *) fail E_INVALID_ARG "bad pbi-id: $PBI" ;; esac

PATHF=".scrum/pbi/$PBI/state.json"
[ -f "$PATHF" ] || fail E_FILE_MISSING "$PATHF"

# Build a jq expression from variadic field-value pairs.
EXPR="."
while [ "$#" -ge 2 ]; do
  F="$1"; V="$2"; shift 2
  case "$F" in
    phase)             case "$V" in design|impl_ut|complete|escalated) ;; *) fail E_INVALID_ARG "bad phase: $V" ;; esac
                       EXPR="$EXPR | .$F = \"$V\"" ;;
    design_round|impl_round)
                       [[ "$V" =~ ^[0-9]+$ ]] || fail E_INVALID_ARG "$F must be int"
                       EXPR="$EXPR | .$F = $V" ;;
    design_status|impl_status|ut_status)
                       case "$V" in pending|in_review|fail|pass) ;; *) fail E_INVALID_ARG "bad $F: $V" ;; esac
                       EXPR="$EXPR | .$F = \"$V\"" ;;
    coverage_status)   case "$V" in pending|fail|pass) ;; *) fail E_INVALID_ARG "bad $F: $V" ;; esac
                       EXPR="$EXPR | .$F = \"$V\"" ;;
    escalation_reason) case "$V" in stagnation|divergence|max_rounds|budget_exhausted|requirements_unclear|coverage_tool_error|coverage_tool_unavailable|catalog_lock_timeout|null) ;; *) fail E_INVALID_ARG "bad $F: $V" ;; esac
                       if [ "$V" = "null" ]; then EXPR="$EXPR | .$F = null"; else EXPR="$EXPR | .$F = \"$V\""; fi ;;
    *) fail E_INVALID_ARG "unknown field: $F" ;;
  esac
done
[ "$#" -eq 0 ] || fail E_INVALID_ARG "trailing arg"

atomic_write "$PATHF" "$EXPR" "$ROOT/docs/contracts/scrum-state/pbi-state.schema.json"
```

- [ ] **Step 4: Run, commit**

```bash
bats tests/unit/scrum-state/test_update-pbi-state.bats
git add scripts/scrum/update-pbi-state.sh tests/unit/scrum-state/test_update-pbi-state.bats
git commit -m "feat(scrum-tools): update-pbi-state.sh (replaces inline update_state)"
```

---

## Task 16: PreToolUse enforcement hook

**Files:**
- Create: `hooks/pre-tool-use-scrum-state-guard.sh`
- Test: `tests/unit/scrum-state/test_state-guard-hook.bats`

- [ ] **Step 1: Write failing tests covering allow + deny cases**

```bash
#!/usr/bin/env bats
load '../../test_helper/common-setup'

HOOK="${BATS_TEST_DIRNAME}/../../../hooks/pre-tool-use-scrum-state-guard.sh"

@test "guard: blocks Edit on .scrum/backlog.json" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\".scrum/backlog.json\"}}'"
  [ "$status" -eq 2 ]
  [[ "$stderr" == *"BLOCKED"* ]] || [[ "$output" == *"BLOCKED"* ]]
}

@test "guard: blocks Write on .scrum/state.json" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Write\",\"tool_input\":{\"file_path\":\".scrum/state.json\"}}'"
  [ "$status" -eq 2 ]
}

@test "guard: blocks Bash with jq redirect into .scrum/" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"jq . .scrum/backlog.json > .scrum/backlog.json.tmp && mv .scrum/backlog.json.tmp .scrum/backlog.json\"}}'"
  [ "$status" -eq 2 ]
}

@test "guard: allows Bash that calls scripts/scrum/" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"scripts/scrum/update-backlog-status.sh pbi-001 review\"}}'"
  [ "$status" -eq 0 ]
}

@test "guard: allows Bash that only reads .scrum/" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Bash\",\"tool_input\":{\"command\":\"cat .scrum/backlog.json | jq .items\"}}'"
  [ "$status" -eq 0 ]
}

@test "guard: allows Edit on non-.scrum file" {
  run bash -c "$HOOK <<< '{\"tool_name\":\"Edit\",\"tool_input\":{\"file_path\":\"src/foo.py\"}}'"
  [ "$status" -eq 0 ]
}

@test "guard: ignores hooks/dashboard-event.sh internal write paths" {
  # PreToolUse only fires on agent tool calls, never inside hooks. This test asserts
  # the hook itself does not crash on unexpected payload shapes.
  run bash -c "$HOOK <<< '{}'"
  [ "$status" -eq 0 ]
}
```

- [ ] **Step 2: Run, verify failure**

Run: `bats tests/unit/scrum-state/test_state-guard-hook.bats`
Expected: FAIL.

- [ ] **Step 3: Implement**

```bash
#!/usr/bin/env bash
# hooks/pre-tool-use-scrum-state-guard.sh — PreToolUse hook.
# Blocks agent edits to .scrum/**/*.json that bypass scripts/scrum/.
# Stdin payload: {tool_name, tool_input.{file_path,command,...}}.
# Exit 2 = block. Exit 0 = allow.
set -euo pipefail

payload="$(cat)"
tool="$(printf '%s' "$payload" | jq -r '.tool_name // ""')"

block() {
  echo "[scrum-guard] BLOCKED: $1. Use scripts/scrum/* instead. See docs/MIGRATION-scrum-state-tools.md." >&2
  exit 2
}

case "$tool" in
  Write|Edit)
    file="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // ""')"
    case "$file" in
      .scrum/*.json|.scrum/pbi/*/*.json) block "$tool $file" ;;
    esac
    ;;
  Bash)
    cmd="$(printf '%s' "$payload" | jq -r '.tool_input.command // ""')"
    # Allow if any scripts/scrum/ is invoked
    if [[ "$cmd" == *"scripts/scrum/"* ]]; then
      exit 0
    fi
    # Block redirects/in-place edits targeting .scrum/*.json
    if [[ "$cmd" =~ (\>\>?|tee|sponge)[[:space:]]+\.scrum/.*\.json ]] \
       || [[ "$cmd" =~ jq[[:space:]]+-i.*\.scrum/.*\.json ]] \
       || [[ "$cmd" =~ sed[[:space:]]+-i.*\.scrum/.*\.json ]]; then
      block "raw write to .scrum json from Bash"
    fi
    ;;
esac
exit 0
```

- [ ] **Step 4: Run tests, fix until green**

Run: `bats tests/unit/scrum-state/test_state-guard-hook.bats`
Expected: 7/7 PASS.

- [ ] **Step 5: Register in `.claude/settings.json`**

Edit `.claude/settings.json`, add to `hooks.PreToolUse`:

```json
{
  "matcher": "Write|Edit|Bash",
  "hooks": [{"type": "command", "command": "$CLAUDE_PROJECT_DIR/hooks/pre-tool-use-scrum-state-guard.sh"}]
}
```

(If the file lacks a `hooks` section, add one. Verify with `jq '.hooks.PreToolUse' .claude/settings.json`.)

- [ ] **Step 6: Commit**

```bash
git add hooks/pre-tool-use-scrum-state-guard.sh tests/unit/scrum-state/test_state-guard-hook.bats .claude/settings.json
git commit -m "feat(scrum-tools): PreToolUse hook blocks raw .scrum/*.json writes"
```

---

## Task 17: Migrate `skills/implementation/SKILL.md`

**Files:**
- Modify: `skills/implementation/SKILL.md` (post-#22 — verify file still exists; PR #22 marks it `removed`)

- [ ] **Step 1: Confirm file still exists post-#22**

Run: `git show origin/feat/pbi-pipeline-impl -- skills/implementation/SKILL.md | head -5`
If removed: SKIP this task and migrate the equivalent guidance under `skills/pbi-pipeline/references/` instead (Task 19).

- [ ] **Step 2: Replace the jq inline**

Find on `skills/implementation/SKILL.md:39`:
```
jq '(.items[] | select(.id == "pbi-001")).status = "in_progress"' .scrum/backlog.json > .scrum/backlog.json.tmp && mv .scrum/backlog.json.tmp .scrum/backlog.json
```

Replace with:
```
scripts/scrum/update-backlog-status.sh "$PBI_ID" in_progress
```

- [ ] **Step 3: Commit**

```bash
git add skills/implementation/SKILL.md
git commit -m "refactor(skills): implementation uses scripts/scrum/update-backlog-status.sh"
```

---

## Task 18: Migrate `skills/cross-review/SKILL.md`

**Files:**
- Modify: `skills/cross-review/SKILL.md`

- [ ] **Step 1: Replace jq inlines on lines 36 and 49**

Replace `... .status = "review" ...` with:
```
scripts/scrum/update-backlog-status.sh "$PBI_ID" review
```

Replace `... .status = "done" ...` with:
```
scripts/scrum/update-backlog-status.sh "$PBI_ID" done
```

- [ ] **Step 2: Commit**

```bash
git add skills/cross-review/SKILL.md
git commit -m "refactor(skills): cross-review uses scripts/scrum/update-backlog-status.sh"
```

---

## Task 19: Migrate `skills/pbi-pipeline/references/state-management.md`

**Files:**
- Modify: `skills/pbi-pipeline/references/state-management.md` (introduced by PR #22)

- [ ] **Step 1: Replace `update_state()` and `log_event()` inline helpers with script invocations**

Replace the entire `Atomic update helper` and `Append helper` blocks with:

````markdown
## Atomic update helper

ALWAYS update via the validated wrapper script (never raw jq):

```bash
scripts/scrum/update-pbi-state.sh "$PBI_ID" design_round 1 design_status in_review
scripts/scrum/update-pbi-state.sh "$PBI_ID" phase complete
scripts/scrum/update-pbi-state.sh "$PBI_ID" phase escalated escalation_reason stagnation
```

The wrapper: validates against `docs/contracts/scrum-state/pbi-state.schema.json`, takes a per-file flock, and writes atomically.

## Append helper

```bash
scripts/scrum/append-pbi-log.sh "$PBI_ID" "$PHASE" "$ROUND" "$EVENT" "$DETAIL"
```

(See Task 20 for `append-pbi-log.sh`. The `pipeline.log` is line-formatted, not JSON, but goes through a wrapper for consistency.)
````

- [ ] **Step 2: Commit**

```bash
git add skills/pbi-pipeline/references/state-management.md
git commit -m "refactor(pbi-pipeline): state-management uses scripts/scrum wrappers"
```

---

## Task 20: `scripts/scrum/append-pbi-log.sh` (line-formatted pipeline.log wrapper)

**Files:**
- Create: `scripts/scrum/append-pbi-log.sh`
- Test: `tests/unit/scrum-state/test_append-pbi-log.bats`

- [ ] **Step 1: Write the failing test**

```bash
#!/usr/bin/env bats
load '../../test_helper/common-setup'

setup() {
  common_setup
  cd "$BATS_TEST_TMPDIR"
  mkdir -p .scrum/pbi/pbi-001
}

@test "append-pbi-log: writes one tab-delimited line" {
  run "${BATS_TEST_DIRNAME}/../../../scripts/scrum/append-pbi-log.sh" pbi-001 design 1 spawn pbi-designer
  [ "$status" -eq 0 ]
  run wc -l .scrum/pbi/pbi-001/pipeline.log
  [[ "$output" == *" 1 "* ]] || [[ "$output" =~ ^[[:space:]]*1[[:space:]] ]]
}

@test "append-pbi-log: rejects unknown phase" {
  run "${BATS_TEST_DIRNAME}/../../../scripts/scrum/append-pbi-log.sh" pbi-001 wibble 1 spawn x
  [ "$status" -eq 64 ]
}
```

- [ ] **Step 2: Run, verify failure**

Run: `bats tests/unit/scrum-state/test_append-pbi-log.bats`
Expected: FAIL.

- [ ] **Step 3: Implement**

```bash
#!/usr/bin/env bash
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/errors.sh"

[ "$#" -eq 5 ] || fail E_INVALID_ARG "usage: append-pbi-log.sh <pbi-id> <phase> <round> <event> <detail>"
PBI="$1"; PHASE="$2"; ROUND="$3"; EVENT="$4"; DETAIL="$5"
case "$PBI" in pbi-[0-9]*) ;; *) fail E_INVALID_ARG "bad pbi-id" ;; esac
case "$PHASE" in init|design|impl_ut|complete|escalated) ;; *) fail E_INVALID_ARG "bad phase: $PHASE" ;; esac
[[ "$ROUND" =~ ^[0-9]+$ ]] || fail E_INVALID_ARG "round must be int"

LOGF=".scrum/pbi/$PBI/pipeline.log"
mkdir -p "$(dirname "$LOGF")"
ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
# printf with single >> is line-atomic on POSIX for small writes (<PIPE_BUF, 4096B)
printf '%s\t%s\t%s\t%s\t%s\n' "$ts" "$PHASE" "$ROUND" "$EVENT" "$DETAIL" >> "$LOGF"
```

- [ ] **Step 4: Run, commit**

```bash
bats tests/unit/scrum-state/test_append-pbi-log.bats
git add scripts/scrum/append-pbi-log.sh tests/unit/scrum-state/test_append-pbi-log.bats
git commit -m "feat(scrum-tools): append-pbi-log.sh (line-formatted pipeline log)"
```

---

## Task 21: Audit and migrate remaining skills

**Files:**
- Modify (as needed): `skills/sprint-planning/SKILL.md`, `skills/spawn-teammates/SKILL.md`, `skills/sprint-review/SKILL.md`, `skills/install-subagents/SKILL.md`, `skills/integration-sprint/SKILL.md`, `skills/smoke-test/SKILL.md`, `skills/retrospective/SKILL.md`, `skills/backlog-refinement/SKILL.md`, `skills/design/SKILL.md` (if not removed by #22), `skills/scaffold-design-spec/SKILL.md`, `skills/change-process/SKILL.md`

- [ ] **Step 1: Inventory remaining raw writes**

Run:
```bash
grep -rEn '\.scrum/.*\.json' skills/ \
  | grep -vE '^\s*#|catalog|hooks\.log|pipeline\.log' \
  | grep -E 'jq |>|>>|tee |sed -i'
```

Expected: list of raw writes per skill. For each, identify which `scripts/scrum/*.sh` replaces it.

- [ ] **Step 2: Replace each one in turn**

For each finding:
- Read the surrounding context to confirm intent.
- Replace the inline jq line with the appropriate script call.
- If no script covers the operation, add a follow-up issue and stop (don't invent new fields).

- [ ] **Step 3: Run hook test against each migrated skill**

```bash
# Manually exercise the hook against the new commands:
for cmd_file in $(git diff --name-only main -- skills/); do
  echo "=== $cmd_file ==="
  grep -E 'scripts/scrum/' "$cmd_file" || echo "(no script invocation found — verify intentional)"
done
```

- [ ] **Step 4: Commit per skill**

```bash
git add skills/<skill>/SKILL.md
git commit -m "refactor(skills): <skill> uses scripts/scrum/*"
```

---

## Task 22: Migration guide

**Files:**
- Create: `docs/MIGRATION-scrum-state-tools.md`

- [ ] **Step 1: Write the guide**

```markdown
# Migration: `.scrum/` raw edits → `scripts/scrum/*`

## What changed

Agents must no longer edit `.scrum/*.json` directly (no `Write`, `Edit`, or `jq ... > .scrum/*.json`). All writes go through validated wrapper scripts.

## Mapping

| Old pattern (raw)                                                                                | New (validated)                                                  |
|--------------------------------------------------------------------------------------------------|------------------------------------------------------------------|
| `jq '...status = "in_progress"' .scrum/backlog.json > tmp && mv tmp .scrum/backlog.json`         | `scripts/scrum/update-backlog-status.sh <pbi-id> in_progress`    |
| `jq '...status = "review"' ...`                                                                  | `scripts/scrum/update-backlog-status.sh <pbi-id> review`         |
| `jq '.status = "active"' .scrum/sprint.json ...`                                                 | `scripts/scrum/update-sprint-status.sh active`                   |
| `jq '.developers["dev-001-s1"].current_pbi = "pbi-007"' .scrum/sprint.json ...`                  | `scripts/scrum/set-sprint-developer.sh dev-001-s1 current_pbi pbi-007` |
| `jq '.phase = "design"' .scrum/state.json ...`                                                   | `scripts/scrum/update-state-phase.sh design`                     |
| `jq '.messages += [...]' .scrum/communications.json ...`                                         | `scripts/scrum/append-communication.sh --from --to --kind --body` |
| `jq '.events += [...]' .scrum/dashboard.json ...`                                                | `scripts/scrum/append-dashboard-event.sh --type --agent --payload` |
| `update_state ".scrum/pbi/$PBI/" '.design_round = 1'` (PR #22 inline helper)                     | `scripts/scrum/update-pbi-state.sh <pbi-id> design_round 1`      |
| `printf '...\t...' >> .scrum/pbi/$PBI/pipeline.log`                                              | `scripts/scrum/append-pbi-log.sh <pbi-id> <phase> <round> <event> <detail>` |

## What enforces this

`hooks/pre-tool-use-scrum-state-guard.sh` is registered as `PreToolUse` in `.claude/settings.json`. It blocks:
- `Write` / `Edit` on `.scrum/**/*.json`
- `Bash` commands that redirect/`tee`/`sponge` into `.scrum/*.json`
- `Bash` with `jq -i` or `sed -i` on `.scrum/*.json`

`Bash` commands containing `scripts/scrum/` are always allowed (the scripts handle validation).

## Failure modes

| Exit code | Meaning              |
|-----------|----------------------|
| 64        | Invalid CLI argument |
| 65        | Schema violation     |
| 66        | Lock timeout         |
| 67        | Required file missing |
| 68        | No JSON Schema validator installed |

## Reading

Reads stay free. `cat .scrum/*.json | jq` is allowed. Schemas in `docs/contracts/scrum-state/` are the read-side contract.
```

- [ ] **Step 2: Commit**

```bash
git add docs/MIGRATION-scrum-state-tools.md
git commit -m "docs: migration guide for scrum-state tools"
```

---

## Task 23: Update CLAUDE.md and close out

**Files:**
- Modify: `CLAUDE.md`

- [ ] **Step 1: Add a "State management" section**

```markdown
## State management

`.scrum/*.json` writes go through `scripts/scrum/*.sh` wrappers. Direct edits are blocked by the `hooks/pre-tool-use-scrum-state-guard.sh` PreToolUse hook. See `docs/MIGRATION-scrum-state-tools.md`.
```

- [ ] **Step 2: Run the full test suite**

```bash
bats tests/unit/ tests/lint/ tests/unit/scrum-state/
```

Expected: all green.

- [ ] **Step 3: Commit**

```bash
git add CLAUDE.md
git commit -m "docs: document scrum-state tool policy in CLAUDE.md"
```

- [ ] **Step 4: Open PR**

```bash
gh pr create --base main --title "feat: validated tool layer for .scrum/ state (closes #18)" \
  --body "$(cat <<'EOF'
## Summary
- JSON Schemas under `docs/contracts/scrum-state/` are the SSOT for `.scrum/*.json` types.
- `scripts/scrum/*.sh` wrappers validate, lock, and atomically write.
- PreToolUse hook blocks raw agent edits to `.scrum/**/*.json`.
- All affected skills migrated.

Closes #18.

## Test plan
- [ ] `bats tests/unit/scrum-state/` green (all 9 suites)
- [ ] `bats tests/unit/ tests/lint/` still green
- [ ] Manual: try editing `.scrum/backlog.json` via Edit tool → expect block
- [ ] Manual: run a sprint end-to-end and inspect `.scrum/` for type drift
EOF
)"
```

---

## Self-review

- [ ] Spec coverage:
  - SSOT schemas → Tasks 1–6, 19 (covers state, sprint, backlog, communications, dashboard, pbi-state).
  - Write scripts → Tasks 8–15, 20.
  - Enforcement hook → Task 16.
  - Migration of existing skills → Tasks 17, 18, 19, 21.
  - Migration guide → Task 22.
  - CLAUDE.md note → Task 23.

- [ ] Placeholder scan: no "TBD", "implement later", "similar to Task N", or hand-waved code blocks. Code is complete in every step.

- [ ] Type consistency: `update-pbi-state.sh` field names match `pbi-state.schema.json` (Task 6). Sprint `developers` shape matches schema (Task 3) and `set-sprint-developer.sh` (Task 11). Backlog status enum matches between schema (Task 4) and `update-backlog-status.sh` (Task 9).

- [ ] Open risks logged:
  - macOS `flock` not in default tooling — fallback path needed if Step 7 probe shows `flock` missing. **Add Task 7b: shlock fallback** (deferred — first probe Linux/CI which has flock).
  - The PreToolUse hook regex is heuristic; sophisticated obfuscation (variable substitution) can bypass it. Acceptable for honest-agent threat model; called out in MIGRATION doc.
  - `dashboard/app.py` reader does not yet validate against the new schemas. Documented in `docs/contracts/scrum-state/README.md` as "readers MUST validate" but enforcement is out of scope for this PR.
