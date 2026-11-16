#!/usr/bin/env bash
# Stop hook for the NightVision plugin (Claude Code). Opt-in: does nothing
# unless NIGHTVISION_ENFORCE=1.
#
# When the agent is about to end its turn in a git repository where
# application source changed during the session, uncommitted or committed,
# and the app holding a changed file has no NightVision scan recorded since
# that change, it asks the agent once to run the ship-check skill or say why
# a scan does not apply.
#
# A scan is recorded in the app's .nightvision/ directory: manifest.json with
# a scan_id (written by run-app-security-scan) or retest.json with a scan_id
# (written by the verify-fix skill after a narrowed retest). Each changed file
# is checked against the nearest such directory above it, so in a monorepo a
# scan of one app does not cover another.
#
# Only files changed after the session started count; the SessionStart hook
# records that time. Without that record (the plugin was enabled mid-session,
# or the state was cleared) every uncommitted file counts.
#
# It nudges once per set of changes: a turn that already received the nudge
# for the same changes is let through, so the agent is never trapped, but a
# new round of edits can be nudged again. It is a reminder, not a hard gate;
# pair it with a CI check for that. Always exits 0.

[ "${NIGHTVISION_ENFORCE:-}" = "1" ] || exit 0

input=$(cat)

# Claude is already continuing because a stop hook fired: let it stop.
if printf '%s' "$input" | grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true'; then
  exit 0
fi

dir="${CLAUDE_PROJECT_DIR:-}"
if [ -z "$dir" ]; then
  dir=$(printf '%s' "$input" | sed -n 's/.*"cwd"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
fi
[ -n "$dir" ] && [ -d "$dir" ] || exit 0
root=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$root" || exit 0

session=$(printf '%s' "$input" | sed -n 's/.*"session_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p')
state_dir="${CLAUDE_PLUGIN_DATA:-${TMPDIR:-/tmp}/nightvision-$(id -u 2>/dev/null)}/nightvision-stop-gate"
started="$state_dir/${session:-unknown}.start"
since=""
if [ -f "$started" ]; then
  since=$(cat "$started" 2>/dev/null)
  case "$since" in
    ''|*[!0-9]*) since="" ;;
  esac
else
  started=""
fi

# True when $1 is application source worth a scan: a code file outside
# dependency, environment, build and test directories.
is_app_source() {
  case "/$1" in
    */node_modules/*|*/vendor/*|*/dist/*|*/build/*|*/out/*|*/target/*|*/coverage/*) return 1 ;;
    */.venv/*|*/venv/*|*/env/*|*/site-packages/*|*/__pycache__/*) return 1 ;;
    */.next/*|*/.nuxt/*|*/.svelte-kit/*|*/.output/*|*/.nightvision/*) return 1 ;;
    */test/*|*/tests/*|*/__tests__/*|*/spec/*|*.test.*|*.spec.*|*_test.*) return 1 ;;
  esac
  case "$1" in
    *.py|*.js|*.jsx|*.mjs|*.cjs|*.ts|*.tsx|*.go|*.java|*.kt|*.kts|*.scala|*.cs|*.php|*.rb|*.rs|*.ex|*.exs|*.vue|*.svelte) return 0 ;;
  esac
  return 1
}

# Prints the scan record (manifest.json or retest.json with a scan_id) that
# covers $1: the newer of the two in the nearest .nightvision/ directory that
# holds one, walking up from the file to the repository root.
scan_record_for() {
  local d best rec
  d=$(dirname "$1")
  while :; do
    best=""
    for rec in "$d/.nightvision/manifest.json" "$d/.nightvision/retest.json"; do
      [ -f "$rec" ] || continue
      grep -Eq '"scan_id"[[:space:]]*:[[:space:]]*"[^"]+' "$rec" 2>/dev/null || continue
      if [ -z "$best" ] || [ "$rec" -nt "$best" ]; then
        best="$rec"
      fi
    done
    if [ -n "$best" ]; then
      printf '%s\n' "$best"
      return 0
    fi
    [ "$d" = "." ] && return 1
    d=$(dirname "$d")
  done
}

# Application source changed in the working tree, untracked, or committed
# since the session started; limited to files modified during the session
# when its start is known.
changed=$(
  {
    git -c core.quotePath=false diff --name-only HEAD 2>/dev/null || git -c core.quotePath=false ls-files 2>/dev/null
    git -c core.quotePath=false ls-files --others --exclude-standard 2>/dev/null
    if [ -n "$since" ]; then
      git -c core.quotePath=false log --since="@$since" --name-only --format= 2>/dev/null
    fi
  } | sort -u | while IFS= read -r f; do
    [ -n "$f" ] && [ -f "$f" ] && is_app_source "$f" || continue
    [ -z "$started" ] || [ "$f" -nt "$started" ] || continue
    printf '%s\n' "$f"
  done | head -n 2000
)
[ -n "$changed" ] || exit 0

# Changed files with no scan recorded since they changed.
unscanned=$(
  while IFS= read -r f; do
    rec=$(scan_record_for "$f")
    if [ -z "$rec" ] || [ "$f" -nt "$rec" ]; then
      printf '%s\n' "$f"
    fi
  done <<< "$changed"
)
[ -n "$unscanned" ] || exit 0

# Nudge once per set of changes in this session.
mkdir -p "$state_dir" 2>/dev/null || exit 0
state_file="$state_dir/${session:-unknown}.nudged"
state=$(
  {
    printf '%s\n' "$unscanned"
    while IFS= read -r f; do cat "$f" 2>/dev/null; done <<< "$unscanned"
  } | cksum
)
if [ -f "$state_file" ] && [ "$(cat "$state_file" 2>/dev/null)" = "$state" ]; then
  exit 0
fi
printf '%s' "$state" > "$state_file" 2>/dev/null

count=$(printf '%s\n' "$unscanned" | wc -l | tr -d ' ')
cat <<EOF
{"decision": "block", "reason": "NightVision enforcement is on: $count application source file(s) changed in this session with no NightVision scan recorded since the change. If this session built or materially changed a web app or API, run the ship-check skill before finishing. If it did not (for example the change is a library, a script or a config tweak), or a scan cannot run, say so in one line with the reason, then finish."}
EOF
exit 0
