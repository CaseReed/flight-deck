#!/usr/bin/env bash
# Test for hooks/fable5-fanout-guard.sh.
#
# Self-contained and portable: builds its own fake Fable-session transcript
# in a temp dir (so the hook's session-model detection sees a fable model),
# feeds synthetic PreToolUse hook inputs to the guard, and asserts the
# permission decision (allow vs deny) for each case. No fixtures outside
# this script, no paths outside $TMPDIR; the temp dir is removed on exit.
#
# Requires jq (the hook itself requires jq to enforce anything; without it
# the hook fails open and every case would read "allow", which would hide
# real regressions, so this test skips instead of reporting misleading
# passes).
#
# Usage: bash tools/test-fable5-guard.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOOK="$(cd "$SCRIPT_DIR/.." && pwd)/hooks/fable5-fanout-guard.sh"

if ! command -v jq >/dev/null 2>&1; then
  echo "SKIP  jq not found on PATH: hooks/fable5-fanout-guard.sh fails open without it, so this test cannot exercise enforcement. Install jq to run it."
  exit 0
fi

if [ ! -x "$HOOK" ]; then
  echo "FAIL  hook not found or not executable: $HOOK"
  exit 1
fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/fable5-guard-test.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

# Synthetic transcripts, JSONL with one assistant line each, read by the hook
# via `select(.type=="assistant") | .message.model`.
fable_transcript="$WORK_DIR/fable-session.jsonl"
printf '%s\n' '{"type":"assistant","message":{"model":"claude-fable-5-20260101"}}' > "$fable_transcript"

opus_transcript="$WORK_DIR/opus-session.jsonl"
printf '%s\n' '{"type":"assistant","message":{"model":"claude-opus-4-8-20260101"}}' > "$opus_transcript"

nonfable_transcript="$WORK_DIR/nonfable-session.jsonl"
printf '%s\n' '{"type":"assistant","message":{"model":"claude-sonnet-5-20260101"}}' > "$nonfable_transcript"

# Actual runtime id format: brackets appended for a context-window variant
# (e.g. "[1m]"). Still has to arm the guard via the loose substring match.
opus_bracket_transcript="$WORK_DIR/opus-bracket-session.jsonl"
printf '%s\n' '{"type":"assistant","message":{"model":"claude-opus-4-8[1m]"}}' > "$opus_bracket_transcript"

# First-turn fail-open: no assistant line exists yet (only a user line, as on
# the very first turn of a session before any assistant reply), so the
# transcript-based detection resolves nothing and the settings.json fallback
# is guaranteed empty (run_case isolates HOME to $WORK_DIR, which has no
# .claude/settings.json). session_model stays empty, which does not match
# *fable*|*opus*, so the guard is inert.
no_assistant_transcript="$WORK_DIR/no-assistant-session.jsonl"
printf '%s\n' '{"type":"user","message":{"content":"hello"}}' > "$no_assistant_transcript"

pass=0
fail=0

