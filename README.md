<div align="center">

<picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/nv-icon-dark.png">
    <img alt="NightVision" src="assets/nv-icon.png">
</picture>

# NightVision Agent Skills

**Your best defense is a good offense: give your coding agent NightVision skills.**

<br>

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Agent Skills](https://img.shields.io/badge/Agent_Skills-Open_Standard-6f42c1.svg)](https://agentskills.io)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Plugin-blueviolet)](https://docs.anthropic.com/en/docs/claude-code)
[![NightVision](https://img.shields.io/badge/NightVision-DAST-orange)](https://nightviz.ai)

</div>

---

[NightVision](https://nightviz.ai) is a DAST platform for web applications and APIs. It reads source code to map every API (Source Intelligence), tests the running application the way an attacker would, including AI-backed endpoints and quantum-vulnerable cryptography, and connects validated findings to source locations when that context is available.

These [Agent Skills](https://agentskills.io) give your coding agent the ability to run NightVision scans, triage results, and integrate security testing into your CI/CD pipelines, all from natural language. Agent Skills are an open format supported by Claude Code, OpenAI Codex, Cursor, and other agentic tools, so the same skill folders work across whichever agent you use.

## Installation

The skills live in `skills/` as portable Agent Skills folders. Install them into whichever agent you use.

### Claude Code

From the terminal:

```bash
claude plugin marketplace add nvsecurity/claude-marketplace
claude plugin install nightvision@nvsecurity
claude
```

Or from inside Claude Code:

```
/plugin marketplace add nvsecurity/claude-marketplace
/plugin install nightvision@nvsecurity
```

> You may need to restart Claude Code for the plugin to load.

### Codex, Cursor, and other Agent Skills tools

The `skills/` folders are standard Agent Skills, so any compatible agent can load them. The method that works across tools is to copy or symlink the folders into a skills directory your agent scans. `~/.agents/skills/` is read by both Codex and Cursor at the user level:

```bash
git clone https://github.com/nvsecurity/nightvision-skills.git
mkdir -p ~/.agents/skills
cp -R nightvision-skills/skills/* ~/.agents/skills/
```

Use a project-level `.agents/skills/` instead to scope the skills to one repository.

Tool-specific shortcuts:

- **Codex**: `$skill-installer` installs skills by name and can be prompted to fetch from a GitHub repository. Codex also reads `.agents/skills/` and `~/.agents/skills/` directly.
- **Cursor**: add via Settings -> Rules -> Project Rules -> Add Rule -> Remote Rule (GitHub) with this repository's URL, or use the directory method above (Cursor also reads `.cursor/skills/`).

## Skills

| Skill | What it does |
|:------|:-------------|
| **`app-security-scan`** | Run the DAST-first app scan harness for local, private, staging, and internal apps. Uses MCP `run-app-security-scan` when available to preflight, discover APIs, create/update targets, start scans, return scan IDs, poll status, summarize findings, export SARIF/CSV, and write a manifest |
| **`scan-configuration`** | Set up DAST scans — create targets, configure and verify authentication (Playwright, headers, cookies, `--login-check`), choose scan duration and engines, set up AI endpoint scanning and quantum readiness, define scope exclusions, and prepare private network scans |
| **`scan-report`** | Generate a shareable PDF security report: an executive summary for AppSec and leadership plus a findings appendix for developers, for one scan, a scan compared with the previous one, or a whole project |
| **`scan-triage`** | Interpret scan results — read SARIF/CSV findings, understand vulnerabilities, locate the vulnerable code, validate with curl, prioritize by severity, suggest fixes, and mark false positives |
| **`source-intelligence`** | Extract OpenAPI specs from source code, check framework support, report weak cryptography and hardcoded credentials, troubleshoot extraction, compare specs across versions, and leverage Code Traceback |
| **`ci-cd-integration`** | Wire NightVision into your pipeline — GitHub Actions, GitLab CI, Azure DevOps, Jenkins, BitBucket, and JFrog with SARIF/CSV export and breaking-change detection |
| **`secure-build`** | Secure-by-default rules the agent follows while writing a web app or API: access control on every object, parameterized queries, secrets out of code and frontend bundles, sessions, CORS and headers, rate limits, uploads, SSRF, AI features, dependencies, and Supabase/Firebase rules |
| **`authz-review`** | Review object-level and function-level access control (BOLA/IDOR, admin actions, mass assignment) route by route with source `file:line`, and write a two-user test the developer runs against their own local or dev app |
| **`verify-fix`** | Prove a finding is fixed: replay the proof-of-concept request, then rerun only the check that found it against the same target, and report verified or still open with the retest scan ID |
| **`ship-check`** | The finish line for agent-built apps: review the change, scan the running app, fix what is real in code written this session, verify each fix with a retest, and report what is open, with false-positive candidates left for AppSec to decide |

### Example Usage

Just ask your agent what you need:

```
> Set up a NightVision scan for my API running on localhost:8080

> Run a NightVision app security scan for this local service

> Triage the results from my last scan and suggest fixes

> Make a PDF report of my last scan that I can send to our CISO

> Is this safe to ship? Run a security check before I deploy

> I fixed the SQL injection, verify the fix

> Can one user see another user's orders in this app?

> Add NightVision to my GitHub Actions workflow

> Extract an OpenAPI spec from this Django project
```

In Claude Code, invoke skills directly with slash commands:

```
/app-security-scan
/scan-configuration
/scan-report
/scan-triage
/source-intelligence
/ci-cd-integration
/secure-build
/authz-review
/verify-fix
/ship-check
```

`/api-discovery`, the former name of `/source-intelligence`, still works.

## Enterprise agent-instructions block

For organization-wide agent instructions, use a block like this and pair it with a configured NightVision MCP server. Put it in the instructions file your agent actually reads: `CLAUDE.md` for Claude Code, `AGENTS.md` for Codex and Cursor. Claude Code does not read `AGENTS.md`, so if you already keep one, add `@AGENTS.md` inside `CLAUDE.md` rather than maintaining the text twice. Do not put shared NightVision credentials in this block.

This block is written for **unattended enforcement**: a population of developers (including non-technical ones) who build apps with an AI agent and will not think to run security testing themselves. It is phrased as a completion gate, not a suggestion, and it closes the loop so results reach a person even though nobody will ask for them. Pre-set `NIGHTVISION_DEFAULT_PROJECT` (and the CLI auth) in the managed MCP server config so the agent never has to ask the developer a NightVision question.

```md
## NightVision Security Workflow (required)

Whenever you create or materially change a web app, API, backend service, route handler, or deployable application, you MUST run a NightVision security scan as part of finishing that work. This is not optional and does not require the developer to ask for it.

Use the NightVision MCP. Prefer `run-app-security-scan`: it handles preflight, Source Intelligence, target create/update, DAST start, scan-ID return, and manifest writing in one call. DAST is the expected outcome; Source Intelligence alone is not enough.

To make the scan actually run, do the work the developer will not:
1. Start the app you just built or changed (use its own run command) so it is reachable locally, then pass that URL as `target_url`. If you cannot start it, say so as a concrete blocker.
2. Let `run-app-security-scan` detect the language, discover APIs from source, create/update the target, and start DAST. Most apps are local or internal; rely on NightVision Smart Proxy behavior rather than assuming the app is public.
3. Do not end your turn on an unfinished scan. Because the developer will not come back to check, either wait for the scan to reach a terminal status, or poll `wait-for-scan`/`get-scan-status` until it does, then `summarize-scan-findings` and export SARIF. Keep the MCP server running for local/private scans so the relay stays alive while the scan runs.

Auth: every NightVision action runs under the developer's own NightVision account configured in the managed MCP server. Never use shared tokens and never ask the developer to paste a token anywhere. For target-application login: use a NightVision app auth profile via `auth`/`auth_id`; for username/password or expiring sessions use Playwright script auth; use header/cookie auth only for stable, non-expiring credentials; otherwise run `no_auth: true` and note that coverage may be limited.

Completion contract: work on a new or materially changed app is not complete until either `.nightvision/manifest.json` exists with a NightVision DAST scan ID, or you have stated the exact blocker that prevented DAST (app would not start, no project, not authenticated, target unreachable). A terminal `FAILED` scan can still contain valid findings, so check issue counts and export/summarize before treating a run as unusable. Report the scan ID, the top findings, and the artifact paths to the developer. Never claim an app was scanned, secured, or free of vulnerabilities unless NightVision results support it.
```

> Trigger reliability note: an agent-instructions rule makes the agent scan reliably in the common case, but it is probabilistic, not guaranteed, on every single turn. In Claude Code, turn on the plugin's enforcement mode (below) so a Stop hook reminds the agent when changed app source has no scan since the change. For hard enforcement across a fleet, add a CI check that fails the build when a new or changed app has no `.nightvision/manifest.json` with a scan ID. The block above is what makes the agent do the right thing; the hook and CI check are what back it up.

## Hooks (Claude Code)

The plugin ships two hooks in `hooks/`. They need only `bash` and `git`, run no NightVision command other than `nightvision version`, and never fail a session.

- **SessionStart** adds a short note to every session: follow `secure-build` while writing app code, and offer `ship-check` before calling an app done. It also warns when the NightVision CLI is missing or older than the supported minimum, so the agent can say so before a scan fails.
- **Stop** does nothing unless enforcement mode is on. In enforcement mode, when the agent is about to finish a turn in a git repository where application source changed during the session (uncommitted, or committed during the session) and the app holding that source has no NightVision scan recorded since the change, it asks the agent to run `ship-check`, or to say in one line why a scan does not apply or cannot run. A scan is recorded in the app's `.nightvision/` directory: `manifest.json` from `run-app-security-scan`, or `retest.json` from a `verify-fix` retest. Each changed file is checked against the nearest `.nightvision/` directory above it, so in a monorepo a scan of one app does not cover another. It asks once per set of changes, so the agent is never stuck in a loop, though a new round of edits can be asked about again; it is a reminder, not a hard gate. With enforcement on, the SessionStart hook also records when each session started, in the plugin's data directory, so files that were already uncommitted before the session are ignored.

### Enforcement mode for an organization

Set `NIGHTVISION_ENFORCE=1` to make `ship-check` required rather than offered, and to turn on the Stop hook. To set it for every developer, put it in Claude Code's managed settings along with the marketplace and plugin, so the plugin is installed and enforcing without each developer doing anything:

```json
{
  "env": {
    "NIGHTVISION_ENFORCE": "1"
  },
  "extraKnownMarketplaces": {
    "nvsecurity": {
      "source": { "source": "github", "repo": "nvsecurity/claude-marketplace" }
    }
  },
  "enabledPlugins": {
    "nightvision@nvsecurity": true
  }
}
```

Managed settings live at `/Library/Application Support/ClaudeCode/managed-settings.json` on macOS, `/etc/claude-code/managed-settings.json` on Linux and WSL, and `C:\Program Files\ClaudeCode\managed-settings.json` on Windows, or are delivered by MDM. Pair this with the agent-instructions block above and a managed NightVision MCP server config that pre-sets `NIGHTVISION_DEFAULT_PROJECT`, so every app built with the agent lands in one NightVision project the AppSec team can see.

The hooks are written for Claude Code. Codex, Cursor and other tools load the skills but not these hooks; use the agent-instructions block there.

## Structure

```
nightvision-skills/
├── .claude-plugin/
│   └── plugin.json
├── hooks/
│   ├── hooks.json
│   ├── session-start.sh
│   └── stop-gate.sh
├── skills/
│   ├── api-discovery/
│   │   └── SKILL.md
│   ├── app-security-scan/
│   │   └── SKILL.md
│   ├── source-intelligence/
│   │   ├── SKILL.md
│   │   └── references/
│   ├── ci-cd-integration/
│   │   ├── SKILL.md
│   │   └── references/
│   ├── scan-configuration/
│   │   └── SKILL.md
│   ├── scan-report/
│   │   └── SKILL.md
│   ├── scan-triage/
│   │   ├── SKILL.md
│   │   └── references/
│   ├── secure-build/
│   │   └── SKILL.md
│   ├── authz-review/
│   │   └── SKILL.md
│   ├── verify-fix/
│   │   └── SKILL.md
│   └── ship-check/
│       └── SKILL.md
├── README.md
└── LICENSE
```

The `skills/` directory is the portable, tool-neutral asset. `.claude-plugin/plugin.json` is the Claude Code plugin manifest and `hooks/` holds its Claude Code hooks; other agents ignore both and load the skill folders directly.

## Contributing

Contributions are welcome! Please open an [issue](https://github.com/nvsecurity/nightvision-skills/issues) or submit a pull request.

## License

Apache License 2.0 — see [LICENSE](LICENSE) for details.
