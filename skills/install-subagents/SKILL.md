---
name: install-subagents
description: >
  Reproducible sub-agent selection from multiple catalog sources.
  Developers invoke after receiving PBI assignments to install
  relevant specialist sub-agents for their work.
disable-model-invocation: false
---

## Inputs

- PBI assignment (task context from `backlog.json` → assigned PBI details)
- Catalog sources (checked in order):
  1. awesome-claude-code-subagents: `.claude/subagents-catalog/categories/`
  2. ECC Plugin agents: `~/.claude/plugins/cache/ecc/ecc/*/agents/`

## Outputs

- `.claude/agents/*.md` — installed sub-agent definition files with YAML
  frontmatter (`tools`, `model`)
- `sprint.json` → `developers[].sub_agents` — runtime-populated with names
  of actually-invoked sub-agents (not candidates)

## Preconditions

- Developer has received PBI assignment via Agent Teams
- `.claude/agents/` directory exists

## Steps

1. **Analyze PBI**: Read the assigned PBI details (title, description,
   acceptance criteria, design document paths) to understand what
   specialist skills are needed.
2. **Browse Catalogs**: Scan available catalog sources in order.
   For each source that exists, list `.md` agent definition files and
   review their YAML frontmatter (`name`, `description`) to find
   matching specialists.
   - **awesome-claude-code-subagents**
     (`.claude/subagents-catalog/categories/`): Each subdirectory is a
     category (e.g., `01-core-development/`, `04-quality-security/`).
   - **ECC Plugin** (`~/.claude/plugins/cache/ecc/ecc/*/agents/`):
     Flat directory of specialist agents (code-reviewer, security-reviewer,
     architect, tdd-guide, e2e-runner, etc.). Use glob pattern to resolve
     the version-specific path.
   If the same agent name appears in multiple catalogs, prefer the
   higher-priority source (awesome-claude-code-subagents > ECC).
3. **Select Agents**: Choose relevant specialist sub-agents based on PBI
   requirements. Consider:
   - Testing specialists (for test-heavy PBIs)
   - Documentation specialists (for docs-related PBIs)
   - Code review specialists (for quality-focused work)
   - Language/framework specialists (matching the project's tech stack)
4. **Install**: Copy selected sub-agent definition files (`.md` with
   YAML frontmatter) to `.claude/agents/`.
5. **Verify**: Confirm installed agents have valid YAML frontmatter with
   required fields (`tools`, `model`).
6. **Use via Task Tool**: During implementation, invoke installed sub-agents
   via `Task(subagent_type="<agent-name>")`. Only record actually-used
   agents in `sprint.json` → `developers[].sub_agents`.

## Graceful Degradation

- If a catalog source is missing, skip it and try the next source.
  Do NOT show an error to the user.
- If all catalog sources are unavailable, proceed without sub-agents.
- If no matching agents are found for the PBI type, proceed without
  sub-agents. Log a brief note for the Scrum Master.
- Sub-agents are optional enhancements, not requirements.

Reference: FR-019

## Exit Criteria

- Relevant sub-agents installed to `.claude/agents/` (if available)
- Developer can proceed with implementation regardless of sub-agent
  availability
- Only actually-invoked agents recorded in `sprint.json` (at runtime)
