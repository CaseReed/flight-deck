# Flight Deck

Flight Deck is a package that fixes eight default weaknesses in how Claude Code runs
out of the box: it barely delegates, has no sense of which model tier a task deserves,
does not calibrate how hard to think, does not resist over-engineering, tests loosely,
forgets what it already knows, has no cost discipline, and pads its analyses and
reports with preamble and filler. The name is the frame, used
lightly: mission control plans and hands work to the crew at their consoles, a
pre-flight checklist gates whether a change is actually done, and cost is fuel, not an
afterthought.

## What it does

| Axis | Default weakness | What Flight Deck does |
|---|---|---|
| Delegation | Runs everything itself, one thread at a time | Splits work into lots and delegates each to a subagent, in parallel |
| Model tier | Same tier for a typo fix and an architecture call | Routes each lot to the tier its difficulty earns: cheap for mechanical work, default for most of it, top tier reserved for judgment calls |
| Reasoning effort | One fixed effort level for everything | Calibrates effort per lot alongside the tier |
| Over-engineering | Adds abstraction layers, defensive code, and tests nobody asked for | Pushes back by default: no layer until a second real use case exists, no guard against inputs that cannot occur |
| Testing discipline | Calls it "done" on the strength of a diff | Picks the proof before writing code, runs the repository's own named check, cites the output |
| Memory and docs | Re-derives what is already known, skips the project's own notes | Recalls persistent memory and reads local docs before planning anything substantial |
| Cost | No sense of what a session is spending | Keeps the top tier in planning and verification only; execution goes to the cheapest tier that clears the bar |
| Verbosity | Buries the answer under preamble and filler in analyses, reports, and explanations | Leads with the conclusion and keeps output tight, with the detail offered on request: a Concise output style across all of Claude Code, plus a concision rule inside mission-control |

## What's inside

