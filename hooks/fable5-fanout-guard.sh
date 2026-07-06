#!/bin/bash
# Fable 5 fan-out guard.
# Born after a real incident: an unpinned workflow spawned dozens of
# frontier-model agents and burned through a session's quota.
# On Fable 5 sessions, Agent/Workflow calls must follow the mission-control
# model calibration: delegated lots run on sonnet/haiku (opus for the hardest),
# Fable 5 stays in the main loop only. Workflow agents INHERIT the session
# model, so an unpinned fan-out burns Fable 5 quota on every subagent.
# Escape hatch: include the token FABLE_OK in the tool input when the user has
# explicitly approved running agents on Fable 5. Known limitation: the token
# is matched anywhere in tool_input (not a dedicated field), so a brief that
# merely quotes this token (e.g. relaying this file's docs to a subagent) can
# disarm the guard. Accepted trade-off for a fail-open safety net.

input=$(cat)

JQ=$(command -v jq || echo /opt/homebrew/bin/jq)
[ -x "$JQ" ] || exit 0  # cannot parse, fail open rather than break all tools

tool=$(printf '%s' "$input" | "$JQ" -r '.tool_name // empty')
transcript=$(printf '%s' "$input" | "$JQ" -r '.transcript_path // empty')

# Resolve the session model: last assistant message in the transcript. The
# settings.json fallback below is best-effort only, not a reliable safety
# net: Claude Code does not store a top-level "model" key in
# ~/.claude/settings.json in practice, so this fallback is usually empty,
# and the transcript read above is what actually detects a Fable 5 session.
# Parsed as JSONL (one JSON object per line) rather than grepped as raw
# text, so a "model" key inside a tool_input (e.g. an Agent call's input)
# never gets mistaken for the session's own model.
session_model=""
if [ -n "$transcript" ] && [ -f "$transcript" ]; then
  session_model=$(tail -n 200 "$transcript" | "$JQ" -r 'select(.type=="assistant") | .message.model // empty' 2>/dev/null | tail -1)
fi
if [ -z "$session_model" ]; then
  session_model=$("$JQ" -r '.model // empty' "$HOME/.claude/settings.json" 2>/dev/null)
fi

case "$session_model" in
  *fable*) ;;      # Fable session: enforce below
  *) exit 0 ;;     # any other model: no restriction
esac

# Explicit user approval token anywhere in the tool input.
if printf '%s' "$input" | "$JQ" -r '.tool_input | tostring' | grep -q 'FABLE_OK'; then
  exit 0
fi

deny() {
  "$JQ" -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
}

if [ "$tool" = "Agent" ]; then
  model=$(printf '%s' "$input" | "$JQ" -r '.tool_input.model // empty')
  case "$model" in
    sonnet|haiku|opus|claude-sonnet*|claude-haiku*|claude-opus*)
      exit 0 ;;
  esac
  deny "Session Fable 5: mission-control calibration is mandatory. Re-invoke Agent with an explicit model ('sonnet' default, 'haiku' for trivial lots, 'opus' only for the hardest verify lots). Fable 5 stays in the main loop. If the user explicitly approved Fable 5 subagents, include FABLE_OK in the prompt."
  exit 0
fi

if [ "$tool" = "Workflow" ]; then
  deny "Session Fable 5: workflow agents inherit the session model, so an unpinned workflow runs every subagent on Fable 5. Author the script yourself with model pinned on EVERY agent() call (sonnet/haiku, opus only for the hardest lots) and state the agent count and models to the user first. Named workflows (code-review etc.) are barred as-is. If the user explicitly approved, include FABLE_OK in the args."
  exit 0
fi

exit 0
