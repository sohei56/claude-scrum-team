#!/usr/bin/env bash
# scrum-start.sh — Entry point for the AI-Powered Scrum Team
# Usage: sh scrum-start.sh
#
# Prerequisites:
#   - Claude Code CLI on PATH
#   - Python 3.9+ with textual and watchdog packages
#
# Exit codes:
#   0 — Claude Code session ended normally
#   1 — Claude Code CLI not found
#   2 — (reserved)
#   3 — Python 3.9+ or TUI dependencies not found
#
# Note: CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 is set process-scoped
# when launching claude. Users do NOT need to export it globally.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# --- Validate prerequisites ---

# Check Claude Code CLI
if ! command -v claude >/dev/null 2>&1; then
  echo "Error: Claude Code CLI not found on PATH." >&2
  echo "Install it: https://docs.anthropic.com/en/docs/claude-code/overview" >&2
  exit 1
fi

# Check Python 3.9+ and TUI packages (textual, watchdog)
# shellcheck source=scripts/lib/check-python.sh
. "$SCRIPT_DIR/scripts/lib/check-python.sh"
check_python_prereqs

# --- Run setup (copies agents, skills, hooks, configures settings) ---
sh "$SCRIPT_DIR/scripts/setup-user.sh"

# --- Detect new vs resume and set initial prompt ---
if [ -f ".scrum/state.json" ]; then
  echo ""
  echo "Existing project detected — resuming from saved state."
  phase="$(jq -r '.phase // "unknown"' .scrum/state.json)"
  echo "  Current phase: $phase"
  initial_prompt="Resuming session. Read .scrum/state.json, .scrum/sprint.json, and .scrum/backlog.json. Reconcile PBI statuses in backlog.json against actual project state — check if implementation files exist for each in-progress PBI and update statuses accordingly (e.g., mark PBIs as done if their code is complete, or keep as in_progress if work remains). Report where we left off, then continue the workflow from the current phase."
else
  echo ""
  echo "New project — starting fresh."
  mkdir -p .scrum/reviews
  initial_prompt="Introduce yourself and begin the Requirements Sprint. Greet the user, explain the Scrum workflow briefly, then start eliciting requirements."
fi

# --- Launch ---
echo ""

if command -v tmux >/dev/null 2>&1; then
  # tmux available — create split layout
  session_name="scrum-team"

  # Kill any stale scrum-team session from a previous run
  tmux kill-session -t "$session_name" 2>/dev/null || true

  echo "Launching Scrum team with tmux dashboard..."
  echo "  Main pane: Claude Code (Scrum Master)"
  echo "  Side pane: TUI Dashboard"
  echo ""

  tmux new-session -d -s "$session_name" -x "$(tput cols)" -y "$(tput lines)"

  # Main pane: Claude Code with Scrum Master agent (Agent Teams enabled process-scoped)
  # TMUX= hides tmux from Claude Code so Agent Teams uses in-process mode for
  # teammates (Shift+Down to cycle) instead of creating split panes that would
  # overwrite the dashboard pane. The positional argument starts an interactive
  # session with an initial prompt (unlike -p which exits).
  # When Claude exits, the tmux session is killed automatically.
  tmux send-keys -t "$session_name" "TMUX= CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude --agent scrum-master '${initial_prompt}'; tmux kill-session -t ${session_name}" C-m

  # Side pane: Textual TUI dashboard
  tmux split-window -h -t "$session_name" \
    "python3 \"$SCRIPT_DIR/dashboard/app.py\"; read -r"

  # Focus main pane
  tmux select-pane -t "$session_name":0.0

  # Attach to session
  tmux attach-session -t "$session_name"
else
  # No tmux — use status line only
  echo "Info: tmux not found — using compact status line dashboard." >&2
  echo "Install tmux for a richer view." >&2
  echo ""
  echo "Launching Claude Code with Scrum Master agent..."
  CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude --agent scrum-master "$initial_prompt"
fi
