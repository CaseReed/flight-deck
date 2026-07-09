# mission-control

A Claude Code skill that orchestrates large tasks in three steps: the frontier model
(Claude Fable 5 / Opus) **plans** and **verifies**, calibrated subagents (Haiku /
Sonnet / Opus depending on complexity) **execute** in parallel, lot by lot.

Result: the quality of the most capable model, without paying it on every line.

Author: Julien Tavernier.

## History

mission-control was born as `tour-de-controle`, a French-language skill written and
maintained by Julien Tavernier as his core orchestration doctrine for Claude Code. On
2026-07-02 it was renamed and translated into English as its successor, and the scope
was widened at the same time: what started as a Fable-5-only cost workaround is now
also the recommended default on Opus-class sessions, because the plan/delegate/verify
logic is judged better engineering in general, not only a way to avoid paying frontier
prices on every line. mission-control fully replaces the French original, which is
retired.

## Install (2 minutes)

1. Drop the `mission-control` folder:
   → in `~/.claude/skills/` to have it in every session,
   → or in `.claude/skills/` at the root of a project for that project only.
   Also copy the companion `test-discipline` folder from the same package next to it.
   Code lots invoke `test-discipline` as a mandatory done-criterion (see Phase 2 of
   SKILL.md); without it on disk, those lots have no test-discipline skill to call and
   degrade to an unenforced "looks done".
2. Add the activation rule to `~/.claude/CLAUDE.md`. Copy the block from
   `CLAUDE-md-activation.md` at the root of this package: it already covers Fable 5 and
   Opus-class sessions, the start-of-session announcement, and the opt-out phrases.
3. Optional: wire the fan-out guard hook. It ships at the root of this package, at
   `hooks/fable5-fanout-guard.sh` (a sibling of `skills/`, not a file inside this skill
   folder). On a Fable 5 session it denies any subagent call without an explicit
   cheaper model and any `Workflow` call outright (workflow agents inherit the session
   model, so one unpinned fan-out can burn a day's frontier quota). It installs
   separately from the skill: copy the script to `~/.claude/hooks/` and register it
   under `PreToolUse` in `~/.claude/settings.json`, following `hooks/HOOKS.md` at the
   package root:

   ```json
   {
     "hooks": {
       "PreToolUse": [
         {
           "matcher": "Agent|Workflow",
           "hooks": [
             {
               "type": "command",
               "command": "$HOME/.claude/hooks/fable5-fanout-guard.sh"
             }
           ]
         }
       ]
     }
   }
   ```

   The hook is deliberately inert on non-Fable sessions: Opus users get the doctrine,
   not the mechanical guard. Not required, the skill works on the honor system without
   it, but the hook makes the calibration rule mechanically enforced instead of just
   documented.

   This is a global `~/.claude/hooks/` install with `settings.json` registration, not a
   skill-scoped `hooks:` frontmatter field, because the guard must protect Agent and
   Workflow calls from the first turn of a Fable 5 session, before the skill has
   necessarily been invoked into context. A skill-scoped hook only activates after the
   skill loads, so it could not catch an early un-pinned fan-out.
4. Restart Claude Code. That's it, no key to configure, the hook is the only optional extra.

Need help? Ask Claude Code directly: "install the mission-control skill I just
downloaded."

## Usage

On a large task (folder audit, series of documents, multi-source analysis, multi-file
migration), just say:

> "mission control"

or "orchestrate this task", "plan-delegate-verify".

The skill then runs its three phases:
→ **PLAN**: split into independent lots, with verifiable done criteria written BEFORE
  any launch, and a model assigned to each lot (Haiku for mechanical work, Sonnet by
  default, Opus for lots that need judgment). Full mechanics: SKILL.md, "Phase 1: PLAN".
→ **DELEGATE**: one subagent per lot, on the model set by the plan, all launched in
  parallel, each with a self-contained brief. Full mechanics: SKILL.md, "Phase 2:
  DELEGATE".
→ **VERIFY**: every deliverable is checked with an inspector's posture (evidence
  required); what fails goes back for a targeted retry, then a final report. Retry
  caps and tier escalation live in SKILL.md, "Phase 3: VERIFY". The report and every
  deliverable follow the skill's concision contract (SKILL.md, "Concision of
  deliverables and reports"): lead with the conclusion, summary first, detail on
  request, without trimming substance.

Code lots invoke the companion **test-discipline** skill to prove the change (choose
the proof, run the repo's named check, cite its output).

## When NOT to run the full 3 phases

→ A short task that a single pass settles: the 3-phase orchestration would cost more
  than the work itself. On a frontier session it still does not execute inline, it
  goes out as simple delegation (one calibrated subagent, brief and check only).
→ A single-piece creative text: splitting it breaks coherence (simple delegation to
  one agent).
→ A micro fix on context already in the conversation, one trivial line and no more:
  the brief would cost more than the fix, this is the one case the frontier model
  handles directly.

## Opt-out phrases

Say any of these to skip the skill for a task or a session: "without mission control",
"no mission control", "do it yourself". These are also recognized in the user's
working language (for example a French user's "sans mission control").

## What to expect per session model

On a frontier session (Claude Fable 5 / Opus), mission-control is the default mode and
announces itself in one short line at the start of the session.

For best results, run that frontier session on Opus 4.8 at High reasoning effort (`/effort high`), the default this package is tuned for. High is the sweet spot for planning and verification; xHigh is slower and heavier for little gain on most lots, so save it for the genuinely hardest reasoning.

On Sonnet or Haiku, it stays silent until you type a trigger phrase ("mission control",
"orchestrate this task", "plan-delegate-verify"). That silence is normal, not a failed
install: opt-in mode does not announce itself. The one exception: on the first
substantial multi-lot task in the session, it reminds you once that it is installed and
opt-in on this model, and that saying "mission control" turns it on.

## Requirements

→ Claude Code (subagents are built in).
→ Hooks only: `jq` on PATH (they fail open without it, see `hooks/HOOKS.md`).
→ Works with any primary model; the pattern pays off more the more capable (and
  expensive) your session model is.

Version: see the VERSION file. Full changes: see the package CHANGELOG.md.
