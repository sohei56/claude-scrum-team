# Codex Code Reviewer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Claude-based code review with Codex (OpenAI) via MCP proxy agent, with Claude fallback when Codex is unavailable.

**Architecture:** A new `codex-code-reviewer` Claude sub-agent reads design docs and source code locally, packages them into a prompt, and calls Codex via `mcp__openai__openai_chat` MCP tool. The existing `security-reviewer` remains unchanged.

**Tech Stack:** Python 3.12+ (MCP server), FastMCP, codex app-server (JSON-RPC), Bash (setup scripts), Bats (tests)

---

### Task 1: Copy mcp-openai MCP Server

**Files:**
- Create: `.mcp-servers/mcp-openai/server.py`
- Create: `.mcp-servers/mcp-openai/codex_client.py`
- Create: `.mcp-servers/mcp-openai/pyproject.toml`

- [ ] **Step 1: Create .mcp-servers/mcp-openai directory**

```bash
mkdir -p .mcp-servers/mcp-openai
```

- [ ] **Step 2: Copy server files from my-investment-agent**

```bash
cp ../my-investment-agent/.mcp-servers/mcp-openai/server.py .mcp-servers/mcp-openai/
cp ../my-investment-agent/.mcp-servers/mcp-openai/codex_client.py .mcp-servers/mcp-openai/
cp ../my-investment-agent/.mcp-servers/mcp-openai/pyproject.toml .mcp-servers/mcp-openai/
```

- [ ] **Step 3: Verify files are identical to source**

```bash
diff .mcp-servers/mcp-openai/server.py ../my-investment-agent/.mcp-servers/mcp-openai/server.py
diff .mcp-servers/mcp-openai/codex_client.py ../my-investment-agent/.mcp-servers/mcp-openai/codex_client.py
diff .mcp-servers/mcp-openai/pyproject.toml ../my-investment-agent/.mcp-servers/mcp-openai/pyproject.toml
```

Expected: no output (files identical).

- [ ] **Step 4: Commit**

```bash
git add .mcp-servers/mcp-openai/
git commit -m "feat: add mcp-openai server for Codex integration

Copy generic Codex gateway from my-investment-agent. Provides
mcp__openai__openai_chat tool via codex app-server JSON-RPC."
```

---

### Task 2: Create codex-code-reviewer Agent

**Files:**
- Create: `agents/codex-code-reviewer.md`
- Reference: `agents/code-reviewer.md` (read for review criteria — do not modify)

- [ ] **Step 1: Create the agent definition**

Create `agents/codex-code-reviewer.md` with the following content:

```markdown
---
name: codex-code-reviewer
description: >
  Proxy code reviewer — reads design docs and source code locally,
  then delegates review to OpenAI Codex via mcp__openai__openai_chat.
  Falls back to Claude-based review when Codex is unavailable.
  Read-only except for MCP calls.
tools:
  - Read
  - Grep
  - Glob
  - Bash
  - mcp__openai__openai_chat
effort: high
maxTurns: 50
---

# Codex Code Reviewer (Proxy)

You are a **proxy code reviewer**. You read design documents and source code
locally, package them into a prompt, and delegate the review to OpenAI Codex
via the `mcp__openai__openai_chat` MCP tool.

## What You Receive

- Paths to design documents (`.design/specs/`)
- Paths to source code files
- Path to `requirements.md`

## What You Do NOT Receive (Intentional)

- PBI details or descriptions from `.scrum/`
- Developer communications or implementation history
- Sprint context or backlog state

This information asymmetry is intentional. The review is purely based on
whether the code fulfills the design specification.

## Process

### Step 1: Collect File Contents

1. Read each design document in full using the Read tool.
2. Read each source code file in full using the Read tool.
3. Read `requirements.md` in full using the Read tool.
4. If there are many source files, use Glob to discover related files
   (e.g., test files) that may have been omitted from the explicit list.

### Step 2: Build the Codex Prompt

Construct `system_prompt`:

~~~
You are an independent code reviewer. You receive design documents and
source code, and you review the implementation without knowing the
implementation history or developer discussions.

## Review Criteria

1. **Completeness**: Are all design requirements implemented?
2. **Scope creep**: Is anything implemented that was NOT in the design?
3. **Correctness**: Does the code correctly implement the specified behavior?
4. **Code quality**: Readability, naming, error handling, test coverage.

## Output Format

```
## Review: [brief description]

