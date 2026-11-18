#!/usr/bin/env bash
# Background monitor for the multi-agent relay.
# Fires when a task's report reaches a TERMINAL status (shipped, or blocked-on-owner), or when a
# fix-batch file for the task appears. Run it in the background; it re-invokes the driver on exit.
# Uses /usr/bin/grep because zsh's grep may be ugrep, which mis-handles -E and globs.
#
# Usage: monitor.sh <report_file> <prompts_dir> <task_id> [max_minutes]
set -u
R="$1"; D="$2"; TASK="$3"; MAX="${4:-180}"
for i in $(seq 1 "$MAX"); do
  if [ -f "$R" ] && /usr/bin/grep -Eq '^\*\*Status: (DONE, shipped|BLOCKED on owner)' "$R"; then
    echo "${TASK}_TERMINAL after ${i} min:"
    /usr/bin/grep -m1 -E '^\*\*Status:' "$R"
    exit 0
  fi
  if [ -n "$(find "$D" -maxdepth 1 -name "${TASK}-*-fix.md" -print -quit 2>/dev/null)" ]; then
    echo "${TASK}_FIX_BATCH after ${i} min:"
    find "$D" -maxdepth 1 -name "${TASK}-*-fix.md"
    exit 0
  fi
  sleep 60
done
echo "${TASK}_STILL_RUNNING after ${MAX} min; last status:"
[ -f "$R" ] && /usr/bin/grep -m1 -E '^\*\*Status:' "$R" || echo "(no report yet)"