- **skills/mission-control/** : the orchestration skill. On a capable session, the
  session itself only plans, delegates, verifies, and decides; execution goes to
  calibrated subagents running in parallel, each with a self-contained brief, then an
  adversarial verification pass checks the results before anything is called done.
  Covers delegation, model-tier routing, reasoning-effort calibration, over-engineering
  avoidance, memory and docs recall, and cost control.
- **skills/test-discipline/** : the testing companion. Owns testing discipline for code
  changes: choose the proof before writing the code, run the repository's actual named
  check, cite its output, and scale how much proof a change needs to how big the change
  is. Called by mission-control's code lots, and usable on its own.
- **hooks/** : three optional hooks: a non-blocking verify-reminder that nudges toward
  verification before a push, a fanout-guard that mechanically enforces the
  model-tier calibration whether or not the skill loaded, and a SessionStart
  update-check that, once a day, notices when a newer release is out and offers to
  update (it never overwrites anything on its own). Registration steps are in
  `hooks/HOOKS.md`.
- **output-styles/** : an optional `Concise` output style. It makes Claude lead with the
  answer, keep the initial response tight, and expand only on request, across all of
  Claude Code, not only mission-control deliverables. Structural rules only, with a
  guard-rail that defers detail rather than dropping substance. Copy it to
  `~/.claude/output-styles/` and turn it on with `/output-style Concise`.

## Usage

Once installed, mission-control is the default execution mode on Fable 5 and
Opus-class sessions for any substantial multi-lot task. On other session models, or
to trigger it explicitly, say "mission control", "orchestrate this task", or
"plan-delegate-verify". To skip it, for one task or the whole session, say "without
mission control", "no mission control", or "do it yourself".

Routing always points down to a cheaper tier, with one narrow, supervised exception
for a single high-value lot going to a more expensive model; see "Supervised
up-delegation" in `skills/mission-control/SKILL.md`.

## Install

### The installer prompt

Copy the block below into a fresh Claude Code session. It is written to be safe: it
clones the repo itself, checks for an existing install first, and it will not touch
your `CLAUDE.md` or `settings.json` without showing you the exact change and waiting
for a yes.

```
Install the Flight Deck skill package for me from https://github.com/CaseReed/flight-deck, following these steps exactly and stopping for confirmation where noted.

1. Clone the repo into a temporary directory (for example /tmp/flight-deck) and read its README.md, CLAUDE-md-activation.md, skills/, and hooks/ so you know what you are installing.

2. Check for an existing install first. Look for ~/.claude/skills/mission-control/ and ~/.claude/skills/test-discipline/, check whether ~/.claude/CLAUDE.md already has a Flight Deck activation block, and check whether ~/.claude/output-styles/concise.md already exists. If everything is already in place, tell me and stop there. Do not re-run steps or overwrite anything that is already installed.

3. Copy the skill folders. Copy skills/mission-control/ and skills/test-discipline/ from the clone into ~/.claude/skills/. If either folder already exists there, show me a diff against the incoming version before doing anything, and ask whether to overwrite, skip, or merge. Never overwrite silently. Also copy output-styles/concise.md into ~/.claude/output-styles/, with the same safety: if it already exists, show me a diff before overwriting.

4. Update ~/.claude/CLAUDE.md. Read CLAUDE-md-activation.md from the clone. If ~/.claude/CLAUDE.md does not exist yet, show me its full proposed contents and ask before creating it. If it exists and already contains this activation block (or an equivalent one covering the same triggers and opt-outs), tell me and make no change. Otherwise, show me the exact diff you intend to apply, including where it gets appended, and wait for my explicit confirmation before writing anything.

5. Offer the hooks, do not install them on your own. Read hooks/HOOKS.md from the clone. Show me what verify-reminder, fanout-guard, and flight-deck-update-check each do, and the exact JSON that would be added to ~/.claude/settings.json to register them (verify-reminder and fanout-guard go under PreToolUse, flight-deck-update-check goes under SessionStart). Ask which ones, if any, I want.

Only once I confirm: copy the chosen hook script(s) into ~/.claude/hooks/ and make each one executable with chmod +x. If settings.json already has content in the relevant section, show me the diff before writing it, otherwise just apply the change. Before reporting a hook as registered, check that jq is installed and on PATH, and warn me if it is not, since the hooks need jq to run (the update-check also needs curl).

6. Finish with a plain summary: which files you copied, what, if anything, got appended to CLAUDE.md, whether the Concise output style was copied and that it stays off until I run /output-style Concise, and which hooks, if any, got registered. For anything I declined, say it was skipped and how to run it later. Then remove the temporary clone.

Do not write to CLAUDE.md or settings.json without showing me the change first and getting a yes. If the package is already installed, say so and stop instead of repeating the steps.
```

### Manual install

1. Copy `skills/mission-control/` and `skills/test-discipline/` into
   `~/.claude/skills/` (or into a project's own `.claude/skills/` for a
   project-only install).
2. Open `CLAUDE-md-activation.md`, copy the block, and paste it into your global
   `~/.claude/CLAUDE.md` (or a project `CLAUDE.md`).
3. Optional: copy `output-styles/concise.md` into `~/.claude/output-styles/`, then turn
   it on with `/output-style Concise` for concise-by-default responses across Claude
   Code. It stays off until you activate it.
4. Optional: read `hooks/HOOKS.md` and register the hooks you want in
   `~/.claude/settings.json`.
5. Restart your session.

## Staying up to date

The optional update-check hook (`flight-deck-update-check.sh`) nudges you at session
start when a newer Flight Deck release ships on GitHub, once a day at most. Updating
just means re-running the installer prompt above: it clones the current release,
shows you a diff against what is installed, and asks before overwriting anything, so
staying current is always a reviewed, opt-in step. This protects installs from
v1.2.0 onward, since it needs both the hook itself and the `VERSION` file it reads.

## Requirements

- Claude Code, which provides the skills directory at `~/.claude/skills/`, the
  `CLAUDE.md` instruction convention, and hook support in `settings.json`.
- Hooks only: `jq` on PATH (they fail open without it).
- Works on any session model; the delegation pattern pays off more the more capable,
  and more expensive, your session model is.

## License

Released under the MIT License. See [LICENSE](LICENSE).

By Julien Tavernier.