**Verdict: PASS | FAIL**

### Findings

| # | Severity | File | Lines | Description |
|---|----------|------|-------|-------------|
| 1 | Critical | path/to/file.py | 42-45 | Description of issue |

### Summary

[2-3 sentences summarizing the review]
```

Severity levels:
- **Critical** — Must fix. Incorrect behavior, security vulnerability, data loss risk.
- **High** — Should fix. Missing requirement, significant quality issue.
- **Medium** — Consider fixing. Maintainability concern, unclear naming.
- **Low** — Optional. Style suggestion, minor improvement.

Verdict rules:
- **PASS** — No Critical or High findings.
- **FAIL** — One or more Critical or High findings.

## Strict Rules

- Do NOT suggest fixes. Only describe the problem.
- If you cannot determine correctness from the provided documents, say so.
- End your response with a line: `STATUS: complete`
- If you need additional file contents to complete the review, list the
  file paths you need and end with: `STATUS: needs_info`
~~~

Construct `user message` by concatenating:

```
## Design Documents

### [filename]
[full contents]

## Source Code

### [filename]
[full contents]

## Requirements

[full contents of requirements.md]

---

Review the source code against the design documents. Follow the output
format specified in your instructions.
```

### Step 3: Call Codex

Call `mcp__openai__openai_chat` with:
- `model`: `"gpt-5.4"`
- `system_prompt`: the system prompt constructed above
- `messages`: JSON array with one entry: `[{"role": "user", "content": "<user message>"}]`

Parse the JSON response:
- If `status` is `"complete"`: proceed to Step 4.
- If `status` is `"needs_info"`: read the requested files, append
  `{"role": "assistant", "content": "<response>"}` and
  `{"role": "user", "content": "<file contents>"}` to the messages array,
  and re-call. Maximum 3 needs_info loops.

### Step 4: Return Result

Return the Codex response as your output. The response should already be
in the correct PASS/FAIL format with the Findings table.

## Fallback: Codex Unavailable

If the `mcp__openai__openai_chat` call returns an error response (containing
"codex コマンドが見つかりません", "タイムアウト", "失敗", or any error
indicator), perform the review yourself using the same criteria above.

When falling back:

1. Log: "Codex unavailable — performing Claude fallback review."
2. Review the code using the exact same criteria (completeness, scope creep,
   correctness, code quality).
3. Produce the same output format (PASS/FAIL + Findings table + Summary).
4. Prepend `[Fallback: Claude review]` to the Summary section.
```

- [ ] **Step 2: Verify the agent file parses correctly**

```bash
head -15 agents/codex-code-reviewer.md
```

Expected: YAML frontmatter with name, description, tools list including `mcp__openai__openai_chat`.

- [ ] **Step 3: Commit**

```bash
git add agents/codex-code-reviewer.md
git commit -m "feat: add codex-code-reviewer proxy agent

Reads design docs and source code locally, delegates review to
Codex via mcp__openai__openai_chat. Falls back to Claude review
when Codex is unavailable."
```

---

### Task 3: Update cross-review Skill

**Files:**
- Modify: `skills/cross-review/SKILL.md:49-55`

- [ ] **Step 1: Replace code-reviewer with codex-code-reviewer in Step 4**

In `skills/cross-review/SKILL.md`, change Step 4 from:

