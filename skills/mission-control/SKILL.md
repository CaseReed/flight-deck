---
name: mission-control
description: >-
  Plan with the session model, delegate execution to per-lot calibrated
  subagents, then verify adversarially: frontier quality without frontier price
  on every line. Default mode on frontier sessions for substantial multi-lot
  tasks; a single-pass task goes out as simple delegation to one sonnet or haiku
  subagent, never inline on the frontier model. Triggers: "mission control",
  "orchestrate this task", "plan-delegate-verify". Opt out with "without mission
  control", "no mission control", "do it yourself", also recognized in the
  user's working language (e.g. a French user's "sans mission control").
when_to_use: >-
  Default on frontier sessions for any substantial multi-lot task unless opted
  out; opt-in via the triggers on non-frontier sessions. Phrases recognized in
  the user's working language.
metadata:
  author: Julien Tavernier
  compatibility: "Claude Code only; requires subagents; hooks optional"
---

# mission-control: plan, delegate, verify

**The frontier model is too valuable to execute, and too good not to verify.** On a
large task you ask it for the two things where it beats everything else, **the plan** and
**the quality control**; execution goes to smaller, faster, cheaper subagents in parallel.

**Flow:** PLAN (session model, once) writes a full spec plus done criteria per lot →
DELEGATE one calibrated subagent per lot, in parallel → VERIFY (session model) each
deliverable against its criteria; any lot that fails loops back as a targeted lot. Why this
pattern works, the cost model, and the doctrine's history: read `references/rationale.md`.

## Hard rules (read before anything else)

- **Never more lots than necessary.** 3 well-specified big lots beat 10 crumbs.
- **Done criteria are written BEFORE launching the agents**, 2 to 4 verifiable per lot,
  never after; otherwise you check what was produced, not what was asked.
- **Real code routes to `sonnet` minimum, never `haiku` in write mode.** A lot that
  writes or edits code meant to run is `sonnet` even when the brief sounds mechanical.
- **Two parallel WRITE lots never share a file.** Sequence them, or isolate with
  `isolation: worktree` on the Agent call.
- **Verification is not optional.** Skip it and the pattern collapses: you just paid
  less for an unchecked result.

## Mode selection

Pick the mode before doing anything. On a frontier session the session model does only
four things itself: plan, orchestrate, verify, decide. Everything else is execution and
gets delegated, even simple single-pass work.

- **Full orchestration (the 3 phases below):** a task with several independent lots,
  auditing a folder, migrating files, a series of deliverables, multi-source analysis, a
  section-by-section rewrite. Needs verifiable success criteria, or lots you can give some.
- **Simple delegation (single pass):** a short, sequential, or single-piece task one pass
  settles, a Jira ticket, a draft, a web or documentation search, a reformat, a creative
  text that must stay coherent. It does NOT run inline on the frontier model: the session
  model writes one self-contained brief, fires ONE Agent call at the model the routing grid
  sets (`sonnet` default; `haiku` for pure non-code mechanics), then checks the result once
  against the criteria; on failure, fix at most one trivial line yourself, anything larger
  goes back once with the exact edit list, single loop. A routine single-pass task run
  inline on the frontier model is the mistake this mode corrects.
- **Inline (the only frontier-model exceptions):** conversational turns (answering,
  explaining, analyzing, giving an opinion); ONE trivial-line micro fix on context already
  loaded; and what a subagent cannot do (a user-facing decision, a tool unavailable to
  subagents, a call that commits the rest of the session).

## Phase 1: PLAN (session model, maximum effort)

1. **Recall first.** Before splitting anything, sweep what the project already knows: the
   session's persistent memory (whatever memory index this environment provides, if any)
   and the project's docs (CLAUDE.md, README, design notes) for prior decisions,
   conventions, and gotchas bearing on this task. Cite in the plan what applies, or state
   "nothing relevant found". A plan that ignores a recorded decision re-litigates settled
   ground.
2. **Full spec first.** If the request is vague, ask ALL your questions in one turn (goal,
   scope, constraints, output format, examples of "good"). A vague request produces vague
   lots and lost subagents.
3. **Split into independent lots.** Each lot must be executable alone, without seeing the
   others. If two lots depend on each other, merge or sequence them. Independence is
   logical AND physical: two parallel WRITE lots never share a file (see the hard rules).
