# Design Spec Catalog

This file is the single source of truth for which design specifications exist
in this project. **Only specifications explicitly marked as enabled below may
be created. Do not create, request, or reference any specification document
that is not listed here or that is marked as disabled.**

When project needs change, update this catalog first, then create the
corresponding files.

## Governance Rules

The following rules are mandatory and enforceable:

1. **Enabled specs require files.** If a spec is marked `enabled`, a
   corresponding file MUST exist at:
   `.design/specs/{category}/{id}-{slug}.md`
   (e.g., `.design/specs/system-wide/S-001-system-architecture.md`).

2. **Disabled specs prohibit files.** If a spec is marked `disabled`, no
   corresponding file may exist under `.design/specs/`. If a file is found
   for a disabled spec, it MUST be deleted or the spec MUST be flipped to
   `enabled` first.

3. **Catalog-first workflow.** When project needs change:
   (1) Update this catalog first (flip status, add entry, etc.).
   (2) Then create or remove the corresponding spec files.
   Never create a spec file without an enabled catalog entry. Never remove
   a catalog entry without first removing its spec file.

4. **No undocumented specs.** Do not create, request, or reference any
   specification document that is not listed in this catalog. If a new
   spec type is needed, add it here first (default to `disabled`), then
   flip to `enabled` when ready.

5. **Category directories.** Spec files are organized by category:
   `decision-records/`, `system-wide/`, `data/`, `interface/`, `ui/`,
   `logic/`, `quality/`, `operations/`.

6. **Immediate stub creation.** When a catalog entry is flipped to
   `enabled`, a template stub file MUST be created immediately via the
   `scaffold-design-spec` Skill. The stub includes required YAML
   frontmatter (`catalog_id`, `created_sprint`, `related_pbis`, `frozen`,
   `revision_history`) and placeholder sections. This prevents empty or
   malformed files and ensures every enabled entry has a valid file from
   the moment it is activated.

## How to read this catalog

- **enabled**: This spec is active. A corresponding file MUST exist under
  `.design/specs/{category}/`.
- **disabled**: This spec is recognized but not needed for this project.
  No file should exist. If circumstances change, flip to `enabled` and
  create the file.

## Decision Records

| ID    | Spec Name                        | Status   | Granularity                          |
|-------|----------------------------------|----------|--------------------------------------|
| D-001 | Architecture Decision Record     | enabled  | One file per decision                |

## System-Wide

| ID    | Spec Name                        | Status   | Granularity                          |
|-------|----------------------------------|----------|--------------------------------------|
| S-001 | System Architecture              | enabled  | One per project                      |
| S-002 | Application Overview             | enabled  | One per project                      |
| S-003 | Infrastructure / Deployment      | disabled | One per project                      |
| S-004 | Security Architecture            | disabled | One per project                      |
| S-005 | Observability / Monitoring       | disabled | One per project                      |

## Data

| ID    | Spec Name                        | Status   | Granularity                          |
|-------|----------------------------------|----------|--------------------------------------|
| S-010 | Data Model / Entity Design       | enabled  | One per domain aggregate or logical module |
| S-011 | Database Design                  | disabled | One per database                     |
| S-012 | Data Flow / Pipeline             | disabled | One per pipeline                     |

## Interface

| ID    | Spec Name                        | Status   | Granularity                          |
|-------|----------------------------------|----------|--------------------------------------|
| S-020 | API Specification                | enabled  | One per domain boundary              |
| S-021 | Event / Message Contract         | disabled | One per event channel                |
| S-022 | External Integration             | disabled | One per external service             |
| S-023 | WebSocket / Realtime             | disabled | One per realtime feature             |

## UI

| ID    | Spec Name                        | Status   | Granularity                          |
|-------|----------------------------------|----------|--------------------------------------|
| S-030 | Screen / Page Design             | enabled  | One per screen                       |
| S-031 | UI Component Design              | enabled  | One per component group              |
| S-032 | Design System / Style Guide      | disabled | One per project                      |
| S-033 | Navigation / Routing             | disabled | One per project                      |
| S-034 | UX Flow / User Journey           | disabled | One per project                      |

## Logic

| ID    | Spec Name                        | Status   | Granularity                          |
|-------|----------------------------------|----------|--------------------------------------|
| S-040 | Business Rule / Domain Logic     | enabled  | One per bounded context              |
| S-041 | Batch / Scheduled Job            | disabled | One per job                          |
| S-042 | Workflow / State Machine         | disabled | One per workflow                     |

## Quality

| ID    | Spec Name                        | Status   | Granularity                          |
|-------|----------------------------------|----------|--------------------------------------|
| S-050 | Test Strategy                    | enabled  | One per project                      |
| S-051 | Performance / SLA                | disabled | One per project                      |
| S-052 | Error Handling / Logging         | disabled | One per project                      |
| S-053 | Accessibility (a11y)             | disabled | One per project                      |
| S-054 | Privacy / Data Handling          | disabled | One per project                      |

## Operations

| ID    | Spec Name                        | Status   | Granularity                          |
|-------|----------------------------------|----------|--------------------------------------|
| S-060 | Migration / Upgrade              | disabled | One per migration                    |
| S-061 | Configuration Management         | disabled | One per project                      |
| S-062 | Disaster Recovery / Backup       | disabled | One per project                      |
| S-063 | Runbook / Ops Playbook           | disabled | One per project                      |
