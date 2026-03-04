# Tasks: AI-Powered Scrum Team

**Input**: Design documents from `/specs/001-ai-scrum-team/`
**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: Lint tests and unit tests are included — the project structure defines `tests/` as a deliverable with bats-core, jq, yq, and ShellCheck.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project**: All files at repository root per plan.md
- Shell scripts: `hooks/`, `scripts/`, root
- Agent definitions: `agents/`
- Skill definitions: `skills/<name>/SKILL.md`
- Python TUI: `dashboard/`
- Tests: `tests/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create project directory structure and initialize test infrastructure

- [x] T001 Create project directory structure per plan.md: `agents/`, `skills/` (14 subdirectories: `sprint-planning/`, `spawn-teammates/`, `install-subagents/`, `design/`, `implementation/`, `cross-review/`, `sprint-review/`, `retrospective/`, `requirements-sprint/`, `integration-sprint/`, `backlog-refinement/`, `change-process/`, `scaffold-design-spec/`, `smoke-test/`), `hooks/`, `dashboard/`, `scripts/`, `tests/{unit,lint,integration,fixtures,test_helper}/`
- [x] T002 [P] Initialize bats-core test infrastructure: add bats-support and bats-assert as git submodules in `tests/test_helper/`, create `tests/test_helper/common-setup.bash` with shared helpers for loading fixtures and asserting JSON structure
- [x] T003 [P] Create contributor setup script `scripts/setup-dev.sh`: install bats-core, jq, yq, shellcheck via brew; run `git submodule update --init --recursive`; then call `scripts/setup-user.sh`. Per agent-interfaces.md § setup-dev.sh
- [x] T004 [P] Create linter/formatter configuration: `.shellcheckrc` for Bash 3.2+ defaults, `pyproject.toml` with ruff (or black + isort) config for `dashboard/` Python code, and `.editorconfig` for consistent whitespace. Constitution VI requires automated code style committed to the repository

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Agent definitions, design governance, and teammate spawning that ALL user stories depend on

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [x] T005 Create Scrum Master agent definition `agents/scrum-master.md` with YAML frontmatter: Delegate mode instruction (coordination only — cannot write code, run tests, or perform implementation), `skills:` listing all 14 ceremony Skills, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` requirement. Per agent-interfaces.md § Scrum Master — responsibilities table covers FR-001 through FR-022
- [x] T006 [P] Create Developer teammate template `agents/developer.md` with YAML frontmatter: `skills: [requirements-sprint, design, implementation, cross-review, install-subagents, smoke-test]`, lifecycle steps (spawn → PBI assignment → read improvements → install sub-agents → design → implement → review → terminate). Per agent-interfaces.md § Developer — responsibilities: FR-002, FR-004, FR-009, FR-012, FR-017, FR-019
- [x] T007 [P] Create `.design/catalog.md` design governance file with 8 categories (system-wide, data, interface, ui, logic, quality, decision-records, operations), 6 governance rules (catalog-first, enabled=file required, disabled=file prohibited, no undocumented specs, category directories, immediate stub creation on enable via `scaffold-design-spec` Skill). Per research.md R8 and data-model.md § DesignDocument
- [x] T008 Create `skills/spawn-teammates/SKILL.md` with `## Inputs` / `## Outputs`: reads `sprint.json` → `pbi_ids`, `developer_count`; reads `backlog.json` → assigned PBIs; outputs `sprint.json` → `developers[]` populated with `assigned_work.implement[]` + `assigned_work.review[]` (round-robin, no self-review); spawns Agent Teams teammates with consistent naming (`dev-001`, ...). Developer count = min(refined PBIs, 6). Per agent-interfaces.md Skill I/O table

**Checkpoint**: Foundation ready — agent definitions, design governance, and teammate spawning in place

---

## Phase 3: User Story 1 — Launch & Requirements (Priority: P1) 🎯 MVP

**Goal**: User runs `sh scrum-start.sh` and is guided through a Requirements Sprint that produces a requirements document and initial Product Backlog

**Independent Test**: Run `sh scrum-start.sh`, answer the Developer's questions, confirm `requirements.md` is produced and `backlog.json` is created with coarse-grained PBIs

