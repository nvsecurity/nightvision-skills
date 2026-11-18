# <TASK_ID> - <one-line task title> (<EPIC> task, ticket <TICKET>)

Role: implementation agent. Repo(s): `<REPO>` at `<ABS_REPO_PATH>`. Branch: `<BRANCH>`
(work on it; do not branch; head `<HEAD_SHA>`). Ship under **<TICKET>**. One commit per touched repo.

## Constraints to carry (verbatim)
<Paste the domain's security/trust constraints verbatim here. Keep the report and the progress log
to non-sensitive values only.>

## What this task is (structural)
<2-6 sentences describing what changes, in structural terms: the shape, not a narrative.>

## The change (lines may have drifted - confirm by reading)
File: `<ABS_PATH>`
- `<symbol>` (~:<line>): <what changes>. <what stays byte-for-byte unchanged>.
- ...
File: `<ABS_PATH>`
- ...

## Out of scope (do NOT touch)
- <the parts belonging to adjacent tasks, named>
- <shipped or other-repo pieces this task only produces/consumes>
- <migration/schema, if none is needed>

## Acceptance (each must fail before the change)
In `<test files>` (place each where its fixtures fit; follow repo conventions; assert on
non-sensitive values only):
- `<test_name>` (<what it pins>);
- ...
Prove RED (fails before) -> GREEN (passes after) for each. If an existing test's premise genuinely
changes, update it and list it in the report; do not silently drop coverage.

## Conventions
- <repo conventions: fmt / lint / test commands, line length, ASCII, migrations, the repo's own
  testing skills>.
- Keep the suite green on its own.

## Report contract (IMPLEMENTATION ONLY - a separate process ships)
On pickup, CREATE `<ABS_PROMPTS_DIR>/<TASK_ID>-impl-report.md` and set the top `**Status: ...**`
line to `**Status: IN PROGRESS: picked up (<local time>)**` first, then keep it live with a
`## Progress` log of timestamped one-liners (plan, RED, GREEN, lint, suite). Under the status line
record: files touched (absolute, new vs modified), the delta, the RED->GREEN proof per acceptance
test, any existing test whose premise changed, and any JUDGMENT CALL you did NOT decide (flag it; do
not decide a design change yourself). Keep the report to non-sensitive values.

**Your lane is implementation only:**
- What you do: implement, write the tests, run them green, keep the report live.
- What you do NOT do: commit, push, run reviews, or touch the tracker.
- When green, set the status line to exactly `**Status: DONE, awaiting fix batch (<local time>)**`.
  - Standing agent: then POLL the prompts dir for `<TASK_ID>-*-fix.md`.
  - Spawned subagent: then STOP and return a concise summary to the caller; do NOT poll.
  A separate shipping process commits under <TICKET>, runs the reviews, may send a
  `<TASK_ID>-*-fix.md` batch (apply it, flip to `**Status: FIX BATCH n IN PROGRESS (<time>)**`, then
  back to `DONE, awaiting fix batch`), runs the full suite, pushes, moves the tracker, and sets the
  terminal `**Status: DONE, shipped by the driver (<local time>). Next: <NEXT_TASK>**`. Do NOT set
  that terminal line yourself.

If an owner-level design decision is needed that you must not make, set instead
`**Status: BLOCKED on owner: <one-line question>**` with the full question in the report body.
If a safeguard blocks the WORK itself, set `**Status: BLOCKED: <why>**` and stop.
