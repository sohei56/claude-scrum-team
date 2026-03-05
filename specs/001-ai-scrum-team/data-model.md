# Data Model: AI-Powered Scrum Team

**Branch**: `001-ai-scrum-team` | **Date**: 2026-02-26
**Source**: [spec.md](spec.md) Key Entities + [research.md](research.md) R2, R4, R8

All state persists as JSON files in `.scrum/` at the user's project root.
One file per concern. Files are read/written by the Scrum Master agent and
read (selectively) by Developer teammates.

---

## Entity: ProjectState

**File**: `.scrum/state.json`
**Owner**: Scrum Master (read/write)
**Readers**: scrum-start.sh (on resume), Textual dashboard app, statusline.sh

| Field | Type | Description |
|-------|------|-------------|
| `product_goal` | string | User-defined desired future state of the product |
| `current_sprint_id` | string \| null | ID of the active Sprint, null if none |
| `phase` | enum | Current workflow phase (see State Transitions) |
| `created_at` | ISO 8601 string | Project creation timestamp |
| `updated_at` | ISO 8601 string | Last state change timestamp |

### State Transitions: `phase`

```
new → requirements_sprint → backlog_created → sprint_planning
  → design → implementation → review → sprint_review
  → retrospective → sprint_planning (next Sprint)
  → integration_sprint → backlog_created (defect-fix loop)
                        → complete
```

Valid phases:
- `new` — project just created, no work started
- `requirements_sprint` — Requirements Sprint in progress
- `backlog_created` — initial Product Backlog created, ready for first Development Sprint
- `sprint_planning` — Sprint Planning in progress (refining PBIs, assigning teammates)
- `design` — Design phase (Developers producing design docs)
- `implementation` — Implementation phase (Developers coding)
- `review` — Cross-review phase
- `sprint_review` — Sprint Review with user
- `retrospective` — Sprint Retrospective
- `integration_sprint` — Integration Sprint in progress
- `complete` — product released

---

## Entity: ProductBacklog

**File**: `.scrum/backlog.json`
**Owner**: Scrum Master (read/write)
**Readers**: Developer teammates (filtered by assignment), Textual dashboard app, statusline.sh

| Field | Type | Description |
|-------|------|-------------|
| `product_goal` | string | Duplicated from state for self-contained reads |
| `items` | PBI[] | Ordered list of Product Backlog Items |
| `next_pbi_id` | integer | Auto-increment counter for PBI IDs |

---

## Entity: PBI (Product Backlog Item)

**Embedded in**: `backlog.json` → `items[]`

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier (e.g., `"pbi-001"`) |
| `title` | string | Short description (e.g., "User Management") |
| `description` | string | Full description; coarse-grained when `draft`, detailed when `refined` |
| `acceptance_criteria` | string[] | Testable conditions that define when the PBI is complete. Empty array when `draft`, non-empty when `refined` |
| `status` | enum | Lifecycle state (see below) |
| `priority` | integer | Order in backlog (1 = highest) |
| `sprint_id` | string \| null | Sprint this PBI is assigned to, null if in backlog |
| `implementer_id` | string \| null | Developer teammate assigned to implement |
| `reviewer_id` | string \| null | Reviewer ID: a Developer teammate (round-robin) or `"scrum-master"` (single-PBI Sprint) |
| `design_doc_paths` | string[] | Paths to design documents relative to project root (e.g., `.design/specs/ui/S-030-login.md`) |
| `review_doc_path` | string \| null | Path to review results relative to `.scrum/` |
| `depends_on_pbi_ids` | string[] | IDs of PBIs that must be completed before this one (used by FR-008) |
| `ux_change` | boolean | Whether this PBI involves UX changes (determines live demo in FR-010) |
| `parent_pbi_id` | string \| null | ID of the coarse-grained PBI this was refined from |
| `created_at` | ISO 8601 string | Creation timestamp |
| `updated_at` | ISO 8601 string | Last update timestamp |

### State Transitions: `status`

```
draft → refined → in_progress → review → done
```

