# Impl + PBI Review + UT Run Reference

Per-Round flow for the post-design stages (max 5 Rounds). Each Round
walks three backlog statuses:

```
in_progress_impl → in_progress_pbi_review → in_progress_ut_run
       ↑                                          │
       └────────── FAIL feedback ─────────────────┘
```

A round starts in `in_progress_impl`, advances to
`in_progress_pbi_review` once impl + UT code is committed, and to
`in_progress_ut_run` only after both reviewers PASS. A FAIL at either
review or at coverage measurement falls back to `in_progress_impl` for
the next round (or escalates via the termination gate).

## Pipeline entry — obtaining `n`

The Round counter is owned by `.scrum/scripts/begin-impl-round.sh`.
The conductor MUST NOT compute `n` itself or write `impl_round` via
`update-pbi-state.sh`. At every impl-Round entry — first entry from
Design success AND re-entry after PBI Review FAIL, UT Run FAIL, or a
Sprint-end Cross Review revert — call:

```bash
n=$(.scrum/scripts/begin-impl-round.sh "$PBI_ID")
```

The wrapper is atomic and idempotent:

- Increments `impl_round`, resets `impl_status` and `ut_status` to
  `pending`, and (idempotently) sets backlog status to
  `in_progress_impl`.
- If a previous `begin-impl-round.sh` call already started this Round
  (`impl_status == "pending" AND impl_round > 0`) — e.g. after a
  Developer crash + respawn — returns the current `impl_round`
  without mutating state. The conductor resumes the same Round.
- Refuses when backlog status is not one of
  `{in_progress_design, in_progress_pbi_review, in_progress_ut_run,
  cross_review, in_progress_impl}`.

This is the only sanctioned writer of `impl_round`. Hand-rolled
`update-pbi-state.sh "$PBI_ID" impl_round <N>` is forbidden in the
impl/PBI-review/UT-run cycle.

## Round n procedure

### Step 1: Parallel spawn (pbi-implementer + pbi-ut-author)

Backlog status is `in_progress_impl`. Issue both Agent calls in a
single message (Claude Code parallel execution). Wait for both to
return.

```text
Agent(subagent_type="pbi-implementer", prompt=<from sub-agent-prompts.md § pbi-implementer>)
Agent(subagent_type="pbi-ut-author", prompt=<from sub-agent-prompts.md § pbi-ut-author>)
```

Status remains `in_progress_impl` while sources/tests are being
written; both per-stage statuses (`impl_status`, `ut_status`) were
already reset to `pending` by `begin-impl-round.sh` above.

### Step 2: Move to PBI Review

Once both sub-agents have produced source + tests for Round n, the
conductor MUST commit the worktree before spawning reviewers so the
reviewers evaluate a pinned snapshot, not an in-flight one:

```bash
bash .scrum/scripts/commit-pbi.sh "$PBI_ID" "round $n: impl + ut"
REVIEW_SHA="$(git -C .scrum/worktrees/$PBI_ID rev-parse HEAD)"
DESIGN_HASH="$(shasum -a 256 .scrum/pbi/$PBI_ID/design/design.md \
  | awk '{print $1}')"
```

`commit-pbi.sh` no-ops cleanly if nothing changed; in that case
`REVIEW_SHA` still resolves to the worktree's current HEAD, which is
exactly the snapshot to review. Both `REVIEW_SHA` and `DESIGN_HASH`
are passed into the two reviewer prompts as pin slots (see
`sub-agent-prompts.md` § codex-impl-reviewer / codex-ut-reviewer).

Then advance the status and spawn the two reviewers in parallel:

```bash
.scrum/scripts/update-backlog-status.sh "$PBI_ID" in_progress_pbi_review
.scrum/scripts/append-pbi-log.sh "$PBI_ID" pbi_review "$n" start —
```

**Codex preflight** (see `sub-agent-prompts.md` § Conductor codex
preflight). The same result applies to both reviewer spawns in this
parallel pair — preflight once, then spawn both:

```bash
source scripts/lib/codex-invoke.sh
codex_is_available && SPAWN_MODEL="" || SPAWN_MODEL="opus"
```

Codex present → spawn both with no `model` override:

```text
Agent(subagent_type="codex-impl-reviewer", prompt=<from sub-agent-prompts.md>)
Agent(subagent_type="codex-ut-reviewer", prompt=<from sub-agent-prompts.md>)
```

