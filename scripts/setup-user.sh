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

# Check Python 3.9+ and TUI packages (textual, watchdog)
# shellcheck source=lib/check-python.sh
. "$SCRIPT_DIR/lib/check-python.sh"
check_python_prereqs

echo "Prerequisites OK: Claude Code, Python $PYTHON_VERSION, textual, watchdog"

# Try to install tmux if missing (optional — dashboard degrades to status line without it)
if ! command -v tmux >/dev/null 2>&1; then
  echo ""
  echo "tmux not found — attempting to install (recommended for TUI dashboard)..."
  if command -v brew >/dev/null 2>&1; then
    brew install tmux && echo "  tmux installed successfully." || echo "  Warning: tmux install failed. The status line fallback will be used." >&2
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get install -y tmux && echo "  tmux installed successfully." || echo "  Warning: tmux install failed. The status line fallback will be used." >&2
  else
    echo "  Could not install tmux automatically (no brew or apt-get found)." >&2
    echo "  Install manually for the full TUI dashboard, or continue without it." >&2
  fi
fi

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
mkdir -p "$TARGET_DIR/.claude/hooks/lib"
for hook_file in "$PROJECT_ROOT/hooks/"*.sh; do
  if [ -f "$hook_file" ]; then
    cp "$hook_file" "$TARGET_DIR/.claude/hooks/"
    chmod +x "$TARGET_DIR/.claude/hooks/$(basename "$hook_file")"
  fi
done
# Copy hook library files
for lib_file in "$PROJECT_ROOT/hooks/lib/"*.sh; do
  if [ -f "$lib_file" ]; then
    cp "$lib_file" "$TARGET_DIR/.claude/hooks/lib/"
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
  "permissions": {
    "allow": [
      "Read",
      "Write",
      "Edit",
      "Bash(*)",
      "Glob",
      "Grep",
      "Agent",
      "WebFetch",
      "WebSearch"
    ]
  },
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
        "matcher": "Write|Edit|Bash|Agent",
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
    ],
    "SubagentStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/dashboard-event.sh"
          }
        ]
      }
    ],
    "SubagentStop": [
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

# --- Configure Playwright MCP for web projects ---
# Detect if this is a web project and add Playwright MCP for browser E2E testing
is_web_project=false

if [ -f "$TARGET_DIR/package.json" ]; then
  # Check for start/dev scripts indicating a web app
  if grep -qE '"(start|dev|serve)"' "$TARGET_DIR/package.json" 2>/dev/null; then
    is_web_project=true
  fi
fi

# Check for other web framework indicators
if [ "$is_web_project" = false ]; then
  if [ -f "$TARGET_DIR/manage.py" ] || \
     [ -f "$TARGET_DIR/next.config.js" ] || \
     [ -f "$TARGET_DIR/next.config.mjs" ] || \
     [ -f "$TARGET_DIR/next.config.ts" ] || \
     [ -f "$TARGET_DIR/nuxt.config.ts" ] || \
     [ -f "$TARGET_DIR/nuxt.config.js" ] || \
     [ -d "$TARGET_DIR/pages" ] || \
     [ -d "$TARGET_DIR/app" ]; then
    is_web_project=true
  fi
fi

if [ "$is_web_project" = true ]; then
  echo ""
  echo "Web project detected — configuring Playwright MCP for browser E2E testing..."
  mcp_file="$TARGET_DIR/.mcp.json"

  if [ -f "$mcp_file" ]; then
    # Merge playwright entry into existing .mcp.json if not already present
    if ! grep -q "playwright" "$mcp_file" 2>/dev/null; then
      # Add playwright server to existing mcpServers
      tmp_mcp="$(mktemp)"
      if jq '.mcpServers.playwright = {"type": "stdio", "command": "npx", "args": ["@anthropic-ai/mcp-playwright"]}' "$mcp_file" > "$tmp_mcp" 2>/dev/null; then
        mv "$tmp_mcp" "$mcp_file"
      else
        rm -f "$tmp_mcp"
      fi
      echo "  Added Playwright MCP to existing .mcp.json"
    else
      echo "  Playwright MCP already configured in .mcp.json"
    fi
  else
    # Create new .mcp.json with playwright
    cat > "$mcp_file" << 'MCP_EOF'
{
  "mcpServers": {
    "playwright": {
      "type": "stdio",
      "command": "npx",
      "args": ["@anthropic-ai/mcp-playwright"]
    }
  }
}
MCP_EOF
    echo "  Created .mcp.json with Playwright MCP"
  fi
else
  echo ""
  echo "Non-web project detected — skipping Playwright MCP configuration."
fi

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
