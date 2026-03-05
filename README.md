<p align="center">
  <img alt="claude-scrum-team" src="images/claude-scrum-team.png" width="700">
</p>

<h1 align="center">claude-scrum-team</h1>

<p align="center">
  <strong>AI-Powered Scrum Team for Claude Code — a full Scrum workflow driven by multi-agent coordination via Agent Teams.</strong>
</p>

<p align="center">
  <a href="https://github.com/sohei56/claude-scrum-team/blob/main/LICENSE"><img src="https://img.shields.io/github/license/sohei56/claude-scrum-team?style=flat-square&color=blue" alt="License"></a>
  <img src="https://img.shields.io/badge/python-3.9%2B-3776AB?style=flat-square&logo=python&logoColor=white" alt="Python 3.9+">
  <img src="https://img.shields.io/badge/bash-3.2%2B-4EAA25?style=flat-square&logo=gnubash&logoColor=white" alt="Bash 3.2+">
  <img src="https://img.shields.io/badge/Claude_Code-Agent_Teams-D97706?style=flat-square&logo=anthropic&logoColor=white" alt="Claude Code Agent Teams">
  <img src="https://img.shields.io/badge/TUI-Textual-7C3AED?style=flat-square" alt="Textual TUI">
</p>

<p align="center">
  <a href="#concept">Concept</a> &bull;
  <a href="#demo">Demo</a> &bull;
  <a href="#features">Features</a> &bull;
  <a href="#quick-start">Quick Start</a> &bull;
  <a href="#architecture">Architecture</a> &bull;
  <a href="#development">Development</a>
</p>

---

Run `scrum-start.sh` in any project directory and a full AI Scrum team takes over — a **Scrum Master** coordinates **Developer** agents through Sprint cycles while you act as the **Product Owner**, approving goals and reviewing the working product.

## Concept

Vibe coding is freewheeling; traditional spec-driven development demands everything be defined upfront. This project occupies the middle ground: you don't need a complete spec before you start, but development still moves with structure and rhythm.

The answer is a Scrum team made entirely of AI agents. A Scrum Master orchestrates the ceremonies and coordinates a pool of Developer agents, while you stay in the Product Owner seat — describing what you want, approving Sprint Goals, and reviewing the results.

## Demo

<p align="center">
  <img alt="scrum-start.sh demo" src="images/demo.gif" width="800">
</p>

One command sets up agents, skills, and hooks — then launches Claude Code with a Scrum Master agent alongside a real-time TUI dashboard in tmux.

### What a session looks like

1. **You describe your project** — the Scrum Master spawns a Developer to elicit requirements and write `requirements.md`
2. **Backlog Refinement** — the SM creates and refines PBIs from your requirements
3. **Sprint Planning** — the SM proposes a Sprint Goal; you approve or adjust
4. **Design + Implementation** — Developers design, then implement their PBIs in parallel
5. **Cross-Review** — each Developer reviews another's work (no self-review)
6. **Sprint Review** — the SM launches the app and demos every completed PBI; you confirm each works
7. **Retrospective** — the team reflects and records improvements for the next Sprint
8. **Repeat** until the Product Goal is achieved, then an **Integration Sprint** runs automated tests and a final UAT

## Features

- **14 ceremony Skills** covering the full Scrum lifecycle: requirements elicitation, backlog refinement, sprint planning, design, implementation, cross-review, sprint review, retrospective, and integration testing
- **Scrum Master in Delegate mode** — orchestrates up to 6 parallel Developer agents per Sprint; never writes code directly
- **Real-time TUI dashboard** — Textual-based four-panel display (Sprint Overview, PBI Progress Board, Communication Log, Work Log) with watchdog filesystem monitoring
- **Design document governance** — immutable catalog (`catalog.md`) paired with an editable enablement config (`catalog-config.json`), enforced by phase-gate hooks
- **Quality enforcement hooks** — phase gates (source code restrictions), completion gates (exit criteria), quality gates (Definition of Done), dashboard events, and session context restoration
- **State persistence** — all state stored in `.scrum/` JSON files for full session resume capability
- **Retrospective-driven improvement** — improvements from past Sprints are captured and applied automatically to future ones

### Sprint Lifecycle

```
Requirements Sprint ──> Backlog Refinement ──> Sprint Planning
                                                     │
                 ┌───────────────────────────────────┘
                 v
         Scaffold Design Specs ──> Spawn Teammates ──> Design Phase
                                                          │
                 ┌────────────────────────────────────────┘
                 v
         Implementation Phase ──> Cross-Review ──> Sprint Review
                                                       │
                 ┌─────────────────────────────────────┘
                 v
           Retrospective ──> [next Sprint or Integration Sprint]
                                        │
                 ┌──────────────────────┘
                 v
         Smoke Tests ──> UAT ──> Release Decision
```

## Why AI Agents Suit This

Human Scrum teams carry overhead: scheduling, miscommunication, context-switching. AI agents sidestep much of that:

- **No coordination tax** — the Scrum Master delegates instantly; Developers start in parallel without waiting for a meeting
- **Perfect memory within a session** — every agent has full access to requirements, design docs, and Sprint state; nothing falls through the cracks
- **Consistent ceremony execution** — Skills enforce mandatory inputs and outputs for every ceremony, so ceremonies don't get skipped or rushed
- **Tireless iteration** — Retrospective improvements feed directly into the next Sprint without anyone needing to remember to act on them

## Quick Start

```bash
# Clone the repository
git clone https://github.com/sohei56/claude-scrum-team.git

# In your project directory:
cd /path/to/your/project

# Launch the Scrum team (auto-installs Python dependencies if needed)
sh /path/to/claude-scrum-team/scrum-start.sh
```

The script validates prerequisites (auto-installing `textual` and `watchdog` if missing), copies agent definitions, Skills, hooks, and the design catalog to your project's `.claude/` directory, and launches a tmux session with Claude Code (Scrum Master) and the TUI dashboard.

For detailed setup instructions, see [quickstart.md](specs/001-ai-scrum-team/quickstart.md).

### Prerequisites

- **Claude Code CLI** installed and on PATH
- **Python 3.9+** with `textual` and `watchdog`
- **tmux** (recommended) for side-by-side dashboard layout

### Your role as Product Owner

| You do | The AI team does |
|--------|-----------------|
| Describe what you want to build | Elicit and write detailed requirements |
| Approve Sprint Goals | Plan Sprints and assign PBIs |
| Review demos in the running app | Design, implement, and cross-review code |
| Report defects during UAT | Fix defects and re-test automatically |
| Make release decisions | Run automated test suites |

## Architecture

| Component | Description |
|-----------|-------------|
| `scrum-start.sh` | Entry point — validates prereqs, copies agents/skills, launches tmux |
| `agents/` | Scrum Master (Delegate mode) and Developer agent definitions |
| `skills/` | 14 ceremony Skills with mandatory Inputs/Outputs |
| `hooks/` | Phase gates, completion gates, quality gates, dashboard events, session context |
| `dashboard/app.py` | Textual TUI with real-time panels |
| `scripts/` | Status line, user setup, contributor setup |
| `.scrum/` | Runtime state (JSON, gitignored) |
| `.design/` | Design documents governed by `catalog.md` (read-only) + `catalog-config.json` (enabled list) |

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup and workflow.

```bash
# Install dev dependencies
sh scripts/setup-dev.sh

# Run tests
bats tests/unit/ tests/lint/

# Lint shell scripts
shellcheck scrum-start.sh scripts/*.sh scripts/lib/*.sh hooks/*.sh hooks/lib/*.sh
```

## License

[MIT](LICENSE)
