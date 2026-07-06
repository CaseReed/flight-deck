---
name: mission-control
description: >-
  Plan with the session's frontier model, delegate execution to per-lot
  calibrated subagents, then verify adversarially before closing out.
  Frontier-model quality without paying frontier price on every line. On a
  Claude Fable 5 or Opus session this is the default mode for any substantial
  multi-lot task (folder audit, multi-file migration, series of deliverables,
  multi-source analysis) once the activation rule from CLAUDE-md-activation.md
  is added to the global CLAUDE.md. A single-pass simple task (a Jira ticket, a draft, a
  web search, a reformat) never runs inline on the frontier model, it goes out
  as simple delegation to one sonnet or haiku subagent. Triggers: "mission
  control", "orchestrate this task", "plan-delegate-verify". Opt out with
  "without mission control", "no mission control", "do it yourself".
when_to_use: >-
  Applies on Fable 5 and Opus-class frontier sessions to any substantive
  multi-lot task without being asked, unless opted out. Trigger and opt-out
  phrases are also recognized in the user's working language (for example a
  French user's "sans mission control"). On non-frontier sessions (Sonnet,
  Haiku) it stays opt-in through the explicit triggers only.
metadata:
  author: Julien Tavernier
  origin: "English successor of the French tour-de-controle skill (2026-07-02)"
---

# mission-control: plan, delegate, verify

The principle: **the frontier model is too valuable to execute, and too good not to
verify.** On a large task, you don't ask it to do everything, you ask it for the two
things where it beats everything else: **the plan** and **the quality control**.
Execution goes to smaller, faster, cheaper subagents that work in parallel.

```
         PLAN                     DELEGATE                   VERIFY
   (frontier model, once)   (small agents, in //)     (frontier model, once)
   ┌──────────────────┐     ┌──────┐ ┌──────┐         ┌──────────────────┐
   │ full spec        │ →   │lot 1 │ │lot 2 │ ...  →  │ check against    │
   │ + "done" criteria│     └──────┘ └──────┘         │ the plan's       │
   │ per lot          │     each lot = one            │ criteria, lot    │
   └──────────────────┘     autonomous agent          │ by lot           │
                                                      └──────────────────┘
                                                        ↳ what fails goes
                                                          back as a
                                                          targeted lot
```

Why this works (and why now):
→ Frontier models like **Claude Fable 5** (and Opus-class models generally) have become
  excellent at long-horizon planning and verification, but every turn is expensive and
  can run several minutes. Using them to execute every subtask means paying
  mission-control prices to push baggage carts.
→ A small model with a **precise spec** delivers near-equivalent work on a well-scoped
  lot. All the quality lives in the scoping and the review, not in the executor's raw
  muscle.
→ Verification by an **agent with a fresh context** beats self-critique: the executor
  can't see its own blind spots.

## When to use it

- **Automatically on a Fable 5 or Opus-class session, once you add the activation rule
  from `CLAUDE-md-activation.md` (shipped at the package root) to your global
  CLAUDE.md**: that rule is what makes this the default execution mode on every
  eligible task, mandates the start-of-session announcement, and gives the opt-out on
  request ("without mission control", or the equivalent in the user's working
  language). Once that block is pasted, Fable 5 and Opus sit at the same default
  level, this is not a Fable-only rule with Opus as a soft afterthought: the
  plan/delegate/verify logic is judged better engineering in general, not only a cost
  workaround forced by Fable 5's price.
- A task with **several independent lots**: auditing a folder, migrating files,
  producing a series of documents, multi-source analysis, a section-by-section rewrite.
- The user wants to **cap cost** while keeping frontier-model quality where it matters.
- The task has **verifiable success criteria** (or can be given some).

## When NOT to orchestrate in 3 phases (but still delegate)

- A short or sequential task that a single pass settles, the 3-phase orchestration
  would cost more than the work itself. **On a frontier session model, "a single pass"
  does NOT mean "the frontier model executes it inline"**: the task goes out as
  **simple delegation** (next section), one calibrated subagent. The frontier model
  writes the brief and checks the result, that's it.
- A creative task that has to stay a single piece (a text, a design): splitting it
  breaks coherence. It goes out as simple delegation to ONE agent (sonnet, opus if it
  is publication-grade).