Codex absent → spawn both with `model="opus"`:

```text
Agent(subagent_type="codex-impl-reviewer", model="opus", prompt=<from sub-agent-prompts.md>)
Agent(subagent_type="codex-ut-reviewer", model="opus", prompt=<from sub-agent-prompts.md>)
```

Apply `reviewer-stall-fallback.md` per reviewer (2-min stall detect
→ single Explore-agent retry → escalate as `reviewer_unavailable` if
both fail). The two reviewers are independent — fall back on either
without affecting the other.

Read review-r{n}.md from each, parse verdicts and findings.

#### Snapshot-pin verification

After reading each `review-r{n}.md`, the conductor MUST verify the
file begins with the pin headers:

```text
Reviewed-Head: <REVIEW_SHA>
Reviewed-Design-Hash: <DESIGN_HASH>
```

If a header is missing or mismatched, OR if the reviewer's JSON
envelope returns `status=error` with `summary` starting
`stale_snapshot:` — re-capture `REVIEW_SHA` and `DESIGN_HASH` (the
worktree may have moved while the reviewer ran) and respawn that
reviewer ONCE with the refreshed pin slots. If the second attempt
also fails verification, escalate via the existing escalation flow
using `escalation_reason=stale_review_snapshot`:

```bash
.scrum/scripts/update-pbi-state.sh "$PBI_ID" escalation_reason stale_review_snapshot
.scrum/scripts/update-backlog-status.sh "$PBI_ID" escalated
.scrum/scripts/append-pbi-log.sh "$PBI_ID" pbi_review "$n" gate "escalate → stale_review_snapshot"
notify_sm_escalation "$PBI_ID" stale_review_snapshot
```

```bash
.scrum/scripts/update-pbi-state.sh "$PBI_ID" impl_status in_review ut_status in_review
```

#### PBI Review FAIL branch

If either reviewer verdict is FAIL (and the termination gate does NOT
fire), build feedback for the next impl round and revert status:

```bash
.scrum/scripts/update-pbi-state.sh "$PBI_ID" impl_status fail
.scrum/scripts/update-backlog-status.sh "$PBI_ID" in_progress_impl
.scrum/scripts/append-pbi-log.sh "$PBI_ID" pbi_review "$n" gate "fail → next round"
# Loop back to "Pipeline entry" — begin-impl-round.sh returns the new n.
# See "Build feedback for next round" below.
```

### Step 3: UT Run (test execution + coverage measurement)

When both reviewers PASS, advance to UT Run:

```bash
.scrum/scripts/update-pbi-state.sh "$PBI_ID" impl_status pass ut_status pass
.scrum/scripts/update-backlog-status.sh "$PBI_ID" in_progress_ut_run
.scrum/scripts/append-pbi-log.sh "$PBI_ID" ut_run "$n" start —
```

See `coverage-gate.md` for the full procedure. Summary:

```bash
# Read .scrum/config.json (apply PBI override if design.md has a
# `yaml runtime-override` fence). Run test_runner.coverage_tool.command
# with merged args. Normalize output → coverage-r{n}.json,
# test-results-r{n}.json. Run pragma audit → pragma-audit-r{n}.json.
```

Tool-launch failure → escalate (`coverage_tool_error`).
Tool not installed → escalate (`coverage_tool_unavailable`).

### Step 4: Aggregate Pass criteria

Pass evaluation logic (see `coverage-gate.md` § Pass criteria):

```text
ALL of:
  test_results.totals.failed == 0
  test_results.totals.exec_errors == 0
  test_results.totals.uncaught_exceptions == 0
  coverage.totals.c0.percent >= c0_threshold (default 100.0)
  if c1.supported: coverage.totals.c1.percent >= c1_threshold (default 100.0)
  no pragma exclusion has reason_source == "missing"
  impl-reviewer.verdict == PASS  (already true to reach this stage)
  ut-reviewer.verdict == PASS    (already true to reach this stage)
  ac-coverage gate (see below) passes
```

#### AC coverage gate (deterministic)

Every AC in `.scrum/pbi/$PBI_ID/ut/ac-coverage-r$n.json` must have a
non-empty `tests` array, AND no listed test id may appear in
`test-results-r$n.json` `failures[]` (the run's `totals` already show
zero `failed` / `exec_errors` / `uncaught_exceptions` per the
surrounding Pass criteria).

