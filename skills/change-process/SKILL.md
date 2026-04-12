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
