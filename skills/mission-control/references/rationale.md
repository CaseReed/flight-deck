# Why mission-control works, and where it came from

Background rationale, not run-time instructions. SKILL.md points here; none
of this file needs to be read mid-run.

## Why this works (and why now)

- Frontier models like Claude Fable 5 (and Opus-class models generally) have
  become excellent at long-horizon planning and verification, but every turn
  is expensive and can run several minutes. Using them to execute every
  subtask means paying mission-control prices to push baggage carts.
- A small model with a precise spec delivers near-equivalent work on a
  well-scoped lot. All the quality lives in the scoping and the review, not
  in the executor's raw muscle.
- Verification by an agent with a fresh context beats self-critique: the
  executor can't see its own blind spots.

## Official positioning

The frontier session model does only four things itself: plan, orchestrate,
verify, decide. The official docs position it exactly there: "built for the
most demanding reasoning and long-horizon agentic work"
(https://platform.claude.com/docs/en/about-claude/models/introducing-claude-fable-5-and-claude-mythos-5),
"your hardest and longest-running tasks", "hand it ambiguous problems:
root-cause investigations, outage debugging, and architecture decisions"
(https://code.claude.com/docs/en/model-config), and it is NEVER the default,
always opt-in. On the other side: Sonnet is "daily coding tasks", "best
combination of speed and intelligence"; Haiku is "sub-agent tasks", the most
economical tier.

The same guide documents how to prompt Fable 5 subagents once a lot is
routed to it:
https://platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5
(the practical rules that follow from it live in
references/advanced-orchestration.md).

## The pricing argument

The frontier tiers cost several times more per token than Sonnet, and Sonnet
several times more than Haiku, so paying the top tier to execute every
subtask is exactly the waste this pattern removes. The payoff scales with
how much more expensive the session model is than the executor tier: the
bigger that gap, the more the pattern saves.

## The opusplan lineage

The "big model plans, small model executes" pattern already exists
officially through the `opusplan` alias (Opus plans, Sonnet executes); this
skill is its extension to Fable 5, and more generally to any frontier
session model.

## History

mission-control is the English successor of the French tour-de-controle
skill, renamed 2026-07-02. The rename also widened the scope: what started
as a Fable-only cost workaround now applies at the same default level to
Opus-class sessions too, because the plan/delegate/verify logic is judged
better engineering in general, not only a price mitigation forced by Fable
5's per-token cost.
