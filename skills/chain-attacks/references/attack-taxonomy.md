# Chain Attack Taxonomy and Harness

Detailed recipes for the six chain classes, plus a reusable two-session sequence harness. Read the non-destructive rule in `SKILL.md` before running anything here. It is restated in the classes that would otherwise tempt a state change (refund replay, role grant, delete-based proofs), and it wins every time: when a chain can only be confirmed by changing state, stop one step short and report it as "reachable, not executed."

Every example below is non-destructive. Where the final proof would require a state change, the example stops on a safe read and shows what to report instead.

## Endpoint inventory source

This step is fully portable: it needs only the CLI and reading source, no MCP tools. Lead with `nightvision openapi extract`, which writes `openapi-spec.yml` with every operation and its source `file:line`. Otherwise read the routers or controllers directly, or generate a spec with the `source-intelligence` skill. If a `run-app-security-scan` already ran and your agent has that output, the spec path is `api_discovery.attached_spec_file` in `.nightvision/manifest.json`, and an agent with the NightVision MCP wired up can pull the inventory from the read-only `list-targets` / `get-scan-paths` tools; both are optional enrichment, never required. The attack sequences in this skill are executed by the agent with `curl`, not through a NightVision scan.

## The two-session harness

A small bash scaffold that runs a request as a chosen session and captures status plus body, so a sequence reads as a list of labeled steps. It takes two bearer tokens (or two cookie jars) from the environment: the developer supplies these for two ordinary accounts they own. Extend `SESSIONS` with an admin token when a class needs one. Never put a production host in `BASE`, and never create the accounts yourself.

```bash
#!/usr/bin/env bash
# chain-harness.sh - run ordered requests as chosen sessions, capture status + body.
# Non-destructive by policy: see SKILL.md. Do not add a step that changes state to "confirm" a chain.
set -u

BASE="${BASE:?set BASE to the developer-owned dev/local host, never production}"

# Sessions supplied by the developer. Bearer-token form; swap in cookie jars if the app uses cookies.
declare -A SESSIONS=(
  [anon]=""
  [A]="${USER_A_TOKEN:?set USER_A_TOKEN}"
  [B]="${USER_B_TOKEN:?set USER_B_TOKEN}"
  [admin]="${ADMIN_TOKEN:-}"
)

# req <session> <method> <path> [json-body]
# Prints "HTTP <status>" then the body. Captures the last body in $LAST_BODY for value flow.
LAST_BODY=""
req() {
  local sess="$1" method="$2" path="$3" body="${4:-}"
  local token="${SESSIONS[$sess]:-}"
  local -a args=(-s -w $'\n__STATUS__%{http_code}' -X "$method" "$BASE$path")
  [ -n "$token" ] && args+=(-H "Authorization: Bearer $token")
  if [ -n "$body" ]; then
    args+=(-H "Content-Type: application/json" --data "$body")
  fi
  echo ">> [$sess] $method $path" >&2
  local out status
  out="$(curl "${args[@]}")"
  status="${out##*__STATUS__}"
  LAST_BODY="${out%$'\n'__STATUS__*}"
  echo "   HTTP $status" >&2
  printf '%s' "$LAST_BODY"
}

# jget <json-path-ish>  - pull a field from $LAST_BODY (requires jq). e.g. jget '.id'
jget() { printf '%s' "$LAST_BODY" | jq -r "$1"; }
```

Notes:
- With cookie-based auth, replace the token header with `-b jarA.txt` / `-b jarB.txt` per session; the developer supplies the jars from a real login.
- `req` only ever reads or sends the body the recipe specifies. It has no "force" or "confirm" mode. Keep it that way.
- For idempotent safe probes, prefer GET/HEAD and status-only reads. Those are allowed. State-changing verbs (POST/PUT/PATCH/DELETE against a capability endpoint) are the line: run them in the control path as the intended actor, but in the attack path stop before the one that changes state.

## Worked example: state-machine step-skip (control, then attack, then compare)

Flow from the model: an order must be `created -> paid -> shipped`. The pay step is supposed to be the only thing that moves an order to `paid`, and only a `paid` order can ship. Hypothesis: a client can PATCH the order straight to `paid` (or `shipped`), skipping payment.

Marking an order paid or shipped is a state change. So the attack run proves the step is *reachable* on a safe read and stops before the PATCH that would move money or fulfillment. The control run does not perform the pay either: it reads a developer-seeded order that already reached `paid` the real way, so we learn what a correctly-paid order looks like without moving money (see the non-destructive rule, which binds the control run too).

