# Changelog

All notable changes to Flight Deck are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.7.1] - 2026-07-09

### Added

- **A capture protocol in the design-fidelity rubric**: every screenshot is taken
  with animations frozen and reduced motion, after fonts load and the page is
  foregrounded and settled (not on network idle), at a 2x scale, full page and per
  breakpoint, with dynamic regions masked. This closes the false "broken" reads
  that come from a frame caught mid-animation or from a backgrounded tab whose
  entrance animations never fired.
- **A "read before you score" analysis protocol (rubric section 2.0)**: the gate
  now describes each region before judging, runs an explicit breakage-signature
  checklist, cross-references the accessibility snapshot against the screenshot to
  catch elements that exist in the DOM but never painted, requires cited evidence
  for a PASS, and zooms into suspicious regions. This closes the false "looks fine"
  verdicts on a visibly broken render.
- **A recommended-session note** in the README and the mission-control per-model
  section: run Flight Deck on Opus 4.8 at High reasoning effort by default, with
  xHigh reserved for the genuinely hardest lots.

### Changed

- **design-fidelity gate moves 2 and 3** point at the new capture and reading
  protocols, and the adversarial re-check re-runs the breakage checklist and the
  DOM-versus-pixel cross-check.

## [1.7.0] - 2026-07-09

### Changed

- **design-fidelity now renders through the Playwright MCP by default** for the
  fidelity gate's visual comparison, in place of the claude-in-chrome extension,
  which becomes a documented fallback. Playwright drives a real browser and gives
  cleaner, more reliable captures. The stable-primitives rule, README, and rubric
  are updated to match.

### Added

- **Render-capture cleanup in the design-fidelity close-out**: the Playwright MCP
  screenshots are transient gate evidence, purged once the user has signed off on
  the frontend, with the capture directory added to `.gitignore` in a git project,
  so the captures do not pollute the workspace.

## [1.6.0] - 2026-07-08

### Added

- **`tools/analyze-run.py`, a transcript analyzer**: a read-only post-hoc
  reader of a Claude Code session transcript that prints an objective
  mission-control scorecard (orchestrator model, Agent-call inventory and
  model-pinning, per-tier token split, verification signal). Zero runtime
  cost, nothing added to the skill.
- **`tools/doctor.sh`, a read-only install check**: reports what is present
  vs missing (skills, activation block, hooks and their registration,
  jq/curl, VERSION, output style), required items vs optional, with a
  remedy per gap.
- **A "What to expect per session model" section** in the mission-control
  README, plus a one-time non-frontier nudge in the activation block, so a
  Sonnet/Haiku user knows mission-control is installed and opt-in (it is
  silent by design until triggered on non-frontier sessions).
- **A `compatibility` declaration** in the skill frontmatter (Claude Code
  only, subagents required, hooks optional).

### Changed

- **fanout-guard hook approval hardened**: the `FABLE_OK` escape hatch must
  now be the first non-empty line of the prompt/string-args, or a dedicated
  `{"FABLE_OK": true}` key / exact array element for structured Workflow
  args. It can no longer be disarmed by a brief that merely relays the
  token in prose.
- **Portability**: the recall and knowledge-pass steps no longer assume a
  specific `MEMORY.md` auto-memory feature.

## [1.5.0] - 2026-07-08

### Added

- **Progressive-disclosure reference files** for mission-control:
  `references/rationale.md` (the why-it-works rationale, cost model, and
  history) and `references/advanced-orchestration.md` (Workflow tool
  mechanics, supervised up-delegation limits, and frontier-subagent
  prompting).

### Changed

- **mission-control SKILL.md restructured imperative-first**: the body was
  cut from 390 to about 200 lines with no doctrine change, and the YAML
  frontmatter (description/when_to_use) was tightened.
- **Agent-calls-first path made primary** over the Workflow tool in
  mission-control's execution guidance.
- **mission-control README refreshed** to point at the `VERSION` file and
  this CHANGELOG instead of a hard-coded version number.

### Fixed

- **Broken "above" cross-references** in SKILL.md, left over from the
  restructuring.
- **Missing test-discipline degradation note**: SKILL.md now documents what
  happens when test-discipline is not installed.
- **fanout-guard model-pin gotcha**: a model pinned only in agent
  frontmatter was getting denied; now documented to pass the model
  explicitly on every Agent call.

## [1.4.0] - 2026-07-08

### Added

