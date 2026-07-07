# Changelog

All notable changes to Flight Deck are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[1.0.0]: https://github.com/CaseReed/flight-deck/releases/tag/v1.0.0
