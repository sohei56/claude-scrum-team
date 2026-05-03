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

# shellcheck source=scripts/lib/check-python.sh
. "$SCRIPT_DIR/scripts/lib/check-python.sh"
check_claude_cli
check_python_prereqs

# --- Run setup (copies agents, skills, hooks, configures settings) ---
sh "$SCRIPT_DIR/scripts/setup-user.sh"

# --- Detect new vs resume and set initial prompt ---
if [ -f ".scrum/state.json" ]; then
  echo ""
  echo "Existing project detected — resuming from saved state."

  # Migrate legacy .scrum/*.json (pre-SSOT layout) idempotently before launch.
  # No-op if files are already canonical. Keeps .legacy.bak alongside changes.
  if [ -x "$SCRIPT_DIR/scripts/scrum/migrate-legacy.sh" ]; then
    sh "$SCRIPT_DIR/scripts/scrum/migrate-legacy.sh" || \
      echo "Warning: migrate-legacy.sh reported issues (continuing)" >&2
  fi

  phase="$(jq -r '.phase // "unknown"' .scrum/state.json)"
  echo "  Current phase: $phase"
  initial_prompt="Read .scrum/state.json, .scrum/sprint.json, and .scrum/backlog.json. Reconcile PBI statuses in backlog.json against actual project state — check if implementation files exist for each in-progress PBI and update statuses accordingly (e.g., mark PBIs as done if their code is complete, or keep as in_progress if work remains). Report where we left off, then continue the workflow from the current phase."
else
  echo ""
  echo "New project — starting fresh."
  mkdir -p .scrum/reviews
  initial_prompt="Introduce yourself and begin the Requirements Sprint. Greet the user, explain the Scrum workflow briefly, then start eliciting requirements."
fi

# --- Launch ---
echo ""

if command -v tmux >/dev/null 2>&1; then
  # tmux available — create the session, optionally with a split dashboard
  session_name="scrum-team"
  min_split_cols=120
  term_cols="$(tput cols)"
  term_lines="$(tput lines)"

  # Kill any stale scrum-team session from a previous run
  tmux kill-session -t "$session_name" 2>/dev/null || true

  # Tmux truecolor: ensure the dashboard pane sees a 256-color TERM and that
  # tmux passes through 24-bit RGB escape sequences. Without this, tmux
  # defaults to TERM=screen (8 colors) inside the pane, which makes Textual
  # render the dashboard nearly monochrome on Apple Terminal. The flags are
  # idempotent and harmless on tmux servers that already have these set.
  tmux set-option -g default-terminal "screen-256color" 2>/dev/null || true
  tmux set-option -ga terminal-overrides ",*:RGB" 2>/dev/null || true

  if [ "$term_cols" -ge "$min_split_cols" ]; then
    echo "Launching Scrum team with tmux dashboard..."
    echo "  Main pane: Claude Code (Scrum Master)"
    echo "  Side pane: TUI Dashboard"
  else
    echo "Launching Scrum team in tmux..."
    echo "  Main pane: Claude Code (Scrum Master)"
    echo "  Dashboard: skipped (terminal width ${term_cols} < ${min_split_cols})"
    echo "  Resize to at least ${min_split_cols} columns to enable the split dashboard."
  fi
  echo ""

  tmux new-session -d -s "$session_name" -c "$PWD" -x "$term_cols" -y "$term_lines"

  # Main pane: Claude Code with Scrum Master agent (Agent Teams enabled process-scoped)
  # --teammate-mode in-process forces Agent Teams to use in-process mode for
  # teammates (Shift+Down to cycle) instead of creating split panes that would
  # overwrite the dashboard pane. The positional argument starts an interactive
  # session with an initial prompt (unlike -p which exits).
  # When Claude exits, the tmux session is killed automatically.
  tmux send-keys -t "$session_name" "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude --agent scrum-master --teammate-mode in-process '${initial_prompt}'; tmux kill-session -t ${session_name}" C-m

  if [ "$term_cols" -ge "$min_split_cols" ]; then
    # Side pane: Textual TUI dashboard.
    # COLORTERM=truecolor signals Rich/Textual to emit 24-bit RGB escapes;
    # the tmux terminal-overrides above let those escapes through to the
    # outer terminal so theme colors render with full contrast.
    tmux split-window -h -c "$PWD" -t "$session_name" \
      "COLORTERM=truecolor python3 \"$SCRIPT_DIR/dashboard/app.py\"; read -r"
  fi

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
