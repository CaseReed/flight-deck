# Advanced orchestration mechanics

Low-frequency mechanics: the Workflow tool, supervised up-delegation, and
Fable-5-specific subagent prompting. SKILL.md points here when a run actually
needs one of these; most runs don't.

## The Workflow tool (4+ lots, structured returns, chaining, budgets)

For 2-3 lots, plain parallel Agent calls are enough (see SKILL.md). For 4+
lots, or a need for structured returns, lot-to-check chaining, or a cost
ceiling, use the Workflow tool instead:

- One `agent()` call per lot, with the plan's `model` AND `effort` both set
  explicitly on the call.
- A JSON `schema` on each agent forces a structured return
  (`{deliverable_path, self_check_per_criterion}`) that can be validated
  without parsing free text.
- `pipeline()` chains execution then the mechanical check, lot by lot,
  WITHOUT a barrier: a finished lot gets checked while the others are still
  running.
- `budget` applies when the user has set a token envelope for the run.
- `phase()` surfaces PLAN / DELEGATE / VERIFY progress to the user.
- `resumeFromRunId` re-runs only the changed lots on a retry; the rest comes
  from cache.

**On a Fable 5 session with the fan-out guard hook active, the guard denies
Workflow calls outright.** Once the user has explicitly approved running the
workflow on Fable 5, include the token `FABLE_OK` in the workflow's args so
the guard lets it through. Never add that token without the user's explicit
approval for that run.

If this environment exposes no Workflow tool, and no SendMessage or
resumeFromRunId either, fall back to parallel Agent calls even past 4 lots:
just launch more subagents in the same turn.

## Supervised up-delegation (the one exception)

The routing rule always points down: never delegate to a model more
expensive than the session's. The one narrow exception: a session on a lower
or equal tier may, deliberately and occasionally, delegate a single
high-value lot (a fine-grained audit, a root-cause dig) to a more expensive
model, for example Fable 5, under hard limits:

- **Scope is narrow and explicit**: one lot, named precisely, never "the
  rest of the task while you're at it."
- **`effort` is capped** at what that lot actually needs, not left at the
  up-delegated model's own default.
- **Assessment-only when the lot is an audit**: it reports findings, it does
  not modify anything; a fix, if needed, comes back as a separate,
  normally-routed lot.
- **The run is watched with a cutoff**: track a proxy for runaway cost, such
  as transcript size, and stop the run if it grows well past what the lot's
  scope justifies.

Up-tiering is a supervised exception you reach for on purpose, never a
default you fall into.

## Prompting subagents for Fable 5

When a lot is routed to Fable 5, whether it is the orchestrating session
itself or a lot up-delegated under the exception above, brief it like this:

- **Set `effort` per lot explicitly.** `medium` is the default for routine
  analysis or writing; reserve `high` for a lot where detection quality is
  genuinely critical (a security-sensitive review, a hard root-cause dig).
  Don't reach for `high` by reflex, Fable 5 at `medium` often already
  outperforms older models running at their top setting.
- **Keep briefs self-contained.** The subagent sees none of this
  conversation: inline the material, the done criteria, and the *why*.
- **One instruction beats an enumeration.** Fable 5 follows a short, clear
  principle well; state the intent once and trust it to generalize instead
  of listing every case it should or shouldn't handle.
- **On a long-running lot, anchor progress claims in tool results.** Ask it
  to report only what it can point to evidence for, and to say plainly when
  something is not yet verified, rather than asserting a status from memory.
- **Never ask a Fable 5 subagent to echo, transcribe, or explain its
  internal reasoning in its response text.** Prompts like "show your
  reasoning step by step" risk tripping the `reasoning_extraction` safety
  classifier, which can trigger a refusal and a fallback to Opus for that
  call (documented in Anthropic's "Prompting Claude Fable 5" guide:
  platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5).
  Ask for the conclusion and the evidence behind it, never a replay of how
  the model got there.
