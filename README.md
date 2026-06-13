<div align="center">

<picture>
    <source media="(prefers-color-scheme: dark)" srcset="assets/nv-icon-dark.png">
    <img alt="NightVision" src="assets/nv-icon.png">
</picture>

# NightVision Skills for Claude Code

**Your best defense is a good offense: Give Claude NightVision skills.**

<br>

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Claude Code](https://img.shields.io/badge/Claude_Code-Plugin-blueviolet)](https://docs.anthropic.com/en/docs/claude-code)
[![NightVision](https://img.shields.io/badge/NightVision-DAST-orange)](https://www.nightvision.net)

</div>

---

[NightVision](https://www.nightvision.net) is a white-box-assisted DAST platform that combines **API Discovery** (static analysis to extract OpenAPI specs from source code), **dynamic scanning** (ZAP + Nuclei engines), and **Code Traceback** (tracing vulnerabilities back to exact source locations) to find exploitable vulnerabilities in web applications and REST APIs.

This plugin gives Claude Code the skills to run NightVision scans, triage results, and integrate security testing into your CI/CD pipelines — all from natural language.

## Installation

**From the terminal:**

```bash
claude plugin marketplace add nvsecurity/claude-marketplace
claude plugin install nightvision@nvsecurity
claude
```

**From inside Claude Code:**

```
/plugin marketplace add nvsecurity/claude-marketplace
```
```
/plugin install nightvision@nvsecurity
```

> You may need to restart Claude Code for the plugin to load.

## Skills

| Skill | What it does |
|:------|:-------------|
| **`scan-configuration`** | Set up DAST scans — create targets, configure authentication (Playwright, headers, cookies), manage projects, define scope exclusions, and prepare private network scans |
| **`scan-triage`** | Interpret scan results — read SARIF/CSV findings, understand vulnerabilities, locate the vulnerable code, validate with curl, prioritize by severity, suggest fixes, and mark false positives |
| **`api-discovery`** | Extract OpenAPI specs from source code via static analysis, troubleshoot extraction issues, compare specs across versions, and leverage Code Traceback |
| **`ci-cd-integration`** | Wire NightVision into your pipeline — GitHub Actions, GitLab CI, Azure DevOps, Jenkins, BitBucket, and JFrog with SARIF/CSV export and breaking-change detection |

### Example Usage

Just ask Claude what you need:

```
> Set up a NightVision scan for my API running on localhost:8080

> Triage the results from my last scan and suggest fixes

> Add NightVision to my GitHub Actions workflow

> Extract an OpenAPI spec from this Django project
```

Or invoke skills directly with slash commands:

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

## Contributing

Contributions are welcome! Please open an [issue](https://github.com/nvsecurity/nightvision-skills/issues) or submit a pull request.

## License

Apache License 2.0 — see [LICENSE](LICENSE) for details.
