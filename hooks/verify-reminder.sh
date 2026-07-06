#!/bin/bash
# verify-reminder: PreToolUse hook, NON-BLOCKING.
#
# Purpose: right before a `git push` runs, remind whoever (or whatever) is
# driving the session to confirm the code change was actually verified: the
# project's own named test/build check was run and its output was cited,
# not just "looks fine" or a type-check alone. This is a nudge, not a gate:
# the push is always allowed to proceed, no matter what the command looks
# like or what the JSON on stdin contains.
#
# Contract: never block, never deny, never error the tool call. Any
# parsing failure (missing jq, empty stdin, malformed JSON, unexpected
# shape) must fall through to a plain `exit 0` so a real push is never
# held up by a bug in this script.

# Read the whole PreToolUse payload once. If stdin is empty, closed, or
# unavailable, $input just ends up empty and every check below exits
# early and safely.
input=$(cat 2>/dev/null)

# Resolve jq the same way the fanout guard does (PATH first, then the
# common Homebrew location on Apple Silicon). If we cannot find a working
# jq, we cannot safely parse JSON, so fail open rather than guess with
# fragile string matching on raw JSON text.
JQ=$(command -v jq || echo /opt/homebrew/bin/jq)
[ -x "$JQ" ] || exit 0

# Reject empty or non-JSON input up front instead of letting later jq
# calls fail confusingly. `-e .` both validates the JSON and requires a
# non-null top-level value.
if [ -z "$input" ] || ! printf '%s' "$input" | "$JQ" -e . >/dev/null 2>&1; then
  exit 0
fi

# Only Bash tool calls carry a shell command worth inspecting. Anything
# else (Read, Edit, Agent, ...) is none of this hook's business.
tool=$(printf '%s' "$input" | "$JQ" -r '.tool_name // empty' 2>/dev/null)
[ "$tool" = "Bash" ] || exit 0

# tool_input.command holds the actual shell command for a Bash call.
# `// empty` covers a missing field, a null tool_input, or a non-object
# tool_input without jq erroring out.
command=$(printf '%s' "$input" | "$JQ" -r '.tool_input.command // empty' 2>/dev/null)
[ -n "$command" ] || exit 0

# Look for a `git push` invocation anywhere in the command. The pattern
# requires "git" and "push" as separate words inside the same chained
# segment (it will not cross a ; & or | into a following command), with
# anything (flags, remote, branch, aliases like -C <dir>) allowed in
# between. This is intentionally permissive: a false positive here only
# costs an extra reminder, never a blocked push, so it is fine to err on
# the side of catching more `git push` shapes (git push, git push origin
# HEAD, git push --force-with-lease, git -C repo push, chained after
# && / ; / |, etc.).
if ! printf '%s' "$command" | grep -Eq '(^|[;&|])[[:space:]]*git[[:space:]]+([^;&|]*[[:space:]])?push([[:space:]]|$|[;&|])'; then
  exit 0
fi

reminder="Reminder before this git push: make sure the code change was verified first. Run this project's own named test/build check (see its CLAUDE.md, package.json scripts, or README) and be ready to cite the output, not just a type-check or a glance at the diff. This is a reminder only, it does not block the push."

# Non-blocking: report the reminder through the top-level `systemMessage`
# field, which Claude Code shows to the user without it counting as a
# permission decision. This hook emits no `hookSpecificOutput` and no
# `permissionDecision` at all, not "allow", not "deny", not "ask": it only
# reminds. The push then proceeds through Claude Code's normal permission
# flow, exactly as if this hook had not run.
"$JQ" -Rn --arg msg "$reminder" '{systemMessage:$msg}'

exit 0