```bash
source ./chain-harness.sh

echo "=== CONTROL: what a correctly-paid order looks like (reads only) ==="
# The developer seeds one order that reached 'paid' through the real pay step and gives its id.
# Read it; do not run the pay yourself, that is money movement.
req A GET "/api/orders/$SEEDED_PAID_OID" >/dev/null
echo "control: a legitimately paid order = status $(jget '.status'), payment $(jget '.payment_id')"  # expect: paid, with a real payment record

echo "=== ATTACK: try to reach 'paid' without the pay step ==="
# A developer-seeded order still in 'created' state (unpaid); the developer supplies its id.
AID="$SEEDED_UNPAID_OID"
req A GET  "/api/orders/$AID" >/dev/null
echo "attack: seeded unpaid order status = $(jget '.status')"  # expect: created

# SAFE PROBE ONLY: does the status-transition endpoint accept our call at all?
# Many apps answer a bad transition with 200 (bug) vs 403/409 (enforced) on a dry read,
# or expose a validation/preview route. Use whichever safe read the app offers.
req A GET "/api/orders/$AID/transitions" >/dev/null
echo "attack: transitions offered to a 'created' order = $(jget '.')"
```

Compare and decide:
- If the transitions probe (or the order's own fields) shows `shipped`/`paid` is offered to a `created` order with no payment, the forbidden step is **reachable**. The next request would be `PATCH /api/orders/$AID {"status":"paid"}` (or `.../ship`), run as A. Do NOT send it: it changes order state and would move fulfillment.
- Report: REACHABLE, NOT EXECUTED. Evidence: the seeded legitimately-paid order carries a real payment record, while the attack order was offered the `paid`/`shipped` transition directly with status still `created` and no payment record. Next request not sent: `PATCH /api/orders/$AID {"status":"paid"}` as A, because it marks an unpaid order paid.
- If instead the probe returns the same `409 invalid transition` the control would hit without paying, there is no finding: note "state-machine step-skip tried on orders, control matched, enforced."

## Stop-short example: one-time-action / refund replay

Flow: a refund consumes a one-time `refund_token` tied to a payment, and the token is single-use. Hypothesis: the token can be replayed to refund twice (double refund), or a token minted for payment X can be spent on payment Y.

A refund moves money. Never send it, in either the first or the replayed form, even against seeded test data. Prove reachability with reads only:

```bash
source ./chain-harness.sh

echo "=== CONTROL: inspect a legitimately issued refund token (no refund sent) ==="
# The developer's setup issues a refund_token for a test payment; read its status.
req A GET "/api/payments/$PAY/refund-token" >/dev/null
RT="$(jget '.token')"
req A GET "/api/refund-tokens/$RT" >/dev/null
echo "control: token single_use=$(jget '.single_use') consumed=$(jget '.consumed') bound_payment=$(jget '.payment_id')"

echo "=== ATTACK: is the token replayable / cross-bindable? (reads only) ==="
# After one legitimate refund in the developer's own records, re-read the token's state.
req A GET "/api/refund-tokens/$RT" >/dev/null
echo "attack: after one use, consumed=$(jget '.consumed')"   # still false => replayable
# Cross-binding: does payment Y accept a validity check against token minted for X?
req A GET "/api/payments/$OTHER_PAY/refund-token/validate?token=$RT" >/dev/null
echo "attack: token valid against a different payment? $(jget '.valid')"
```

Decide and report:
- If `consumed` stays `false` after a use, or the validate probe says the token is valid against a payment it was not minted for, the replay/cross-spend is **reachable**. Next request NOT sent: `POST /api/payments/$OTHER_PAY/refund {"token":"'$RT'"}` as A. Report REACHABLE, NOT EXECUTED, stopped before the refund, with the token-status reads as evidence.
- Never send the refund to "confirm." A single reachable-not-executed finding with the token still valid is the deliverable.

## The six classes

Each class: what it is, how to recognize candidate flows from the model, the exact ordered test, and (where relevant) the stop-short handling.

### 1. Cross-tenant object chains

**What it is.** An ID, token, or reference minted inside tenant A's flow is carried into tenant B's session partway through a sequence, so B acts on or pulls in A's object. Single-request IDOR is `authz-review`'s job; this is the multi-step version, where the ID is produced by one step and consumed by a later step under a different session.

**Recognize it.** In the model, any flow whose step emits an ID or handle that a later step accepts (a cart ID, an upload handle, a draft ID, a signed URL, a job ID), combined with objects that have `tenant_id`/`org_id`. Candidate wherever step K returns something step K+1 takes as input.

**Ordered test.**
1. Control: run the whole flow as A, end to end, and record the emitted ID and the final legitimate result.
2. Attack: run the early step as A to mint the ID, then run the consuming step as B (same request shape, A's ID) and read the result.
3. Compare: finding if B's consuming step accepts A's ID and returns or links A's data, where the control shows the ID only ever belongs to its minting tenant. If B gets 403/404 as the control-for-B would, enforced.

**Stop short** if the consuming step would change state (B attaching A's object, B submitting with A's handle). Prove B *can read/select* A's ID into the flow (the step echoes it back, a preview shows A's object), then report the state-changing submit as the next request not sent.

### 2. State-machine step-skips

**What it is.** Reaching step N of an ordered flow without completing N-1: mark an order paid/shipped without paying, publish without approval, activate without verification, complete onboarding without the gating step.

**Recognize it.** Any flow in the model with a recorded intended order and a server-side precondition on a later step. Candidate for every "step X is supposed to require state Y first."

**Ordered test.**
1. Control: run the benign path in order as the intended actor; record that the later step's precondition was met by the earlier step.
2. Attack: reach the later step directly (call it, or PATCH the status field) on an object that has NOT completed the prior step.
3. Compare: finding if the later state is offered/accepted without the precondition, where the control needed the earlier step. See the worked example above.

**Stop short:** the later step is usually the state change (ship, publish, activate). Prove it is offered to an object in the wrong state with a safe transitions/preview read, and report the transition request as not sent. Worked example above.

### 3. One-time-action replay

**What it is.** Replaying something meant to be used exactly once: a reset token, invite, coupon, nonce, idempotency key, or signature. Double-spend a coupon; reuse a consumed password-reset token; replay a signed request.

**Recognize it.** Every single-use artifact in the model: password reset, email verification, invite acceptance, discount codes, webhook signatures with a nonce, "idempotency-key" headers.

**Ordered test.**
1. Control: use the artifact once through the intended flow as the intended actor; confirm it works and the artifact is now marked consumed (read its status).
2. Attack: read the artifact's status again after the one use; if still valid, the replay is reachable.
3. Compare: finding if the artifact is reusable where the model says single-use. Prefer the status read over actually replaying.

**Stop short:** the replay itself (second reset, second coupon redemption, second refund) is the state change. Confirm reusability from the artifact's status (`consumed=false` after a use, or a validity probe still returning valid) and report the replay request as not sent. Refund-replay worked example above.

### 4. Value tampering carried across steps

**What it is.** A value established in an early step (price, quantity, discount, currency, role, tier) is trusted by a later step instead of being re-derived server-side. Includes TOCTOU: a value validated in one step is mutated before the commit step reads it again.

**Recognize it.** Flows where an early step stores a value the client influenced and a later step acts on the stored value: cart price frozen at add-to-cart, a quote total reused at checkout, a role chosen at invite time trusted at accept time, a discount validated then applied later.

**Ordered test.**
1. Control: run the flow normally; record the value the later step uses and that it matches a server-derived expectation.
2. Attack: set or mutate the value in the early step (tamper the price/qty/discount in the add/validate call), then read what the later step *would* commit (an order summary, a checkout preview, a confirmation GET).
3. Compare: finding if the later step reflects the tampered value, where the control re-derives it. TOCTOU variant: validate with a good value, change the underlying record, then re-read the commit step's view.

**Stop short:** the commit step (place order, finalize, charge) is the state change. Prove the tampered value survives to the commit *preview/summary* with a read, and report the commit request as not sent.

### 5. Privilege-escalation chains

**What it is.** A sequence of individually-low-privilege actions that together grant higher privilege. No single step is admin-only, but their combination is: self-invite to an org and accept into an admin role, create a resource then transfer ownership to yourself, chain a profile update into a role field.

**Recognize it.** In the model, any pair of actions where one produces something (an invite, a pending membership, an ownership handle) that another consumes to raise a role or cross into another org. Capability endpoints that grant roles, transfer ownership, or accept memberships are the targets.

**Ordered test.**
1. Control: run the legitimate version as the actor who is allowed to (an admin invites, the invitee accepts at the intended role); record the resulting role.
2. Attack: run the low-privilege steps yourself (self-issue the invite, or craft the accept with an elevated role field), and read what role the account *would* hold.
3. Compare: finding if the chain reaches a higher role than any single step should grant, where the control required an admin.

**Stop short (role grant):** actually accepting into the elevated role is the state change. Prove the accept step *offers* the elevated role (the accept preview or the invite record shows `role=admin` accepted from a self-issued invite, the authorization check passes on a safe read), and report the accept/grant request as the next request not sent. Never grant the role to confirm.

### 6. Confused-deputy / SSRF-in-a-flow

**What it is.** Making the server act on an attacker-chosen target during a multi-step flow: a webhook URL, import-from-URL, avatar-fetch, callback, or PDF-render that the server fetches or posts to. The attacker controls the destination in an early step and the server reaches it in a later step.

**Recognize it.** Every endpoint in the model that takes a URL, hostname, or callback the server later contacts: webhook registration, "import from URL," remote media fetch, SSO callback URL, outbound notification config.

**Ordered test.**
1. Control: set the target to a legitimate value and confirm the server contacts it as intended (read the delivery/log record if the app exposes one).
2. Attack: set the target in the early step to an attacker-chosen destination the developer controls and can observe (a logging endpoint on the dev host, a request-capture URL the developer owns), then trigger the later step and read whether the server dispatched to it.
3. Compare: finding if the server will fetch/post to the attacker-chosen target where the control used a validated one. Use a destination the developer owns and can watch; never point it at a third party.

**Stop short:** if triggering the fetch would itself cause a state change (sending a real webhook with live data, importing into the account), prove the target was *accepted and stored* for dispatch with a read of the config, and report the trigger as the next request not sent. If the fetch is a harmless GET to a developer-owned capture endpoint, that read-only dispatch is allowed as evidence; anything that posts real data or mutates the account is not.

## Closing rule

Across all six classes: the control run exists to prove the benign path behaves differently, so a refusal that the benign path would also get is never a finding. Report only chains where the attack reproduced the forbidden state or left it reachable one safe step away, and leave every state-changing final request for the developer to send in their own environment.
