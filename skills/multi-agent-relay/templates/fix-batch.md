# <TASK_ID> - fix batch <n>

Apply these on top of the current implementation. Keep the report's status at
`**Status: FIX BATCH <n> IN PROGRESS (<time>)**` while you work, then set it back to
`**Status: DONE, awaiting fix batch (<time>)**`. Items:

A. `<file:symbol>` - <the change, concretely>. (Acceptance: <a test that was RED before this item,
   GREEN after>.)
B. ...

Scope: only these items; do not re-open settled parts of the task. If an item needs a design
decision you must not make, flag it in the report rather than guessing. Record, per item, the
RED->GREEN proof and any existing test whose premise the item changed.
