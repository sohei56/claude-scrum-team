---
name: change-process
description: FR-016 Change Process — modify frozen documents with user approval
disable-model-invocation: false
---

## Inputs

- Frozen document path
- Proposed change (reason + details)
- User approval

## Outputs

- Updated document with revision_history entry (change_process: true)
- Scope changes→backlog.json PBI add/modify

## PO Mode (po_mode: "agent")

This section only applies when `.scrum/config.json.po_mode == "agent"`.
Human-mode readers can skip it; the numbered Steps below are unchanged.
In agent mode the SM never waits on human input — every user-approval
prompt resolves through the PO teammate
(`rules/scrum-context.md` § PO seat resolution).

The user-approval points in the numbered Steps are re-targeted as
follows:

| Step | Phrase in human mode | Agent-mode override |
|---|---|---|
| 3 | SM presents change request to user in natural language | SM sends `[<scope>] PO_DECISION_REQUEST kind=change_request options=[approve,reject] recommendation=<...>` with the frozen doc path, the proposed delta, the reason, and the affected PBI ids as payload. `<scope>` is `pbi-NNN` when a single PBI is affected, otherwise `sprint-N` or `product`. |
| 4 | User approves or rejects | PO judges the request against `docs/product/vision.md` Scope In/Out and the measurable release criteria. Approval requires a concrete tie-back to a brief/vision clause; YAGNI applies otherwise (`agents/product-owner.md` § Decision principles). **Both approve and reject** are persisted by the PO via `.scrum/scripts/append-po-decision.sh`, and the resulting `dec_id` is echoed in the `PO_DECISION` reply — this is the PO's responsibility, not the SM's. |
| 5 | If approved → update doc + revision_history | Unchanged in shape. The `revision_history` entry's `summary` field should reference the `dec_id` returned in row 4 so the doc edit is traceable to the decision log. |
| 7 | Notify all Developers of approved change | Unchanged; SM remains the broker for all SM ↔ Developer traffic. |

## Steps

1. Developer identifies change need→formulates request
2. Raise to SM: doc path, reason, proposed changes, affected PBI IDs
3. SM presents change request to user in natural language
4. User approves or rejects
5. **If approved**: Update doc→append revision_history: sprint, author, date, summary, pbis, change_process: true
6. Scope changes→update backlog.json (add/modify PBIs)
7. Notify all Developers of approved change

Ref: FR-016, FR-020

## Exit Criteria

- Approved: doc updated, revision_history has change_process: true, Developers notified, scope changes in backlog.json
- Rejected: no changes, Developer notified
- po_mode=agent: `.scrum/po/decisions.json` contains a `kind=change_request` record (approve or reject) for this request, and its `dec_id` is referenced from the doc's `revision_history` entry when approved