4. **Decide the routing at planning time**, never at launch: the execution tier and
   reasoning effort from the routing grid, with a 3-5 word justification ("pure mechanics",
   "nuanced writing"). Write the lot's done criteria now: 2 to 4 verifiable ones (not "good
   quality" but "contains the exact figures from the source table", "under 300 words", "0
   dead links"). Any lot that writes code meant to run MUST carry a test-evidence criterion
   authored via the test-discipline skill (a named check that passes, its output cited); if
   test-discipline is not installed, name the repo's own check inline in the criterion
   instead and say the skill was absent.
5. **Distill the intent, don't relay the words.** Apply the colleague test: would a
   stranger with none of this conversation know exactly what to do and where to stop? If
   yes, pass the request as-is. If not, close that gap in the brief, and cut scope to
   YAGNI, because an over-briefed subagent over-builds. Confirm the plan with the user if
   the task is heavy or ambiguous; otherwise proceed.

## Phase 2: DELEGATE (calibrated subagents, in parallel)

6. **One pinned Agent call per lot, all in the same turn** so they run in parallel, at any
   lot count. Set `model:` explicitly on every call (`"haiku"` / `"sonnet"` / `"opus"`)
   even when an agent definition's frontmatter pins it: the fanout guard reads only the
   call parameter and denies the rest. If this environment exposes a Workflow tool and the
   run needs structured returns, lot-to-check chaining, or a token budget, read
   `references/advanced-orchestration.md` first, which also documents the exact form of the
   `FABLE_OK` token; on a Fable 5 session the fanout guard denies Workflow calls unless you
   pass that token, which you never add without the user's explicit approval for that run.
7. **Each brief is self-contained**, the subagent sees NOTHING of this conversation. Use
   this template:

   ```
   Mission: <one sentence, action verb>.
   Context and why: <inline what the subagent needs; it has none of this conversation>.
   Material: <exact paths, data, links>.
   Done criteria: <2-4 verifiable; a code lot carries a test-discipline evidence
     criterion with cited output>.
   Output contract: <small deliverable: your final response IS the deliverable, return
     the raw content, no summary. File deliverable: WRITE to <fixed path>, return only
     that path plus your self-check against each criterion>. Lead with the result, no
     preamble.
   Model + effort: <tier + effort + 3-5 word justification>.
   ```
   A code lot's brief also says: invoke the test-discipline skill, run the repo's named
   check, quote the tail of its output. A code deliverable with no cited check is
   unverified. Keep briefs lean: N lots returning raw content flood the VERIFY context.
8. While the agents run, don't redo their work. Wait.

## Phase 3: VERIFY (session model, inspector hat on)

9. **Check each deliverable against its done criteria, actively trying to reject it.** For
   each criterion ask "what would prove this failed?" and verify against the sources:
   re-read the produced file, cross-check the figures, test the links. A deliverable that
   "looks fine" without evidence is unverified. Past roughly 6 lots, parallelize the
   mechanical checks: delegate the mechanically verifiable criteria (counts, links,
   formats, tests) to fresh-context verifier subagents (`haiku`/`sonnet`, low effort), one
   per lot, in parallel; keep the judgment criteria and the final call for yourself. A
   fresh verifier beats self-critique, including yours.
10. **Check for over-delivery, not just under-delivery.** Done criteria measure presence
    ("it does X"), never restraint ("it does ONLY X"), so a lot can pass every criterion
    and still be over-engineered. For each deliverable, hunt for what the criteria did not
    require: an abstraction with a single caller, a config knob nobody asked for, defensive
    code for inputs that cannot occur, a test for a case that cannot happen. Flag it and
    trim it. This verify pass is the only place the pattern catches it.