# run_case NAME EXPECTED(allow|deny) TOOL TOOL_INPUT_JSON [transcript]
#
# TOOL_INPUT_JSON is the JSON value the hook should see:
#   - Agent:    the full tool_input object, e.g. {"prompt": "...", "model": "sonnet"}.
#   - Workflow: the value of .tool_input.args (string, object, or array);
#     this function wraps it into {args: ...} since the hook only ever
#     reads .tool_input.args for Workflow.
run_case() {
  local name="$1" expected="$2" tool="$3" tool_input="$4" transcript="${5:-$fable_transcript}"
  # Isolate HOME to the test's own temp dir for the hook invocation, so the
  # hook's settings.json fallback (~/.claude/settings.json) can never read
  # the real user's HOME. $WORK_DIR has no .claude/settings.json, so the
  # fallback stays empty here regardless of what the real machine has
  # configured (e.g. a frontier `model` key), keeping cases deterministic.
  local HOME="$WORK_DIR"
  local hook_input
  if [ "$tool" = "Workflow" ]; then
    hook_input=$(jq -n --arg tool "$tool" --argjson args "$tool_input" --arg t "$transcript" \
      '{tool_name:$tool, tool_input:{args:$args}, transcript_path:$t}')
  else
    hook_input=$(jq -n --arg tool "$tool" --argjson ti "$tool_input" --arg t "$transcript" \
      '{tool_name:$tool, tool_input:$ti, transcript_path:$t}')
  fi

  local raw_out decision
  raw_out=$(printf '%s' "$hook_input" | "$HOOK")
  if [ -z "$raw_out" ]; then
    decision="allow"
  else
    decision=$(printf '%s' "$raw_out" | jq -r '.hookSpecificOutput.permissionDecision // empty')
    if [ "$decision" != "deny" ]; then
      decision="allow"
    fi
  fi

  if [ "$decision" = "$expected" ]; then
    pass=$((pass + 1))
    printf 'PASS  %-60s expected=%-6s got=%-6s\n' "$name" "$expected" "$decision"
  else
    fail=$((fail + 1))
    printf 'FAIL  %-60s expected=%-6s got=%-6s raw=%s\n' "$name" "$expected" "$decision" "$raw_out"
  fi
}

echo "== Agent =="
run_case "Agent prompt first line FABLE_OK -> ALLOW" \
  allow Agent '{"prompt": "FABLE_OK\ndo the thing", "model": "sonnet"}'
run_case "Agent model=sonnet, no token -> ALLOW" \
  allow Agent '{"prompt": "do the thing", "model": "sonnet"}'
run_case "Agent mid-prose token -> DENY" \
  deny Agent '{"prompt": "context: FABLE_OK is the token\ndo the thing"}'
run_case "Agent no token, no model -> DENY" \
  deny Agent '{"prompt": "do the thing"}'

echo "== Workflow =="
run_case "Workflow args string, first line FABLE_OK -> ALLOW" \
  allow Workflow '"FABLE_OK\nrest of the script"'
run_case "Workflow args object {FABLE_OK: true} -> ALLOW" \
  allow Workflow '{"FABLE_OK": true}'
run_case "Workflow args object {FABLE_OK: \"false\"} -> DENY" \
  deny Workflow '{"FABLE_OK": "false"}'
run_case "Workflow args object {approval: FABLE_OK} -> DENY" \
  deny Workflow '{"approval": "FABLE_OK"}'
run_case "Workflow args object {x: FABLE_OK\\nmore} -> DENY (poison channel closed)" \
  deny Workflow '{"x": "FABLE_OK\nmore"}'
run_case "Workflow args array [FABLE_OK, y] -> ALLOW" \
  allow Workflow '["FABLE_OK", "y"]'
run_case "Workflow no token -> DENY" \
  deny Workflow '{"x": "irrelevant"}'

echo "== Opus session (frontier: guard armed) =="
run_case "Opus session, Agent no token, no model -> DENY" \
  deny Agent '{"prompt": "do the thing"}' "$opus_transcript"
run_case "Opus session, Agent model=sonnet -> ALLOW" \
  allow Agent '{"prompt": "do the thing", "model": "sonnet"}' "$opus_transcript"
run_case "Opus session, Agent model=haiku -> ALLOW" \
  allow Agent '{"prompt": "do the thing", "model": "haiku"}' "$opus_transcript"
run_case "Opus session, Agent model=opus -> ALLOW" \
  allow Agent '{"prompt": "do the thing", "model": "opus"}' "$opus_transcript"
run_case "Opus session, Agent model=fable, no token -> DENY (up-delegation barred)" \
  deny Agent '{"prompt": "do the thing", "model": "fable"}' "$opus_transcript"
run_case "Opus session, Agent prompt first line FABLE_OK -> ALLOW" \
  allow Agent '{"prompt": "FABLE_OK\ndo the thing"}' "$opus_transcript"
run_case "Opus session, Workflow no token -> DENY" \
  deny Workflow '{"x": "irrelevant"}' "$opus_transcript"
