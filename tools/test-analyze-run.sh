#!/usr/bin/env bash
# Test for tools/analyze-run.py.
#
# Runs the analyzer against the committed synthetic fixture
# (tools/sample-transcript.jsonl, no real transcript data) and asserts exact
# expected values in both its --json output (numeric/structural checks) and
# its default human-readable scorecard (label and section checks).
#
# Usage: bash tools/test-analyze-run.sh

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ANALYZER="${SCRIPT_DIR}/analyze-run.py"
FIXTURE="${SCRIPT_DIR}/sample-transcript.jsonl"

failures=0
checks=0

check() {
  # check "label" "actual" "expected"
  checks=$((checks + 1))
  if [ "$2" = "$3" ]; then
    printf 'PASS  %s\n' "$1"
  else
    failures=$((failures + 1))
    printf 'FAIL  %s: expected [%s], got [%s]\n' "$1" "$3" "$2"
  fi
}

check_contains() {
  # check_contains "label" "haystack" "needle"
  checks=$((checks + 1))
  if printf '%s' "$2" | grep -Fq -- "$3"; then
    printf 'PASS  %s\n' "$1"
  else
    failures=$((failures + 1))
    printf 'FAIL  %s: did not find [%s]\n' "$1" "$3"
  fi
}

check_not_contains() {
  # check_not_contains "label" "haystack" "needle"
  checks=$((checks + 1))
  if printf '%s' "$2" | grep -Fq -- "$3"; then
    failures=$((failures + 1))
    printf 'FAIL  %s: unexpectedly found [%s]\n' "$1" "$3"
  else
    printf 'PASS  %s\n' "$1"
  fi
}

if [ ! -f "$FIXTURE" ]; then
  echo "FAIL  fixture missing: $FIXTURE"
  exit 1
fi

# --- JSON mode: exact structural/numeric assertions ---
json_out="$(python3 "$ANALYZER" "$FIXTURE" --json)"
if [ -z "$json_out" ]; then
  echo "FAIL  analyzer produced no --json output"
  exit 1
fi

read_field() {
  # read_field '<python expr on the parsed dict named d>'
  python3 -c "
import json, sys
d = json.loads(sys.argv[1])
print($1)
" "$json_out"
}

check "orchestrator dominant model" \
  "$(read_field "d['orchestrator_model']['dominant']")" \
  "claude-opus-4-8"

# FIX 1: the fixture embeds one isSidechain:true assistant line tagged with
# a different model (claude-sonnet-4-5). If the analyzer stopped excluding
# sidechain lines from the orchestrator model count, this would read "2"
# (the one real orchestrator sonnet line at line 2, plus the sidechain one).
check "orchestrator model counts exclude sidechain line (sonnet)" \
  "$(read_field "d['orchestrator_model']['counts'].get('claude-sonnet-4-5')")" \
  "1"
check "orchestrator model counts (opus, unaffected by sidechain line)" \
  "$(read_field "d['orchestrator_model']['counts'].get('claude-opus-4-8')")" \
  "11"

check "agent calls total" \
  "$(read_field "d['agent_calls']['total']")" \
  "7"

check "agent tier: sonnet" "$(read_field "d['agent_calls']['by_tier'].get('sonnet')")" "2"
check "agent tier: opus" "$(read_field "d['agent_calls']['by_tier'].get('opus')")" "1"
check "agent tier: haiku" "$(read_field "d['agent_calls']['by_tier'].get('haiku')")" "2"
check "agent tier: none (missing model)" "$(read_field "d['agent_calls']['by_tier'].get('none')")" "1"

check "missing-model call line" \
  "$(read_field "d['agent_calls']['missing_model'][0]['line']")" \
  "13"

# FIX 4: the fixture's Workflow call (Lot F, no .input.model) must NOT be
# counted among the pinning-violation "missing_model" entries (still just
# Lot E), and must appear instead in its own workflow_calls category.
check "missing-model list excludes the Workflow call" \
  "$(read_field "len(d['agent_calls']['missing_model'])")" \
  "1"
check "workflow calls count" \
  "$(read_field "len(d['agent_calls']['workflow_calls'])")" \
  "1"
check "workflow call line" \
  "$(read_field "d['agent_calls']['workflow_calls'][0]['line']")" \
  "17"

check "advisory count (haiku + code-looking prompt)" \
  "$(read_field "len(d['advisory_haiku_code_prompts'])")" \
  "1"

check "advisory flagged line" \
  "$(read_field "d['advisory_haiku_code_prompts'][0]['line']")" \
  "11"

check "total input tokens" "$(read_field "d['tokens']['input_tokens']")" "14575"
check "total output tokens" "$(read_field "d['tokens']['output_tokens']")" "1855"
check "cache-read tokens" "$(read_field "d['tokens']['cache_read_input_tokens']")" "6590"
check "cache-creation tokens" "$(read_field "d['tokens']['cache_creation_input_tokens']")" "500"

# FIX 1: the fixture's sidechain line (line 5) carries nonzero usage
# (input_tokens 25, output_tokens 40) on claude-sonnet-4-5, a different
# model than the opus orchestrator. The next two checks are load-bearing
# for the split: if the split were removed and the sidechain line's output
# were merged into the main loop, main-loop output would read 1855 (not
# 1815) and sidechain output would read 0 (not 40), so both would fail.
check "main-loop output tokens (non-sidechain sum only)" \
  "$(read_field "d['tokens']['main_loop_output_tokens']")" \
  "1815"
