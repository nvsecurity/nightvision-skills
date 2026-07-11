---
name: app-security-scan
description: DAST-first NightVision scan for an app you just built or changed. Use when a user (or an org CLAUDE.md rule) wants a local, private, staging, or internal web app/API security-scanned. Drives the NightVision MCP `run-app-security-scan` harness.
user-invocable: true
allowed-tools: Bash, Read, Grep, mcp__nightvision__auth-status, mcp__nightvision__preflight-app, mcp__nightvision__run-app-security-scan, mcp__nightvision__wait-for-scan, mcp__nightvision__get-scan-status, mcp__nightvision__summarize-scan-findings, mcp__nightvision__export-sarif
---

# NightVision App Security Scan

Run a real DAST scan against an app you just built or changed. API Discovery runs first when the backend language is supported, because it improves coverage and lets findings trace back to a source file and line (Code Traceback). DAST is the expected outcome on every run, not just a generated spec.

## Workflow

1. Know the app's URL. You are running on the developer's machine with the app's source in front of you, so you know how it serves. If it is not already running, start it with its own command (`npm run dev`, `docker compose up`, the framework dev server). Pass that URL as `target_url`. Do not ask the harness to guess it.
2. Call `run-app-security-scan` with `project_path`, `target_url`, the NightVision project, and the app-auth mode (see Auth). One call does preflight, API Discovery, target create/update, DAST start, and writes `.nightvision/manifest.json`.
3. It returns a `scan_id` quickly (`wait` defaults to false). DAST commonly runs longer than 10 minutes, so do not assume it finished.
4. Poll `wait-for-scan` or `get-scan-status` until a terminal status.
5. Export SARIF and summarize: call `export-sarif` (the harness attaches the discovered spec so findings carry endpoint + source file:line) and `summarize-scan-findings`. Report the scan id, target, project, finding counts, and the top findings with endpoint, source file:line, evidence, and a suggested fix.
6. The manifest is the local record and stays in the repo. Treat the work as incomplete until `.nightvision/manifest.json` holds a `scan_id`, or you have reported a concrete blocker.

Resolve blockers the harness reports rather than working around them: `not_authenticated` / `invalid_or_expired_token` (auth), `target_url_required` (you did not pass the URL), `runtime_url_not_reachable` (the app is not up, start it), `nightvision_project_required`. Use `dry_run: true` when the user only wants a readiness check without creating targets or starting a scan.

## Unattended mode

When an org CLAUDE.md rule triggers this after an app is built (no human watching): start the app yourself, rely on `NIGHTVISION_DEFAULT_PROJECT` and the environment's NightVision token (never prompt for them; a missing one is a blocker to report), and close the loop before ending your turn. Do not leave a scan running with nobody watching: poll to a terminal status, then export SARIF and summarize. If you cannot start the app or auth is missing, report that as the concrete blocker instead of silently skipping the scan.

## Auth

Two different things. NightVision account auth is the user's own NightVision token; never paste a shared token into CLAUDE.md, a repo file, or a team config, each user authenticates as themselves. Target-app auth is how DAST logs into the app under test, passed to the scan as:

- `no_auth: true` to scan unauthenticated (say so; it may miss authenticated functionality).
- `auth` (named profile) or `auth_id` (credential UUID) for an existing NightVision app-auth credential.
- `app_auth` with `type: "playwright_script"` for any username/password, OAuth, MFA, or expiring-session login. Do not turn an expiring cookie or bearer token into a header/cookie credential.
- `app_auth` with `type: "headers"` or `"cookies"` only for stable, non-expiring credentials such as a service API key; set `credential_lifetime: "stable"`.

## Reporting

A terminal `FAILED` scan can still contain valid findings: check the finding count and summarize what it found before calling a run unusable. Never claim the app is secure or scanned unless NightVision results support it. If DAST could not run, report the blocker and the manifest path.

## Remediation (find-to-fix)

When the user wants findings fixed and not just reported, use what each finding actually carries. It varies by class, so do not assume every finding gives you a source line or a parameter:

- Request-level findings (SQL injection, XSS, command injection, and similar) carry a source `file:line`, the endpoint, the vulnerable parameter, and the proof-of-concept payload. The `file:line` is the DAST-observable entry point (the endpoint handler), not always the sink: open it, follow the named parameter into the service or repository that uses it, find the sink, and apply the standard fix for the class (a parameterized query for SQL injection, output encoding for reflected XSS), matching the codebase's existing patterns.
- Response/config-level findings (missing security headers, weak authentication method, error or stack-trace disclosure) usually have no per-line source location; fix them in the app's security configuration (the header/filter/security config), not at one handler.

NightVision does not hand you a patch (`fixes`/`codeFlows` in the SARIF are empty), and not every finding maps to source, so treat this as a locate-and-fix aid. Always re-scan with `run-app-security-scan` and confirm the finding is gone before calling it fixed. Remediation is a follow-on to the scan, not a replacement: scan first, and only change code when the user asks for fixes.
