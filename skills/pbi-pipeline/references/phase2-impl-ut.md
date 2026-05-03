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

`.scrum/scripts/update-pbi-state.sh "$PBI_ID" impl_round "$n" impl_status pending ut_status pending`

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
.scrum/scripts/update-pbi-state.sh "$PBI_ID" impl_status pass ut_status pass coverage_status pass phase complete
# update-pbi-state.sh auto-projects backlog.json items[].status = "review"
# (cross-review will later advance phase to review_complete → backlog "done").
write_summary "$PBI_DIR/impl/summary.md"
write_summary "$PBI_DIR/ut/summary.md"
.scrum/scripts/append-pbi-log.sh "$PBI_ID" impl_ut "$n" gate "success → complete"
# Then: notify SM (no separate backlog.status write needed)
```

#### Termination gate (Stagnation / Divergence / Hard cap)

See `termination-gates.md`. On any escalate gate:

```bash
.scrum/scripts/update-pbi-state.sh "$PBI_ID" phase escalated escalation_reason "<reason>"
.scrum/scripts/append-pbi-log.sh "$PBI_ID" impl_ut "$n" gate "escalate → <reason>"
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
.scrum/scripts/append-pbi-log.sh "$PBI_ID" impl_ut "$n" gate "fail → round $((n+1))"
# Recurse with n+1
```