Match rule (pragmatic — `test-results-rN.schema.json` enumerates
failures only, not passes; passing tests are implied by the failed-
totals being zero AND the test id not appearing in `failures[]`):

```bash
# Run as a function/subshell; any non-zero path = AC gate FAIL.
AC_MAP=".scrum/pbi/$PBI_ID/ut/ac-coverage-r$n.json"
TEST_RESULTS=".scrum/pbi/$PBI_ID/metrics/test-results-r$n.json"

# 1. File exists.
[[ -f "$AC_MAP" ]] || { echo "ac_coverage_missing"; return 1; }

# 2. Every criteria[].tests array is non-empty.
jq -e '.criteria | length > 0 and all(.tests | length > 0)' \
  "$AC_MAP" > /dev/null \
  || { echo "ac_coverage_empty_tests"; return 1; }

# 3. No listed test id appears in test-results failures[].
FAILED_IDS=$(jq -r '.failures[].test_id' "$TEST_RESULTS")
LISTED_IDS=$(jq -r '.criteria[].tests[]' "$AC_MAP")
while IFS= read -r tid; do
  [[ -z "$tid" ]] && continue
  if grep -Fxq "$tid" <<<"$FAILED_IDS"; then
    echo "ac_coverage_test_failed:$tid"; return 1
  fi
done <<<"$LISTED_IDS"
```

Known limitation: a listed test id that the runner never collected
(renamed/deleted test) appears in neither `failures[]` nor any pass
record, so this gate cannot detect it. That existence check is owned
by `codex-ut-reviewer` (Review Criterion #2: every listed test id
must exist in the supplied test files — dangling id → FAIL).

`test_id` in `failures[]` is whatever the test runner emits (e.g.
pytest produces `tests/unit/test_foo.py::test_bar`). The UT author
MUST use the same `<file>::<test-name>` form so the comparison is
direct (see `agents/pbi-ut-author.md` § "AC coverage map"). If a
project's runner uses a divergent test_id format, declare the
mapping convention in the design doc's `runtime-override` block;
absent that, the format above is the contract.

A failed AC gate routes like a UT Run FAIL (existing branch below).

#### Success branch (hand off to SM)

```bash
.scrum/scripts/update-pbi-state.sh "$PBI_ID" coverage_status pass
write_summary "$PBI_DIR/impl/summary.md"
write_summary "$PBI_DIR/ut/summary.md"
.scrum/scripts/mark-pbi-ready-to-merge.sh "$PBI_ID"
# mark-pbi-ready-to-merge.sh sets head_sha / paths_touched / ready_at
# and sets backlog.json items[].status = "in_progress_merge".
.scrum/scripts/append-pbi-log.sh "$PBI_ID" ut_run "$n" gate "success → in_progress_merge"
# Then: notify SM (PBI_READY_TO_MERGE).
```

#### UT Run FAIL (test/coverage failure)

If Pass criteria fail at UT Run (and the termination gate does NOT
fire), revert to impl for the next round:

```bash
.scrum/scripts/update-pbi-state.sh "$PBI_ID" coverage_status fail ut_status fail
.scrum/scripts/update-backlog-status.sh "$PBI_ID" in_progress_impl
.scrum/scripts/append-pbi-log.sh "$PBI_ID" ut_run "$n" gate "fail → next round"
# Loop back to "Pipeline entry" — begin-impl-round.sh returns the new n.
# See "Build feedback for next round".
```

#### Termination gate (Stagnation / Divergence / Hard cap)

See `termination-gates.md`. On any escalate gate:

```bash
.scrum/scripts/update-pbi-state.sh "$PBI_ID" escalation_reason "<reason>"
.scrum/scripts/update-backlog-status.sh "$PBI_ID" escalated
.scrum/scripts/append-pbi-log.sh "$PBI_ID" "$STAGE" "$n" gate "escalate → <reason>"
notify_sm_escalation "$PBI_ID" "<reason>"
```

`$STAGE` is `pbi_review` or `ut_run` depending on where the gate
fired.

### Build feedback for next round

See `feedback-routing.md`. Generate:

- `feedback/impl-r{n+1}.md` (impl-reviewer findings + test failures
  framed for impl)
- `feedback/ut-r{n+1}.md` (ut-reviewer findings + test failures framed
  for UT + coverage gaps + pragma issues)