check "sidechain output tokens (nonzero, proves the split is load-bearing)" \
  "$(read_field "d['tokens']['sidechain_output_tokens']")" \
  "40"
check "frontier share pct" "$(read_field "d['tokens']['frontier_share_pct']")" "98.1"

check "criteria-before-launch detected" \
  "$(read_field "d['criteria_before_launch']['detected']")" \
  "True"
check "criteria-before-launch line" \
  "$(read_field "d['criteria_before_launch']['detail']['line']")" \
  "3"
check "first agent call line" \
  "$(read_field "d['criteria_before_launch']['first_agent_call_line']")" \
  "4"

check "verification signal detected" \
  "$(read_field "d['verification_signal']['detected']")" \
  "True"
check "verification signal tool names" \
  "$(read_field "d['verification_signal']['tool_names']")" \
  "['Read', 'Bash']"
check "last agent return line" \
  "$(read_field "d['verification_signal']['last_agent_return_line']")" \
  "18"
check "final assistant line" \
  "$(read_field "d['verification_signal']['final_assistant_line']")" \
  "23"

check "retry duplicate description count" \
  "$(read_field "d['retries']['duplicate_descriptions'].get('Lot A: implement auth migration')")" \
  "2"

check "duration seconds" "$(read_field "d['duration']['seconds']")" "420.0"

check "parsed line count" "$(read_field "d['meta']['parsed_lines']")" "23"
check "skipped line count" "$(read_field "d['meta']['skipped_lines']")" "0"

# --- Human-readable mode: labeling and section assertions ---
human_out="$(python3 "$ANALYZER" "$FIXTURE")"

check_contains "human output labels EXACT" "$human_out" "[EXACT]"
check_contains "human output labels HEURISTIC" "$human_out" "[HEURISTIC]"
check_contains "human output labels BEST-EFFORT" "$human_out" "[BEST-EFFORT"
check_contains "human output flags pinning violation" "$human_out" "NO EXPLICIT MODEL (pinning violation)"
check_contains "human output flags Lot E missing model" "$human_out" "Lot E: misc cleanup"
check_contains "human output flags Lot D advisory" "$human_out" "Lot D: quick fix"
check_contains "human output shows frontier share" "$human_out" "98.1%"
check_contains "human output has caveats footer" "$human_out" "Caveats:"
check_contains "human output states orchestrator-only scope" "$human_out" "ORCHESTRATOR side only"

# FIX 3: the frontier-share line must read as the share of tokens visible in
# THIS transcript, not the true economic delegation split.
check_contains "human output relabels frontier share as transcript-visible" \
  "$human_out" "VISIBLE IN THIS TRANSCRIPT"
# FIX 1: this fixture's sidechain output tokens are now nonzero (40), so the
# "not the delegation cost split" note (which only prints when sidechain
# output tokens are exactly 0) must be ABSENT from this scorecard.
check_not_contains "human output omits the zero-sidechain note (sidechain tokens are nonzero here)" \
  "$human_out" "not the delegation cost split"

# FIX 4: the Workflow call (Lot F) must be reported in its own category, not
# folded into the pinning-violation list.
check_contains "human output reports Workflow calls as their own category" \
  "$human_out" "model pinned inside the workflow script, not checkable from the parent transcript"
check_contains "human output shows the Workflow call" "$human_out" "Lot F: parallel workflow batch"

# FIX 2: the caveats footer must describe sidechain handling truthfully
# instead of claiming subagent turns are never embedded.
check_contains "caveats footer documents isSidechain handling" "$human_out" "isSidechain: true"
check_not_contains "caveats footer no longer claims subagent transcripts are never embedded" \
  "$human_out" "does not embed a subagent's own"

# FIX 2: the module docstring must not carry the old, now-false claim either.
checks=$((checks + 1))
if grep -q "does NOT embed a subagent" "$ANALYZER"; then
  failures=$((failures + 1))
  echo "FAIL  docstring still claims a subagent's turns are never embedded"
else
  echo "PASS  docstring no longer claims a subagent's turns are never embedded"
fi

# --- Malformed-line tolerance: analyzer must not crash on bad JSON lines ---
tmp_bad="$(mktemp "${TMPDIR:-/tmp}/analyze-run-test.XXXXXX")"
cat "$FIXTURE" > "$tmp_bad"
echo "{not valid json" >> "$tmp_bad"
bad_out="$(python3 "$ANALYZER" "$tmp_bad" --json 2>&1)"
bad_rc=$?
rm -f "$tmp_bad"
checks=$((checks + 1))
if [ "$bad_rc" -eq 0 ] && printf '%s' "$bad_out" | grep -q '"skipped_lines": 1'; then
  echo "PASS  analyzer tolerates one malformed line (skipped_lines: 1, exit 0)"
else
  failures=$((failures + 1))
  echo "FAIL  analyzer did not tolerate a malformed line as expected (rc=${bad_rc})"
fi

echo "----------------------------------------"
if [ "$failures" -eq 0 ]; then
  echo "ALL TESTS PASSED (${checks} checks)"
  exit 0
else
  echo "${failures} of ${checks} checks FAILED"
  exit 1
fi
