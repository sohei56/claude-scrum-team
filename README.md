<p align="center">
  <img alt="claude-scrum-team" src="images/claude-scrum-team.png" width="700">
</p>

<h1 align="center">claude-scrum-team</h1>

<p align="center">
  <strong>AI-powered Scrum team for Claude Code</strong>
</p>

<p align="center">
  <a href="https://github.com/sohei56/claude-scrum-team/blob/main/LICENSE"><img src="https://img.shields.io/github/license/sohei56/claude-scrum-team?style=flat-square&color=blue" alt="License"></a>
  <img src="https://img.shields.io/badge/python-3.9%2B-3776AB?style=flat-square&logo=python&logoColor=white" alt="Python 3.9+">
  <img src="https://img.shields.io/badge/bash-3.2%2B-4EAA25?style=flat-square&logo=gnubash&logoColor=white" alt="Bash 3.2+">
  <img src="https://img.shields.io/badge/Claude_Code-Agent_Teams-D97706?style=flat-square&logo=anthropic&logoColor=white" alt="Claude Code Agent Teams">
  <img src="https://img.shields.io/badge/TUI-Textual-7C3AED?style=flat-square" alt="Textual TUI">
</p>

<p align="center">
  <a href="#quick-start">Quick Start</a> &bull;
  <a href="#architecture">Architecture</a> &bull;
  <a href="#development">Development</a> &bull;
  <a href="specs/001-ai-scrum-team/quickstart.md">Full Docs</a>
</p>

---

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
