#!/usr/bin/env bash
# check-python.sh — Shared prerequisite checks
# Sourced by scrum-start.sh and setup-user.sh to avoid duplication.
#
# Provides:
#   check_claude_cli   — Verify Claude Code CLI on PATH (exits 1 on failure)
#   check_python_prereqs — Verify Python 3.9+ and TUI packages (exits 3 on failure)
#
# On success: exports PYTHON_VERSION (e.g. "3.12").

# Guard against double-sourcing
# shellcheck disable=SC2317
if [ "${_CHECK_PYTHON_LOADED:-}" = "1" ]; then
  return 0 2>/dev/null || true
fi
_CHECK_PYTHON_LOADED=1

# Verify Claude Code CLI is available
check_claude_cli() {
  if ! command -v claude >/dev/null 2>&1; then
    echo "Error: Claude Code CLI not found on PATH." >&2
    echo "Install it: https://docs.anthropic.com/en/docs/claude-code/overview" >&2
    exit 1
  fi
}

check_python_prereqs() {
  # 1. python3 on PATH
  if ! command -v python3 >/dev/null 2>&1; then
    echo "Error: Python 3.9+ not found on PATH." >&2
    echo "Install Python: https://www.python.org/downloads/" >&2
    exit 3
  fi

  # 2. Version >= 3.9
  PYTHON_VERSION="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
  export PYTHON_VERSION
  local major minor
  major="$(echo "$PYTHON_VERSION" | cut -d. -f1)"
  minor="$(echo "$PYTHON_VERSION" | cut -d. -f2)"
  if [ "$major" -lt 3 ] || { [ "$major" -eq 3 ] && [ "$minor" -lt 9 ]; }; then
    echo "Error: Python 3.9+ required, found Python $PYTHON_VERSION." >&2
    exit 3
  fi

  # 3. TUI packages — auto-install if missing
  local missing_pkgs=""
  if ! python3 -c "import textual" 2>/dev/null; then
    missing_pkgs="textual"
  fi
  if ! python3 -c "import watchdog" 2>/dev/null; then
    missing_pkgs="${missing_pkgs:+${missing_pkgs} }watchdog"
  fi
  if [ -n "$missing_pkgs" ]; then
    echo "Installing missing Python package(s): ${missing_pkgs}..."
    # shellcheck disable=SC2086
    if python3 -m pip install --quiet $missing_pkgs 2>/dev/null; then
      echo "  Installed successfully."
    else
      echo "Error: Failed to install Python package(s): ${missing_pkgs}" >&2
      echo "" >&2
      echo "Try installing manually:" >&2
      echo "  pip install textual watchdog" >&2
      exit 3
    fi
  fi
}