- `draft` — coarse-grained (e.g., "User Management"). Created during initial backlog creation.
- `refined` — implementation-ready (one function, screen, API, or platform component). Refined during Sprint Planning. `acceptance_criteria` must be filled.
- `in_progress` — Developer actively implementing.
- `review` — cross-review by another Developer.
- `done` — meets Definition of Done (FR-017).

### Validation Rules
- `implementer_id` and `reviewer_id` MUST differ (FR-006). Reviewers are assigned round-robin. In a single-PBI Sprint, `reviewer_id` is `"scrum-master"`.
- `implementer_id` and `reviewer_id` are set only when `status` is `refined` or later.
- `design_doc_paths` is populated when design documents are produced (before `in_progress`).
- `acceptance_criteria` MUST be non-empty when transitioning from `draft` to `refined`.
- `depends_on_pbi_ids` is used by the Scrum Master to avoid placing dependent PBIs in the same Sprint (FR-008).
- `ux_change` is set during refinement and determines whether Sprint Review includes a live demo (FR-010).
- `parent_pbi_id` is set only for refined PBIs that were broken down from a draft PBI.
- The total number of PBIs with `status: refined` SHOULD stay within 6-12 (1-2 Sprints of capacity) to avoid over-refinement (FR-003). No global PBI count limit.

---

## Entity: Sprint

**File**: `.scrum/sprint.json`
**Owner**: Scrum Master (read/write)
**Readers**: Developer teammates (filtered), Textual dashboard app, statusline.sh

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier (e.g., `"sprint-001"`) |
| `goal` | string | Sprint Goal text |
| `type` | enum | `"requirements"`, `"development"`, or `"integration"` |
| `status` | enum | `"planning"`, `"active"`, `"cross_review"`, `"sprint_review"`, `"complete"` |
| `pbi_ids` | string[] | IDs of PBIs in the Sprint Backlog |
| `developer_count` | integer | Number of Developer teammates: min(refined PBIs, 6) |
| `developers` | Developer[] | Active Developer teammate definitions |
| `started_at` | ISO 8601 string | Sprint start timestamp |
| `completed_at` | ISO 8601 string \| null | Sprint completion timestamp |

### Embedded: Developer

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Teammate identifier (e.g., `"dev-001-s3"`) |
| `assigned_work` | object | PBI assignments split by responsibility |
| `assigned_work.implement` | string[] | PBI IDs this Developer implements |
| `assigned_work.review` | string[] | PBI IDs this Developer reviews (round-robin assigned) |
| `status` | enum | `"active"`, `"idle"`, `"failed"` |
| `sub_agents` | string[] | Names of specialist sub-agents actually invoked via the Task tool (runtime-populated, not candidates) |

---

## Entity: SprintHistory

**File**: `.scrum/sprint-history.json`
**Owner**: Scrum Master (append-only)
**Readers**: Textual dashboard app, statusline.sh

| Field | Type | Description |
|-------|------|-------------|
| `sprints` | SprintSummary[] | Completed Sprint summaries |

### Embedded: SprintSummary

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Sprint ID |
| `goal` | string | Sprint Goal |
| `type` | enum | Sprint type |
| `pbis_completed` | integer | Number of PBIs that reached `done` |
| `pbis_total` | integer | Number of PBIs in Sprint Backlog |
| `started_at` | ISO 8601 string | Start timestamp |
| `completed_at` | ISO 8601 string | Completion timestamp |

---

## Entity: ImprovementLog

**File**: `.scrum/improvements.json`
**Owner**: Scrum Master (read/write)
**Readers**: Developer teammates (at Sprint start)

| Field | Type | Description |
|-------|------|-------------|
| `entries` | Improvement[] | All improvement entries |
| `last_consolidation_sprint` | string \| null | Sprint ID of last 3-Sprint consolidation |

### Embedded: Improvement

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Unique identifier |
| `sprint_id` | string | Sprint this was recorded in |
| `description` | string | What to improve |
| `status` | enum | `"active"`, `"archived"` |
| `created_at` | ISO 8601 string | When recorded |
| `archived_at` | ISO 8601 string \| null | When archived (during consolidation) |

### Validation Rules
- Consolidation occurs every 3 Sprints (FR-012).
- Archived entries are retained but not shown to Developers.

---

## Entity: RequirementsDocument

