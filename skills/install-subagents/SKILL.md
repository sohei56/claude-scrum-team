---
name: install-subagents
description: >
  Reproducible sub-agent selection from the awesome-claude-code-subagents
  catalog. Developers invoke after receiving PBI assignments to install
  relevant specialist sub-agents for their work.
disable-model-invocation: true
---

## Inputs (required state)

- PBI assignment (task context from `backlog.json` → assigned PBI details)
- Catalog URL: `https://github.com/VoltAgent/awesome-claude-code-subagents/tree/main`

## Outputs (files/keys updated)

- `.claude/agents/*.md` — installed sub-agent definition files with YAML
  frontmatter (`tools`, `model`)
- `sprint.json` → `developers[].sub_agents` — runtime-populated with names
  of actually-invoked sub-agents (not candidates)

## Preconditions

- Developer has received PBI assignment via Agent Teams
- `.claude/agents/` directory exists
- Network access available (for catalog browsing)

## Steps

1. **Analyze PBI**: Read the assigned PBI details (title, description,
   acceptance criteria, design document paths) to understand what
   specialist skills are needed.
2. **Browse Catalog**: Access the awesome-claude-code-subagents catalog at
   `https://github.com/VoltAgent/awesome-claude-code-subagents/tree/main`.
3. **Select Agents**: Choose relevant specialist sub-agents based on PBI
   requirements. Consider:
   - Testing specialists (for test-heavy PBIs)
   - Documentation specialists (for docs-related PBIs)
   - Code review specialists (for quality-focused work)
   - Language/framework specialists (matching the project's tech stack)
4. **Install**: Download selected sub-agent definition files (`.md` with
   YAML frontmatter) to `.claude/agents/`.
5. **Verify**: Confirm installed agents have valid YAML frontmatter with
   required fields (`tools`, `model`).
6. **Use via Task Tool**: During implementation, invoke installed sub-agents
   via `Task(subagent_type="<agent-name>")`. Only record actually-used
   agents in `sprint.json` → `developers[].sub_agents`.

## Graceful Degradation

- If the catalog is unavailable (network error, 404, etc.), proceed
  without sub-agents. Do NOT show an error to the user.
- If no matching agents are found for the PBI type, proceed without
  sub-agents. Log a brief note for the Scrum Master.
- Sub-agents are optional enhancements, not requirements.

## Exit Criteria

- Relevant sub-agents installed to `.claude/agents/` (if available)
- Developer can proceed with implementation regardless of sub-agent
  availability
- Only actually-invoked agents recorded in `sprint.json` (at runtime)