run_case "Opus session, Workflow args object {FABLE_OK: true} -> ALLOW" \
  allow Workflow '{"FABLE_OK": true}' "$opus_transcript"

echo "== Non-Fable session =="
run_case "non-Fable session, Workflow no token -> ALLOW (guard inert)" \
  allow Workflow '{"x": "irrelevant"}' "$nonfable_transcript"

echo "== Bracket-form model id (actual runtime format) =="
run_case "Opus bracket-id session, Agent no token, no model -> DENY" \
  deny Agent '{"prompt": "do the thing"}' "$opus_bracket_transcript"
run_case "Opus bracket-id session, Agent model=sonnet -> ALLOW" \
  allow Agent '{"prompt": "do the thing", "model": "sonnet"}' "$opus_bracket_transcript"

echo "== First-turn fail-open (no assistant line yet) =="
run_case "No-assistant transcript, Agent no token, no model -> ALLOW (undetectable session model)" \
  allow Agent '{"prompt": "do the thing"}' "$no_assistant_transcript"

echo "== FABLE_OK precedence and structured Workflow approval on Opus =="
run_case "Opus session, Workflow args string first line FABLE_OK -> ALLOW" \
  allow Workflow '"FABLE_OK\nrest of the script"' "$opus_transcript"
run_case "Opus session, Agent model=fable WITH FABLE_OK token -> ALLOW (token beats up-delegation bar)" \
  allow Agent '{"prompt": "FABLE_OK\ndo the thing", "model": "fable"}' "$opus_transcript"

echo "== Long-form model allow-list =="
run_case "Opus session, Agent model=claude-sonnet-5 (long form) -> ALLOW" \
  allow Agent '{"prompt": "do the thing", "model": "claude-sonnet-5"}' "$opus_transcript"

echo "== settings.json fallback arming (positive counterpart to first-turn fail-open) =="
# When the transcript resolves no model (same no-assistant-line transcript as
# the fail-open case above) but $HOME/.claude/settings.json carries a
# frontier model, the guard must fall back to that and arm. This needs a
# bespoke invocation rather than run_case: run_case forces HOME=$WORK_DIR,
# which deliberately has no settings.json (that is what keeps the fail-open
# case above deterministic). Here a dedicated home dir is created INSIDE
# $WORK_DIR so it is still removed by the top-level trap, and the real
# ~/.claude is never touched.
settings_arm_home="$WORK_DIR/settings-arm-home"
mkdir -p "$settings_arm_home/.claude"
printf '%s\n' '{"model":"claude-fable-5"}' > "$settings_arm_home/.claude/settings.json"

settings_arm_input=$(jq -n --arg t "$no_assistant_transcript" \
  '{tool_name:"Agent", tool_input:{prompt:"do the thing"}, transcript_path:$t}')
settings_arm_raw_out=$(HOME="$settings_arm_home" bash -c 'printf "%s" "$1" | "$2"' _ "$settings_arm_input" "$HOOK")
if [ -z "$settings_arm_raw_out" ]; then
  settings_arm_decision="allow"
else
  settings_arm_decision=$(printf '%s' "$settings_arm_raw_out" | jq -r '.hookSpecificOutput.permissionDecision // empty')
  if [ "$settings_arm_decision" != "deny" ]; then
    settings_arm_decision="allow"
  fi
fi

settings_arm_expected="deny"
if [ "$settings_arm_decision" = "$settings_arm_expected" ]; then
  pass=$((pass + 1))
  printf 'PASS  %-60s expected=%-6s got=%-6s\n' \
    "settings.json fallback arms (no transcript model, frontier settings.json) -> DENY" \
    "$settings_arm_expected" "$settings_arm_decision"
else
  fail=$((fail + 1))
  printf 'FAIL  %-60s expected=%-6s got=%-6s raw=%s\n' \
    "settings.json fallback arms (no transcript model, frontier settings.json) -> DENY" \
    "$settings_arm_expected" "$settings_arm_decision" "$settings_arm_raw_out"
fi

echo
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
