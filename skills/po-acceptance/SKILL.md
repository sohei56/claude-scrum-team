---
name: po-acceptance
description: >
  PO acceptance verification — launches and operates the app to verify
  acceptance criteria by command execution. Used in Sprint Review
  (demo mode) and Integration Sprint (UAT mode) when
  .scrum/config.json po_mode is "agent".
disable-model-invocation: false
---

## Inputs

- `mode` — one of `demo` | `uat` (required, passed by the SM in the
  `PO_DECISION_REQUEST` envelope).
- `<sprint-id>` — current sprint id (from `.scrum/sprint.json.id`).
- **demo mode:**
  - List of completed PBI ids for this Sprint (from
    `.scrum/sprint.json.developers[].current_pbi` plus
    `.scrum/backlog.json` items with `status == done` and
    `sprint_id == <sprint-id>`).
  - For each PBI: `acceptance_criteria` array from
    `.scrum/backlog.json.items[]`. AC ids are **1-based positional
    indices** into that array (AC #1 = first element).
- **uat mode:**
  - `docs/requirements.md` (release-relevant Functional Requirements
    and Non-Functional Requirements).
  - `docs/product/vision.md` release criteria section (when present;
    the brief is the fallback).
  - `.scrum/test-results.json` from the latest `smoke-test` run
    (precondition: `overall_status ∈ {passed, passed_with_skips}`).

## Outputs

- **demo mode:** one transcript per PBI at
  `.scrum/po/acceptance/<sprint-id>/<pbi-id>.md`. One
  `kind=demo_acceptance` decision per PBI in
  `.scrum/po/decisions.json` (recorded via
  `.scrum/scripts/append-po-decision.sh`), with `evidence` pointing
  to the transcript path.
- **uat mode:** one combined transcript at
  `.scrum/po/uat-<sprint-id>.md`. One `kind=uat_item` decision per
  release criterion, with `evidence` pointing to the relevant
  section anchor of the transcript.
- Per-PBI / per-item `pass | fail | waive` verdicts reported to SM in
  a single aggregated `SendMessage`:

  ```
  [sprint-N] PO_ACCEPTANCE_REPORT mode=<mode> results=[<pbi-id>:<verdict>,...]
  ```

- The app process the skill launched is stopped before the skill
  exits.

## Preconditions

- `.scrum/config.json.po_mode == "agent"` (the PO is active).
- demo mode: invoked from a Sprint Review context; at least one PBI
  has `status == awaiting_cross_review` or has merged into `main`.
- uat mode: invoked from an Integration Sprint context;
  `test-results.json.overall_status ∈ {passed, passed_with_skips}`
  (skipped runner categories must be acknowledged separately).

## Steps

### 1. Detect and start the app

1. Identify the start command, checking in this order and stopping
   at the first match:
   - `README.md` → look for an explicit "Run" / "Quickstart" section
     fenced shell block.
   - `package.json` `scripts.start` or `scripts.dev` → `npm start`
     / `npm run dev`.
   - `Makefile` target `run`, `start`, or `dev` → `make <target>`.
   - `docker-compose.yml` → `docker compose up -d`.
   - Language-native: `python -m <module>` only if requirements.md
     or README documents the module path; otherwise treat as not
     detected.
2. Launch the command in the background, redirecting stdout/stderr
   to `.scrum/po/acceptance/<sprint-id>/_app.log` (demo) or
   `.scrum/po/uat-<sprint-id>.app.log` (uat).
3. Probe readiness:
   - HTTP service: `curl -sf <base-url>/healthz` (or the
     requirements-defined health endpoint, else `/`), retry 10× at
     2-second intervals.
   - CLI / library: run a `--version` or `--help` smoke command.
4. **Startup failure handling.** If readiness never returns OK, do
   **not** attempt to fix the app. Record `startup_failed: true` in
   every transcript section for this run, mark every AC/item as
   `fail` with `rationale=APP_STARTUP_FAILED — see _app.log`, persist
   the decisions via `append-po-decision.sh`, send the aggregated
   `PO_ACCEPTANCE_REPORT` to SM with `results=[*:fail]`, then jump to
   step 5 (app stop / cleanup). The defect routes back through SM
   in the normal failure path.

### 2. Verify acceptance criteria

For each AC (demo: one PBI at a time; uat: one release criterion at
a time):

1. **Map** the AC text to a runnable verification command:
   - HTTP API → `curl` (capture status code with
     `-s -o /dev/null -w '%{http_code}'`, capture response body
     only for failing or content-asserting cases).
   - CLI → run the subcommand documented by the AC and capture
     exit code + stdout/stderr.
   - Browser flow → use Playwright MCP (`.mcp.json` has
     `mcpServers.playwright`) for navigate / click / form-fill /
     assertion sequences.
   - Data assertion → query the persistence store the AC names
     (e.g., `sqlite3`, `psql`, `redis-cli`).
2. **Execute** the command. Capture the full command line, exit
   code, and the relevant fragment of output (≤ 50 lines, prefer
   the assertion-bearing slice). Do not store credentials or
   tokens in the transcript.
3. **Compare** observed output against the AC expectation. The
   verdict is one of:
   - `pass` — the command ran and the output matches the AC.
   - `fail` — the command ran and the output does not match, OR
     the command itself failed to run.
   - `unverifiable` — the AC cannot be mapped to a runnable
     command (e.g., "users feel confident", "the UI looks clean").
     `unverifiable` is **not** a terminal verdict on its own.
4. **Resolve `unverifiable`.** An `unverifiable` AC is recorded as
   `fail` unless the PO chooses to `waive` it with an explicit
   `rationale` naming the gap and the evidence that would lift the
   waiver. The decision log entry uses `decision=waive` and
   `kind=demo_acceptance | uat_item`.

### 3. Write the transcript

Append a section per AC to the transcript file. Required fields:

```markdown
## AC #<n>: <verbatim AC text>

- verdict: pass | fail | waive
- command: `<exact-command-line>`
- exit_code: <int>
- output (truncated):

  ```
  <captured output, ≤ 50 lines>
  ```

- rationale: <why the verdict; required for fail and waive>
- evidence_extras: <optional links to logs, screenshots, etc.>
```

The transcript is markdown for human review; the structured fields
above are the contract.

### 4. Persist decisions

For each AC (demo) or release criterion (uat), invoke:

```bash
.scrum/scripts/append-po-decision.sh \
    --sprint "<sprint-id>" \
    --pbi "<pbi-id>" \
    --kind "<demo_acceptance|uat_item>" \
    --decision "<pass|fail|waive>" \
    --rationale "<verdict rationale>" \
    --evidence ".scrum/po/acceptance/<sprint-id>/<pbi-id>.md#ac-<n>"
```

- Demo mode passes both `--sprint` and `--pbi`; uat mode passes
  `--sprint` only (omit `--pbi`). The message `[<scope>]` prefix in
  the aggregated report is `pbi-NNN` for demo and `sprint-N` for
  uat — the wrapper itself has no `--scope` flag.
- The script returns `dec_id` (`dec-NNNN`); the PO must echo it in
  the final aggregated report so the SM can back-link.

### 5. Stop the app, report to SM

1. Send the app process(es) a `SIGTERM`; after 5 seconds, escalate
   to `SIGKILL`. For `docker compose up` use
   `docker compose down`. For background `npm run dev`, use the
   recorded PID.
2. Confirm the readiness endpoint no longer responds (or the PID is
   gone) before exiting.
3. Send the aggregated report to the SM via `SendMessage`:

   ```
   [<scope>] PO_ACCEPTANCE_REPORT mode=<mode> results=[<id>:<verdict>:<dec_id>,...]
   ```

   - In demo mode `<scope>` is `sprint-<id>` and each result is
     `<pbi-id>:<pbi-aggregate-verdict>:<one dec_id per AC>` flattened.
   - In uat mode `<scope>` is `sprint-<id>` and each result is
     `<criterion-id>:<verdict>:<dec_id>`.
4. The skill exits. Re-entering for retries (e.g., after a defect
   fix) starts again at step 1 with a fresh transcript suffix
   (e.g., `<pbi-id>-r2.md`).

## Exit Criteria

- All ACs (demo) or release criteria (uat) have a verdict recorded
  in `decisions.json` via `append-po-decision.sh`.
- The transcript file exists at the documented path and is
  referenced as `evidence` on every decision entry.
- `PO_ACCEPTANCE_REPORT` has been sent to SM.
- The app has been stopped.

## Strict Rules

- The PO **never** fixes defects discovered during acceptance. A
  failing AC is reported back to the SM, who creates a follow-up
  PBI per `FR-010` and the defect routing rules.
- The PO **never** edits source code, tests, or design docs while
  this skill runs. The path-guard hook blocks Writes outside
  `docs/product/**` and `.scrum/po/**`.
- The PO **never** lowers the AC bar to make a verification pass.
  If the AC is ambiguous, choose `unverifiable` and either `fail`
  or `waive`; do not silently relax it.
- The PO **never** marks an `unverifiable` AC as `pass`. The only
  legal non-fail verdict for an unverifiable AC is `waive` with a
  rationale.
