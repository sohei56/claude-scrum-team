# claude-scrum-team

An AI-powered Scrum development team for [Claude Code](https://docs.anthropic.com/en/docs/claude-code/overview). Launch a complete Scrum workflow — Requirements Sprint, Development Sprints with design/implementation/cross-review, Sprint Reviews, Retrospectives, and Integration Sprints — all orchestrated by AI agents.

## How It Works

A shell script launches Claude Code with a **Scrum Master** agent (team lead in Delegate mode) that coordinates **Developer** teammates via [Agent Teams](https://code.claude.com/docs/en/agent-teams). The Scrum Master facilitates ceremonies, manages the Product Backlog, and orchestrates Sprint cycles. Developers design, implement, and cross-review PBIs independently.

A real-time **TUI dashboard** (Textual + watchdog) runs alongside in a tmux pane showing Sprint progress, PBI status, agent communications, and file changes.

## Prerequisites

- **Claude Code CLI** installed and on PATH
- **Python 3.9+** with TUI packages:
  ```bash
  pip install textual watchdog
  ```
- **tmux** (recommended) for side-by-side dashboard layout

## Quick Start

```bash
# Clone the repository
git clone https://github.com/sohei56/claude-scrum-team.git

# In your project directory:
cd /path/to/your/project

# Install TUI dependencies (recommended: use a virtual environment)
python3 -m venv .venv
source .venv/bin/activate
pip install textual watchdog

# Launch the Scrum team
sh /path/to/claude-scrum-team/scrum-start.sh
```

The script validates prerequisites, copies agent definitions and Skills to your project's `.claude/` directory, and launches a tmux session with Claude Code (Scrum Master) and the TUI dashboard.

For detailed setup instructions, see [quickstart.md](specs/001-ai-scrum-team/quickstart.md).

## Architecture

| Component | Description |
|-----------|-------------|
| `scrum-start.sh` | Entry point — validates prereqs, copies agents/skills, launches tmux |
| `agents/` | Scrum Master (Delegate mode) and Developer agent definitions |
| `skills/` | 13 ceremony Skills with mandatory Inputs/Outputs |
| `hooks/` | Phase gates, completion gates, quality gates, dashboard events |
| `dashboard/app.py` | Textual TUI with 4 real-time panels |
| `scripts/` | Status line, user setup, contributor setup |
| `.scrum/` | Runtime state (JSON, gitignored) |
| `.design/` | Design documents governed by `catalog.md` |

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and workflow.

```bash
# Install dev dependencies
sh scripts/setup-dev.sh

# Run tests
bats tests/unit/ tests/lint/

# Lint shell scripts
shellcheck scrum-start.sh scripts/*.sh hooks/*.sh
```

## License

See [LICENSE](LICENSE) for details.
