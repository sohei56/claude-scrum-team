---
name: install-subagents
description: >
  Select and verify project-managed sub-agents for PBI work.
  Developers invoke after receiving PBI assignments.
disable-model-invocation: false
---

## Inputs

- PBI assignment (task context from `backlog.json` → assigned PBI details)
- Project sub-agents in `agents/` directory:
  - `code-reviewer.md` — independent code review (used by Scrum Master)
  - `security-reviewer.md` — security vulnerability scanning (used by Scrum Master)
  - `tdd-guide.md` — TDD workflow guidance
  - `build-error-resolver.md` — build/lint error diagnosis

## Outputs

- Confirmation that relevant sub-agents are available in `.claude/agents/`
- `sprint.json` → `developers[].sub_agents` — runtime-populated with names
  of actually-invoked sub-agents (not candidates)

## Preconditions

- Developer has received PBI assignment via Agent Teams
- `.claude/agents/` directory exists with project sub-agent definitions

## Steps

1. **Analyze PBI**: Read the assigned PBI details (title, description,
   acceptance criteria, design document paths) to understand what
   specialist skills are needed.
2. **List available sub-agents**: Read `.claude/agents/` directory and
   identify available sub-agents by reading their YAML frontmatter
   (`name`, `description`).
   Available sub-agents for Developer use:
   - `tdd-guide` — invoke for test-first development guidance
   - `build-error-resolver` — invoke when builds or tests fail
   Note: `code-reviewer` and `security-reviewer` are used by the
   Scrum Master during the review phase, not by Developers directly.
3. **Verify availability**: Confirm the sub-agent definition files exist
   and have valid YAML frontmatter with required fields.
4. **Use via Agent tool**: During implementation, invoke sub-agents via
   `Agent(subagent_type="<agent-name>")`. Only record actually-used
   agents in `sprint.json` → `developers[].sub_agents`.

## Graceful Degradation

- If sub-agent definition files are missing, proceed without them.
  Sub-agents are optional enhancements, not requirements.
- Log a brief note if expected agents are unavailable.

Reference: FR-019

## Exit Criteria

- Developer has verified which sub-agents are available
- Developer can proceed with implementation regardless of sub-agent
  availability
- Only actually-invoked agents recorded in `sprint.json` (at runtime)
