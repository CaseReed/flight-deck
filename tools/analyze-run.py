#!/usr/bin/env python3
"""Flight Deck transcript analyzer: a post-hoc reader of a Claude Code session
transcript (JSONL) that prints an objective mission-control scorecard.

WHAT THIS IS
------------
Claude Code already writes a complete, structured record of every session:
the transcript JSONL, with every assistant message, every model, every token
count, and every tool call, in file order. This script is a READER of that
data. It adds no runtime hooks, no new telemetry, and does not modify the
transcript or anything else. It serves three uses with the same code path:
the mission-control eval grader, the red-team scorer, and ad hoc field
analytics ("analyze my last mission-control run").

WHAT IT MEASURES
----------------
Only the ORCHESTRATOR side. A Claude Code transcript embeds the orchestrator's
own assistant turns, plus the Agent/Task/Workflow tool_use blocks (the briefs
it sends to subagents) and their tool_result blocks (the returned summaries).
Depending on the Claude Code version, the parent transcript MAY also embed a
subagent's own turns inline, marked with a top-level "isSidechain": true field
on those assistant lines. This script identifies sidechain lines by that field
and excludes them from every orchestrator-side metric below (model counts,
the agent-call inventory, the criteria-before-launch scan, and the
verification scan); their OUTPUT tokens are reported separately from the
orchestrator's main-loop output tokens, while their input and cache tokens
are not split out and remain merged into the aggregate totals.

Every metric printed below is explicitly labeled EXACT, HEURISTIC, or
BEST-EFFORT:
  EXACT       mechanically read from a documented field, no interpretation.
  HEURISTIC   a keyword or ordering rule that approximates a judgment call;
              always advisory, never a pass/fail verdict on its own.
  BEST-EFFORT depends on optional data (timestamps, description text reuse)
              that may be absent or ambiguous; reported when available.

KNOWN LIMITATION
----------------
The transcript JSONL is an internal Claude Code format that can drift across
product versions: field names, nesting, or the set of line "type" values may
change. This script reads only the specific fields it needs (documented next
to each accessor below) and is tested against the committed synthetic sample
at tools/sample-transcript.jsonl, not against a live schema contract. If a
future transcript format renames or restructures these fields, this script
should be expected to need an update, and its output should be treated as
"best current reading", not a guaranteed-stable API.

USAGE
-----
    python3 tools/analyze-run.py <path-to-transcript.jsonl>
    python3 tools/analyze-run.py <path-to-transcript.jsonl> --json
    python3 tools/analyze-run.py <path-to-transcript.jsonl> --no-cost

Python 3 standard library only. No pip install, no network access.
"""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter, defaultdict
from datetime import datetime, timezone


# ---------------------------------------------------------------------------
# Editable price table. USD per 1,000,000 tokens, by model tier.
# These are illustrative defaults, not a guaranteed-current price list: edit
# them to match your actual plan's published rates before trusting the dollar
# figures. The dollar-equivalent is optional and only ever reads this table;
# it is never hardcoded inline in the calculation below.
# NOTE: published prices change over time; the numbers below may already lag
# current rates. Check your provider's pricing page before trusting them.
# ---------------------------------------------------------------------------
PRICE_TABLE_USD_PER_MTOK = {
    "opus":    {"input": 15.00, "output": 75.00},
    "sonnet":  {"input": 3.00,  "output": 15.00},
    "haiku":   {"input": 1.00,  "output": 5.00},
    "fable":   {"input": 10.00, "output": 50.00},
    "unknown": {"input": 3.00,  "output": 15.00},  # fallback: treated as sonnet-equivalent
}

# Tiers considered "frontier" for the frontier-tier token share metric.
FRONTIER_TIERS = {"opus", "fable"}

# Tool names that represent a delegation call, as opposed to a direct tool
# action (Read, Bash, Edit, ...) taken by the orchestrator itself.
AGENT_CALL_NAMES = {"Agent", "Task", "Workflow"}