- **design-fidelity skill**: a verified Claude Design to Claude Code bridge. It
  owns an independent, browser-grounded fidelity gate (design reference vs the
  rendered UI, a structured rubric, a gap contract, token discipline, a ranked
  punch-list, and an adversarial re-check) and orchestrates import and build by
  calling the documented slash commands, mission-control, test-discipline, and a
  craft skill (frontend-design by default, ui-ux-pro-max when present), rather
  than reimplementing them. The Claude Design reference stays authoritative and
  the skill depends only on stable primitives, never on the undocumented beta
  claude-design MCP internals.

## [1.3.1] - 2026-07-07

### Changed

- **Close-out knowledge pass is now per-surface and verified** (mission-control,
  workflow step 11). It sweeps persistent memory, CLAUDE.md, and the project's own
  internal docs one at a time, actually opening each rather than assuming one is
  covered because another is, and it reports the outcome per surface so the pass is
  auditable. A skip must be a checked conclusion, not an assumption.

## [1.3.0] - 2026-07-07

### Added

- **Uninstall prompt** (in the README): a copy-paste block that removes Flight Deck
  cleanly. It inventories what is installed, then removes the skills, the Concise
  output style, the hooks and their settings.json entries, the CLAUDE.md activation
  block, and the update-check cache, showing a diff and asking before each change so
  nothing else is touched. Handles both copied and symlinked installs, and never
  touches the package repo itself.

## [1.2.0] - 2026-07-07

### Added

- **Update-check hook** (`hooks/flight-deck-update-check.sh`): an optional
  SessionStart hook that checks GitHub at most once a day for a release newer
  than the installed `skills/mission-control/VERSION` and, when behind, injects
  a note so the assistant tells you and offers to update. Non-blocking, never
  auto-overwrites, fails open without jq, curl, or network.
- **`VERSION` file** (`skills/mission-control/VERSION`): records the installed
  release so the update-check hook can compare against the latest on GitHub.

### Changed

- README and HOOKS.md document the update-check hook, and the installer prompt
  offers it (registered under SessionStart).

## [1.1.0] - 2026-07-07

### Added

- **Concise output style** (`output-styles/concise.md`): an optional, global output
  style that makes Claude lead with the answer, keep the initial response tight, and
  expand only on request. Structural rules only (lead with the conclusion, a length cap,
  progressive disclosure, format matched to content, diagrams only when structural),
  with a form-not-substance guard-rail so nothing factual is dropped, only deferred.
  Copy it to `~/.claude/output-styles/` and turn it on with `/output-style Concise`.
- **Concision contract in mission-control**: a new "Concision of deliverables and
  reports" section, wired into the Phase 3 final report and the Phase 2 subagent brief,
  so the skill's own deliverables and reports lead with the conclusion, summarize first,
  and offer detail on request without trimming substance.

### Changed

- README documents verbosity as the eighth default weakness Flight Deck addresses, and
  covers installing the Concise output style.

## [1.0.0] - 2026-07-07

Initial public release.

### Added

- **mission-control skill**: plan / delegate / verify orchestration. The session model
  plans and verifies; execution goes to calibrated subagents running in parallel, each
  with a self-contained brief. Covers delegation, model-tier routing, reasoning-effort
  calibration, over-engineering avoidance, memory and docs recall, and cost control.
- **test-discipline skill**: choose the proof before writing code, run the repository's
  own named check, cite its output, and scale the proof to the size of the change.
  Called by mission-control code lots, usable on its own.
- **hooks**: `verify-reminder` (a non-blocking nudge toward verification before a push)
  and `fanout-guard` (enforces model-tier calibration on fan-out whether or not the
  skill loaded). Registration steps in `hooks/HOOKS.md`.
- **CLAUDE-md-activation.md**: the activation block that makes mission-control the
  default execution mode on Fable 5 and Opus-class sessions, with the start-of-session
  announcement and the opt-out phrases.

[1.7.1]: https://github.com/CaseReed/flight-deck/releases/tag/v1.7.1
[1.7.0]: https://github.com/CaseReed/flight-deck/releases/tag/v1.7.0
[1.6.0]: https://github.com/CaseReed/flight-deck/releases/tag/v1.6.0
[1.5.0]: https://github.com/CaseReed/flight-deck/releases/tag/v1.5.0
[1.4.0]: https://github.com/CaseReed/flight-deck/releases/tag/v1.4.0
[1.3.1]: https://github.com/CaseReed/flight-deck/releases/tag/v1.3.1
[1.3.0]: https://github.com/CaseReed/flight-deck/releases/tag/v1.3.0
[1.2.0]: https://github.com/CaseReed/flight-deck/releases/tag/v1.2.0
[1.1.0]: https://github.com/CaseReed/flight-deck/releases/tag/v1.1.0
[1.0.0]: https://github.com/CaseReed/flight-deck/releases/tag/v1.0.0