- [x] T009 [US1] Create entry-point shell script `scrum-start.sh`: validate prerequisites (Claude Code on PATH, `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, Python 3.9+, `textual` + `watchdog` importable), detect new vs resume via `.scrum/state.json`, copy `agents/*.md` to `<project>/.claude/agents/`, copy `skills/*/SKILL.md` to `<project>/.claude/skills/`, copy `hooks/*.sh` to `<project>/.claude/hooks/`, configure `.claude/settings.json` (status line + hook entries), launch tmux split layout (main pane: `claude --agent scrum-master`, side pane: `python dashboard/app.py`) or fallback to status line with info message. Exit codes: 0=normal, 1=CLI missing, 2=Agent Teams off, 3=Python/TUI missing (with pip/venv guidance). Delegates validation and file-copying logic to `scripts/setup-user.sh` (see T010). Per agent-interfaces.md § scrum-start.sh
- [x] T010 [P] [US1] Create end-user setup script `scripts/setup-user.sh`: validate Claude Code, Agent Teams env var, Python 3.9+, pip, TUI packages (`textual`, `watchdog`); copy agents/skills to `<project>/.claude/`; configure status line and hooks in `<project>/.claude/settings.json`. NEVER modify `~/.claude/`. Print actionable pip/venv guidance if dependencies missing. Called by both `scrum-start.sh` (T009) and `setup-dev.sh` (T003) — shared prerequisite validation and file-copying logic. Per agent-interfaces.md § setup-user.sh
- [x] T011 [P] [US1] Create SessionStart hook `hooks/session-context.sh`: read `.scrum/state.json`, output JSON with `additionalContext` containing current phase, Sprint ID, Sprint Goal, and resume context. Per agent-interfaces.md § SessionStart Hook
- [x] T012 [US1] Create `skills/requirements-sprint/SKILL.md` with `## Inputs` / `## Outputs`: input `state.json` → `phase: new`; output `.scrum/requirements.md` (created via single Developer dialogue covering business, functional, non-functional requirements), `state.json` → `phase: requirements_sprint → backlog_created`, `backlog.json` (initial Product Backlog with coarse-grained PBIs, `next_pbi_id` set). Handles follow-up questions for unclear answers. FR-002, FR-003, FR-015
- [x] T013 [US1] Create status line script `scripts/statusline.sh`: read session JSON from stdin + `.scrum/state.json`, `backlog.json`, `sprint.json`, `dashboard.json` from disk; output 3-line ANSI-formatted text — Line 1: `Sprint <N> "<Goal>" | Phase: <phase> | <X>/<Y> PBIs done`, Line 2: `Backlog: <N> items (<M> refined, <K> draft)`, Line 3: `Agents: SM:active Dev1:impl(PBI-7) Dev2:review(PBI-5)`. Handle missing files gracefully. Per agent-interfaces.md § statusline.sh

**Checkpoint**: User can launch a Scrum team, complete a Requirements Sprint, and see a Product Backlog with coarse-grained PBIs. Status line shows current state.

---

## Phase 4: User Story 2 — Development Sprint Cycle (Priority: P2)

**Goal**: Iterative Development Sprints with Sprint Planning, design, implementation, cross-review, Sprint Review, and Retrospective

**Independent Test**: Start a Development Sprint after Requirements Sprint, verify Sprint Planning refines PBIs, design documents are produced, implementation and cross-review occur, Sprint Review presents Increment, Retrospective records improvements

### Ceremony Skills (sequential ceremony order)

- [x] T014 [US2] Create `skills/backlog-refinement/SKILL.md` with `## Inputs` / `## Outputs`: input `backlog.json` → `items[]` with `status: draft`, `requirements.md`, count of existing `refined` PBIs (WIP check); output `backlog.json` → `items[].status: refined`, `acceptance_criteria` (non-empty), `ux_change`, `design_doc_paths` populated. Refined WIP capped at 6-12 (1-2 Sprints of capacity). FR-003
- [x] T015 [US2] Create `skills/sprint-planning/SKILL.md` with `## Inputs` / `## Outputs`: input `state.json` → `phase: backlog_created | retrospective`, `backlog.json` → refined PBIs; output `sprint.json` (created with `id`, `goal`, `type: development`, `status: planning`, `pbi_ids`, `developer_count`), `backlog.json` → `items[].sprint_id`, `implementer_id`, `reviewer_id` (round-robin, no self-review; single-PBI Sprint: `reviewer_id = "scrum-master"`), `state.json` → `phase: sprint_planning`. Propose Sprint Goal for user approval. Avoid dependent PBIs in same Sprint. FR-005, FR-006, FR-007, FR-008
- [x] T016 [US2] Create `skills/scaffold-design-spec/SKILL.md` with `## Inputs` / `## Outputs`: input `.design/catalog.md` (newly enabled entries), `sprint.json` → `id` (current Sprint), `backlog.json` → PBI IDs for `related_pbis`; output `.design/specs/{category}/{id}-{slug}.md` stub files with YAML frontmatter (`catalog_id`, `created_sprint`, `last_updated_sprint`, `related_pbis`, `frozen: false`, `revision_history` with initial entry) and placeholder sections. FR-004
- [x] T017 [US2] Create `skills/design/SKILL.md` with `## Inputs` / `## Outputs`: input `state.json` → `phase: sprint_planning`, `sprint.json` → `developers[]`, `.design/catalog.md`, existing `.design/specs/**/*.md` stubs (created by `scaffold-design-spec`); output populated design documents with `revision_history` entries including `pbis` field, `backlog.json` → `items[].design_doc_paths`, `state.json` → `phase: design`. Developers MUST read all existing designs from previous Sprints for consistency. FR-004
- [x] T018 [US2] Create `skills/implementation/SKILL.md` with `## Inputs` / `## Outputs`: input `state.json` → `phase: design`, `sprint.json`, `.design/specs/**/*.md`, `requirements.md`; output source code + test files in user's project, `backlog.json` → `items[].status: in_progress`, `state.json` → `phase: implementation`. Developers read improvement log and apply relevant improvements. FR-017
- [x] T019 [US2] Create `skills/cross-review/SKILL.md` with `## Inputs` / `## Outputs`: input `state.json` → `phase: implementation`, all PBIs with `status: in_progress` implementation complete; output `.scrum/reviews/<pbi-id>-review.md` (created per PBI), `backlog.json` → `items[].status: review → done`, `items[].review_doc_path`. In single-PBI Sprint: `reviewer_id = "scrum-master"`, Scrum Master performs review. Reviewers read requirements + design docs. Issues fixed in Sprint or logged as new PBIs. `state.json` → `phase: review`. FR-009
- [x] T020 [US2] Create `skills/sprint-review/SKILL.md` with `## Inputs` / `## Outputs`: input `state.json` → `phase: review`, `sprint.json`, `backlog.json`; output `sprint-history.json` → `sprints[]` (SprintSummary appended: `id`, `goal`, `type`, `pbis_completed`, `pbis_total`, `started_at`, `completed_at`), `state.json` → `phase: sprint_review`. Present change summary. Live demo ONLY if any PBI has `ux_change: true`. Report remaining backlog scope and Product Goal progress. FR-010, FR-011
- [x] T021 [US2] Create `skills/retrospective/SKILL.md` with `## Inputs` / `## Outputs`: input `state.json` → `phase: sprint_review`; output `improvements.json` → `entries[]` (new Improvement appended: `id`, `sprint_id`, `description`, `status: active`, `created_at`), `state.json` → `phase: retrospective`. Consolidate every 3 Sprints: archive stale entries, update `last_consolidation_sprint`. Share brief report with user. FR-012
- [x] T022 [P] [US2] Create `skills/change-process/SKILL.md` with `## Inputs` / `## Outputs`: input frozen document path, proposed change description, user approval; output updated document with new `revision_history` entry (`pbis`, `change_process: true`), `backlog.json` updates if scope changes needed. Developer raises → Scrum Master consults user → user approves → documents updated → all Developers notified. FR-016, FR-020

### Sprint Enforcement Hooks (all independent)

- [x] T023 [P] [US2] Create PreToolUse hook `hooks/phase-gate.sh`: read `.scrum/state.json` → `phase` and `.design/catalog.md`; output `permissionDecision` JSON (`allow`, `deny`, or `ask`). Phase gating rules: deny `Edit` on source files during `design` phase, deny `Write`/`Edit` under `.design/specs/` if target file has no enabled catalog entry, deny code modifications during `sprint_review`, deny source file creation during `requirements_sprint`. Per agent-interfaces.md § PreToolUse Hook
- [x] T024 [P] [US2] Create Stop hook `hooks/completion-gate.sh`: read `.scrum/state.json` and relevant state files for current phase; output exit code 0 (allow) or exit code 2 with `reason` JSON if exit criteria not met (e.g., PBIs not all `done` before Sprint Review, no improvement recorded before Retrospective end). Per agent-interfaces.md § Stop Hook
- [x] T025 [P] [US2] Create TaskCompleted hook `hooks/quality-gate.sh`: read PBI status, test results, lint results; output exit code 0 (pass) or exit code 2 with instructions if Definition of Done gates fail — check: design document exists and reviewed, implementation follows design, unit tests written and passing, existing tests pass (no regressions), code passes linter/formatter, cross-review completed. FR-017. Per agent-interfaces.md § TaskCompleted Hook
- [x] T026 [P] [US2] Create PostToolUse/TeammateIdle hook `hooks/dashboard-event.sh`: read hook event JSON from stdin (Claude Code hook payload); append file change events (`type: file_changed`, `file_path`, `change_type`) to `.scrum/dashboard.json` → `events[]`; append agent communication messages to `.scrum/communications.json` → `messages[]`. Cap at `max_events` (100) / `max_messages` (200), trim oldest. Create files with empty arrays if not present. Per agent-interfaces.md § dashboard-event.sh

**Checkpoint**: Full Development Sprint cycle works: planning → design → implementation → cross-review → Sprint Review → Retrospective. Hooks enforce phase gates and quality gates.

---

## Phase 5: User Story 3 — Integration Sprint (Priority: P3)

**Goal**: Product-wide quality assurance Sprint with integration, E2E, regression testing, and user acceptance testing

**Independent Test**: After Development Sprints, trigger Integration Sprint, verify all testing categories execute, user can declare release-ready

- [x] T027 [US3] Create `skills/integration-sprint/SKILL.md` with `## Inputs` / `## Outputs`: input `state.json` → `phase: retrospective`, user confirmation that Product Goal is achieved; output integration testing, E2E testing, regression testing, documentation consistency checks. For user acceptance testing: prepare product for hands-on use (launch locally, share URL/start command), provide guided testing flow covering key user workflows, collect user feedback at each step. Minor defects fixed in-Sprint; major defects added to backlog → return to Development Sprints. `state.json` → `phase: integration_sprint → complete` when user confirms release-ready. FR-013

**Checkpoint**: Integration Sprint verifies product quality across all Sprints. User can declare release-ready.

---

## Phase 6: User Story 4 — TUI Dashboard (Priority: P4)

**Goal**: Rich terminal UI dashboard with four real-time panels showing Sprint status, PBI progress, communications, and file changes

**Independent Test**: Launch dashboard during a Development Sprint, verify Sprint Overview, PBI Progress Board, Communication Log, and File Change Log all update in real time

- [x] T028 [US4] Create Textual TUI dashboard `dashboard/app.py`: Python 3.9+ application using `textual` framework with `watchdog` filesystem monitoring of `.scrum/` directory. Four panels: (a) Sprint Overview — `DataTable` or `Static` widget sourced from `state.json` + `sprint.json` showing Sprint Goal, phase, PBI count, Developer assignments; (b) PBI Progress Board — `DataTable` (sortable, colored rows by status) sourced from `backlog.json` showing each PBI with `id`, `title`, `status`, `implementer_id`, `reviewer_id`; (c) Communication Log — `RichLog` (scrollable) sourced from `communications.json` showing messages with `sender_id`, `sender_role`, `recipient_id`, `type`, `content`, `timestamp`; (d) File Change Log — `RichLog` (scrollable) sourced from `dashboard.json` showing `file_path`, `change_type`, `agent_id`, `timestamp`. Watchdog `Observer` watches `.scrum/` → worker threads re-read JSON → panels update via Textual message passing. Keyboard: Tab between panels, arrow keys to scroll. Gracefully handle missing or empty files. FR-014. Per agent-interfaces.md § Textual TUI App

**Checkpoint**: Dashboard displays all four panels with real-time updates from `.scrum/` JSON files.

---

## Phase 7: User Story 5 — Dynamic Agent Capabilities (Priority: P5)

**Goal**: Developers self-select and install specialist sub-agents from the awesome-claude-code-subagents catalog during Sprint Planning

**Independent Test**: Observe Sprint Planning, verify Developers select relevant sub-agents based on assigned PBIs, use them via Task tool during implementation

- [x] T029 [US5] Create `skills/install-subagents/SKILL.md` with `## Inputs` / `## Outputs`: input PBI assignment (task context from `backlog.json` → assigned PBI details), catalog URL (`https://github.com/VoltAgent/awesome-claude-code-subagents/tree/main`); output `.claude/agents/*.md` (installed sub-agent definition files with YAML frontmatter: `tools`, `model`), `sprint.json` → `developers[].sub_agents` (runtime-populated with actually-invoked agent names, not candidates). Graceful degradation: if catalog unavailable or no matching agents, Developer proceeds without sub-agents, no error shown to user. FR-019. Per research.md R9

**Checkpoint**: Developers can self-select specialist sub-agents and use them via the Task tool.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Test suite, linting, documentation, and end-to-end validation

- [x] T030 [P] Create agent definition lint tests `tests/lint/agent-frontmatter.bats`: validate YAML frontmatter in `agents/scrum-master.md` and `agents/developer.md` using yq — required fields present (`name`, `description`, `skills`), Scrum Master has Delegate mode instruction, Developer has `install-subagents` in skills list, no unknown fields
- [x] T031 [P] Create skill definition lint tests `tests/lint/skill-frontmatter.bats`: validate all 14 `skills/*/SKILL.md` files — YAML frontmatter present with required fields, `## Inputs` and `## Outputs` sections exist in body, `disable-model-invocation: true` set. Use yq for frontmatter and grep for body sections
- [x] T032 [P] Create state file schema validation tests `tests/unit/state-schema.bats`: create fixture JSON files in `tests/fixtures/` (valid + invalid samples for each entity), validate against `specs/001-ai-scrum-team/contracts/state-schemas.json` definitions using jq — test ProjectState, ProductBacklog, PBI, Sprint, Developer (`assigned_work.implement` + `assigned_work.review`), ImprovementLog, CommunicationsLog, DashboardEvents
- [x] T033 [P] Create hook unit tests `tests/unit/hooks.bats`: test each hook script with mock `.scrum/` state files in `tests/fixtures/` — `phase-gate.sh` (verify deny/allow per phase), `session-context.sh` (verify JSON output with additionalContext), `completion-gate.sh` (verify exit code 2 on unmet criteria), `quality-gate.sh` (verify DoD checks), `dashboard-event.sh` (verify JSON append to dashboard.json + communications.json)
- [x] T034 Create script integration tests `tests/integration/script-compose.bats`: test `scrum-start.sh` prerequisite checking with mocked missing dependencies (verify exit codes 1/2/3 and stderr messages), test `setup-user.sh` file copying (verify `.claude/agents/`, `.claude/skills/`, `.claude/settings.json` created correctly), test `statusline.sh` output format with fixture state files (verify 3-line ANSI output)
- [x] T035 Run ShellCheck on all shell scripts (`scrum-start.sh`, `scripts/*.sh`, `hooks/*.sh`) and fix all warnings/errors for Bash 3.2+ compatibility. Run ruff (or black + isort) on `dashboard/app.py` and fix all Python style issues
- [x] T036 Validate end-to-end flow per `quickstart.md` § Testing an End-to-End Flow: create temp project, run `setup-user.sh`, verify `.scrum/` directory structure, `.claude/agents/` contains both agent definitions, `.claude/skills/` contains all 14 ceremony skills, hooks configured in `.claude/settings.json`, status line displays correctly
- [x] T037 [P] Create `README.md` at repository root: project description, badges (if applicable), prerequisites (Claude Code, Python 3.9+, TUI packages), quickstart usage (`sh scrum-start.sh`), link to `specs/001-ai-scrum-team/quickstart.md` for detailed setup, link to `CONTRIBUTING.md`, license. Constitution VI requires clear README instructions and documented public interfaces
- [x] T038 [P] Create `CONTRIBUTING.md` at repository root: development setup (link to `scripts/setup-dev.sh`), running tests (`bats tests/unit/ tests/lint/`), running linters (`shellcheck`, `ruff`), commit conventions (Constitution IV task-based commits), branch conventions, PR process, code style expectations (reference `.shellcheckrc`, `pyproject.toml`, `.editorconfig`). Constitution VI requires contributing guidelines

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 (directory structure) — BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 — entry point and first Sprint
- **US2 (Phase 4)**: Depends on Phase 3 — needs running team from Requirements Sprint
- **US3 (Phase 5)**: Depends on Phase 4 — needs Development Sprint cycle working
- **US4 (Phase 6)**: Depends on Phase 2 (reads `.scrum/` schemas) — can develop in parallel with US1-US3; full integration requires US2 hooks (T026)
- **US5 (Phase 7)**: Depends on Phase 2 — can develop in parallel with US2+
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: Depends on Foundational (Phase 2) — no other story dependencies
- **US2 (P2)**: Depends on US1 — needs Requirements Sprint complete, backlog with coarse-grained PBIs
- **US3 (P3)**: Depends on US2 — needs Development Sprint cycle working
- **US4 (P4)**: Can develop after Phase 2 (schema-driven), full test after US2 hooks (T026)
- **US5 (P5)**: Can develop after Phase 2, integrates into US2 Developer lifecycle

### Within Each User Story

- Skills follow ceremony order (planning → design → implementation → review)
- Hooks are independent and can be developed in parallel
- Entry scripts depend on agent/skill definitions being defined

### Parallel Opportunities

- **Phase 1**: T002, T003, T004 can run in parallel
- **Phase 2**: T006, T007 can run in parallel (after T005)
- **Phase 3**: T010, T011 can run in parallel
- **Phase 4**: All hooks (T023-T026) can run in parallel; T022 (change-process) is independent of ceremony order
- **US4 + US5**: Can develop in parallel with US2 ceremony skills (different files, no shared state)
- **Phase 8**: All lint/unit tests (T030-T033) can run in parallel; T037, T038 can run in parallel

---

## Parallel Example: Phase 4 Hooks

```bash
# All hooks read from .scrum/ state files independently:
Task: "Create PreToolUse hook hooks/phase-gate.sh"
Task: "Create Stop hook hooks/completion-gate.sh"
Task: "Create TaskCompleted hook hooks/quality-gate.sh"
Task: "Create PostToolUse hook hooks/dashboard-event.sh"
```

## Parallel Example: Phase 8 Tests

```bash
# All lint/unit tests validate independent file sets:
Task: "Create agent lint tests tests/lint/agent-frontmatter.bats"
Task: "Create skill lint tests tests/lint/skill-frontmatter.bats"
Task: "Create state schema tests tests/unit/state-schema.bats"
Task: "Create hook unit tests tests/unit/hooks.bats"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (directory structure, test infra, linter config)
2. Complete Phase 2: Foundational (agent defs, catalog, spawn-teammates)
3. Complete Phase 3: User Story 1 (scrum-start.sh, requirements-sprint, statusline)
4. **STOP and VALIDATE**: Run `sh scrum-start.sh`, complete Requirements Sprint, verify backlog created
5. Deploy/demo if ready

### Incremental Delivery

1. Phase 1 + 2 → Foundation ready
2. Add US1 → Launch team, complete Requirements Sprint → **MVP!**
3. Add US2 → Full Development Sprint cycle → Core product
4. Add US4 → TUI dashboard for real-time monitoring
5. Add US3 → Integration Sprint for release quality
6. Add US5 → Dynamic sub-agent capabilities
7. Phase 8 → Test suite, documentation, and validation

### Parallel Team Strategy

With multiple developers:

1. Team completes Setup + Foundational together
2. Once Foundational is done:
   - Developer A: US1 (scrum-start.sh + requirements-sprint)
   - Developer B: US4 (dashboard/app.py — schema-driven, parallel safe)
3. After US1:
   - Developer A: US2 ceremony skills (T014-T021)
   - Developer B: US2 hooks (T023-T026) — all [P]
   - Developer C: US5 (install-subagents — independent)
4. After US2: US3 (Integration Sprint)
5. Phase 8: All test tasks are [P]; README + CONTRIBUTING are [P]

---

## Notes

- [P] tasks = different files, no dependencies on incomplete tasks
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Commit after each task or logical group (Constitution IV)
- All shell scripts must pass ShellCheck (Bash 3.2+ compatibility)
- All Python code must pass ruff (or black + isort) linting
- All agent/skill definitions must have valid YAML frontmatter
- All skills must declare `## Inputs` and `## Outputs` sections
- Reference `contracts/state-schemas.json` for JSON structure validation
- Reference `contracts/agent-interfaces.md` for agent I/O contracts
- Reference `data-model.md` for entity schemas and validation rules