11. **What fails loops back as a targeted lot.** Resume the executing agent via SendMessage
    if the environment allows (its context is intact), otherwise a new subagent; in both
    cases hand it the faulty deliverable, the failed criterion, and the expected fix.
    Maximum **2 retry loops**; if the 1st retry fails on the same model, the 2nd launches
    one tier up (`haiku`→`sonnet`→`opus`, the last rung being you taking the lot over).
    Before escalating a lot that failed twice, check the authoritative source (official
    docs, the library's own source or spec, the actual error), and if that does not settle
    it, run a targeted web search; a repeated failure is often missing information, not an
    under-calibrated lot, and no tier upgrade fixes a wrong assumption. Beyond 2 loops,
    take the lot over yourself or escalate the blocker to the user. **Micro-fix boundary:**
    one trivial line (delete or replace) gets fixed during the check and noted. Several
    corrections in the same pass are a batch, and a batch is execution: hand the full edit
    list to one sonnet subagent instead of applying it yourself, even when the files are
    skills or docs.
12. **Final report:** what was produced (with paths), what was verified and how, what was
    retried, what remains open. Never "everything looks good" without pointing at the
    evidence. Lead with what was produced and verified; see Concision below.
13. **Knowledge pass at close-out, per surface and verified.** Once the work is confirmed
    done, sweep three surfaces one at a time, actually opening each rather than concluding
    "already covered" from memory: (a) persistent memory, and the entries this work
    touched, (b) CLAUDE.md, the project's and the global one, (c) the project's own docs
    (README, design notes). On each, record what is durable and non-derivable that this
    work established (a decision, a gotcha, a convention, a lasting status) and prune what
    it made stale, routing by scope: a project-specific fact to that project's memory,
    CLAUDE.md, or docs; a cross-project preference or doctrine to the global memory or
    CLAUDE.md. A skip must be a checked conclusion (surface opened, it holds), not an
    assumption. Report the outcome per surface ("memory: added X; project CLAUDE.md:
    nothing new; docs: nothing new"). The pass is never optional.

## Routing grid

**Routing is relative to your session model**, not to fixed names. The session model
orchestrates; execution routes to the tiers BELOW it. Never delegate a lot to a model more
expensive than your session model, the orchestrator is the ceiling.

| Role | Model | Effort | When |
|---|---|---|---|
| Planning + verification | the session model | high (xhigh for a critical lot) | Always, where intelligence pays off |
| Mechanical execution | `haiku` | low | Zero judgment, outside code: extract, list, count, reformat |
| Standard execution (**default**) | `sonnet` | medium (high for real code or tight criteria) | Analysis, synthesis, structured writing, web/documentation research, ANY lot touching real code |
| Complex execution | `opus` | high (xhigh for hard code) | Nuanced judgment, publication-grade writing, multi-step reasoning within the lot |

- **When torn between two tiers**, pick the higher if the lot is expensive to redo or on
  the critical path, the lower otherwise. A retry costs more than the tier gap.
- **`opus` stays the exception.** If most lots need `opus`, the split is bad, re-split.
- **Let the done criteria decide:** a lot OUTSIDE code with purely mechanical criteria
  ("exact count", "exhaustive list") never needs more than `haiku`. On code this yields:
  mechanical criteria ("tests pass", "0 tsc errors") never pull a code lot below `sonnet`.
- **Effort** is set where the environment exposes it (the `effort` parameter, or an agent
  definition's frontmatter); if the Agent tool in use exposes no per-call effort, the Model
  column alone carries the routing, don't improvise a workaround. It is the 2nd cost lever
  after the tier: `low` on mechanical lots is the safest saving; `xhigh` only for hard code
  on `opus` or your own verification of a critical lot. Raising effort never rescues a
  badly specified lot.

**Supervised up-delegation (the one exception):** a session on a lower or equal tier may
occasionally delegate ONE named high-value lot to a more expensive model under hard limits:
scope narrow and explicit, `effort` capped at what the lot needs, assessment-only for an
audit (it reports, it modifies nothing), and the run watched with a cutoff on a
runaway-cost proxy such as transcript size. Before up-delegating a lot: read
`references/advanced-orchestration.md` first.

## Concision of deliverables and reports

Form, not substance. Lead with the conclusion or headline result in the first sentence,
never with preamble. For anything longer than a few lines: a short plain-language summary
first, discrete findings as bullets, then what remains open; progressive disclosure, the
short version first and the full breakdown on request, nothing dropped only deferred. Trim
words, repetition, and restated context, never a fact, a risk, a caveat, or the evidence
behind a "done" claim. A one-line answer stays one line.

## Prompting a frontier subagent

When a lot runs on a frontier model (the orchestrating session, or an up-delegated lot):
set `effort` per lot explicitly (`medium` for routine work, `high` only where detection
quality is genuinely critical), state the intent once rather than enumerating cases, and
**never ask it to echo, transcribe, or explain its internal reasoning in its response**
(it risks a safety-classifier refusal); ask for the conclusion and the evidence, not a
replay of how it got there. Full frontier-subagent guidance: read
`references/advanced-orchestration.md`.
