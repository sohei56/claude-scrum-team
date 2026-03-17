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

- `state.json` → `phase: "integration_sprint"`
- `.scrum/requirements.md` — for endpoint/workflow discovery
- Project source code with existing tests

## Outputs

- `.scrum/test-results.json` — structured test results (see data model)

## Preconditions

- You are a Developer teammate assigned to testing during the Integration Sprint
- The project has been through at least one Development Sprint with tests written

## Steps

### 1. Initialize test-results.json

Create or overwrite `.scrum/test-results.json` with:

```json
{
  "categories": [],
  "overall_status": "running",
  "started_at": "<current ISO 8601 timestamp>",
  "updated_at": "<current ISO 8601 timestamp>"
}
```

### 2. Detect test frameworks

Check the project root for test runners using this lookup table. Check each
entry in order and collect ALL matches (a project may have multiple):

| Indicator file/pattern | Runner command | Category |
|----------------------|---------------|----------|
| `package.json` with `"test"` script | `npm test` | `unit` |
| `package.json` with `"test:e2e"` script | `npm run test:e2e` | `e2e` |
| `package.json` with `"test:integration"` script | `npm run test:integration` | `integration` |
| `pytest.ini`, `pyproject.toml` with `[tool.pytest]`, or `tests/` with `*.py` | `python -m pytest` | `unit` |
| `Cargo.toml` | `cargo test` | `unit` |
| `go.mod` | `go test ./...` | `unit` |
| `Makefile` with `test` target | `make test` | `unit` |
| `tests/` with `*.bats` files | `bats tests/` | `unit` |

If NO test runner is detected, record a single category with
`status: "skipped"` and `runner_command: "none detected"`.

### 3. Run detected tests

For each detected runner:

1. Run the command and capture exit code + output
2. Parse output to extract pass/fail counts where possible
3. Record a `TestCategory` entry:
   - `name`: category from the lookup table
   - `status`: `"passed"` if exit code 0, `"failed"` otherwise
   - `total`, `passed`, `failed`, `skipped`: parsed from output (use 1/0 if unparseable)
   - `errors`: for failed tests, extract test name and error message (up to 10 entries)
   - `runner_command`: the command that was run
   - `executed_at`: current ISO 8601 timestamp
4. Append the category to `test-results.json` → `categories[]`
5. Update `test-results.json` → `updated_at`

### 4. HTTP smoke testing

Discover HTTP endpoints and test each one:

1. **Find the start command**: Check `package.json` scripts (`start`, `dev`,
   `serve`), `Makefile` targets, `docker-compose.yml`, `manage.py`, or README
2. **Start the application** in the background
3. **Wait for the app** to be ready (retry `curl -s -o /dev/null -w "%{http_code}" http://localhost:<port>/` up to 10 times with 2-second intervals)
4. **Discover endpoints**: Scan route files, `requirements.md`, and source code
   for URL paths. Look for:
   - Express/Fastify/Koa route definitions (`app.get`, `router.post`, etc.)
   - Next.js/Nuxt pages directory (`pages/`, `app/` directories)
   - Django/Flask URL patterns (`urlpatterns`, `@app.route`)
   - OpenAPI/Swagger specs
   - Any URLs mentioned in `requirements.md`
5. **Test each endpoint** with `curl`:
   - GET endpoints: expect 200 (or 301/302 for redirects)
   - Flag any 4xx or 5xx response as a failure
   - Record each as an entry in the errors array if failed
6. **Stop the application** (kill the background process)
7. Record a `TestCategory` entry with `name: "smoke"`:
   - `total`: number of endpoints tested
   - `passed`: endpoints returning 2xx/3xx
   - `failed`: endpoints returning 4xx/5xx or connection refused
   - `errors`: failed endpoint details (`test_name`: "GET /path", `message`: "Expected 2xx, got 404")

If no start command is found, record smoke category as `status: "skipped"`.

### 5. Browser E2E testing (if Playwright MCP available)

Check if the Playwright MCP server is available by looking for it in
`.mcp.json` at the project root.

**If available:**

1. Ensure the application is running (start it if not already running from step 4)
2. Use the Playwright MCP tools to:
   - Navigate to the application's main URL
   - Click every visible link and navigation item
   - Verify no page returns a blank screen or error page
   - Fill and submit any visible forms with test data
   - Check that key user workflows from `requirements.md` complete successfully
3. Record a `TestCategory` entry with `name: "browser"`:
   - Count each page navigation / interaction as a test
   - Record errors for pages that fail to load, return errors, or show blank content

**If not available:**

1. Record the browser category as `status: "skipped"` with
   `runner_command: "playwright MCP not configured"`.
2. **Warn the user explicitly** — display a visible warning message:

   > ⚠️ **Browser E2E tests skipped**: Playwright MCP server is not
   > configured. Browser-level testing (page navigation, form submission,
   > visual verification) will not be performed.
   >
   > To enable browser E2E testing, add the Playwright MCP server to
   > `.mcp.json` in your project root:
   >
   > ```json
   > {
   >   "mcpServers": {
   >     "playwright": {
   >       "command": "npx",
   >       "args": ["@anthropic-ai/mcp-playwright"]
   >     }
   >   }
   > }
   > ```
   >
   > See: https://github.com/anthropics/mcp-playwright

### 6. Compute overall status

After all categories are recorded:

1. If ANY category has `status: "failed"` → set `overall_status: "failed"`
2. If ALL non-skipped categories have `status: "passed"`:
   - If ANY category has `status: "skipped"` → set `overall_status: "passed_with_skips"`
   - If NO category has `status: "skipped"` → set `overall_status: "passed"`
3. Update `updated_at` with the current timestamp
4. Write the final `.scrum/test-results.json`

### 7. Report results to Scrum Master

Send a message to the Scrum Master via Agent Teams with:
- Overall status (passed/failed/passed_with_skips)
- Summary per category: `unit: 15/15 passed`, `smoke: 7/8 failed`
- First 3 error details for any failed category
- **For each skipped category**: include the reason it was skipped and how
  to enable it (e.g., "browser: skipped — Playwright MCP not configured")

Reference: FR-013

## Exit Criteria

- `.scrum/test-results.json` exists with `overall_status` set to `"passed"` or `"failed"`
- All detectable test categories have been executed or marked as `"skipped"`
- Results reported to Scrum Master via Agent Teams messaging
