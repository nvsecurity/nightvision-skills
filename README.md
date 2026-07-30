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

[NightVision](https://nightviz.ai) is a developer-first DAST and API security platform. It dynamically tests running web applications and APIs, discovers REST endpoints from supported source code, and connects validated findings to source locations when that context is available.

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
| **`scan-configuration`** | Set up DAST scans — create targets, configure authentication (Playwright, headers, cookies), manage projects, define scope exclusions, and prepare private network scans |
| **`scan-triage`** | Interpret scan results — read SARIF/CSV findings, understand vulnerabilities, locate the vulnerable code, validate with curl, prioritize by severity, suggest fixes, and mark false positives |
| **`api-discovery`** | Extract OpenAPI specs from source code via static analysis, troubleshoot extraction issues, compare specs across versions, and leverage Code Traceback |
| **`ci-cd-integration`** | Wire NightVision into your pipeline — GitHub Actions, GitLab CI, Azure DevOps, Jenkins, BitBucket, and JFrog with SARIF/CSV export and breaking-change detection |

### Example Usage

Just ask your agent what you need:

```
> Set up a NightVision scan for my API running on localhost:8080

> Run a NightVision app security scan for this local service

> Triage the results from my last scan and suggest fixes

> Add NightVision to my GitHub Actions workflow

> Extract an OpenAPI spec from this Django project
```

In Claude Code, invoke skills directly with slash commands:

```
/app-security-scan
/scan-configuration
/scan-triage
/api-discovery
/ci-cd-integration
```

## Enterprise agent-instructions block

For organization-wide agent instructions, use a block like this and pair it with a configured NightVision MCP server. Put it in the instructions file your agent actually reads: `CLAUDE.md` for Claude Code, `AGENTS.md` for Codex and Cursor. Claude Code does not read `AGENTS.md`, so if you already keep one, add `@AGENTS.md` inside `CLAUDE.md` rather than maintaining the text twice. Do not put shared NightVision credentials in this block.

This block is written for **unattended enforcement**: a population of developers (including non-technical ones) who build apps with an AI agent and will not think to run security testing themselves. It is phrased as a completion gate, not a suggestion, and it closes the loop so results reach a person even though nobody will ask for them. Pre-set `NIGHTVISION_DEFAULT_PROJECT` (and the CLI auth) in the managed MCP server config so the agent never has to ask the developer a NightVision question.

```md
## NightVision Security Workflow (required)

Whenever you create or materially change a web app, API, backend service, route handler, or deployable application, you MUST run a NightVision security scan as part of finishing that work. This is not optional and does not require the developer to ask for it.

Use the NightVision MCP. Prefer `run-app-security-scan`: it handles preflight, API Discovery, target create/update, DAST start, scan-ID return, and manifest writing in one call. DAST is the expected outcome; API Discovery alone is not enough.

To make the scan actually run, do the work the developer will not:
1. Start the app you just built or changed (use its own run command) so it is reachable locally, then pass that URL as `target_url`. If you cannot start it, say so as a concrete blocker.
2. Let `run-app-security-scan` detect the language, discover APIs from source, create/update the target, and start DAST. Most apps are local or internal; rely on NightVision Smart Proxy behavior rather than assuming the app is public.
3. Do not end your turn on an unfinished scan. Because the developer will not come back to check, either wait for the scan to reach a terminal status, or poll `wait-for-scan`/`get-scan-status` until it does, then `summarize-scan-findings` and export SARIF. Keep the MCP server running for local/private scans so the relay stays alive while the scan runs.

Auth: every NightVision action runs under the developer's own NightVision account configured in the managed MCP server. Never use shared tokens and never ask the developer to paste a token anywhere. For target-application login: use a NightVision app auth profile via `auth`/`auth_id`; for username/password or expiring sessions use Playwright script auth; use header/cookie auth only for stable, non-expiring credentials; otherwise run `no_auth: true` and note that coverage may be limited.

Completion contract: work on a new or materially changed app is not complete until either `.nightvision/manifest.json` exists with a NightVision DAST scan ID, or you have stated the exact blocker that prevented DAST (app would not start, no project, not authenticated, target unreachable). A terminal `FAILED` scan can still contain valid findings, so check issue counts and export/summarize before treating a run as unusable. Report the scan ID, the top findings, and the artifact paths to the developer. Never claim an app was scanned, secured, or free of vulnerabilities unless NightVision results support it.
```

> Trigger reliability note: an agent-instructions rule makes the agent scan reliably in the common case, but it is probabilistic, not guaranteed, on every single turn. For hard enforcement across a fleet, pair this block with a harness-level gate (for example a Stop/PreCompact hook or a CI check) that fails the turn/build when a new or changed app has no `.nightvision/manifest.json` with a scan ID. The block above is what makes the agent do the right thing; the hook is what guarantees it.

## Structure

```
nightvision-skills/
├── .claude-plugin/
│   └── plugin.json
├── skills/
│   ├── app-security-scan/
│   │   └── SKILL.md
│   ├── api-discovery/
│   │   ├── SKILL.md
│   │   └── references/
│   ├── ci-cd-integration/
│   │   ├── SKILL.md
│   │   └── references/
│   ├── scan-configuration/
│   │   └── SKILL.md
│   └── scan-triage/
│       ├── SKILL.md
│       └── references/
├── README.md
└── LICENSE
```

The `skills/` directory is the portable, tool-neutral asset. `.claude-plugin/plugin.json` is the Claude Code plugin manifest; other agents ignore it and load the skill folders directly.

## Contributing

Contributions are welcome! Please open an [issue](https://github.com/nvsecurity/nightvision-skills/issues) or submit a pull request.

## License

Apache License 2.0 — see [LICENSE](LICENSE) for details.
