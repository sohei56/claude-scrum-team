---
name: install-subagents
description: >
  Reproducible sub-agent selection from the awesome-claude-code-subagents
  catalog. Developers invoke after receiving PBI assignments to install
  relevant specialist sub-agents for their work.
disable-model-invocation: false
---

## Inputs

- PBI assignment (task context from `backlog.json` → assigned PBI details)
- Catalog path: `.claude/subagents-catalog/categories/`

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
2. **Browse Catalog**: Read the local sub-agent catalog at
   `.claude/subagents-catalog/categories/`. Each subdirectory is a
   category (e.g., `01-core-development/`, `04-quality-security/`).
   List `.md` files within relevant categories and review their
   descriptions to find matching specialists.
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

- If the catalog directory is missing (setup skipped or clone failed),
  proceed without sub-agents. Do NOT show an error to the user.
- If no matching agents are found for the PBI type, proceed without
  sub-agents. Log a brief note for the Scrum Master.
- Sub-agents are optional enhancements, not requirements.

Reference: FR-019

## Exit Criteria

- Relevant sub-agents installed to `.claude/agents/` (if available)
- Developer can proceed with implementation regardless of sub-agent
  availability
- Only actually-invoked agents recorded in `sprint.json` (at runtime)
