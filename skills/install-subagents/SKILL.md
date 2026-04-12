---
name: install-subagents
description: >
  Select and verify project-managed sub-agents for PBI work.
  Developers invoke after receiving PBI assignments.
disable-model-invocation: false
---

## Inputs

- PBI assignment (backlog.json → assigned PBI details)
- Sub-agent definitions in `agents/` directory

## Outputs

- Confirmation of available sub-agents
- sprint.json → developers[].sub_agents (runtime: actually-used agents only)

## Steps

1. Analyze PBI→determine specialist needs
2. Read `.claude/agents/`→identify available sub-agents:
   - `tdd-guide` — test-first guidance
   - `build-error-resolver` — build/test failure diagnosis
   - Note: code-reviewer/security-reviewer = SM scope (not for Developers)
3. Verify definition files exist with valid YAML frontmatter
4. During implementation→invoke via `Agent(subagent_type="<name>")`. Record only actually-used agents in sprint.json

## Graceful Degradation

Sub-agent files missing→proceed without. Sub-agents are optional enhancements.

Ref: FR-019

## Exit Criteria

- Available sub-agents verified
- Can proceed regardless of sub-agent availability
