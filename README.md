# NightVision Skills Plugin

Skills for working with [NightVision](https://www.nightvision.net), a white-box-assisted DAST platform that combines API Discovery, dynamic scanning (ZAP + Nuclei), and Code Traceback to find exploitable vulnerabilities in web applications and REST APIs.

## Installation

**From the terminal:**

```bash
claude plugin marketplace add nvsecurity/skills
claude plugin install nightvision@nvsecurity
claude
```

**From inside Claude Code:**

```
/plugin marketplace add nvsecurity/skills
```
```
/plugin install nightvision@nvsecurity
```

> You may need to restart Claude Code for the plugin to load.

## Available Skills

| Skill | Description |
|-------|-------------|
| `scan-configuration` | Configure NightVision DAST scans (targets, authentication, projects, scope exclusions, private network scans) |
| `scan-triage` | Interpret and act on NightVision scan results (SARIF/CSV findings, severity prioritization, remediation, false positive handling) |
| `api-discovery` | Extract OpenAPI specs from source code using NightVision API Discovery (static analysis, Code Traceback, spec diffing) |
| `ci-cd-integration` | Integrate NightVision DAST scanning into CI/CD pipelines (GitHub Actions, GitLab CI, Azure DevOps, Jenkins, BitBucket, JFrog) |

## Usage

Skills are invoked using slash commands in Claude Code:

```
/scan-configuration
/scan-triage
/api-discovery
/ci-cd-integration
```

Or Claude will automatically use relevant skills based on context.

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

## License

Apache License 2.0 — see [LICENSE](LICENSE) for details.