# Heuristic keyword lists. Edit freely; these are approximations, not a spec.
CODE_WRITING_KEYWORDS = [
    "implement", "fix the bug", "fix a bug", "write code", "write a function",
    "write the function", "refactor", "function", "class ", "def ", "```",
    "algorithm", "unit test", "parse", "bugfix", "stack trace", "compile",
    "regression", "edge case", ".py", ".ts", ".tsx", ".js", ".jsx", ".go",
    "endpoint", "api route", "schema migration",
]

CRITERIA_KEYWORDS = [
    "success criteria", "done criteria", "definition of done", "acceptance criteria",
    "criteria:", "criteria are", "done when", "must:", "checklist", "must include",
    "should include", "must pass", "verify that",
]


def classify_tier(model_str):
    """Classify a model identifier into a canonical tier: opus/sonnet/haiku/
    fable/unknown. Accepts either a full model id (e.g. "claude-opus-4-8",
    read from assistant .message.model) or a short tier string (e.g. "sonnet",
    read from an Agent/Task/Workflow tool_use's .input.model). Substring
    match, case-insensitive, checked in a fixed priority order so a string
    that happens to contain more than one tier name resolves deterministically.
    """
    if not model_str:
        return "unknown"
    s = str(model_str).lower()
    for tier in ("opus", "sonnet", "haiku", "fable"):
        if tier in s:
            return tier
    return "unknown"


def load_lines(path):
    """Parse the transcript file into a list of (line_no, dict) pairs.
    line_no is 1-indexed and doubles as the event-order key: the transcript
    format guarantees event order equals line order. Malformed lines are
    skipped and reported via the returned skipped count, never raising.
    """
    parsed = []
    skipped = 0
    with open(path, "r", encoding="utf-8") as f:
        for line_no, raw in enumerate(f, start=1):
            raw = raw.strip()
            if not raw:
                continue
            try:
                obj = json.loads(raw)
            except json.JSONDecodeError:
                skipped += 1
                continue
            if isinstance(obj, dict):
                parsed.append((line_no, obj))
            else:
                skipped += 1
    return parsed, skipped


def is_assistant_line(obj):
    return obj.get("type") == "assistant"


def content_blocks(obj):
    """Return the .message.content list for a line, or [] if absent/not a list.
    Reads: .message.content
    """
    msg = obj.get("message")
    if not isinstance(msg, dict):
        return []
    content = msg.get("content")
    return content if isinstance(content, list) else []


