---
name: change-process
description: FR-016 Change Process — modify frozen documents with user approval
disable-model-invocation: false
---

## Inputs

- Frozen document path (the document to be modified)
- Proposed change description (reason and details of the change)
- User approval (required before changes are applied)

## Outputs

- Updated document with new `revision_history` entry containing: sprint,
  author, date, summary, pbis, `change_process: true`
- `backlog.json` updates if scope changes are needed (add/modify PBIs)

## Preconditions

- The target document exists and is in a frozen state
- A Developer has identified a need to change the frozen document
- The Scrum Master is available to present the change request to the user

## Steps

1. **Identify change need**: A Developer identifies that a frozen document
   needs to be modified and formulates the change request.
2. **Raise change request**: Developer raises the change request to the
   Scrum Master with:
   - Document path
   - Reason for the change
   - Proposed changes (specific content modifications)
   - Affected PBIs (list of PBI ids impacted by the change)
3. **Present to user**: Scrum Master presents the change request to the
   user in natural language, explaining what needs to change and why.
4. **User decision**: User approves or rejects the change request.
5. **If approved**: Update the document content with the proposed changes.
   Append a `revision_history` entry with:
   - `sprint`: current Sprint id
   - `author`: id of the Developer who requested the change
   - `date`: current timestamp
   - `summary`: description of what was changed
   - `pbis`: list of affected PBI ids
   - `change_process`: `true`
6. **Scope changes**: If the change introduces scope changes, update
   `backlog.json` accordingly (add new PBIs or modify existing ones).
7. **Notify Developers**: Notify all Developers of the approved change
   so they can adjust their work if needed.

Reference: FR-016, FR-020

## Exit Criteria

- If approved: document has been updated with the proposed changes
- A `revision_history` entry exists with `change_process: true`
- All Developers have been notified of the change
- If scope changes needed: `backlog.json` has been updated with
  new or modified PBIs
- If rejected: no changes made, Developer notified of rejection
