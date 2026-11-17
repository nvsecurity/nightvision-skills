#!/usr/bin/env bash
# SessionStart hook for the NightVision plugin (Claude Code).
#
# Prints a short note that Claude Code adds to the session context:
# - the secure-build and ship-check skills apply to app work in this session;
# - with NIGHTVISION_ENFORCE=1, ship-check is required before app work is
#   complete, and the Stop hook checks for it;
# - the NightVision CLI is missing or older than the supported minimum.
#
# With NIGHTVISION_ENFORCE=1 it also records when the session started, so the
# Stop hook only counts files changed during the session, not ones already
# uncommitted before it.
#
# It runs only `nightvision version` and file operations in the plugin's data
# directory, and always exits 0 so a problem here can never block a session.

MIN_CLI_VERSION="0.26.0"

# True when $1 is strictly older than $2 (both major.minor.patch).
version_below() {
  local IFS=.
  local -a a=($1) b=($2)
  local i
  for i in 0 1 2; do
    local x=${a[i]:-0} y=${b[i]:-0}
    if ((10#$x < 10#$y)); then return 0; fi
    if ((10#$x > 10#$y)); then return 1; fi
  done
  return 1
}

if [ "${NIGHTVISION_ENFORCE:-}" = "1" ]; then
  input=""
  [ -t 0 ] || input=$(cat 2>/dev/null)
  session=$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
  state_dir="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/nightvision-$(id -u 2>/dev/null)}/nightvision-stop-gate"
  if [ -n "$session" ] && mkdir -p "$state_dir" 2>/dev/null; then
    # Keep the first start time when a session resumes or compacts.
    [ -f "$state_dir/$session.start" ] || date +%s > "$state_dir/$session.start" 2>/dev/null
    # Drop state from sessions older than a week.
    find "$state_dir" -type f -mtime +7 -exec rm -f {} + 2>/dev/null
  fi

  echo "NightVision enforcement is on: when this session creates or materially changes a web app, API, route handler, auth logic or data access, follow the secure-build skill while writing it and run the ship-check skill before you tell the developer the work is done. Work is not complete until the app's .nightvision/ directory records a scan run after the change (manifest.json from a scan, or retest.json from verify-fix), or you have stated the concrete blocker that prevented the scan."
else
  echo "NightVision: when this session creates or materially changes a web app, API, route handler, auth logic or data access, follow the secure-build skill while writing it, and before you tell the developer it is done, offer to run the ship-check skill (a NightVision scan of the running app, with fixes verified by retest)."
fi

if ! command -v nightvision >/dev/null 2>&1; then
  echo "NightVision CLI not found on PATH, so NightVision scans will fail. If the developer asks for a scan or ship-check, tell them to install the CLI first (https://docs.nightviz.ai/welcome/tutorials-and-guides/installing-the-cli/) and run 'nightvision login'."
  exit 0
fi

# The CLI prints its version on stderr.
version_output=$(nightvision version 2>&1)
if [[ $version_output =~ [Vv]ersion[[:space:]]+v?([0-9]+)\.([0-9]+)\.([0-9]+) ]]; then
  cli_version="${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
  if version_below "$cli_version" "$MIN_CLI_VERSION"; then
    echo "NightVision CLI $cli_version is older than the supported minimum $MIN_CLI_VERSION, so some NightVision tools may fail. Suggest the developer upgrade it before scanning."
  fi
fi

exit 0
