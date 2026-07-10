---
name: app-security-scan
description: DAST-first NightVision harness for agents helping users create, run, or review a web app/API. Use when a user asks to scan a local, private, staging, or internal app, especially when the app was just created or changed. Prefer the NightVision MCP `run-app-security-scan` harness when available.
user-invocable: true
allowed-tools: Bash, Read, Grep, ToolSearch, mcp__nightvision__authenticate, mcp__nightvision__auth-status, mcp__nightvision__doctor, mcp__nightvision__login-help, mcp__nightvision__preflight-app, mcp__nightvision__run-app-security-scan, mcp__nightvision__wait-for-scan, mcp__nightvision__summarize-scan-findings, mcp__nightvision__export-sarif, mcp__nightvision__export-csv, mcp__nightvision__discover-api, mcp__nightvision__create-target, mcp__nightvision__start-scan, mcp__nightvision__get-scan-status, mcp__nightvision__get-scan-checks, mcp__nightvision__list-managed-scan-processes, mcp__nightvision__get-managed-scan-process, mcp__nightvision__cancel-managed-scan-process
---

# NightVision App Security Scan

Use this skill when a user is building or modifying a web app/API and needs a NightVision security scan. The goal is to run DAST, not just generate documentation. API Discovery is used when possible because it improves scan coverage and Code Traceback, but DAST is the expected outcome on every run.

## Priority workflow

Prefer the NightVision MCP server when it is available. It gives the agent one structured flow instead of making the user know projects, targets, API Discovery, scan IDs, polling, and SARIF export.

If tool discovery is available, look for NightVision MCP tools named `run-app-security-scan`, `preflight-app`, `wait-for-scan`, `summarize-scan-findings`, `export-sarif`, and `export-csv`. If the MCP server has a different Claude tool prefix, use the discovered tools with those names.

Default to this sequence:

1. Run `run-app-security-scan` for normal scan requests. It performs preflight, API Discovery, target create/update, DAST start, scan ID return, and manifest writing.
2. Use `dry_run: true` when the user asks whether the app is ready to scan, when you are preparing a demo, or when you need readiness diagnostics without creating/updating targets or starting DAST.
3. Use `preflight-app` only for lightweight diagnostics or when the full harness is not needed.
4. Resolve blockers the harness reports:
   - NightVision auth missing.
   - App is not running or target URL is not reachable.
   - NightVision project is missing or ambiguous.
   - Target app auth is missing and the scan would be too shallow unauthenticated.
5. If a scan ID is produced, return it immediately with the target name, project, manifest path, and a note that DAST commonly runs longer than 10 minutes.
6. Poll later with `get-scan-status`, `list-scans`, or `wait-for-scan` when the user asks for results.
7. When the scan reaches a terminal status, call `summarize-scan-findings` and export SARIF. Its default filters are open critical, high, medium, and low findings.
8. If CSV is useful for sharing or spreadsheet review, call `export-csv`.

Do not ask non-security users to manually choose every NightVision primitive before trying the harness. Start with the harness, then fall back only when needed.

## Unattended / non-technical developer mode

When this workflow is triggered automatically (for example by an organization CLAUDE.md rule after an app is built) rather than by an explicit user request, assume the developer will not start the app, will not answer NightVision questions, and will not come back later to check results. Do the work for them:

1. Start the app you just built or changed using its own run command (for example `npm start`, `npm run dev`, `docker compose up`, the framework dev server) so it is reachable locally, then pass that URL as `target_url`. If it cannot be started, report that as the concrete blocker instead of silently skipping the scan.
2. Rely on `NIGHTVISION_DEFAULT_PROJECT` and the managed CLI auth from the environment. Do not prompt the developer for a project or token; if auth or project is missing, that is a setup blocker to report, not a question to ask.
3. Close the loop before ending your turn. Do not leave a scan running with nobody watching: either call `run-app-security-scan` with `wait: true`, or start it and then poll `wait-for-scan`/`get-scan-status` until a terminal status, then `summarize-scan-findings` and export SARIF. Report the scan ID, the top findings, and the artifact paths.

Treat the work as incomplete until `.nightvision/manifest.json` contains a scan ID or you have reported a concrete blocker.

Example harness call shape:

```json
{
  "project_path": "/absolute/path/to/app",
  "target_url": "http://127.0.0.1:8080",
  "nightvision_project": "Project Name",
  "auth": "optional-app-auth-profile",
  "auth_id": "optional-app-auth-uuid",
  "no_auth": true,
  "wait": false
}
```

Use `wait: true` only when the MCP client can keep one tool call open for the full scan duration. Do not assume DAST completes in under 10 minutes.

Use exactly one target-app auth mode when possible:

- `auth` for a named NightVision app auth profile.
- `auth_id` for a NightVision app auth credential UUID.
- `no_auth: true` when scanning unauthenticated.
- `app_auth` with `type: "playwright_script"` when the app uses a username/password login flow.
- `app_auth` with `type: "headers"` or `type: "cookies"` only for stable, non-expiring app credentials. Set `credential_lifetime: "stable"`.

Do not confuse target-app auth with NightVision account auth. NightVision account auth is the user's own NightVision login/token.

## MCP tool expectations

`preflight-app` should return:

- Repo metadata.
- Detected language/framework.
- Target URL reachability.
- NightVision auth/project/target readiness.
- Blockers and warnings.
- `.nightvision/manifest.json`.

`run-app-security-scan` should:

- Validate repo and app runtime.
- Use `NIGHTVISION_DEFAULT_PROJECT`, an explicit `nightvision_project`, or an unambiguous default/single project.
- Run API Discovery when a supported backend language is detected.
- Create or update the NightVision target with the current app URL and generated spec when available.
- Start a NightVision DAST scan.
- Return the scan ID and manifest path without waiting by default.
- Keep the MCP server process running for local/private scans so the CLI relay stays alive.
- Wait for completion only when explicitly requested.
- Export SARIF to `.nightvision/nightvision-<scan_id>.sarif` when the scan reaches a terminal status and results are available.
- Export CSV to `.nightvision/nightvision-<scan_id>.csv` when requested or useful for review.
- Summarize open findings with severity, endpoint, evidence, and explanation when results are available.
- Write `.nightvision/manifest.json` with the scan ID, target, project, spec path, SARIF path, blockers, and warnings.

When `dry_run: true`, the harness should not create/update targets or start scans. It may still return readiness blockers such as `not_authenticated`. Treat those blockers as setup work before the real run, not as a failed dry run.

NightVision normally detects when Smart Proxy/private scan behavior is needed for localhost, Docker, Kubernetes, corporate networks, and internal cloud apps. Use `force_private_scan` only as an override when automatic detection is not working for the environment.

A terminal `FAILED` scan can still contain valid findings. Check `issues_count` and export/summarize available results before treating the run as unusable.

## Required user-owned auth

Do not paste shared NightVision tokens into commands, repo files, or Claude instructions. Each user should authenticate with their own NightVision account.

Acceptable auth patterns:

```bash
nightvision login --api-url https://api.nightvision.net/api/v1/
nightvision token create
export NIGHTVISION_TOKEN="<user-owned-token>"
export NIGHTVISION_DEFAULT_PROJECT="<project-name>"
```

Never put a shared NightVision token in `CLAUDE.md`, a repository file, a managed MCP config, or a team-wide environment block. Each user should authenticate as themselves.

If the target app requires a browser login, username/password form, OAuth flow, MFA step, or any expiring session cookie/token, use Playwright script auth. Do not turn an expiring session cookie or bearer token into a header/cookie credential.

```bash
nightvision auth playwright create my-app-auth http://localhost:8080
```

Use direct headers or cookies only for stable app credentials such as service API keys:

```bash
nightvision auth headers create my-api-auth -H "Authorization: Bearer <app-token>"
```

Use `auth`, `auth_id`, or `no_auth` explicitly when running the scan harness. If no app auth is supplied, explain that the DAST scan is unauthenticated and may miss authenticated functionality.

## CLI fallback

If the MCP server is not installed or the MCP tools are unavailable, use the CLI flow below. Keep it DAST-first.

```bash
nightvision version
nightvision project list -F json
```

Detect the backend language and run API Discovery when supported:

```bash
mkdir -p .nightvision
nightvision swagger extract . --lang java -o .nightvision/openapi.yml --no-upload
```

Create or update the target. Use an API target when a spec exists, otherwise use WEB:

```bash
nightvision target create "$TARGET_NAME" "$TARGET_URL" --type API -p "$NIGHTVISION_PROJECT" --spec-file .nightvision/openapi.yml \
  || nightvision target update "$TARGET_NAME" -p "$NIGHTVISION_PROJECT" -u "$TARGET_URL" --spec-file .nightvision/openapi.yml
```

For a WEB target:

```bash
nightvision target create "$TARGET_NAME" "$TARGET_URL" --type WEB -p "$NIGHTVISION_PROJECT" \
  || nightvision target update "$TARGET_NAME" -p "$NIGHTVISION_PROJECT" -u "$TARGET_URL"
```

Run DAST:

```bash
nightvision scan "$TARGET_NAME" -p "$NIGHTVISION_PROJECT" --no-auth -F json
```

For authenticated scans:

```bash
nightvision scan "$TARGET_NAME" -p "$NIGHTVISION_PROJECT" --auth "$AUTH_NAME" -F json
```

Export results:

```bash
nightvision export sarif --scan-id "$SCAN_ID" --swagger-file .nightvision/openapi.yml --output ".nightvision/nightvision-$SCAN_ID.sarif"
nightvision export csv --scan-id "$SCAN_ID" --output ".nightvision/nightvision-$SCAN_ID.csv"
```

## Agent behavior

Block before creating/updating targets, starting scans, exporting results, or reading findings when NightVision auth is missing. It is fine to run dry-run readiness checks without auth.

Do not treat API Discovery failure as a reason to skip DAST. If discovery fails, warn the user, create or reuse a WEB target, and scan the running app.

For explicit target URLs, validate that URL. Do not silently switch to another common localhost port if the user supplied a URL.

For private or internal apps, assume the CLI is running from a network location that can reach the app. The app does not need to be public.

Use stable local artifacts:

- `.nightvision/openapi.yml` or `.nightvision/openapi_<lang>.yml`
- `.nightvision/nightvision-<scan_id>.sarif`
- `.nightvision/nightvision-<scan_id>.csv`
- `.nightvision/manifest.json`

After the scan, summarize:

- Scan ID.
- Target name and URL.
- Project.
- Whether API Discovery ran and which spec was attached.
- Whether the scan was authenticated.
- Whether the scan is still running, succeeded, failed with findings, or failed without useful results.
- SARIF and CSV paths, if exported.
- Critical, high, and medium finding counts when results are available.
- The top open findings with endpoint, evidence, and suggested next action.

Do not claim the app is secure, scanned, or free of vulnerabilities unless NightVision results support that statement. If DAST could not run, report the blocker and the manifest path.
