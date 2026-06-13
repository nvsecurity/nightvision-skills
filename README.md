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
[![NightVision](https://img.shields.io/badge/NightVision-DAST-orange)](https://www.nightvision.net)

</div>

---

[NightVision](https://www.nightvision.net) is a white-box-assisted DAST platform that combines **API Discovery** (static analysis to extract OpenAPI specs from source code), **dynamic scanning** (ZAP + Nuclei engines), and **Code Traceback** (tracing vulnerabilities back to exact source locations) to find exploitable vulnerabilities in web applications and REST APIs.

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
| **`scan-configuration`** | Set up DAST scans — create targets, configure authentication (Playwright, headers, cookies), manage projects, define scope exclusions, and prepare private network scans |
| **`scan-triage`** | Interpret scan results — read SARIF/CSV findings, understand vulnerabilities, locate the vulnerable code, validate with curl, prioritize by severity, suggest fixes, and mark false positives |
| **`api-discovery`** | Extract OpenAPI specs from source code via static analysis, troubleshoot extraction issues, compare specs across versions, and leverage Code Traceback |
| **`ci-cd-integration`** | Wire NightVision into your pipeline — GitHub Actions, GitLab CI, Azure DevOps, Jenkins, BitBucket, and JFrog with SARIF/CSV export and breaking-change detection |

### Example Usage

Just ask your agent what you need:

```
> Set up a NightVision scan for my API running on localhost:8080

> Triage the results from my last scan and suggest fixes

> Add NightVision to my GitHub Actions workflow

> Extract an OpenAPI spec from this Django project
```

In Claude Code, invoke skills directly with slash commands:

```
/scan-configuration
/scan-triage
/api-discovery
/ci-cd-integration
```

## Structure

```
nightvision-skills/
├── .claude-plugin/
│   └── plugin.json
├── skills/
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
