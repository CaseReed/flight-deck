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

nonfable_transcript="$WORK_DIR/nonfable-session.jsonl"
printf '%s\n' '{"type":"assistant","message":{"model":"claude-sonnet-5-20260101"}}' > "$nonfable_transcript"

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

echo "== Non-Fable session =="
run_case "non-Fable session, Workflow no token -> ALLOW (guard inert)" \
  allow Workflow '{"x": "irrelevant"}' "$nonfable_transcript"

echo
echo "Results: $pass passed, $fail failed"
[ "$fail" -eq 0 ]