```markdown
4. **Spawn reviewers**: For each PBI, spawn two sub-agents in parallel
   via the Agent tool:
   - `code-reviewer` — pass design doc paths, source file paths,
     and requirements.md path. Do NOT pass PBI descriptions,
     developer communications, or `.scrum/` state files.
   - `security-reviewer` — pass source file paths and requirements.md
     path only.
```

to:

```markdown
4. **Spawn reviewers**: For each PBI, spawn two sub-agents in parallel
   via the Agent tool:
   - `codex-code-reviewer` — pass design doc paths, source file paths,
     and requirements.md path. Do NOT pass PBI descriptions,
     developer communications, or `.scrum/` state files.
   - `security-reviewer` — pass source file paths and requirements.md
     path only.
```

- [ ] **Step 2: Verify the change**

```bash
grep -n "codex-code-reviewer" skills/cross-review/SKILL.md
```

Expected: line ~51 shows `codex-code-reviewer`.

- [ ] **Step 3: Commit**

```bash
git add skills/cross-review/SKILL.md
git commit -m "refactor: use codex-code-reviewer in cross-review skill

Replace code-reviewer with codex-code-reviewer proxy agent.
Security reviewer remains unchanged."
```

---

### Task 4: Update Scrum Master Agent

**Files:**
- Modify: `agents/scrum-master.md:89-96` (FR-009)
- Modify: `agents/scrum-master.md:151-152` (phase workflow)

- [ ] **Step 1: Update FR-009**

In `agents/scrum-master.md`, change line 90 from:

```markdown
- After all implementations complete, spawn `code-reviewer` and
  `security-reviewer` sub-agents per PBI via the Agent tool
```

to:

```markdown
- After all implementations complete, spawn `codex-code-reviewer` and
  `security-reviewer` sub-agents per PBI via the Agent tool
```

- [ ] **Step 2: Update phase workflow description**

In `agents/scrum-master.md`, change line 151 from:

```markdown
   - **Review phase** → Scrum Master spawns `code-reviewer` and
     `security-reviewer` sub-agents per PBI (see cross-review skill)
```

to:

```markdown
   - **Review phase** → Scrum Master spawns `codex-code-reviewer` and
     `security-reviewer` sub-agents per PBI (see cross-review skill)
```

- [ ] **Step 3: Verify both changes**

```bash
grep -n "codex-code-reviewer" agents/scrum-master.md
```

Expected: two matches (FR-009 and phase workflow).

- [ ] **Step 4: Commit**

```bash
git add agents/scrum-master.md
git commit -m "refactor: update scrum-master to use codex-code-reviewer

Update FR-009 and phase workflow references from code-reviewer
to codex-code-reviewer proxy agent."
```

---

### Task 5: Update setup-user.sh — MCP Server Distribution

**Files:**
- Modify: `scripts/setup-user.sh`

- [ ] **Step 1: Add mcp-openai copy section after Playwright MCP block**

After the existing Playwright MCP configuration block (line ~282), add:

```bash
# --- Configure Codex MCP for cross-model code review ---
# Codex MCP enables the codex-code-reviewer agent to delegate code review
# to OpenAI models. When codex is not installed, the agent falls back to
# Claude-based review automatically.

if command -v codex >/dev/null 2>&1; then
  echo ""
  echo "Configuring Codex MCP for cross-model code review..."

  # Copy MCP server files
  mcp_server_dir="$TARGET_DIR/.mcp-servers/mcp-openai"
  mkdir -p "$mcp_server_dir"
  cp "$PROJECT_ROOT/.mcp-servers/mcp-openai/server.py" "$mcp_server_dir/"
  cp "$PROJECT_ROOT/.mcp-servers/mcp-openai/codex_client.py" "$mcp_server_dir/"
  cp "$PROJECT_ROOT/.mcp-servers/mcp-openai/pyproject.toml" "$mcp_server_dir/"
  echo "  Copied mcp-openai server to .mcp-servers/mcp-openai/"

  # Add openai entry to .mcp.json
  mcp_file="$TARGET_DIR/.mcp.json"

  if [ -f "$mcp_file" ]; then
    if ! grep -q '"openai"' "$mcp_file" 2>/dev/null; then
      tmp_mcp="$(mktemp)"
      if jq '.mcpServers.openai = {"command": "uv", "args": ["run", "--directory", ".mcp-servers/mcp-openai", "python", "server.py"]}' "$mcp_file" > "$tmp_mcp" 2>/dev/null; then
        mv "$tmp_mcp" "$mcp_file"
      else
        rm -f "$tmp_mcp"
      fi
      echo "  Added Codex MCP to existing .mcp.json"
    else
      echo "  Codex MCP already configured in .mcp.json"
    fi
  else
    cat > "$mcp_file" << 'MCP_EOF'
{
  "mcpServers": {
    "openai": {
      "command": "uv",
      "args": ["run", "--directory", ".mcp-servers/mcp-openai", "python", "server.py"]
    }
  }
}
MCP_EOF
    echo "  Created .mcp.json with Codex MCP"
  fi
else
  echo ""
  echo "Note: codex not found — code review will use Claude fallback."
  echo "  Install: npm i -g @openai/codex && codex login"
fi
```

- [ ] **Step 2: Add mcp__openai__openai_chat to settings.json permissions**

In the `settings.json` heredoc within `setup-user.sh`, add `"mcp__openai__openai_chat"` to the `allow` array. Change:

```json
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
```

to:

```json
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
      "mcp__openai__openai_chat"
    ]
```

- [ ] **Step 3: Verify syntax**

```bash
bash -n scripts/setup-user.sh
```

Expected: no output (valid syntax).

- [ ] **Step 4: Run shellcheck**

```bash
shellcheck scripts/setup-user.sh
```

Expected: no errors (warnings about `local` in POSIX are acceptable).

- [ ] **Step 5: Commit**

```bash
git add scripts/setup-user.sh
git commit -m "feat: distribute mcp-openai server in setup-user.sh

Copy mcp-openai server to target project and configure .mcp.json
when codex CLI is available. Add mcp__openai__openai_chat to
settings.json permissions."
```

---

### Task 6: Verify End-to-End Setup

**Files:**
- No new files — verification only

- [ ] **Step 1: Run setup in a temp directory to verify file distribution**

```bash
tmpdir="$(mktemp -d)"
cd "$tmpdir"
git init
sh /Users/inouesouhei/work/claude-scrum-team/scripts/setup-user.sh
```

Verify:
- `.claude/agents/codex-code-reviewer.md` exists
- `.claude/agents/code-reviewer.md` still exists (retained)
- `.claude/skills/cross-review/SKILL.md` contains `codex-code-reviewer`
- If codex is installed: `.mcp-servers/mcp-openai/server.py` exists and `.mcp.json` contains `"openai"` entry
- `.claude/settings.json` contains `mcp__openai__openai_chat` in allow list

- [ ] **Step 2: Verify .mcp.json merging with existing entries**

```bash
tmpdir2="$(mktemp -d)"
cd "$tmpdir2"
git init
echo '{"mcpServers":{"playwright":{"command":"npx","args":["@anthropic-ai/mcp-playwright"]}}}' > .mcp.json
sh /Users/inouesouhei/work/claude-scrum-team/scripts/setup-user.sh
cat .mcp.json
```

Expected: both `playwright` and `openai` entries present (if codex installed).

- [ ] **Step 3: Clean up temp directories**

```bash
rm -rf "$tmpdir" "$tmpdir2"
```

- [ ] **Step 4: Run existing test suite**

```bash
cd /Users/inouesouhei/work/claude-scrum-team
bats tests/unit/ tests/lint/
```

Expected: all tests pass.

- [ ] **Step 5: Commit (if any fixes were needed)**

Only if previous steps revealed issues requiring code changes.
