# Codex Code Reviewer — Design Spec

**Date:** 2026-04-12
**Branch:** feat/ecc-subagent-catalog
**Status:** Approved

## Problem

The current cross-review workflow uses Claude sub-agents for both code review
and security review. Using the same model family for implementation and review
limits perspective diversity. Delegating code review to OpenAI Codex via MCP
provides an independent, cross-model review that receives only design documents
and deliverables — no implementation context.

## Solution

Replace the `code-reviewer` sub-agent invocation in cross-review with a new
`codex-code-reviewer` proxy agent. This agent reads files locally (Claude),
constructs a prompt with design docs and source code, and calls Codex via
`mcp__openai__openai_chat`. Security review remains with Claude.

## Architecture

### Before

```
Scrum Master
  ├─ code-reviewer (Claude sub-agent)
  └─ security-reviewer (Claude sub-agent)
```

### After

```
Scrum Master
  ├─ codex-code-reviewer (Claude sub-agent = proxy)
  │    ├─ Read/Glob: collect design docs + source code
  │    ├─ Build system_prompt + user message
  │    └─ mcp__openai__openai_chat → Codex → PASS/FAIL
  │
  │   [Codex unavailable]
  │    └─ Fallback: Claude performs review using same criteria
  │
  └─ security-reviewer (Claude sub-agent, unchanged)
```

## Deliverables

| File | Operation | Description |
|------|-----------|-------------|
| `agents/codex-code-reviewer.md` | Create | Proxy agent definition |
| `.mcp-servers/mcp-openai/server.py` | Create (copy) | FastMCP server wrapping codex app-server |
| `.mcp-servers/mcp-openai/codex_client.py` | Create (copy) | JSON-RPC client for codex app-server |
| `.mcp-servers/mcp-openai/pyproject.toml` | Create (copy) | Python project config (mcp[cli], Python 3.12+) |
| `skills/cross-review/SKILL.md` | Modify | Replace `code-reviewer` with `codex-code-reviewer` |
| `agents/scrum-master.md` | Modify | Update FR-009 agent reference |
| `scripts/setup-user.sh` | Modify | Add mcp-openai distribution + .mcp.json config |

## Agent: codex-code-reviewer.md

### Tools

- Read, Grep, Glob, Bash (file access — same as existing code-reviewer)
- mcp__openai__openai_chat (Codex invocation)

### Processing Flow

1. Read design docs, source code, and requirements.md in full
2. Build `system_prompt` with review criteria and output format specification
3. Build `user message` with design doc contents + source code contents
4. Call `mcp__openai__openai_chat` (model: gpt-5.4)
5. Check response status:
   - `complete` → format as PASS/FAIL and return
   - `needs_info` → read requested files, append answer, re-call (max 3 loops)
6. Return result in existing review format

### system_prompt Content

Reuses the review criteria from `code-reviewer.md`:

- **Completeness**: Are all design requirements implemented?
- **Scope creep**: Is anything implemented that was NOT in the design?
- **Correctness**: Does the code correctly implement the specified behavior?
- **Code quality**: Readability, naming, error handling, test coverage

Output format:

```markdown
## Review: [brief description]

**Verdict: PASS | FAIL**

### Findings

| # | Severity | File | Lines | Description |
|---|----------|------|-------|-------------|
| 1 | Critical | path/to/file.py | 42-45 | Description |

### Summary

[2-3 sentences]

STATUS: complete
```

Severity levels: Critical, High, Medium, Low.
Verdict: PASS if no Critical/High findings; FAIL otherwise.

### Fallback Behavior

When `mcp__openai__openai_chat` returns an error (codex not installed, auth
expired, timeout, etc.):

1. Detect error in response JSON
2. Perform the same review using Claude's own reasoning (identical criteria)
3. Annotate result with `[Fallback: Claude review]`

## MCP Server Distribution

### Source

Copy `.mcp-servers/mcp-openai/` from `my-investment-agent` as-is. The server
is a generic Codex gateway — no project-specific customization needed.

Files:
- `server.py` — FastMCP server exposing `openai_chat` tool
- `codex_client.py` — codex app-server JSON-RPC client (persistent subprocess)
- `pyproject.toml` — dependencies: `mcp[cli]>=1.0,<2.0`, Python 3.12+

### setup-user.sh Changes

Follow the same pattern as the existing Playwright MCP configuration:

```bash
if command -v codex >/dev/null 2>&1; then
  # Copy .mcp-servers/mcp-openai/ to target project
  # Add "openai" entry to .mcp.json (merge with existing entries)
else
  echo "Note: codex not found — code review will use Claude fallback."
  echo "  Install: npm i -g @openai/codex && codex login"
fi
```

### .mcp.json Entry

```json
{
  "mcpServers": {
    "openai": {
      "command": "uv",
      "args": ["run", "--directory", ".mcp-servers/mcp-openai", "python", "server.py"]
    }
  }
}
```

Merged into existing `.mcp.json` alongside playwright and other servers.

### settings.json Changes

Add to permissions allow list:

```json
"allow": [
  "Read", "Write", "Edit", "Bash(*)",
  "Glob", "Grep", "Agent", "WebFetch", "WebSearch",
  "mcp__openai__openai_chat"
]
```

## cross-review Skill Changes

### SKILL.md Step 4

Replace `code-reviewer` with `codex-code-reviewer`. The information passed
(design doc paths, source file paths, requirements.md path) remains the same.
The proxy agent handles file reading and Codex invocation internally.

## Existing code-reviewer.md

Retained (not deleted). Reasons:
- Serves as reference for review criteria in system_prompt construction
- Used as fallback logic reference
- Available for manual/ad-hoc review use cases

## Prerequisites

- `codex` CLI: `npm i -g @openai/codex`
- `codex login`: ChatGPT OAuth authentication (free tier works)
- `uv`: Python package runner
- Python 3.12+

All optional — system degrades gracefully to Claude fallback when unavailable.
