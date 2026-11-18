---
name: chain-attacks
description: Find and reproduce multi-step business-logic vulnerabilities (vuln chains) in a web app or API, where each request is individually allowed but the ordered combination across steps or sessions breaks a business rule. Use after adding a multi-step flow (checkout, invite/accept, approval/publish, password reset, refund), when a user asks "can a sequence of allowed requests reach a forbidden state", to test business-logic or chained vulnerabilities, or as part of ship-check. Non-destructive and dev-only: it never takes a state-changing action and runs only against an app the developer owns.
allowed-tools: Bash, Read, Grep, Glob, mcp__nightvision__list-targets, mcp__nightvision__get-target-details, mcp__nightvision__get-scan-paths, mcp__nightvision__get-vulnerable-paths, mcp__nightvision__list-issues, mcp__nightvision__list-additional-paths
---

# NightVision Chain Attacks

Scanners and humans both struggle with the same bug: a flaw where every single request is allowed, but the ordered combination of requests, sometimes across two sessions, reaches a state the business rules forbid. You cannot find it one request at a time. It takes holding a hypothesis across many requests and reading each response to shape the next one: mint a token in tenant A's flow and spend it in tenant B's session, mark an order shipped without ever paying, replay a one-time reset token, let a price set in step one be trusted by step five. This skill builds a model of the app, derives those hypotheses from a fixed taxonomy, and runs each one as a scripted ordered sequence with a legitimate-actor control, so a chain is reported only when it actually reproduces.

**Relationship to `authz-review`.** `authz-review` asks "can user B touch user A's object in one request": single-request, object-level and function-level access control. `chain-attacks` asks the harder question: "can a sequence of individually-allowed requests, possibly across two sessions, reach a state the business rules forbid." It reuses the actor and object model `authz-review` builds and goes beyond it to sequences, state machines, and values that flow from one step into the next. Run `authz-review` first; its single-request gaps are the cheaper find, and its model is the starting point here.

What this is and is not: it is a code review plus ordered, non-destructive probes run against an environment the developer owns. It is not a NightVision scan result. Report what you find as CODE REVIEW findings, never as NightVision findings, and never claim a flow is safe because this skill did not flag it.

**Portability.** The executable core is just Bash, `curl`, and reading source files, so it runs on any agent and any model (Codex included), with no dependency on the NightVision MCP tools or any Claude-only feature. The `allowed-tools` line lists the NightVision read tools, but every step works without them: they are optional enrichment for an agent that has the NightVision MCP wired up, never a requirement. Lead with the portable path everywhere (an OpenAPI spec from the `nightvision openapi extract` CLI, or reading routers and controllers directly).

## The non-destructive rule (read this first)

**Never perform a destructive or state-changing action to prove a chain.** No refund, no delete, no role grant, no publish, no status change, no money movement, no token consumption, not even against data the agent seeded itself. There is no exception for "it is only my own test data": the point of this skill is to prove reachability safely, and a half-run chain that already moved money is not a cleaner result than one stopped one step short.

