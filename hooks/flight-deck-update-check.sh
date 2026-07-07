#!/bin/bash
# flight-deck-update-check: SessionStart hook, NON-BLOCKING, fail-open.
#
# Once a day, checks GitHub for a Flight Deck release newer than the installed
# VERSION and, if the install is behind, injects a short note into the session
# context (SessionStart additionalContext) so the assistant can tell the user
# and offer to update. It never blocks or errors a session: any problem
# (no jq, no curl, no network, no VERSION file, bad JSON, rate limit) ends in a
# silent `exit 0`. Updating itself is never automatic: the note points the user
# at the installer prompt, which diffs and asks before overwriting anything.
#
# Requires jq and curl on PATH. Missing either, it fails open (no check, no error).

# 1. Tooling. Fail open if jq or curl is unavailable.
JQ=$(command -v jq || echo /opt/homebrew/bin/jq)
[ -x "$JQ" ] || exit 0
command -v curl >/dev/null 2>&1 || exit 0

# 2. Installed version. The VERSION file rides along with the copied skill
#    folder, so its presence also means Flight Deck is actually installed here.
VERSION_FILE="$HOME/.claude/skills/mission-control/VERSION"
[ -r "$VERSION_FILE" ] || exit 0
installed=$(tr -d ' \t\r\n' < "$VERSION_FILE")
[ -n "$installed" ] || exit 0

# 3. Daily cache: at most one GitHub call per 24h. Stamp BEFORE the call so a
#    hang or failure still will not re-hit GitHub for a day.
CACHE="$HOME/.claude/.flight-deck-update-check"
now=$(date +%s)
last=$(cat "$CACHE" 2>/dev/null || echo 0)
case "$last" in ''|*[!0-9]*) last=0 ;; esac
[ $((now - last)) -ge 86400 ] || exit 0
echo "$now" > "$CACHE" 2>/dev/null

# 4. Latest release tag from GitHub, time-boxed and quiet. Fail open on anything.
latest=$(curl -fsS --max-time 5 -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/CaseReed/flight-deck/releases/latest" 2>/dev/null \
  | "$JQ" -r '.tag_name // empty' 2>/dev/null)
latest=${latest#v}
[ -n "$latest" ] || exit 0

# 5. Notify only if latest is strictly newer than installed (version sort).
[ "$latest" != "$installed" ] || exit 0
newest=$(printf '%s\n%s\n' "$installed" "$latest" | sort -V | tail -n1)
[ "$newest" = "$latest" ] || exit 0   # installed is already >= latest

# 6. Emit context so the assistant surfaces it and can offer the update.
msg="Flight Deck $latest is available (installed: $installed). Tell the user in one short line and offer to update. Updating means re-running the Flight Deck installer prompt from https://github.com/CaseReed/flight-deck, which shows a diff and asks before overwriting anything. Never update without the user's go-ahead."
"$JQ" -n --arg m "$msg" '{hookSpecificOutput:{hookEventName:"SessionStart",additionalContext:$m}}'
exit 0
