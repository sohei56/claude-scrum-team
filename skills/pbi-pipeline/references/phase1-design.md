# Design Phase Reference

Per-Round flow for the design phase (max 5 Rounds).

## Round n procedure

1. **Prepare**
   - `.scrum/scripts/update-pbi-state.sh "$PBI_ID" design_round "$n" design_status pending`
   - `.scrum/scripts/append-pbi-log.sh "$PBI_ID" design "$n" start —`

2. **Step 1: Spawn pbi-designer** (single Agent call)
   - Build prompt from `sub-agent-prompts.md` § pbi-designer
   - Wait for completion
   - Parse JSON envelope from output. If status=error → escalate.
   - `.scrum/scripts/update-pbi-state.sh "$PBI_ID" design_status in_review`

3. **Step 2: Spawn codex-design-reviewer** (single Agent call)
   - Build prompt from `sub-agent-prompts.md` § codex-design-reviewer
   - Wait for completion
   - Read .scrum/pbi/<pbi-id>/design/review-r{n}.md → parse Verdict.

4. **Step 3: Termination gate** (see termination-gates.md)
   - **Success**: design-reviewer verdict == PASS
     - `.scrum/scripts/update-pbi-state.sh "$PBI_ID" design_status pass phase impl_ut impl_round 0`
     - `.scrum/scripts/append-pbi-log.sh "$PBI_ID" design "$n" gate "success → impl_ut"`
     - Return to caller (pipeline phase 2 begins)
   - **Stagnation / Divergence / Hard cap**: escalate
     - `.scrum/scripts/update-pbi-state.sh "$PBI_ID" phase escalated escalation_reason "<reason>"`
     - `.scrum/scripts/append-pbi-log.sh "$PBI_ID" design "$n" gate "escalate → <reason>"`
     - Notify SM (see `escalation-notify` snippet below)
   - **Other FAIL**: review-r{n}.md becomes input to Round n+1
     - `.scrum/scripts/append-pbi-log.sh "$PBI_ID" design "$n" gate "fail → round $((n+1))"`
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