- Rapid-fire micro-tasks: a subagent starts from zero (fresh context to rebuild),
  delegation only pays off on volume lots, not on one-minute touch-ups.

## Simple delegation, the single-pass mode

**On a frontier session model, it does only four things itself: plan, orchestrate,
verify, decide.** The official docs position it exactly there: "built for the most
demanding reasoning and long-horizon agentic work"
(https://platform.claude.com/docs/en/about-claude/models/introducing-claude-fable-5-and-claude-mythos-5),
"your hardest and longest-running tasks", "hand it ambiguous problems: root-cause
investigations, outage debugging, and architecture decisions"
(https://code.claude.com/docs/en/model-config), and it is NEVER the default, always
opt-in. On the other side: Sonnet is "daily coding tasks", "best combination of speed
and intelligence"; Haiku is "sub-agent tasks", the most economical tier. The frontier
tiers cost several times more per token than Sonnet, and Sonnet several times more than
Haiku, so paying the top tier to execute every subtask is the waste this pattern
removes. The payoff scales with how much more expensive the session model is than the
executor tier. The "big model plans, small model executes" pattern already exists
officially through the `opusplan` alias (Opus plans, Sonnet executes); this skill is
its extension to Fable. Everything else is EXECUTION. Even simple, even single-pass,
it gets delegated. Creating a Jira ticket or running a web search with Fable 5 means
running a mission-control-priced baggage cart: a routine single-pass task run inline
on the frontier model is exactly the mistake this section corrects.

How it runs (lightweight, not the full 3 phases):
1. The frontier model writes ONE self-contained brief: mission, source material copied
   in full (the subagent sees nothing of the conversation), done criteria, expected
   output format.
2. ONE Agent call with the model set by the routing grid: `sonnet` by default (Jira
   creation/editing, Slack/email drafts, short writing, small edits, **web and
   documentation research**: official docs, fact-checking, library due diligence),
   `haiku` if it is pure mechanical work outside code (extract, count, reformat).
3. The frontier model checks the result against the criteria (one read, not a
   counter-investigation), fixes at most one trivial line itself, anything larger
   goes back as a retry with the exact edit list, single loop.

Stays inline for the frontier model (the only exceptions):
- **Conversational** turns: answering, explaining, analyzing in the thread, giving an
  opinion.
- A **micro fix**: one trivial line on context already loaded in the conversation, no
  more. A series of edits, or editing a skill, doc, or config file, is execution and
  gets delegated with the exact edit list.
- What the subagent **cannot do**: a user-facing decision, an action on a tool
  unavailable to subagents, a call that commits the rest of the session.

## Workflow (3 phases)

### Phase 1: PLAN (you, the frontier model, maximum effort)

0. **RECALL first.** Before splitting anything, sweep what the project already knows:
   the session's persistent memory (the MEMORY.md index and any entry it points to) and
   the project's own docs (CLAUDE.md, README, design notes) for prior decisions,
   conventions, and gotchas bearing on this task. Cite in the plan what applies, or
   state 'nothing relevant found'. A plan that ignores a decision already recorded
   re-litigates settled ground or repeats a known mistake.
1. **Full spec first.** If the request is vague, ask ALL your questions in a single
   turn (goal, scope, constraints, output format, examples of "good"). A plan built on
   a vague request produces vague lots, and lost subagents.
2. **Split into independent lots.** Each lot must be executable alone, without seeing
   the others. If two lots depend on each other, merge them or sequence them.
   Independence is logical AND physical: two lots that WRITE never share a file (two
   parallel agents on the same file silently clobber each other). If overlap is
   unavoidable, sequence the lots or isolate them with `isolation: worktree` on the
   Agent tool.
3. **For each lot, write 4 things** in a plan shown to the user:
   - **Mission**: one sentence, action verb.
   - **Material**: the exact files, data, or links the lot needs, plus the exact
     output path if the deliverable is a file.
   - **Done criteria**: 2 to 4 **verifiable** criteria (not "good quality", but
     "contains the exact figures from the source table", "under 300 words", "0 dead
     links"). For any lot that writes code meant to run, at least one done criterion
     MUST be a test-evidence criterion authored via the test-discipline skill (a named
     check that passes, its output cited), never a subjective "works".
   - **Model + effort**: the execution tier AND the reasoning level chosen from the
     routing grid (see Defaults below), with a 3-5 word justification ("pure
     mechanics", "nuanced writing"...). Routing is decided AT PLANNING TIME, never
     improvised at launch.
3b. **Distill the intent, don't relay the words.** The user's request is raw material,
    not the brief. Before a lot is briefed, restate its objective in the subagent's
    terms: inline the context the subagent cannot see (it has none of this
    conversation), give the *why* behind the ask (a subagent that knows the goal
    generalizes; one that only has the words guesses), and **cut the scope to YAGNI**,
    dropping every ask not needed to hit the done criteria, because a subagent briefed
    to over-deliver over-builds (extra layers, defensive code, tests for cases that
    cannot happen). This is not a rewrite ritual: if the request is already objective +
    scope + stop-condition, pass it as-is. The trigger is the colleague test, would a
    stranger with none of this conversation know exactly what to do and when to stop?
    If not, that gap is what you distill, nothing more.
4. Confirm the plan with the user if the task is heavy or ambiguous. Otherwise,
   proceed.

### Phase 2: DELEGATE (calibrated subagents, in parallel)

5. **Pick the orchestration tool for the size of the run**:
   - **2-3 lots**: the Agent/Task tool, one subagent per lot with the **model assigned
     in the plan** (`model: "haiku"` / `"sonnet"` / `"opus"`), all launched **in the
     same turn** so they run in parallel.
   - **4+ lots, or a need for structured returns, lot-to-check chaining, or a cost
     ceiling**: the Workflow tool. One `agent()` per lot with the plan's `model` AND
     `effort`; a JSON `schema` on each agent to force a structured return
     ({deliverable_path, self_check_per_criterion}) validated without parsing;
     `pipeline()` to chain execution then mechanical check lot by lot WITHOUT a barrier
     (a finished lot gets checked while the others are still running); `budget` when
     the user has set a token envelope; `phase()` so the user sees PLAN / DELEGATE /
     VERIFY progress. Same routing grid, applied natively. **On a Fable 5 session with
     the fan-out guard hook active, the guard denies Workflow calls outright**: once
     the user has explicitly approved running the workflow on Fable 5, include the
     token `FABLE_OK` in the workflow's args so the guard lets it through. **Fallback**:
     if this environment exposes no Workflow tool, and no SendMessage or
     resumeFromRunId either, the 2-3 lots rule above (parallel Agent calls) also
     applies to 4+ lots: just launch more subagents in the same turn instead.
6. **Each subagent's prompt is self-contained**: it sees NOTHING of the conversation.
   Copy into it the mission, the material (full paths), the done criteria, and the
   expected output format. End with THE closing instruction that matches the lot:
   - **Small deliverable** (fits in under a page, not meant to be a file): "Your final
     response IS the deliverable, return the raw content, not a summary of what you
     did."
   - **Large deliverable or a file**: "WRITE the deliverable to disk at the path fixed
     by the plan; your final response contains only that path plus your self-check
     against each done criterion."
   - **Code lot**: invoke the `test-discipline` skill, run the repo's named check, and
     put the tail of its output in your self-check. A code deliverable with no cited
     check output is unverified.
   Why: N lots returning their raw content flood the orchestrator's context, and it is
   the VERIFY phase (the one that justifies the whole pattern) that pays the price.
7. While the agents are running, don't redo their work yourself. Wait.

### Phase 3: VERIFY (you, the frontier model, inspector hat on)

8. **Check each deliverable against its done criteria, actively trying to reject it.**
   For each criterion, ask: "what would prove this failed?" and go verify against the
   sources (re-read the produced file, cross-check the figures, test the links). A
   deliverable that "looks fine" without evidence is unverified. **Past roughly 6
   lots, parallelize the mechanical checks**: delegate the mechanically verifiable
   criteria (counts, links, formats, tests that pass) to fresh-context verifier
   subagents (`haiku`/`sonnet`, low effort), one per lot, launched in parallel. Keep
   the final call and the judgment criteria for yourself. This is the skill's own
   argument turned on itself: a fresh verifier beats self-critique, including yours.
8b. **Check for over-delivery, not just under-delivery.** A lot can pass every done
    criterion and still be over-engineered, because done criteria measure presence ('it
    does X'), never restraint ('it does ONLY X'). For each deliverable ask: is there
    anything here the criteria did not require, an abstraction with a single caller, a
    config knob nobody asked for, defensive code for inputs that cannot occur, a test for
    a case that cannot happen? Flag it and trim it. Over-engineering is a defect even when
    the feature works, and this verify pass is the only place the pattern catches it.
9. **What fails goes back as a targeted lot**: resume the executing agent via
   SendMessage if the environment allows it (its context is intact; on a Workflow run,
   relaunch with `resumeFromRunId`, only the changed lots re-run, the rest comes from
   cache), otherwise a new subagent, in both cases handing it the faulty deliverable,
   the failed criterion, and the expected fix. Maximum **2 retry loops**, beyond that,
   take the lot back yourself or escalate the blocker to the user.
   **Tier escalation**: if the 1st retry fails on the same model, the 2nd launches one
   tier up (haiku to sonnet to opus, the last rung being you, the session model,
   taking the lot over directly). A repeated failure is rarely a briefing problem, it
   is an under-calibrated lot, and one tier up costs less than a 3rd loop.
   **Check the source before escalating**: when stuck (real uncertainty, or a lot that
   failed twice), check the authoritative source before guessing or escalating: the
   official docs for the problem, the library's own source or spec, the actual error.
   If the official source does not settle it, run a targeted web search. A repeated
   failure is often missing information, not an under-calibrated lot, and no tier
   upgrade fixes a wrong assumption.
   **Micro-fix exception**: a trivial, mechanical deviation (1 line or less to delete
   or replace) gets fixed directly during the check and noted in the report, a full
   loop for that would be wasteful. Several corrections found in the same verify pass
   are a batch, and a batch is execution: hand the full edit list to one sonnet
   subagent instead of applying it yourself, even when the files are skills or docs.
10. **Final report** to the user: what was produced (with paths), what was verified
    and how, what was retried, what remains open. Never "everything looks good"
    without pointing at the evidence.
11. **Knowledge pass at close-out.** Once the work is confirmed done, record what is
    durable and non-derivable (a decision, a gotcha, a new convention, a status that
    outlives the session) to the right scope, and prune what this work made stale. Route
    by scope: a project-specific fact goes to that project's memory or its CLAUDE.md, a
    cross-project preference or doctrine goes to global memory or the global CLAUDE.md.
    Skip anything the code, the git history, or an existing doc already records. If nothing
    qualifies, that is fine, but the pass itself is not optional.

## Defaults, the routing grid

**Routing is relative to your session model, not to fixed names.** The session model
orchestrates (plans and verifies); execution always routes to the tiers BELOW it. The
grid below assumes a top-tier session, so shift the names down to match where yours sits:
- **Session = Fable 5**: orchestrate with Fable; code and nuanced lots to Opus or Sonnet;
  mechanical lots to Haiku.
- **Session = Opus**: orchestrate with Opus; code lots to Sonnet; mechanical lots to Haiku.
- **Session = Sonnet**: orchestrate with Sonnet; mechanical lots to Haiku; code stays on
  Sonnet. Less headroom, so the pattern pays off less, which is expected.
Rule: never delegate a lot to a model more expensive than your session model. The
orchestrator is the ceiling, execution lives under it. Read the table's tier names
relative to your own session, not as absolutes.

| Role | Model | Effort | When |
|---|---|---|---|
| Planning + verification | the session model (ideally Fable 5 / Opus) | high (xhigh to verify a critical lot) | Always, this is where intelligence pays off |
| Mechanical execution | `haiku` | low | Zero judgment required, outside code: extract, list, count, reformat, inventory |
| Standard execution (**default**) | `sonnet` | medium (high for real code or tight criteria) | Analysis, synthesis, structured writing, web/documentation research, and ANY lot touching real code, 90% of the quality at a fraction of the cost |
| Complex execution | `opus` | high (xhigh for hard code) | Nuanced judgment, publication-grade writing, multi-step reasoning WITHIN the lot, ambiguous or contradictory material |

Routing rules:
→ **When torn between two tiers**, pick the higher tier if the lot is expensive to
  redo or sits on the critical path, the lower one otherwise. A retry costs more than
  the price gap between two tiers.
→ **`opus` stays the exception, not the rule.** If most lots need `opus`, the split is
  bad (lots too big, too ambiguous), re-split, or accept the task isn't a fit for
  delegation.
→ **When in doubt, let the done criteria decide**: a lot OUTSIDE CODE whose criteria
  are purely mechanical ("exact count", "exhaustive list") never needs more than
  `haiku`, whatever the size of the material. On code, this rule yields to the next
  one: mechanical criteria ("tests pass", "0 tsc errors") never pull a code lot below
  `sonnet`.
→ **Real code routes to `sonnet` minimum, never `haiku`.** As soon as a lot writes or
  edits code meant to run (source files, tests, scripts, executable config), it is
  `sonnet` even if the brief sounds mechanical. A "trivial" rename breaks an import. A
  "dumb" migration misses an edge case. The retry costs more than the tier gap. `haiku`
  stays acceptable on code only in READ mode (inventorying usages, counting
  occurrences), never in write mode.
→ **Effort is set wherever the environment exposes it**: the `effort` parameter on
  Workflow subagents, or an agent definition's frontmatter (`.claude/agents/*.md`). If
  the Agent tool in use doesn't expose effort per call, the Model column alone carries
  the routing, don't improvise a workaround.
→ **Effort is the 2nd cost lever after the tier.** Every notch adds reasoning tokens
  and latency. `low` on mechanical lots is the pattern's safest saving. `xhigh` is
  reserved for two cases: hard code on `opus`, and your own verification of a critical
  lot. Raising effort never rescues a badly specified lot.

### Supervised up-delegation (the one exception)

The rule above always points down: never a model more expensive than the session's.
The one narrow exception: a session on a lower or equal tier may, deliberately and
occasionally, delegate a single high-value lot (a fine-grained audit, a root-cause
dig) to a more expensive model, for example Fable 5, under hard limits:
→ **Scope is narrow and explicit**: one lot, named precisely, never "the rest of the
  task while you're at it."
→ **`effort` is capped** at what that lot actually needs, not left at the up-delegated
  model's own default.
→ **Assessment-only when the lot is an audit**: it reports findings, it does not
  modify anything; a fix, if needed, comes back as a separate, normally-routed lot.
→ **The run is watched with a cutoff**: track a proxy for runaway cost, such as
  transcript size, and stop the run if it grows well past what the lot's scope
  justifies.
Up-tiering is a supervised exception you reach for on purpose, never a default you
fall into.

Golden rules:
→ **Never more lots than necessary.** 3 well-specified big lots beat 10 crumbs.
→ **Done criteria are written BEFORE launching the agents**, never after, otherwise
  you end up checking what was produced instead of what was asked for.
→ **Verification is not optional.** Skip phase 3 and the whole pattern collapses: you
  just paid less for an unchecked result.

## Prompting subagents for Fable 5

When a lot is routed to Fable 5, whether it is the orchestrating session itself or a
lot up-delegated under the exception above, brief it like this:

- **Set `effort` per lot explicitly.** `medium` is the default for routine analysis or
  writing; reserve `high` for a lot where detection quality is genuinely critical (a
  security-sensitive review, a hard root-cause dig). Don't reach for `high` by reflex,
  Fable 5 at `medium` often already outperforms older models running at their top
  setting.
- **Keep briefs self-contained.** The subagent sees none of this conversation: inline
  the material, the done criteria, and the *why*, not just the words of the request.
- **One instruction beats an enumeration.** Fable 5 follows a short, clear principle
  well; don't try to list every case it should or shouldn't handle, state the intent
  once and trust it to generalize.
- **On a long-running lot, anchor progress claims in tool results.** Ask it to report
  only what it can point to evidence for from this session, and to say plainly when
  something is not yet verified, rather than asserting a status from memory.
- **Never ask a Fable 5 subagent to echo, transcribe, or explain its internal reasoning
  in its response text.** Prompts like "show your reasoning step by step in your
  answer" risk tripping the `reasoning_extraction` safety classifier, which can trigger
  a refusal and a fallback to Opus for that call (documented in Anthropic's "Prompting
  Claude Fable 5" guide: platform.claude.com/docs/en/build-with-claude/prompt-engineering/prompting-claude-fable-5).
  Ask for the conclusion and the evidence behind it, never a replay of how the model got there.
