---
name: test-discipline
description: >-
  Owns testing discipline for any code change (source, tests, scripts, or
  executable config) about to be called done. Before touching code, choose the
  proof before coding, one of a new or updated automated test, the existing
  suite, a browser or manual flow for UI, or a build/typecheck for structural
  changes, and name it in one line. Then find and run the repo's own named
  check command from its CLAUDE.md, README, or package scripts. A
  "done", "fixed", or "passing" claim must cite the output, quoting the tail
  of what actually ran, never asserted from memory. Proof is scaled to the
  change, real failure modes get covered, cases that cannot happen do not,
  and no new abstraction is added just to make something testable. Fully
  self-contained, no external dependency required. Fires on finishing a code
  change, on being asked to verify or confirm something works, or when
  invoked explicitly by an orchestrating skill's code lot.
when_to_use: On any change to code meant to run, right before that change would be called done, or when a code lot invokes it explicitly.
metadata:
  author: Julien Tavernier
---

# test-discipline: pick the proof, run it, cite it

The principle: a code change is not done because it compiles or because it looks
right. It is done because you ran something that would have failed if the change
were wrong, and you can show the output. No output, not done.

## When it fires

- Any change to code meant to run: source, tests, scripts, executable config.
- Right before that change would be called done, fixed, or passing.
- When an orchestrating skill's code lot invokes this skill.
- Not a per-keystroke check. It fires once, at the point a change is about to be
  claimed complete, not on every edit along the way.

## The procedure

1. **Before coding, name the proof class in one line.** Pick the one that fits the
   change: a new or updated automated test (unit or integration), the existing
   suite, a browser or manual walkthrough for UI, or a build/typecheck for a purely
   structural change. State which one before writing a line of code.
2. **Find the repo's own named check.** Look in the project's CLAUDE.md,
   README, or package scripts for the command it already uses to test, build, or
   lint. This skill embeds no commands of its own, it stays generic across repos.
   If the project names no check, say so out loud and fall back to the language's
   conventional runner, flagged as an assumption, not asserted as fact.
3. **Write the missing proof**, sized to the change from step 1. Do not invent a
   heavier proof class than the change calls for.
4. **Run the named check and quote its tail.** A "done", "fixed", or "passing"
   claim must show the actual last lines of the actual command output. No run, no
   claim.

## Proportionality (IMPORTANT, a hard rule)

Proof is scaled to the change, not maximized.
- No tests for inputs or states that cannot happen in the real code path.
- No new abstraction layer, seam, or defensive branch added just to make something
  "testable" that did not need it before.
- Add proof where a real failure mode exists. Not everywhere, not by default.

This rule exists so testing discipline does not become its own over-engineering. A
three-line fix does not earn a new test harness.

## Invocation contract

When an orchestrating skill's code lot (for example a mission-control style
pipeline) invokes this skill, run steps 1 to 4 inside that lot and return the tail
of the check's output as part of the lot's self-check against its done criteria.
The lot is not done until this skill has run and the output is quoted, not
summarized.