Reads are fine. Safe idempotent probes that do not change state are fine (a GET that reveals whether an authorization check passes, re-fetching a token's status, reading the current state of an object). Creating throwaway data is the developer's call to describe in their own setup, not the agent's to do on its own initiative.

**This binds the control run too.** The benign baseline exists to show how the app behaves when used correctly, not to license a destructive action because it is "the intended one." Establish it by reading developer-seeded state wherever you can. Any benign step you do run must itself be non-destructive: no money movement, no deletion, no role or permission grant, no publish or fulfillment, no outbound send of real data. When the benign path's completion would require one of those, read a developer-seeded example that already reached that state instead of performing it.

When a chain can only be *confirmed* by taking a state-changing action, **stop one step short and report it as "reachable, not executed."** Give:

- the exact next request you did NOT send: method, path, body, and which session it would run as;
- the evidence that the forbidden step is reachable: the authorization check already passed on a safe read, the state precondition is already met, the one-time token is still valid on a status read, the server already echoed the attacker-controlled value back;
- why you stopped: naming the state change the request would cause.

A "reachable, not executed" finding is a real finding. It is reported with the same weight as a reproduced one; the only difference is the last request is left for the developer to send in their own environment if they want the final confirmation.

## Safety and scope

- **The developer's own local or dev app only.** Never production. Never a shared, staging, or customer environment. Confirm the target host is one the developer owns before sending a single request, and say so in the report.
- **Sessions come from the developer, never created by the agent.** You need up to four: anonymous, ordinary user A, ordinary user B (a second tenant or account), and a privileged/admin user. The developer supplies these as bearer tokens or cookie jars. Never create accounts in, or point the test at, an environment the developer does not own.
- **Findings are CODE REVIEW, not NightVision findings.** Never claim a flow is safe because this skill did not flag it; it tests the hypotheses the model suggested, not every possible sequence.

## Workflow

1. **Build a model of the app.** From source plus the NightVision endpoint inventory, write down:
   - **Actors** and how to get a session for each (anonymous, user A, user B in a second tenant, admin). Record which token or cookie jar maps to each. Sessions come from the developer.
   - **Objects** and their owner or tenant fields (`owner_id`, `tenant_id`, `org_id`), so you know what "belongs to A" means.
   - **Multi-step flows** and their intended step order: checkout/payment, invite/accept, approval/publish, password reset, onboarding, refund, order fulfillment. Record the order the steps are *supposed* to run in, and what server-side state each step is supposed to require before it runs.
   - **Capability endpoints**: anything that refunds, grants a role, changes a price, changes status, transfers ownership, consumes a one-time token, or triggers an outbound fetch. These are the steps a chain is trying to reach.
   For the endpoint inventory, lead with the portable path: an OpenAPI spec from `nightvision openapi extract` (which writes `openapi-spec.yml`, every operation with its source `file:line`), or read the routers and controllers directly, or generate a spec with the `source-intelligence` skill. If your agent has the NightVision MCP wired up, the read-only tools in `allowed-tools` (list-targets, get-scan-paths, list-issues, and the rest) can enrich the model, but nothing here requires them. Reuse `authz-review`'s actor/object work rather than redoing it.
2. **Derive attack hypotheses from the fixed taxonomy.** For each flow and capability endpoint in the model, walk the six classes in `references/attack-taxonomy.md` and write down every candidate: which flow, which class, and the exact ordered sequence you would run. Do not invent classes; the taxonomy is the checklist.
3. **Run each hypothesis with a legitimate-actor control.** For every candidate, in order:
   - **Control run first.** Run the benign path as the actor who is *supposed* to run it, and record the expected responses (status and the response field that proves each step).
   - **Attack run second.** Run the attack sequence (reordered, cross-session, replayed, or tampered per the class) and capture the same fields.
   - **Compare.** A chain is a finding only when the attack sequence reproduced the forbidden state AND the control shows the benign path behaves differently. If the "attack" gets the same refusal the benign path would, it is not a finding; say so and move on.
   - **Stop short of any state change** per the non-destructive rule, and report that candidate as "reachable, not executed" with its evidence.
   The two-session harness and a worked control-then-attack example are in `references/attack-taxonomy.md`.
4. **Report only reproduced or reachable chains.** Each with the exact ordered requests so the developer can rerun it. Drop the hypotheses that did not pan out (a one-line note that you tried the class and the control matched is enough).

## The taxonomy

Six classes, each a named subsection in `references/attack-taxonomy.md` with what it is, how to recognize candidate flows from the model, and the exact ordered test:

- **Cross-tenant object chains**: carry an ID or token minted in tenant A's flow into tenant B's session mid-sequence.
- **State-machine step-skips**: reach step N without completing N-1 (mark an order paid or shipped without the pay step; publish without approval).
- **One-time-action replay**: replay a single-use token, coupon, invite, or signature; double-spend; reuse a consumed reset token.
- **Value tampering carried across steps**: a price, quantity, discount, or role set in an early step and trusted by a later step; TOCTOU between validate and commit.
- **Privilege-escalation chains**: a sequence of low-privilege actions that together grant higher privilege (self-invite to an org, then accept as admin).
- **Confused-deputy / SSRF-in-a-flow**: make the server act on an attacker-chosen target during a flow (webhook URL, import-from-URL, callback).

The reference file carries the detailed recipe for each, and repeats the non-destructive stop-short handling on the classes that would otherwise tempt a state change (refund replay, role grant, delete-based proofs). Read it before running step 2.

## Reporting format

Report CODE REVIEW findings. For each reproduced or reachable chain:

```
Chain: <short name> (<taxonomy class>)
Target: <host> (confirmed dev/local, owned by developer)
Flow: <the business flow and the rule it breaks>
Status: REPRODUCED | REACHABLE, NOT EXECUTED (stopped before <state change>)

Control run (benign path, as <intended actor>):
  1. <METHOD> <path>  [session: <actor>]  -> <status>, <proving field>=<value>
  ...
  Result: <what the benign path correctly does>

Attack run (as <attacker sessions>):
  1. <METHOD> <path>  [session: <actor>]  -> <status>, <proving field>=<value>
  2. <METHOD> <path>  [session: <actor>]  -> <status>, <proving field>=<value>
  ...
  Result: <the forbidden state reached, or the exact next request NOT sent and why>

Evidence: <the response field(s) that prove it, and for reachable-not-executed, why the next step is reachable>
Code: <file:line of the missing check, if found>
```

List REPRODUCED chains first, then REACHABLE-NOT-EXECUTED. End with a one-line note of the classes you tried where the control matched the attack (no finding), so the developer knows what was covered.

## Related skills

`authz-review` covers single-request object-level and function-level access control and builds the actor/object model this skill reuses. `secure-build` covers the business-logic rules to follow while writing the code. `ship-check` runs this review as part of finishing an app. `app-security-scan` runs a NightVision DAST scan of the running app.