**File**: `.scrum/requirements.md`
**Format**: Markdown (not JSON — human-readable document)
**Owner**: Scrum Master (write once during Requirements Sprint)
**Readers**: All Developer teammates, Integration Sprint

This is the single source of truth for what the product must do. Produced
during the Requirements Sprint (FR-002). Frozen during Development Sprints
(FR-020). Changes follow the Change Process (FR-016).

---

## Entity: DesignCatalogConfig

**File**: `.design/catalog-config.json`
**Owner**: Scrum Master (read/write)
**Readers**: Developer teammates (read-only), phase-gate.sh, scaffold-design-spec skill
**Reference**: `.design/catalog.md` (read-only document type catalog)

Controls which design spec types are active for the project. The full list
of recognized document types lives in `.design/catalog.md` (read-only,
managed in claude-scrum-team). This config file is the only editable part.

| Field | Type | Description |
|-------|------|-------------|
| `enabled` | string[] | Array of spec IDs from catalog.md that are active (e.g., `["D-001", "S-001", "S-010"]`) |

### Rules
- Only spec IDs that exist in `.design/catalog.md` may appear in `enabled`.
- The phase-gate hook enforces that design spec files can only be created
  for IDs present in both `catalog.md` (exists) and `catalog-config.json`
  (enabled).
- When a spec ID is added to `enabled`, the `scaffold-design-spec` skill
  must be invoked to create template stubs.
- `catalog.md` is read-only in working directories; only this config file
  may be edited to control which entries are active.

---

## Entity: DesignDocument

**Directory**: `.design/specs/{category}/`
**Governance**: `.design/catalog.md` (type reference) + `.design/catalog-config.json` (enablement)
**Format**: Markdown with YAML frontmatter
**Owner**: Assigned Developer (write), Reviewer (read)
**Readers**: All Developers in subsequent Sprints (FR-004)

Design documents are governed by `.design/catalog.md` (read-only type
reference) and `.design/catalog-config.json` (editable enabled list). No
design document may be created unless its spec type is listed in the catalog
and enabled in the config. Files follow the naming convention
`.design/specs/{category}/{id}-{slug}.md`.

| Category | Example Entry | Example File |
|----------|--------------|-------------|
| system-wide | S-001 System Architecture | `system-wide/S-001-system-architecture.md` |
| data | S-010 Data Model | `data/S-010-data-model.md` |
| interface | S-020 API Specification | `interface/S-020-api-spec.md` |
| ui | S-030 Screen / Page Design | `ui/S-030-login-screen.md` |
| logic | S-040 Business Rule | `logic/S-040-auth-rules.md` |
| quality | S-050 Test Strategy | `quality/S-050-test-strategy.md` |
| decision-records | D-001 Architecture Decision Record | `decision-records/D-001-auth-api-choice.md` |
| operations | S-060 Migration / Upgrade | `operations/S-060-v2-migration.md` |
| docs | D-010 Requirements Document | `docs/D-010-requirements.md` |

### YAML Frontmatter

```yaml
---
catalog_id: S-001
created_sprint: sprint-001
last_updated_sprint: sprint-003
related_pbis:
  - pbi-001
  - pbi-005
  - pbi-012
frozen: true
revision_history:
  - sprint: sprint-001
    author: dev-001-s1
    date: "2026-03-01T10:00:00Z"
    summary: "Initial architecture design"
    pbis: [pbi-001, pbi-005]
  - sprint: sprint-003
    author: dev-004-s3
    date: "2026-03-05T14:30:00Z"
    summary: "Added caching layer per PBI-012"
    pbis: [pbi-012]
    change_process: true
---
```

### Revision History (mandatory)

Every design document MUST include a `revision_history` array in its YAML
frontmatter to track edit history across Sprints. Each entry is a
`RevisionEntry` object:

| Field | Type | Description |
|-------|------|-------------|
| `sprint` | string | Sprint ID in which the edit was made |
| `author` | string | Developer ID who made the edit |
| `date` | ISO 8601 string | Timestamp of the edit |
| `summary` | string | One-line description of what changed |
| `pbis` | string[] | PBI IDs that triggered this edit (e.g., `["pbi-012"]`). Required for all entries |
| `change_process` | boolean \| absent | `true` if the document was frozen and FR-016 Change Process was followed. Omitted on initial creation |

