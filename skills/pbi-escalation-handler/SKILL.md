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
