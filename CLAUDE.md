# claude-scrum-team Development Guidelines

## Project Structure

```text
scrum-start.sh           # Entry point — validates prereqs, launches tmux
agents/                  # Scrum Master + Developer agent definitions
  scrum-master.md        # Team lead (Delegate mode)
  developer.md           # Developer teammate
skills/                  # Ceremony Skills (YAML frontmatter + Markdown)
  backlog-refinement/    change-process/      cross-review/
  design-phase/          implementation-phase/ install-subagents/
  integration-sprint/    requirements-sprint/  retrospective/
  scaffold-design-spec/  smoke-test/          spawn-teammates/
  sprint-planning/       sprint-review/
hooks/                   # Claude Code hooks (phase gates, dashboard events)
dashboard/               # Textual TUI dashboard (Python)
  app.py                 # Main TUI application
scripts/                 # Setup and utility scripts
  setup-user.sh          # Copies agents/skills/hooks to target project
  setup-dev.sh           # Installs dev dependencies (bats, shellcheck, etc.)
tests/                   # Test suites
  unit/                  # Bats unit tests
  lint/                  # Bats lint tests
specs/                   # Feature specifications and data model
.design/                 # Design document governance (catalog.md)
.scrum/                  # Runtime state (JSON, gitignored)
```

## Technologies

- **Shell**: Bash 3.2+ (macOS/Linux compatible)
- **Python**: 3.9+ with Textual 8.x (TUI), watchdog (filesystem monitoring)
- **Agents/Skills**: Markdown with YAML frontmatter
- **State**: JSON files in `.scrum/` directory
- **CLI**: Claude Code with Agent Teams (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`)

## Commands

```bash
# Run tests
bats tests/unit/ tests/lint/

# Lint shell scripts
shellcheck scrum-start.sh scripts/*.sh hooks/*.sh

# Lint/format Python
ruff check dashboard/
ruff format dashboard/

# Install dev dependencies
sh scripts/setup-dev.sh

# Launch the Scrum team (in target project directory)
sh /path/to/claude-scrum-team/scrum-start.sh
```

## Code Style

- **Shell**: POSIX-compatible Bash 3.2+, `set -euo pipefail`, shellcheck clean
- **Python**: Ruff-formatted, type hints, 4-space indent
- **Markdown**: 2-space indent for YAML frontmatter, 80-char line width for prose
- **JSON**: 2-space indent
- **Commits**: Conventional Commits format (`feat:`, `fix:`, `docs:`, `chore:`)

## Key Conventions

- Scrum Master agent operates in **Delegate mode** — coordinates only, never writes code
- All state persisted to `.scrum/` JSON files for resume capability
- Design documents governed by `.design/catalog.md` (enabled/disabled entries)
- Developer teammates named with Sprint suffix: `dev-001-s{N}`
- PBI status flow: `draft → refined → in_progress → review → done`
- Sprint status flow: `planning → active → cross_review → sprint_review → complete`
- Phase flow: `new → requirements_sprint → backlog_created → sprint_planning → design → implementation → review → sprint_review → retrospective → [next Sprint or integration_sprint] → complete`

<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