### Rules
- **Catalog-first**: no design file may be created without an entry in
  `.design/catalog.md` AND an enabled entry in `.design/catalog-config.json`.
  The Scrum Master adds spec IDs to the config's `enabled` array during
  Sprint Planning.
- **Immediate stub creation**: when a spec ID is added to the `enabled`
  array in `catalog-config.json`, the Scrum Master invokes
  `scaffold-design-spec` to create a template stub with required
  frontmatter and placeholder sections. Developers populate the stub
  during the design phase.
- Multiple PBIs may reference the same design document.
- PBIs reference design documents via `design_doc_paths: string[]`
  (paths relative to project root, e.g., `.design/specs/ui/S-030-login.md`).
- Updates to existing documents follow FR-020 freeze/Change Process
  rules **and MUST append to `revision_history`**.
- Each `revision_history` entry MUST include `pbis`.
- Frozen after the Sprint in which they are created (FR-020).

---

## Entity: CommunicationsLog

**File**: `.scrum/communications.json`
**Owner**: Hook scripts (append-only)
**Readers**: Textual dashboard app (Communication Log panel), statusline.sh

Stores agent-to-agent messages captured by Claude Code hooks. Used by
the Textual dashboard's Communication Log panel (FR-014c) to display
messages with sender, recipient, and timestamp.

| Field | Type | Description |
|-------|------|-------------|
| `messages` | CommunicationMessage[] | Ordered list of agent messages |
| `max_messages` | integer | Maximum messages to retain (default: 200, oldest trimmed) |

### Embedded: CommunicationMessage

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | ISO 8601 string | When the message was sent |
| `sender_id` | string | Agent ID of the sender (e.g., `"scrum-master"`, `"dev-001-s3"`) |
| `sender_role` | string | Human-readable role (e.g., `"Scrum Master"`, `"Developer"`) |
| `recipient_id` | string \| null | Agent ID of the recipient; null = broadcast to all |
| `type` | enum | Message type: `"task_assignment"`, `"progress_update"`, `"review_request"`, `"review_result"`, `"phase_notification"`, `"change_request"`, `"file_change"`, `"agent_spawn"`, `"status_change"`, `"session_event"` |
| `content` | string | Human-readable message summary |

### Rules
- Messages are appended by hook scripts (`hooks/dashboard-event.sh`) when
  Agent Teams messaging events are detected.
- The file is capped at `max_messages` entries; oldest are trimmed on each append.
- If the file does not exist, the first hook creates it with an empty `messages` array.
- Dashboard readers tolerate a missing or empty file gracefully.

---

## Entity: DashboardEvents

**File**: `.scrum/dashboard.json`
**Owner**: Hook scripts (append-only)
**Readers**: Textual dashboard app (Work Log panel), statusline.sh

Stores timestamped agent activity events written by Claude Code hooks
(R2 Layer 2). Used by the Textual dashboard's Work Log panel
(FR-014d) and the status line for real-time agent activity.

| Field | Type | Description |
|-------|------|-------------|
| `events` | DashboardEvent[] | Ordered list of recent events |
| `max_events` | integer | Maximum events to retain (default: 100, oldest trimmed) |

### Embedded: DashboardEvent

| Field | Type | Description |
|-------|------|-------------|
| `timestamp` | ISO 8601 string | When the event occurred |
| `type` | enum | Event type: `"task_completed"`, `"teammate_idle"`, `"file_changed"`, `"phase_transition"`, `"subagent_start"`, `"subagent_stop"` |
| `agent_id` | string \| null | Developer or agent ID that triggered the event |
| `pbi_id` | string \| null | Related PBI ID, if applicable |
| `file_path` | string \| null | Absolute or relative file path (populated when `type` is `"file_changed"`) |
| `change_type` | enum \| null | `"created"`, `"modified"`, or `"deleted"` (populated when `type` is `"file_changed"`) |
| `detail` | string | Human-readable event description |

### Rules
- Events are appended by hook scripts (`hooks/dashboard-event.sh`).
- The file is capped at `max_events` entries; oldest are trimmed on each append.
- If the file does not exist, the first hook creates it with an empty `events` array.
- Dashboard readers tolerate a missing or empty file gracefully.

