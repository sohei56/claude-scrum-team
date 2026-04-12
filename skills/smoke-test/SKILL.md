---
name: smoke-test
description: >
  Smoke Test — automated test execution for Integration Sprint. Detects
  test frameworks, runs all tests, performs HTTP smoke testing, optionally
  runs browser E2E via Playwright MCP, and records results to
  .scrum/test-results.json.
disable-model-invocation: false
---

## Inputs

- state.json → phase: "integration_sprint"
- requirements.md (endpoint/workflow discovery)
- Project source code

## Outputs

- `.scrum/test-results.json`

## Preconditions

- Developer teammate assigned to Integration Sprint testing
- ≥1 Development Sprint completed (tests exist)

## Steps

### 1. Initialize test-results.json

```json
{"categories": [], "overall_status": "running", "started_at": "<ISO8601>", "updated_at": "<ISO8601>"}
```

### 2. Detect test frameworks

Check project root, collect ALL matches:
- package.json "test"→`npm test` (unit)
- package.json "test:e2e"→`npm run test:e2e` (e2e)
- package.json "test:integration"→`npm run test:integration` (integration)
- pytest.ini / pyproject.toml [tool.pytest] / tests/*.py→`python -m pytest` (unit)
- Cargo.toml→`cargo test` (unit)
- go.mod→`go test ./...` (unit)
- Makefile test target→`make test` (unit)
- tests/*.bats→`bats tests/` (unit)

None detected→status: "skipped", runner_command: "none detected"

### 3. Run detected tests

Each runner: execute→capture exit code + output→parse pass/fail counts→record TestCategory (name, status, total, passed, failed, skipped, errors (max 10), runner_command, executed_at)→append to test-results.json→update updated_at

### 4. HTTP smoke testing

1. Find start command (package.json/Makefile/docker-compose etc)
2. Start app in background
3. Wait ready (curl retry 10x, 2s intervals)
4. Discover endpoints: route files, requirements.md, source code, OpenAPI specs
5. Curl each: GET→expect 2xx/3xx→4xx/5xx = failure
6. Stop app
7. Record TestCategory name: "smoke"

No start command→smoke status: "skipped"

### 5. Browser E2E (if Playwright MCP available)

Check `.mcp.json` for Playwright MCP.

**Available**: Ensure app running→Playwright MCP: navigate main URL→click all links/nav→verify no blank/error pages→fill+submit forms→verify requirements.md workflows→record TestCategory name: "browser"

**Not available**: status: "skipped". Warn user: Browser E2E skipped, Playwright MCP not configured. Enable by adding to `.mcp.json`: `{"mcpServers":{"playwright":{"command":"npx","args":["@anthropic-ai/mcp-playwright"]}}}`

### 6. Compute overall_status

- ANY failed→"failed"
- ALL non-skipped passed + ANY skipped→"passed_with_skips"
- ALL passed, NONE skipped→"passed"

### 7. Report to SM

Overall status, per-category summary (e.g., unit: 15/15 passed), first 3 error details for failed categories, skipped category reasons + how to enable

Ref: FR-013

## Exit Criteria

- test-results.json exists with overall_status set
- All detectable categories executed or skipped
- Results reported to SM
