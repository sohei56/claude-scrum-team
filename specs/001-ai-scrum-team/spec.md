# Feature Specification: AI-Powered Scrum Team

**Feature Branch**: `001-ai-scrum-team`
**Created**: 2026-02-21
**Status**: Draft
**Input**: User description: "Build claude-scrum-team — a shell-script-launched AI-powered Scrum development team for Claude Code."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Launch Scrum Team and Requirements Elicitation (Priority: P1)

The user runs `sh ./claude-scrum-team/scrum-start.sh` from the
CLI and an AI Scrum team is assembled automatically. The user is
guided through a Requirements Sprint where a single Developer asks
structured questions to elicit product requirements. The user
responds in natural language. The Sprint concludes when both
parties agree on the requirements document. After the Requirements
Sprint, the Scrum Master creates the initial Product Backlog with
coarse-grained PBIs.

**Why this priority**: Without team startup and requirements
elicitation, no subsequent development activity is possible.
This is the entry point for the entire product.

**Independent Test**: Run `sh ./claude-scrum-team/scrum-start.sh`,
answer the Developer's questions, and confirm the requirements
document is produced, saved, and the initial Product Backlog is
created with coarse-grained PBIs.

**Acceptance Scenarios**:

1. **Given** the shell script is available and no project is active,
   **When** the user runs `sh ./claude-scrum-team/scrum-start.sh`,
   **Then** a Scrum Master and one Developer are created, and the
   Developer begins asking requirements questions.

5. **Given** a project already exists on disk,
   **When** the user runs `sh ./claude-scrum-team/scrum-start.sh`,
   **Then** the system resumes the existing project from the exact
   point where it was last interrupted.

2. **Given** the Requirements Sprint is in progress,
   **When** the user answers all questions and confirms the
   requirements,
   **Then** a requirements document is saved covering business,
   functional, and non-functional requirements.

3. **Given** the Requirements Sprint is in progress,
   **When** the user provides incomplete or unclear answers,
   **Then** the Developer asks follow-up questions to clarify
   before proceeding.

