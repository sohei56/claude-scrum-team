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

# shellcheck source=lib/check-python.sh
. "$SCRIPT_DIR/lib/check-python.sh"
check_claude_cli
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
  # Copy references/ subdirectory if present (pbi-pipeline pattern)
  if [ -d "$skill_dir/references" ]; then
    mkdir -p "$TARGET_DIR/.claude/skills/$skill_name/references"
    cp "$skill_dir/references/"*.md "$TARGET_DIR/.claude/skills/$skill_name/references/" 2>/dev/null || true
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

# --- Copy PBI Pipeline configuration template ---
# Provide .scrum-config.example.json so users can copy it to .scrum/config.json
# and adapt to their project's test_runner / coverage_tool. Only copies if the
# example template is missing in the target.
if [ -f "$PROJECT_ROOT/.scrum-config.example.json" ] && [ ! -f "$TARGET_DIR/.scrum-config.example.json" ]; then
  cp "$PROJECT_ROOT/.scrum-config.example.json" "$TARGET_DIR/"
  echo "  Copied .scrum-config.example.json (copy to .scrum/config.json and adapt)"
fi

# --- Copy contract JSON Schemas (PBI Pipeline artifacts) ---
if [ -d "$PROJECT_ROOT/docs/contracts" ]; then
  mkdir -p "$TARGET_DIR/docs/contracts"
  cp "$PROJECT_ROOT/docs/contracts/"*.schema.json "$TARGET_DIR/docs/contracts/" 2>/dev/null || true
fi

# --- Copy design catalog ---
echo "Copying design catalog to $TARGET_DIR/docs/design/..."
mkdir -p "$TARGET_DIR/docs/design"
cp "$PROJECT_ROOT/docs/design/catalog.md" "$TARGET_DIR/docs/design/"
# Copy default catalog config if none exists yet (preserve existing project config)
if [ ! -f "$TARGET_DIR/docs/design/catalog-config.json" ]; then
  cp "$PROJECT_ROOT/docs/design/catalog-config.json" "$TARGET_DIR/docs/design/"
  echo "  Created default catalog-config.json"
else
  echo "  catalog-config.json already exists — preserving project configuration"
fi

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
      "WebSearch",
      "Bash(codex *)"
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
        "matcher": "Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/phase-gate.sh"
          }
        ]
      },
      {
        "matcher": "Read|Write|Edit",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/pre-tool-use-path-guard.sh"
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
          },
          {
            "type": "command",
            "command": ".claude/hooks/dashboard-event.sh"
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
          },
          {
            "type": "command",
            "command": ".claude/hooks/dashboard-event.sh"
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
    ],
    "PostCompact": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/session-context.sh"
          }
        ]
      }
    ],
    "StopFailure": [
      {
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/stop-failure.sh"
          },
          {
            "type": "command",
            "command": ".claude/hooks/dashboard-event.sh"
          }
        ]
      }
    ],
    "FileChanged": [
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

# --- Configure Playwright MCP for browser E2E testing ---
# Always configure Playwright MCP if npx is available. The smoke-test skill
# gracefully skips browser E2E when Playwright MCP is not in .mcp.json,
# so adding it unconditionally is safe — it only activates during
# Integration Sprint when a running app is detected.

if command -v npx >/dev/null 2>&1; then
  echo ""
  echo "Configuring Playwright MCP for browser E2E testing..."
  mcp_file="$TARGET_DIR/.mcp.json"

  if [ -f "$mcp_file" ]; then
    # Merge playwright entry into existing .mcp.json if not already present
    if ! grep -q "playwright" "$mcp_file" 2>/dev/null; then
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
  echo "Note: npx not found — skipping Playwright MCP configuration."
  echo "  Install Node.js to enable browser E2E testing in Integration Sprint."
fi

# --- Check Codex CLI for cross-model code review ---
# The codex-code-reviewer agent calls `codex review` directly via CLI.
# When codex is not installed, the agent falls back to Claude-based review.

if command -v codex >/dev/null 2>&1; then
  echo ""
  echo "Codex CLI detected — cross-model code review enabled."
else
  echo ""
  echo "Note: codex not found — code review will use Claude fallback."
  echo "  Install: npm i -g @openai/codex && codex login"
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
echo "  docs/design/            — Design catalog and configuration"
echo "  .claude/settings.json — Hook and status line configuration"
