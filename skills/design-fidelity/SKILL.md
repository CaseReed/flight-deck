---
name: design-fidelity
description: >-
  Governs the Claude Design to Claude Code handoff and proves, in a real
  browser, that the shipped UI matches the design. Owns an independent fidelity
  gate (design reference vs rendered UI, a structured rubric, a gap contract,
  token discipline, a ranked punch-list, and an adversarial re-check) and
  orchestrates the rest by calling the documented slash commands for import plus
  mission-control and test-discipline for the build, with frontend-design (or
  ui-ux-pro-max when present) as the build craft standard. The Claude Design
  reference is authoritative: craft fills what the design leaves undefined, it
  never overrides the explicit design. Depends only on stable primitives (the
  design reference, the rendered app, Chrome), never on the undocumented beta
  claude-design MCP internals, and degrades gracefully when a command or the
  MCP is unavailable. Triggers include "implement this Claude Design design",
  "design handoff", "does the UI match the design", "verify design fidelity",
  or a Claude Design URL or export given as input. Opt out with "without
  design-fidelity" or "skip the fidelity check".
when_to_use: >-
  Fires when a Claude Design design (a URL, an export, or a handoff bundle)
  must become shipped frontend and be proven, in a browser, to match the
  design, on the trigger phrases or when such a reference is the task input;
  on a mission-control session it also fires without being named. Opt out with
  "without design-fidelity" or "skip the fidelity check".
metadata:
  author: Julien Tavernier
---

# design-fidelity: verify the build against the design

The principle: a UI is not done because it compiles and looks plausible. It is done
because it was checked against its actual design reference, side by side, in a real
browser, and the gaps were named, not glossed over. This skill owns that check; it
composes existing skills and commands for everything else.

## 1. When this fires (and when it does not)

Fires on the trigger phrases in the frontmatter above ("implement this Claude Design
design", "design handoff", "does the UI match the design", "verify design fidelity"),
and on any turn where a Claude Design URL or export is given as input. On a session
where mission-control is active, it also fires whenever a Claude Design URL, export,
or handoff bundle shows up as the task's input, without the user having to name the
skill.

It does not invent a design from scratch. Producing a design that does not yet exist
is Claude Design's job, or a craft skill's (frontend-design, ui-ux-pro-max) job when
there is no reference to hold the build to. This skill only reproduces and verifies a
design that already exists somewhere: a URL, an export, a screenshot.

Honor the opt-out phrases ("without design-fidelity", "skip the fidelity check"):
when given, skip the fidelity gate, run the build as an ordinary craft task, and say
in the close-out that the gate was skipped by request.

## 2. The trajectory it governs

Four stages, one line each. The pattern to notice: this skill composes, it does not
rebuild what already exists.

- **Import**: capture the design reference through the documented slash command for
  Claude Design import, or an export, when the command is unavailable. This skill does
  not reimplement that import logic.
- **Build**: mission-control splits and calibrates the build lots, test-discipline
  names the proof for each, and a craft skill executes them against the reference.
- **Verify (owned core)**: the fidelity gate below, this skill's one piece of unique
  work, and the reason it exists as a separate skill rather than a note inside another
  one.
- **Close-out**: the standard Flight Deck knowledge pass, described in section 6.

## 3. The fidelity gate (owned core)

Seven moves, run in order. The full rubric each dimension is checked against lives in
`references/fidelity-rubric.md`; this section only names the moves.

1. **Capture the authoritative reference** from a stable source: a `claude.ai/design/<id>`
   URL, or an export (standalone HTML, `.zip`, PDF, screenshot) when the URL is not
   available.
2. **Render the real app and open it in Chrome** at the target breakpoints, next to the
   reference, so the comparison is visual and side by side, not a description from
   memory.
3. **Compare on the rubric**: structure, spacing, typography, tokens, component states,
   responsive behavior, motion, accessibility. Full detail, checks, and per-dimension
   verdicts are in `references/fidelity-rubric.md`, not repeated here.
4. **Apply the gap contract**: anything the reference leaves undefined (an unstated
   state, an in-between breakpoint, dark mode, an a11y specific) is a craft decision,
   not a divergence, and is checked against the craft bar instead.
5. **Check token discipline**: the built code should use the design's tokens (color,
   typography, component) rather than hardcoded values that duplicate them.
6. **Emit a ranked punch-list**: every real divergence, ordered by severity, feeding the
   next build lot when the gate fails.
7. **Run an adversarial re-check**: a second pass that assumes the first pass missed
   something, and actively hunts states, responsive edges, and tokens for what got
   waved through.

## 4. Composition contract

The build itself is not this skill's work. It is delegated to `mission-control` for
lot calibration and `test-discipline` for picking the proof; the build lots invoke a
craft skill, `frontend-design` by default, `ui-ux-pro-max` when it is present or
preferred.

The reproduce-not-invent guardrail governs that delegation: the design reference is
authoritative. Craft fills in what the reference leaves undefined (per the gap
contract in section 3), but it never overrides what the reference states explicitly.
A build that drifts from the reference on a defined point is not craft judgment, it is
a divergence, and the fidelity gate flags it as one.

## 5. Degradation and stable-primitives rule

This skill has no hard dependency on the undocumented `claude-design` MCP. It depends
only on stable primitives: the design reference, the rendered app, and Chrome. On MCP
or import-command failure, it falls back to an export or the design URL itself as the
reference and continues the gate from there.

It never blocks silently on a source it could not obtain. When a reference, a
breakpoint render, or a comparison genuinely cannot be produced, the gate reports that
dimension as "not-verifiable" and says why, rather than passing it in silence or
stalling the task.

## 6. Close-out

Once the fidelity gate has run, close out with the standard Flight Deck knowledge
pass: memory, CLAUDE.md, and the project's own docs, updated wherever the run
surfaced something durable (a recurring divergence pattern, a token gap, a command
that degraded).

Code-to-design push-back, feeding a shipped fix back into the Claude Design source, is
out of scope for this skill. That is phase 2.