4. **Given** the requirements document is complete,
   **When** the Requirements Sprint concludes,
   **Then** the Scrum Master creates the initial Product Backlog
   with coarse-grained PBIs (e.g. "User Management", "Payment
   Processing", "CI/CD Setup").

---

### User Story 2 - Development Sprint Cycle (Priority: P2)

The user experiences iterative Development Sprints. The Scrum
Master proposes a Sprint Goal scoped at a granularity that is
easy for the PO to review — it does not necessarily need to be
a coherent bundle of related functionality. The user approves
or adjusts the goal in natural language. Coarse-grained PBIs are refined into
implementation-ready PBIs at Sprint Planning. Developers produce
design documents for their assigned PBIs, then implement and test
them in parallel. Cross-review occurs within the same Sprint. At
Sprint Review, the Scrum Master presents the Increment with a
summary and, only when UX changes are included, a live demo.
The user inspects results and provides feedback. A Sprint Retrospective records
improvements.

**Why this priority**: This is the core development loop that
produces working software. It includes design, implementation,
testing, and review in each Sprint.

**Independent Test**: Start a Development Sprint after the
Requirements Sprint, verify Sprint Planning refines PBIs, design
documents are produced, implementation and cross-review occur,
and Sprint Review presents the Increment to the user.

**Acceptance Scenarios**:

1. **Given** the Product Backlog exists with coarse-grained PBIs,
   **When** the Scrum Master proposes a Sprint Goal,
   **Then** the user can approve or request changes in natural
   language.

2. **Given** the user approves the Sprint Goal,
   **When** Sprint Planning occurs,
   **Then** the Scrum Master refines coarse-grained PBIs into
   implementation-ready PBIs (one per function, screen, API, or
   platform component) and assigns each to one implementer and
   one reviewer.

3. **Given** Sprint Planning is complete,
   **When** the Design phase begins,
   **Then** Developers produce design documents for their assigned
   PBIs and read all existing design documents from previous
   Sprints to ensure consistency.

4. **Given** design is complete,
   **When** Developers work on assigned PBIs,
   **Then** each PBI is implemented by one Developer and reviewed
   by a different Developer within the same Sprint.

5. **Given** all PBIs in the Sprint meet the Definition of Done,
   **When** Sprint Review occurs,
   **Then** the Scrum Master presents a summary of changes and,
   only when the Increment includes UX changes, runs a live demo
   for the user.

6. **Given** the Sprint Review is complete,
   **When** the Sprint Retrospective occurs,
   **Then** improvements are recorded in a persistent log and a
   brief report is shared with the user.

7. **Given** a new Development Sprint begins,
   **When** Developers start work on assigned PBIs,
   **Then** each Developer reads the improvement log and applies
   relevant improvements to their current work.

---

### User Story 3 - Integration Sprint and Release (Priority: P3)

When the user determines the Product Goal has been achieved, the
team transitions to an Integration Sprint. This Sprint focuses on
product-wide quality assurance: integration testing, end-to-end
testing, regression testing, documentation consistency checks,
and user acceptance testing via live demo. When the user confirms
the product is release-ready, the project is complete.

**Why this priority**: The Integration Sprint is the final gate
before release. It depends on all Development Sprints being
complete.

**Independent Test**: After Development Sprints, trigger the
Integration Sprint, verify all testing categories are executed,
and confirm the user can declare the product release-ready.

**Acceptance Scenarios**:

1. **Given** the user has indicated the Product Goal is achieved,
   **When** the Integration Sprint begins,
   **Then** no new feature development occurs and all testing
   categories are executed.

2. **Given** the Integration Sprint reveals minor defects,
   **When** defects are identified,
   **Then** they are fixed within the Integration Sprint.

3. **Given** the Integration Sprint reveals major defects,
   **When** defects are identified,
   **Then** they are added to the Product Backlog and the team
   returns to Development Sprints.

4. **Given** all automated tests pass,
   **When** user acceptance testing begins,
   **Then** the team prepares the product for hands-on testing
   (e.g. launches the app locally, shares the URL or start
   command), provides the user with a guided testing flow
   covering key user workflows, and collects the user's
   feedback at each step.

5. **Given** the user has completed the guided testing flow,
   **When** the user confirms the product is release-ready,
   **Then** the project is marked complete.

---

### User Story 4 - TUI Dashboard (Priority: P4)

The user can view project progress through a rich terminal UI
dashboard. The dashboard shows the Product Backlog, Sprint
Backlog, sprint progress, and agent activity. The user never
needs to inspect raw files or logs to understand project status.

**Why this priority**: The dashboard is the primary interface
for the user to monitor progress. While development can proceed
without it (via Sprint Review summaries), it significantly
improves the user experience.

**Independent Test**: Launch the dashboard during a Development
Sprint and verify it displays Product Backlog, Sprint Backlog,
progress indicators, and agent activity in real time.

**Acceptance Scenarios**:

1. **Given** a Development Sprint is in progress,
   **When** the dashboard is displayed,
   **Then** the Product Backlog, Sprint Backlog, sprint progress,
   and agent activity are persistently visible alongside the
   conversation.

2. **Given** a Developer completes a PBI,
   **When** the dashboard updates,
   **Then** the sprint progress reflects the completed PBI in
   real time without the user needing to refresh or invoke a
   command.

---

### User Story 5 - Dynamic Agent Capabilities (Priority: P5)

During Sprint Planning, each Developer self-selects and installs
appropriate specialist agents from the awesome-claude-code-
subagents catalog (`https://github.com/VoltAgent/awesome-claude-code-subagents/tree/main`)
to handle their assigned tasks. This happens automatically without
user involvement.

**Why this priority**: Enhances Developer effectiveness but is
not required for core functionality. Development Sprints can
operate without specialist agents.

**Independent Test**: Observe Sprint Planning and verify each
Developer selects relevant specialist agents from the catalog
based on their assigned PBIs.

**Acceptance Scenarios**:

1. **Given** Sprint Planning assigns a PBI to a Developer,
   **When** the Developer prepares for implementation,
   **Then** the Developer selects and installs relevant specialist
   agents from the awesome-claude-code-subagents catalog.

2. **Given** the catalog is unavailable or has no matching agents,
   **When** the Developer prepares for implementation,
   **Then** the Developer proceeds without specialist agents and
   no error is shown to the user.

---

### Edge Cases

- What happens when the user cancels a Sprint mid-implementation?
  Only the PO can cancel a Sprint. Work in progress is preserved,
  and the Scrum Master adjusts the Product Backlog accordingly.

- What happens when dependent PBIs must coexist in the same Sprint?
  The assigned implementers agree on the interface contract between
  their components before implementation begins.

- What happens when the Developer count exceeds 10?
  The Scrum Master narrows the Sprint Goal to reduce the number of
  PBIs until the Developer count is within the 1-10 range.

- What happens when cross-review finds issues that cannot be fixed
  within the Sprint?
  Issues are logged as new PBIs in the Product Backlog for a future
  Sprint.

- What happens when the improvement log grows too large?
  The log is reviewed every 3 Sprints to consolidate entries and
  archive items that are no longer relevant.

- What happens when the user wants to change requirements during
  Development Sprints?
  The Change Process is followed: Developer raises the issue,
  Scrum Master consults the user, and if approved, documents are
  updated and all Developers are notified.

- What happens when a later Sprint's design conflicts with an
  earlier Sprint's design documents?
  Developers read all existing design documents before producing
  new ones. If a conflict is discovered, the Change Process is
  followed to update the affected documents.

- What happens when the user closes Claude Code mid-Sprint?
  All project state is persisted to disk. When the user starts a
  new session, the project resumes from the exact point where it
  was interrupted.

- What happens when a Developer agent fails or crashes
  mid-implementation?
  The Scrum Master detects the failure, reassigns the PBI to a
  new Developer agent, and work resumes. No user intervention is
  required.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST launch a complete Scrum team (Scrum
  Master + Developers) when the user runs the shell script
  `scrum-start.sh`. If a project already exists on disk, running
  the script MUST resume the existing project from where it was
  last interrupted.

- **FR-002**: The system MUST conduct a Requirements Sprint where
  a single Developer elicits requirements from the user through
  structured questions and produces a requirements document
  covering business, functional, and non-functional requirements.

- **FR-003**: The Scrum Master MUST create the initial Product
  Backlog after the Requirements Sprint with coarse-grained PBIs.
  PBIs MUST be progressively refined into implementation-ready
  granularity when selected for a Sprint.

- **FR-004**: Each Development Sprint MUST include a Design phase
  where Developers produce design documents for their assigned
  PBIs before implementation begins. Developers MUST read all
  existing design documents from previous Sprints to ensure
  consistency.

- **FR-005**: The Scrum Master MUST propose Sprint Goals scoped at
  a granularity that is easy for the PO to review. Sprint Goals
  do not need to target coherent groups of related functionality.
  The Scrum Master MUST present them to the user for approval in
  natural language.

- **FR-006**: The system MUST assign each PBI to one implementer
  and one reviewer. No Developer reviews their own work.

- **FR-007**: The system MUST determine the Developer count per
  Sprint as number of PBIs x 2, capped at 10. If the count
  exceeds 10, the Scrum Master MUST narrow the Sprint Goal.

- **FR-008**: The Scrum Master MUST avoid placing PBIs with
  dependencies on each other in the same Sprint. When unavoidable,
  implementers MUST agree on interface contracts before
  implementation begins.

- **FR-009**: Cross-review MUST occur within the same Sprint,
  after all implementers complete their work. Reviewers MUST read
  the requirements document and relevant design documents (both
  current and previous Sprints). Review issues MUST be either
  fixed within the Sprint or logged as new PBIs.

- **FR-010**: At Sprint Review, the Scrum Master MUST present the
  Increment with a change summary. A live demo MUST be performed
  only when the Increment includes UX changes; otherwise the
  demo is omitted.

- **FR-011**: The Scrum Master MUST report Product Backlog
  remaining scope and Product Goal achievement progress at every
  Sprint Review.

- **FR-012**: Sprint Retrospective MUST record improvements in a
  persistent log that carries across Sprints. The log MUST be
  reviewed every 3 Sprints to consolidate and archive entries.
  At the start of each subsequent Sprint, Developers MUST read
  the improvement log and apply relevant improvements to their
  work.

- **FR-013**: The system MUST conduct an Integration Sprint when
  the user indicates the Product Goal is achieved, covering
  integration testing, end-to-end testing, regression testing,
  documentation consistency checks, and user acceptance testing.
  For user acceptance testing, the team MUST prepare the product
  for hands-on use (e.g. launch locally, share URL or start
  command), provide a guided testing flow covering key user
  workflows, and collect the user's feedback at each step.

- **FR-014**: The system MUST provide a TUI dashboard that is
  persistently visible alongside the conversation, showing
  Product Backlog, Sprint Backlog, sprint progress, and agent
  activity. The dashboard MUST update in real time as work
  progresses.

- **FR-015**: All user interactions MUST be in natural language.
  The user MUST NOT be required to write structured items, edit
  configuration files, or perform developer-level operations.

- **FR-016**: The system MUST follow the Change Process for any
  modifications to requirements or design documents during
  Development Sprints: Developer raises issue, Scrum Master
  consults user, user approves, documents are updated, all
  Developers are notified.

- **FR-017**: A PBI meets the Definition of Done when: design
  document is produced and reviewed before implementation begins,
  implementation follows the design document, unit tests are
  written and pass, existing tests pass (no regressions), code
  passes linter and formatter, and cross-review is completed.

- **FR-018**: The system MUST be launchable via a shell script
  (`scrum-start.sh`) that the user runs from the CLI. The only
  prerequisite is a working Claude Code installation — no
  additional tool installation is required.

- **FR-019**: Developers MUST self-select and install appropriate
  specialist agents from the awesome-claude-code-subagents catalog
  (`https://github.com/VoltAgent/awesome-claude-code-subagents/tree/main`)
  during Sprint Planning based on their assigned tasks.

- **FR-020**: The requirements document MUST be frozen during
  Development Sprints. Design documents MUST be frozen after the
  Sprint in which they are created. Changes MUST follow the Change
  Process (FR-016).

- **FR-021**: The system MUST persist all project state to disk so
  that the user can close Claude Code at any point and resume the
  project in a later session. On resume, the project MUST continue
  from the exact point where it was interrupted.

- **FR-022**: If a Developer agent fails or crashes during
  implementation, the Scrum Master MUST detect the failure,
  reassign the PBI to a new Developer agent, and resume work
  without requiring user intervention.

### Key Entities

- **Scrum Team**: The complete team consisting of the Product
  Owner (user), Scrum Master (AI), and Developers (AI agents).

- **Product Backlog**: Ordered list of PBIs representing all work
  needed to achieve the Product Goal. Managed by the Scrum Master.
  PBIs start coarse-grained and are progressively refined.

- **Product Backlog Item (PBI)**: A unit of work that starts
  coarse-grained (e.g. "User Management") and is refined to
  implementation-ready granularity (one function, screen, API,
  or platform component) when selected for a Sprint. Each
  refined PBI produces three deliverables: design document,
  implementation, and tests. Design is completed and reviewed
  before implementation begins.

- **Sprint Backlog**: The Sprint Goal plus the set of refined PBIs
  selected for the Sprint, with assigned implementers and
  reviewers.

- **Increment**: A usable result of a Sprint that meets the
  Definition of Done.

- **Requirements Document**: The single source of truth for what
  the product must do. Produced in the Requirements Sprint.

- **Design Documents**: Design knowledge base that grows
  incrementally across Sprints. Each Sprint adds design documents
  for its PBIs. Previous Sprints' documents are referenced for
  consistency.

- **Improvement Log**: Persistent record of retrospective
  improvements that carries across Sprints.

- **Product Goal**: The desired future state of the product,
  defined and owned by the user.

- **Sprint Goal**: An objective for a Sprint scoped at a granularity
  that is easy for the PO to review, proposed by the Scrum Master
  and approved by the user. Does not need to target coherent groups
  of related functionality.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: The user can go from zero to a running Scrum team
  with a single shell command (`sh ./claude-scrum-team/scrum-start.sh`)
  and no additional setup.

- **SC-002**: The Requirements Sprint produces a complete
  requirements document through natural language conversation
  alone — the user never edits structured files.

- **SC-003**: Every Development Sprint produces at least one
  Increment that meets the Definition of Done, including
  cross-review by a different Developer.

- **SC-004**: The user can understand project status at any time
  through the TUI dashboard without inspecting code, logs, or
  internal files.

- **SC-005**: The user interacts exclusively in natural language
  across all Scrum events — no structured input, configuration
  editing, or developer-level operations are required.

- **SC-006**: The Integration Sprint catches defects that
  individual Sprint testing missed, as verified by integration,
  end-to-end, and regression test results.

- **SC-007**: The system operates as a self-contained shell-script-
  launched tool with no dependencies beyond Claude Code itself.

- **SC-008**: Sprint Retrospective improvements demonstrably
  carry forward — improvements logged in Sprint N are reflected
  in team behavior in subsequent Sprints.

- **SC-009**: Design documents produced in later Sprints are
  consistent with those from earlier Sprints, as verified during
  the Integration Sprint documentation consistency check.

## Clarifications

### Session 2026-02-21

- Q: Can the user close Claude Code mid-Sprint and resume later? → A: Full resume — all project state is persisted to disk and the project resumes on the next session.
- Q: What happens if the shell script is run when a project already exists? → A: Auto-resume — the script resumes the existing project automatically.
- Q: How does the user access the TUI dashboard during a Sprint? → A: Always visible — the dashboard is shown persistently alongside the conversation.
- Q: What happens if a Developer agent fails mid-implementation? → A: Auto-recover — the Scrum Master detects the failure, reassigns the PBI to a new Developer agent, and work resumes.

## Out of Scope (MVP)

- Web-based dashboard
- Multi-user / multi-PO support
- Integration with external project management tools
- Custom agent definitions by users (the awesome-claude-code-
  subagents catalog at `https://github.com/VoltAgent/awesome-claude-code-subagents/tree/main`
  is used instead)
- Multiple Scrum Teams working on the same product

## Assumptions

- Claude Code is installed and available on the user's PATH,
  providing the necessary APIs for agent orchestration (Agent
  Teams).
- The awesome-claude-code-subagents catalog
  (`https://github.com/VoltAgent/awesome-claude-code-subagents/tree/main`)
  is publicly accessible and provides installable agent
  configurations.
- The user's environment supports TUI rendering (standard terminal
  emulator with basic ANSI support).
- Agent Teams can be re-created per Sprint without significant
  setup overhead, as stated in the Claude Code Agent Teams
  documentation.
- The user clones or downloads the claude-scrum-team repository
  and runs the shell script from within or alongside their
  project directory.
