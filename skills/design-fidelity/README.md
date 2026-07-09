# design-fidelity

A verified Claude Design to Claude Code bridge: it does not just implement a design,
it proves, in a real browser, that the shipped UI matches it.

## What it does

A UI is not done because it compiles and looks plausible. It is done because it was
checked against its actual design reference, side by side, in a real browser, with
the gaps named rather than glossed over. design-fidelity owns that check and composes
existing skills for everything else.

The trajectory has four stages: **Import** (capture the design reference), **Build**
(mission-control and a craft skill produce the UI, or an ordinary craft build with the
repo's own check when those skills are absent), **Verify** (the fidelity gate,
this skill's one piece of unique work), and **Close-out** (the standard Flight Deck
knowledge pass). It does not invent a design from scratch, that is Claude Design's job
or a craft skill's when there is no reference to hold the build to; it only reproduces
and verifies a design that already exists.

The fidelity gate itself runs seven moves in order: capture the authoritative
reference, render the real app with the Playwright MCP next to it, compare on a structured rubric
(structure, spacing, typography, tokens, component states, responsive behavior,
motion, accessibility), apply the gap contract for anything the reference leaves
undefined, check token discipline, emit a ranked punch-list of real divergences, and
run an adversarial re-check that assumes the first pass missed something. The gate
passes only when the punch-list has zero blocking entries; a failing gate feeds the
punch-list into the next build lot.

The skill has no hard dependency on the undocumented `claude-design` MCP. It depends
only on stable primitives (the design reference, the rendered app, a real browser) and
degrades to an export or the design URL itself when the MCP or import command is
unavailable, reporting a dimension as not-verifiable rather than passing it in
silence.

## What is inside

- `SKILL.md`: the skill body, the trigger and opt-out phrases, the four-stage
  trajectory, the seven-move fidelity gate, the composition contract, the
  degradation rule, and the close-out step.
- `references/fidelity-rubric.md`: the full expansion of the gate, read by a build
  lot to actually run the check, with the breakpoint set, the per-dimension checks
  and tolerances, the gap contract procedure, token discipline, the adversarial
  re-check protocol, and the punch-list output schema.

## Usage and triggers

Fires on: "implement this Claude Design design", "design handoff", "does the UI
match the design", "verify design fidelity", or a Claude Design URL or export given
as input. On a session where mission-control is active, it also fires whenever a
Claude Design URL, export, or handoff bundle shows up as the task's input, without
the user having to name the skill.

Opt out with "without design-fidelity" or "skip the fidelity check": the fidelity
gate is skipped, the build runs as an ordinary craft task, and the close-out states
that the gate was skipped by request.

## How it composes

design-fidelity does not rebuild what already exists, it orchestrates it:

- **mission-control** splits and calibrates the build lots.
- **test-discipline** names the proof for each build lot.
- A **craft skill** executes the build against the reference, `frontend-design` by
  default, `ui-ux-pro-max` when it is present or preferred.

The reproduce-not-invent guardrail governs that delegation: the design reference is
authoritative. Craft fills in what the reference leaves undefined, per the gap
contract, but never overrides what the reference states explicitly. A build that
drifts from the reference on a defined point is not craft judgment, it is a
divergence, and the fidelity gate flags it as one.

## Requirements

- Claude Code with skills.
- The Playwright MCP, to render the real app next to the design reference for the
  visual comparison step. It gives cleaner, more reliable captures than the claude-in-chrome
  extension, which works as a fallback.
- A Claude Design reference as input: a `claude.ai/design/<id>` URL, or an export
  (standalone HTML, `.zip`, PDF, screenshot) when the URL is not available.