def analyze(path):
    lines, skipped = load_lines(path)
    total_lines = len(lines) + skipped

    # --- pass 1: collect assistant model tags, usage, and tool_use blocks ---
    orchestrator_model_counts = Counter()
    agent_calls = []          # dicts describing each Agent/Task/Workflow tool_use
    non_agent_tool_lines = [] # line_no of any other tool_use (Read/Bash/Edit/...)
    text_before_first_agent = []  # (line_no, text) assistant text/thinking blocks
    first_agent_line = None

    token_totals = {
        "input_tokens": 0,
        "output_tokens": 0,
        "cache_read_input_tokens": 0,
        "cache_creation_input_tokens": 0,
    }
    main_loop_output_tokens = 0     # isSidechain == False
    sidechain_output_tokens = 0     # isSidechain == True (subagent turn embedded here, rare)
    tokens_by_tier = defaultdict(lambda: {"input_tokens": 0, "output_tokens": 0})

    timestamps = []

    for line_no, obj in lines:
        ts = obj.get("timestamp")
        if isinstance(ts, str):
            timestamps.append(ts)

        if not is_assistant_line(obj):
            continue

        msg = obj.get("message", {})
        model = msg.get("model")
        is_sidechain = bool(obj.get("isSidechain", False))

        usage = msg.get("usage")
        if isinstance(usage, dict):
            in_tok = usage.get("input_tokens", 0) or 0
            out_tok = usage.get("output_tokens", 0) or 0
            cache_read = usage.get("cache_read_input_tokens", 0) or 0
            cache_creation = usage.get("cache_creation_input_tokens", 0) or 0

            token_totals["input_tokens"] += in_tok
            token_totals["output_tokens"] += out_tok
            token_totals["cache_read_input_tokens"] += cache_read
            token_totals["cache_creation_input_tokens"] += cache_creation

            if is_sidechain:
                sidechain_output_tokens += out_tok
            else:
                main_loop_output_tokens += out_tok

            tier = classify_tier(model)
            tokens_by_tier[tier]["input_tokens"] += in_tok
            tokens_by_tier[tier]["output_tokens"] += out_tok

        if is_sidechain:
            # An embedded subagent turn (see the module docstring). Its token
            # usage was already counted above (split out as sidechain, never
            # merged into main-loop), but everything below this point is
            # orchestrator-side accounting: model counts, the agent-call
            # inventory, and the criteria scan must see only the
            # orchestrator's own turns, never a subagent's.
            continue

        if model:
            orchestrator_model_counts[model] += 1

        for block in content_blocks(obj):
            if not isinstance(block, dict):
                continue
            btype = block.get("type")

            if btype in ("text", "thinking") and first_agent_line is None:
                text_val = block.get("text") or block.get("thinking") or ""
                if text_val:
                    text_before_first_agent.append((line_no, text_val))

            if btype == "tool_use":
                name = block.get("name")
                if name in AGENT_CALL_NAMES:
                    if first_agent_line is None:
                        first_agent_line = line_no
                    inp = block.get("input") if isinstance(block.get("input"), dict) else {}
                    agent_calls.append({
                        "line": line_no,
                        "id": block.get("id"),
                        "name": name,
                        "model": inp.get("model"),       # None/missing => pinning violation
                        "description": inp.get("description"),
                        "prompt": inp.get("prompt") or "",
                    })
                else:
                    non_agent_tool_lines.append(line_no)

    # --- Agent-call inventory (EXACT) ---
    # A Workflow tool_use has no top-level .input.model: a workflow script
    # pins models itself, on each agent() call inside it, so there is nothing
    # to check from the parent transcript. Report Workflow calls as their own
    # category instead of counting them as an un-pinned Agent/Task call.
    tier_breakdown = Counter()
    missing_model = []
    workflow_calls = []
    for call in agent_calls:
        if call["name"] == "Workflow":
            workflow_calls.append({"line": call["line"], "description": call["description"]})
            continue
        if call["model"]:
            tier_breakdown[classify_tier(call["model"])] += 1
        else:
            tier_breakdown["none"] += 1
            missing_model.append({"line": call["line"], "description": call["description"]})

    # --- Advisory: haiku pinned on code-looking prompts (HEURISTIC) ---
    advisory = []
    for call in agent_calls:
        if call["model"] and classify_tier(call["model"]) == "haiku":
            prompt_lower = call["prompt"].lower()
            matched = [kw for kw in CODE_WRITING_KEYWORDS if kw in prompt_lower]
            if matched:
                advisory.append({
                    "line": call["line"],
                    "description": call["description"],
                    "matched_keywords": matched,
                })

    # --- Token split (EXACT from usage) ---
    frontier_input = sum(tokens_by_tier[t]["input_tokens"] for t in FRONTIER_TIERS)
    frontier_output = sum(tokens_by_tier[t]["output_tokens"] for t in FRONTIER_TIERS)
    frontier_tokens = frontier_input + frontier_output
    all_tokens_in_out = token_totals["input_tokens"] + token_totals["output_tokens"]
    frontier_share_pct = (
        round(100.0 * frontier_tokens / all_tokens_in_out, 1) if all_tokens_in_out else 0.0
    )

    dollar_equivalent = 0.0
    for tier, toks in tokens_by_tier.items():
        rates = PRICE_TABLE_USD_PER_MTOK.get(tier, PRICE_TABLE_USD_PER_MTOK["unknown"])
        dollar_equivalent += (toks["input_tokens"] / 1_000_000.0) * rates["input"]
        dollar_equivalent += (toks["output_tokens"] / 1_000_000.0) * rates["output"]

    # --- Orchestrator model (EXACT) ---
    dominant_model = orchestrator_model_counts.most_common(1)[0][0] if orchestrator_model_counts else None

    # --- Criteria-before-launch (HEURISTIC) ---
    criteria_detected = None
    for line_no, text in text_before_first_agent:
        text_lower = text.lower()
        matched_kw = next((kw for kw in CRITERIA_KEYWORDS if kw in text_lower), None)
        if matched_kw:
            criteria_detected = {"line": line_no, "matched_keyword": matched_kw}
            break

    # --- Verification signal (HEURISTIC) ---
    # "Last subagent return" is the tool_result line whose tool_use_id matches
    # one of the Agent/Task/Workflow tool_use blocks' ids (not just any
    # tool_result: a Read or Bash call also produces a tool_result, and those
    # must NOT be mistaken for a subagent return). We match by id, then take
    # the one with the highest line number.
    agent_call_ids = {call["id"] for call in agent_calls if call.get("id")}
    last_agent_return_line = None
    if agent_call_ids:
        for line_no, obj in lines:
            if obj.get("type") != "user":
                continue
            msg = obj.get("message", {})
            content = msg.get("content")
            if not isinstance(content, list):
                continue
            for block in content:
                if (isinstance(block, dict) and block.get("type") == "tool_result"
                        and block.get("tool_use_id") in agent_call_ids):
                    last_agent_return_line = line_no

    final_assistant_line = None
    for line_no, obj in lines:
        if is_assistant_line(obj) and not obj.get("isSidechain", False):
            final_assistant_line = line_no

    verification_tool_names = []
    if last_agent_return_line is not None and final_assistant_line is not None:
        for line_no, obj in lines:
            if line_no <= last_agent_return_line or line_no >= final_assistant_line:
                continue
            if not is_assistant_line(obj):
                continue
            if obj.get("isSidechain", False):
                continue
            for block in content_blocks(obj):
                if isinstance(block, dict) and block.get("type") == "tool_use":
                    name = block.get("name")
                    if name not in AGENT_CALL_NAMES:
                        verification_tool_names.append(name)

    verification_detected = bool(verification_tool_names)

    # --- Retry/loop count (BEST-EFFORT): repeated Agent descriptions ---
    description_counts = Counter(
        call["description"] for call in agent_calls if call["description"]
    )
    duplicate_descriptions = {
        desc: count for desc, count in description_counts.items() if count > 1
    }

    # --- Duration (BEST-EFFORT) ---
    duration_seconds = None
    start_ts = end_ts = None
    if timestamps:
        parsed_ts = []
        for ts in timestamps:
            try:
                # Handles the "...Z" suffix used in transcript timestamps.
                parsed_ts.append(datetime.fromisoformat(ts.replace("Z", "+00:00")))
            except ValueError:
                continue
        if parsed_ts:
            start_dt = min(parsed_ts)
            end_dt = max(parsed_ts)
            start_ts = start_dt.isoformat()
            end_ts = end_dt.isoformat()
            duration_seconds = (end_dt - start_dt).total_seconds()

    return {
        "meta": {
            "path": path,
            "total_lines": total_lines,
            "parsed_lines": len(lines),
            "skipped_lines": skipped,
        },
        "orchestrator_model": {
            "dominant": dominant_model,
            "counts": dict(orchestrator_model_counts),
        },
        "agent_calls": {
            "total": len(agent_calls),
            "by_tier": dict(tier_breakdown),
            "missing_model": missing_model,
            "workflow_calls": workflow_calls,
        },
        "advisory_haiku_code_prompts": advisory,
        "tokens": {
            **token_totals,
            "main_loop_output_tokens": main_loop_output_tokens,
            "sidechain_output_tokens": sidechain_output_tokens,
            "by_tier": {t: dict(v) for t, v in tokens_by_tier.items()},
            "frontier_tokens_in_out": frontier_tokens,
            "total_tokens_in_out": all_tokens_in_out,
            "frontier_share_pct": frontier_share_pct,
            "dollar_equivalent_usd": round(dollar_equivalent, 4),
        },
        "criteria_before_launch": {
            "detected": criteria_detected is not None,
            "detail": criteria_detected,
            "first_agent_call_line": first_agent_line,
        },
        "verification_signal": {
            "detected": verification_detected,
            "tool_names": verification_tool_names,
            "last_agent_return_line": last_agent_return_line,
            "final_assistant_line": final_assistant_line,
        },
        "retries": {
            "duplicate_descriptions": duplicate_descriptions,
        },
        "duration": {
            "start": start_ts,
            "end": end_ts,
            "seconds": duration_seconds,
        },
    }