---

## Entity: HookLog

**File**: `.scrum/hooks.log`
**Owner**: All hooks (append-only via `log_hook` from `hooks/lib/validate.sh`)
**Readers**: Developers (debugging)

Plain-text log of hook activity for debugging. Each line is a timestamped
entry in the format: `<ISO8601> [LEVEL] <hook_name>: <message>`.

Levels: `INFO`, `WARN`, `ERROR`.

### Constraints

- The file is auto-trimmed to 500 lines (newest kept) on each append.
- Created automatically on first log entry.
- Not required for any hook functionality — purely diagnostic.

---

## Entity: TestResults

**File**: `.scrum/test-results.json`
**Owner**: Developer teammates (write during Integration Sprint)
**Readers**: Scrum Master (quality gate), completion-gate.sh, Textual dashboard app

Tracks automated test execution results during the Integration Sprint.
Written by Developer teammates running the `smoke-test` skill.
The Scrum Master blocks UAT until `overall_status` is `"passed"`.

| Field | Type | Description |
|-------|------|-------------|
| `categories` | TestCategory[] | Results per test category |
| `overall_status` | enum | `"pending"`, `"running"`, `"passed"`, `"failed"` |
| `started_at` | ISO 8601 string | When testing began |
| `updated_at` | ISO 8601 string | Last update timestamp |

### Embedded: TestCategory

| Field | Type | Description |
|-------|------|-------------|
| `name` | enum | `"unit"`, `"integration"`, `"e2e"`, `"smoke"`, `"regression"`, `"browser"` |
| `status` | enum | `"pending"`, `"running"`, `"passed"`, `"failed"`, `"skipped"` |
| `total` | integer | Total number of tests |
| `passed` | integer | Tests that passed |
| `failed` | integer | Tests that failed |
| `skipped` | integer | Tests that were skipped |
| `errors` | TestError[] | Details for failed tests |
| `runner_command` | string | Command used to run the tests |
| `executed_at` | ISO 8601 string | When this category was executed |

### Embedded: TestError

| Field | Type | Description |
|-------|------|-------------|
| `test_name` | string | Name or identifier of the failed test |
| `message` | string | Error message or failure reason |

### Rules
- Created by Developer teammates during the Integration Sprint via `smoke-test` skill.
- The `completion-gate.sh` hook blocks session stop during `integration_sprint` phase unless `overall_status` is `"passed"`.
- The Scrum Master reads this file to decide whether to proceed to UAT.
- Categories with `status: "skipped"` do not block the overall status.

---

## Entity: ReviewResult

**File**: `.scrum/reviews/<pbi-id>-review.md`
**Format**: Markdown
**Owner**: Assigned Reviewer (write)
**Readers**: Implementer, Scrum Master

Cross-review results for a PBI. Created during the Review phase (FR-009).

---

## File Relationships

```
state.json
  └── current_sprint_id → sprint.json.id

backlog.json
  └── items[].sprint_id → sprint.json.id
  └── items[].implementer_id → sprint.json.developers[].id
  └── items[].reviewer_id → sprint.json.developers[].id
  └── items[].design_doc_paths[] → .design/specs/{category}/{id}-{slug}.md
  └── items[].review_doc_path → reviews/<pbi-id>-review.md
  └── items[].parent_pbi_id → items[].id (self-reference)
  └── items[].depends_on_pbi_ids[] → items[].id (cross-reference)

sprint.json
  └── pbi_ids[] → backlog.json.items[].id
  └── developers[].assigned_work.implement[] → backlog.json.items[].id
  └── developers[].assigned_work.review[] → backlog.json.items[].id

improvements.json
  └── entries[].sprint_id → sprint-history.json.sprints[].id

communications.json
  └── messages[].sender_id → sprint.json.developers[].id | "scrum-master"
  └── messages[].recipient_id → sprint.json.developers[].id | "scrum-master" | null

dashboard.json
  └── events[].agent_id → sprint.json.developers[].id
  └── events[].pbi_id → backlog.json.items[].id

test-results.json
  (standalone — no foreign key references; read by completion-gate.sh and dashboard)
```
