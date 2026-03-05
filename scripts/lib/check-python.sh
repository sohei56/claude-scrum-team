#!/usr/bin/env bash
# check-python.sh — Shared Python prerequisite checks
# Sourced by scrum-start.sh and setup-user.sh to avoid duplication.
#
# Verifies:
#   1. python3 is on PATH
#   2. Python version >= 3.9
#   3. textual and watchdog packages are importable
#
# On failure: prints actionable error to stderr and exits with code 3.
# On success: exports PYTHON_VERSION (e.g. "3.12").

# Guard against double-sourcing
# shellcheck disable=SC2317
if [ "${_CHECK_PYTHON_LOADED:-}" = "1" ]; then
  return 0 2>/dev/null || true
fi
_CHECK_PYTHON_LOADED=1

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

  # 3. TUI packages
  local missing_pkgs=""
  if ! python3 -c "import textual" 2>/dev/null; then
    missing_pkgs="textual"
  fi
  if ! python3 -c "import watchdog" 2>/dev/null; then
    missing_pkgs="${missing_pkgs:+${missing_pkgs} }watchdog"
  fi
  if [ -n "$missing_pkgs" ]; then
    echo "Error: Missing Python package(s): ${missing_pkgs}" >&2
    echo "" >&2
    echo "Recommended: install in a virtual environment:" >&2
    echo "  python3 -m venv .venv" >&2
    printf '  source .venv/bin/activate   # On Windows: .venv\\Scripts\\Activate.ps1\n' >&2
    echo "  pip install textual watchdog" >&2
    echo "" >&2
    echo "Or install directly:" >&2
    echo "  pip install textual watchdog" >&2
    echo "" >&2
    echo "If pip is not available:" >&2
    echo "  python3 -m ensurepip --upgrade   # Install pip itself" >&2
    echo "  # Or: apt install python3-pip    # Debian/Ubuntu" >&2
    echo "  # Or: brew install python3       # macOS (includes pip)" >&2
    exit 3
  fi
}