def format_scorecard(result, show_cost=True):
    lines = []
    add = lines.append
    meta = result["meta"]

    add("=" * 72)
    add("Mission-Control Scorecard (transcript-only, post-hoc)")
    add("=" * 72)
    add(f"Transcript : {meta['path']}")
    add(f"Lines      : {meta['total_lines']} total, {meta['parsed_lines']} parsed, "
        f"{meta['skipped_lines']} skipped (malformed JSON)")
    add("")

    om = result["orchestrator_model"]
    add("1. Orchestrator model  [EXACT]")
    add(f"   Dominant model (by assistant message count): {om['dominant']}")
    for model, count in sorted(om["counts"].items(), key=lambda kv: -kv[1]):
        add(f"     - {model}: {count} assistant message(s)")
    add("")

    ac = result["agent_calls"]
    add("2. Agent-call inventory  [EXACT]")
    add(f"   Total Agent/Task/Workflow calls: {ac['total']}")
    for tier in ("opus", "sonnet", "haiku", "fable", "unknown", "none"):
        if tier in ac["by_tier"]:
            label = "NO EXPLICIT MODEL (pinning violation)" if tier == "none" else tier
            add(f"     - {label}: {ac['by_tier'][tier]}")
    if ac["missing_model"]:
        add("   Pinning compliance: FAILED, calls with no .input.model:")
        for m in ac["missing_model"]:
            add(f"     - line {m['line']}: \"{m['description']}\"")
    else:
        add("   Pinning compliance: OK, every Agent/Task/Workflow call had an explicit model.")
    if ac["workflow_calls"]:
        add(f"   Workflow calls (model pinned inside the workflow script, not checkable "
            f"from the parent transcript): {len(ac['workflow_calls'])}")
        for w in ac["workflow_calls"]:
            add(f"     - line {w['line']}: \"{w['description']}\"")
    add("")

    adv = result["advisory_haiku_code_prompts"]
    add("3. Advisory: haiku pinned on a code-writing-looking prompt  [HEURISTIC, advisory only]")
    if adv:
        for a in adv:
            add(f"   - line {a['line']}: \"{a['description']}\" "
                f"(matched: {', '.join(a['matched_keywords'])})")
    else:
        add("   None flagged.")
    add("")

    tok = result["tokens"]
    add("4. Token split  [EXACT from usage; dollar-equivalent OPTIONAL/approximate]")
    add(f"   Total input tokens               : {tok['input_tokens']}")
    add(f"   Total output tokens               : {tok['output_tokens']}")
    add(f"   Cache-read input tokens           : {tok['cache_read_input_tokens']}")
    add(f"   Cache-creation input tokens       : {tok['cache_creation_input_tokens']}")
    add(f"   Main-loop (non-sidechain) output   : {tok['main_loop_output_tokens']}")
    add(f"   Sidechain (embedded subagent) out. : {tok['sidechain_output_tokens']}")
    add(f"   Frontier-tier (opus/fable) share of tokens VISIBLE IN THIS TRANSCRIPT (in+out) : "
        f"{tok['frontier_tokens_in_out']} of {tok['total_tokens_in_out']} "
        f"({tok['frontier_share_pct']}%)")
    if tok["sidechain_output_tokens"] == 0:
        add("   Note: subagent token usage is not embedded in this transcript; this is")
        add("   not the delegation cost split, only the share of tokens this transcript")
        add("   happens to contain.")
    for tier, v in sorted(tok["by_tier"].items()):
        add(f"     - {tier}: input={v['input_tokens']}, output={v['output_tokens']}")
    if show_cost:
        add(f"   Dollar-equivalent (illustrative and may lag current pricing; edit "
            f"PRICE_TABLE_USD_PER_MTOK): ${tok['dollar_equivalent_usd']:.4f}")
    add("")

    cbl = result["criteria_before_launch"]
    add("5. Criteria-before-launch  [HEURISTIC]")
    if cbl["detected"]:
        d = cbl["detail"]
        add(f"   Detected: criteria-like text at line {d['line']} "
            f"(matched keyword: \"{d['matched_keyword']}\"), "
            f"before first Agent call at line {cbl['first_agent_call_line']}.")
    else:
        add("   Not detected: no criteria-like keyword found in an assistant message "
            f"before the first Agent call (line {cbl['first_agent_call_line']}).")
    add("")

    vs = result["verification_signal"]
    add("6. Verification signal  [HEURISTIC]")
    if vs["detected"]:
        add(f"   Detected: tool action(s) {vs['tool_names']} between the last subagent "
            f"return (line {vs['last_agent_return_line']}) and the final assistant "
            f"message (line {vs['final_assistant_line']}).")
    else:
        add("   Not detected: no tool action found between the last subagent return "
            "and the final assistant message.")
    add("")

    rt = result["retries"]
    add("7. Retry/loop count  [BEST-EFFORT: repeated Agent descriptions]")
    if rt["duplicate_descriptions"]:
        for desc, count in rt["duplicate_descriptions"].items():
            add(f"   - \"{desc}\": called {count} times")
    else:
        add("   No repeated Agent descriptions found.")
    add("")

    dur = result["duration"]
    add("   Duration  [BEST-EFFORT: from timestamp field, if present]")
    if dur["seconds"] is not None:
        add(f"   Start: {dur['start']}  End: {dur['end']}  Elapsed: {dur['seconds']:.1f}s")
    else:
        add("   Not available: no parsable timestamp field found in this transcript.")
    add("")

    add("-" * 72)
    add("Caveats:")
    add("  EXACT      = mechanically read from a documented transcript field.")
    add("  HEURISTIC  = keyword/ordering approximation; advisory, not a verdict.")
    add("  BEST-EFFORT= depends on optional data (timestamps, description reuse).")
    add("  This scorecard measures the ORCHESTRATOR side only. Depending on the")
    add("  Claude Code version, the parent transcript may also embed a subagent's")
    add("  own turns inline, marked with isSidechain: true; when present, those")
    add("  lines are excluded from every orchestrator-side metric above (model")
    add("  counts, agent-call inventory, criteria scan, verification scan), and")
    add("  their token usage is split out separately, never merged into the")
    add("  main-loop counts.")
    add("  The transcript JSONL is an internal format that can drift across")
    add("  Claude Code versions; this script reads only the fields it needs and")
    add("  is tested against tools/sample-transcript.jsonl, not a schema contract.")
    add("=" * 72)
    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(
        description="Print an objective mission-control scorecard from a Claude Code "
                    "session transcript JSONL. Reader only, python3 stdlib only."
    )
    parser.add_argument("transcript", help="path to a session transcript .jsonl file")
    parser.add_argument("--json", action="store_true",
                         help="emit machine-readable JSON instead of the human scorecard")
    parser.add_argument("--no-cost", action="store_true",
                         help="omit the optional dollar-equivalent line from the human scorecard")
    args = parser.parse_args()

    try:
        result = analyze(args.transcript)
    except FileNotFoundError:
        print(f"error: transcript not found: {args.transcript}", file=sys.stderr)
        sys.exit(2)

    if args.json:
        print(json.dumps(result, indent=2))
    else:
        print(format_scorecard(result, show_cost=not args.no_cost))


if __name__ == "__main__":
    main()
