#!/usr/bin/env bash
# setup-user.sh — End user setup: validate prerequisites and prepare project
# Usage: sh scripts/setup-user.sh
# Called by both scrum-start.sh and setup-dev.sh
# NEVER modifies ~/.claude/ or any global settings
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TARGET_DIR="$(pwd)"

echo "=== claude-scrum-team: Project Setup ==="
echo ""

# --- Validate prerequisites ---

# Check Claude Code CLI
if ! command -v claude >/dev/null 2>&1; then
  echo "Error: Claude Code CLI not found on PATH." >&2
  echo "Install it: https://docs.anthropic.com/en/docs/claude-code/overview" >&2
  exit 1
fi

# Check Python 3.9+
if ! command -v python3 >/dev/null 2>&1; then
  echo "Error: Python 3.9+ not found on PATH." >&2
  echo "Install Python: https://www.python.org/downloads/" >&2
  exit 3
fi

# Verify Python version >= 3.9
python_version="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
python_major="$(echo "$python_version" | cut -d. -f1)"
python_minor="$(echo "$python_version" | cut -d. -f2)"
if [ "$python_major" -lt 3 ] || { [ "$python_major" -eq 3 ] && [ "$python_minor" -lt 9 ]; }; then
  echo "Error: Python 3.9+ required, found Python $python_version." >&2
  exit 3
fi

# Check TUI packages (textual, watchdog)
missing_packages=()
if ! python3 -c "import textual" 2>/dev/null; then
  missing_packages+=("textual")
fi
if ! python3 -c "import watchdog" 2>/dev/null; then
  missing_packages+=("watchdog")
fi

if [ ${#missing_packages[@]} -gt 0 ]; then
  echo "Error: Python TUI packages '${missing_packages[*]}' are required." >&2
  echo "" >&2
  echo "Recommended: install in a virtual environment:" >&2
  echo "  python3 -m venv .venv" >&2
  echo "  source .venv/bin/activate   # On Windows: .venv\\Scripts\\activate" >&2
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

echo "Prerequisites OK: Claude Code, Python $python_version, textual, watchdog"
echo ""

# --- Copy agent definitions ---
echo "Copying agent definitions to $TARGET_DIR/.claude/agents/..."
mkdir -p "$TARGET_DIR/.claude/agents"
cp "$PROJECT_ROOT/agents/"*.md "$TARGET_DIR/.claude/agents/"

# --- Copy skill definitions ---
echo "Copying skill definitions to $TARGET_DIR/.claude/skills/..."
for skill_dir in "$PROJECT_ROOT/skills"/*/; do
  skill_name="$(basename "$skill_dir")"
  mkdir -p "$TARGET_DIR/.claude/skills/$skill_name"
  if [ -f "$skill_dir/SKILL.md" ]; then
    cp "$skill_dir/SKILL.md" "$TARGET_DIR/.claude/skills/$skill_name/"
  fi
done

# --- Copy hook scripts ---
echo "Copying hook scripts to $TARGET_DIR/.claude/hooks/..."
mkdir -p "$TARGET_DIR/.claude/hooks"
for hook_file in "$PROJECT_ROOT/hooks/"*.sh; do
  if [ -f "$hook_file" ]; then
    cp "$hook_file" "$TARGET_DIR/.claude/hooks/"
    chmod +x "$TARGET_DIR/.claude/hooks/$(basename "$hook_file")"
  fi
done

# --- Configure settings.json ---
echo "Configuring $TARGET_DIR/.claude/settings.json..."

settings_file="$TARGET_DIR/.claude/settings.json"

# Always write settings.json with current hook configuration.
# If the file already exists, back it up so user customizations aren't lost.
if [ -f "$settings_file" ]; then
  cp "$settings_file" "${settings_file}.bak"
  echo "  Backed up existing settings.json to settings.json.bak"
fi

cat > "$settings_file" << 'SETTINGS_EOF'
{
  "permissions": {},
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/session-context.sh"
          }
        ]
      }
    ],
    "PreToolUse": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/phase-gate.sh"
          }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/dashboard-event.sh"
          }
        ]
      }
    ],
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/completion-gate.sh"
          }
        ]
      }
    ],
    "TaskCompleted": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/quality-gate.sh"
          }
        ]
      }
    ],
    "TeammateIdle": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/dashboard-event.sh"
          }
        ]
      }
    ]
  }
}
SETTINGS_EOF
echo "  Written settings.json with hook configuration."

# --- Configure status line ---
# Status line config goes in settings.json or .claude/settings.local.json
# The statusline.sh script is referenced by path

echo ""
echo "=== Setup complete ==="
echo ""
echo "Project configured at: $TARGET_DIR"
echo "  .claude/agents/     — Agent definitions"
echo "  .claude/skills/     — Skill definitions"
echo "  .claude/hooks/      — Hook scripts"
echo "  .claude/settings.json — Hook and status line configuration"
