#!/bin/bash
# Fable 5 fan-out guard.
# Born after a real incident: an unpinned workflow spawned dozens of
# frontier-model agents and burned through a session's quota.
# On Fable 5 sessions, Agent/Workflow calls must follow the mission-control
# model calibration: delegated lots run on sonnet/haiku (opus for the hardest),
# Fable 5 stays in the main loop only. Workflow agents INHERIT the session
# model, so an unpinned fan-out burns Fable 5 quota on every subagent.
# Escape hatch: when the user has explicitly approved running agents on
# Fable 5 for that run, the token FABLE_OK must appear in one of these
# dedicated positions, never as a substring match anywhere in the tool
# input:
#   - Agent: FABLE_OK is the first non-empty line of the call's prompt
#     (.tool_input.prompt), leading/trailing whitespace ignored, compared
#     after trimming.
#   - Workflow, args is a string (.tool_input.args): same
#     first-non-empty-line-trimmed rule, applied to that string.
#   - Workflow, args is a JSON object: a top-level key FABLE_OK whose value
#     is the JSON boolean true, exactly (e.g. {"FABLE_OK": true}). Any other
#     value, including "true", 1, or any other string, does not approve.
#     There is no other approval form for object args: a top-level string
#     value (e.g. {"approval": "FABLE_OK"}) never approves, even if its
#     first line reads FABLE_OK, because a string value under an arbitrary
#     key is a relay channel a poisoned document can fill.
#   - Workflow, args is a JSON array: any element that is exactly the
#     string "FABLE_OK" (e.g. ["FABLE_OK", ...]).
# A brief that merely quotes or mentions the token elsewhere in the text
# (for example relaying this file's own docs to a subagent, or fixture
# content that says "include FABLE_OK in the prompt") does not disarm the
# guard, because the token has to occupy one of the positions above, not be
# found as a substring anywhere else.

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

# Explicit user approval token, checked entirely in jq so each shape of
# tool_input gets the matching rule, instead of first flattening everything
# to text and then checking "the first line" of that text. That flattening
# (a plain `tostring` on .tool_input.args) is what caused an earlier
# regression: tostring on a JSON object or array renders it as one compact
# single line, so a structured-args approval (the recommended
# {"FABLE_OK": true} form, or an array containing "FABLE_OK") could never
# be "the first line" and was always denied, even though it is a legitimate
# approval. A later regression went the other way: treating any top-level
# string value inside an object's first non-empty line as an approval
# reopened a disarm-by-relay channel, since an attacker-controlled document
# relayed through an arbitrary key (e.g. {"x": "FABLE_OK\n<rest>"}, or
# {"expected_output": "FABLE_OK"}) could then disarm the guard. Object args
# now approve on exactly one shape: a top-level key FABLE_OK whose value is
# the JSON boolean true, nothing else. A parse error, an unrecognized tool,
# or a tool_input shape that matches none of the rules below simply yields
# "false" here: that means no approval was found and enforcement continues
# below, not that the guard itself fails open (the actual fail-open path is
# the missing-jq exit above, which skips enforcement entirely).
# shellcheck disable=SC2016 # jq program in single quotes: $tool/$ti/$args/$t are jq bindings, not shell variables.
approved=$(printf '%s' "$input" | "$JQ" -r '
  def trimmed_first_line:
    if type != "string" then null
    else
      split("\n")
      | map(gsub("^[ \t\r]+|[ \t\r]+$"; ""))
      | map(select(length > 0))
      | first
    end;
  def is_ok_line: trimmed_first_line == "FABLE_OK";
  .tool_name as $tool
  | .tool_input as $ti
  | if $tool == "Agent" then
      ($ti.prompt // "") | is_ok_line
    elif $tool == "Workflow" then
      ($ti.args) as $args
      | ($args | type) as $t
      | if $t == "string" then
          $args | is_ok_line
        elif $t == "object" then
          ($args.FABLE_OK == true)
        elif $t == "array" then
          any($args[]; . == "FABLE_OK")
        else
          false
        end
    else
      false
    end
' 2>/dev/null)

# A token quoted mid-prose, or sharing a line with other text, does not
# count in either string-typed form above (Agent prompt, or Workflow string
# args): the check is always "first non-empty line, trimmed, equals
# FABLE_OK exactly", never a substring search. Workflow object args have no
# string-typed form at all; only the exact-boolean-true key counts.
if [ "$approved" = "true" ]; then
  exit 0
fi

deny() {
  # shellcheck disable=SC2016 # $r is a jq --arg binding, not a shell variable; single quotes are intentional.
  "$JQ" -n --arg r "$1" '{hookSpecificOutput:{hookEventName:"PreToolUse",permissionDecision:"deny",permissionDecisionReason:$r}}'
}

if [ "$tool" = "Agent" ]; then
  model=$(printf '%s' "$input" | "$JQ" -r '.tool_input.model // empty')
  case "$model" in
    sonnet|haiku|opus|claude-sonnet*|claude-haiku*|claude-opus*)
      exit 0 ;;
  esac
  deny "Session Fable 5: mission-control calibration is mandatory. Re-invoke Agent with an explicit model ('sonnet' default, 'haiku' for trivial lots, 'opus' only for the hardest verify lots). Fable 5 stays in the main loop. If the user explicitly approved Fable 5 subagents, put FABLE_OK on its own first line of the prompt."
  exit 0
fi

if [ "$tool" = "Workflow" ]; then
  deny "Session Fable 5: workflow agents inherit the session model, so an unpinned workflow runs every subagent on Fable 5. Author the script yourself with model pinned on EVERY agent() call (sonnet/haiku, opus only for the hardest lots) and state the agent count and models to the user first. Named workflows (code-review etc.) are barred as-is. If the user explicitly approved: when args is a string, put FABLE_OK on its own first line; when args is a structured object, add a top-level {\"FABLE_OK\": true} key (value must be the boolean true) instead; when args is an array, include the element \"FABLE_OK\"."
  exit 0
fi

exit 0
