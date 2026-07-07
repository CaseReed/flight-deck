# design-fidelity — a Flight Deck skill

**A verified Claude Design → Claude Code bridge.**

Date: 2026-07-07 · Target package version: Flight Deck 1.4.0 · Status: design approved, pending spec review.

---

## 1. Context and problem

Claude Design (Anthropic Labs, `claude.ai/design`, beta since 2026-06-17) now connects
bidirectionally to Claude Code. The link is real and rests on a **confirmed, stable
surface**: the slash commands `/design`, `/design-sync`, `/design-login`, plus an official
MCP server `claude-design` at `https://api.anthropic.com/v1/design/mcp`. Design→Code passes
a "handoff bundle" (Claude Code continues from existing work, not from a screenshot).
Code→Design pushes built work back via `/design-sync`.

Two facts shape the whole design:

1. **The official flow already self-checks.** `/design-sync` "builds with your components,
   checks its output against your design system, and makes corrections before you see it."
   A skill that merely imports and builds therefore **duplicates the official tool**. The
   only non-redundant contribution — and precisely Flight Deck's thesis — is **independent,
   browser-grounded verification**: the self-check is the model grading its own homework;
   Flight Deck supplies the independent proof.

2. **The MCP internals are beta and unstable.** The exact tool functions of the
   `claude-design` MCP are documented nowhere, and the auto-injected `claude_design` MCP
   returns 404/401 for some accounts (open `anthropics/claude-code` issues #69313, #69324).
   A durable skill must **not** depend on these undocumented internals.

**Problem statement:** provide a Flight Deck discipline that governs the Claude Design →
Claude Code trajectory and *proves*, in a real browser, that the shipped UI matches the
design — composing with existing tooling instead of reimplementing it, and depending only on
stable primitives.

## 2. Goals and non-goals

**Goals**
- Own one thing well: an independent, browser-grounded **fidelity gate** (design reference
  vs. rendered UI) that yields a pass/fail verdict and a ranked punch-list.
- Orchestrate the full trajectory (import → build → verify → close-out) by **calling**
  existing tools, not rebuilding them.
- Stay robust to beta churn: no hard dependency on undocumented MCP internals; degrade
  gracefully.
- Fit Flight Deck's identity — a discipline that strengthens the verification axis, a
  companion skill (like `test-discipline`), not a new default-weakness axis and not a wrapper.

**Non-goals (v1)**
- Reimplementing import or build (owned by the official commands and by `mission-control`).
- Code→Design push-back via `/design-sync` (deferred to phase 2; most beta-risky).
- Design-regression persistence (phase 2).
- Packaging Flight Deck as a distributable Claude Code plugin (phase 2).

## 3. Approach

**Verify-spine that orchestrates.** The skill possesses the fidelity-verification discipline
and orchestrates the rest by invoking the confirmed slash commands for import and
`mission-control` for the build. Center of gravity and durable value = independent
verification. This honors the "whole trajectory" intent while keeping the skill discipline-first,
non-duplicative, and beta-robust.

## 4. What it OWNS — the fidelity gate

Principle: *the `/design-sync` self-check is the model correcting its own copy; here we supply
the independent proof.* Built on **stable primitives only** (design reference + rendered app +
Chrome), never on the flaky MCP.

1. **Reference.** Capture the authoritative design at the target breakpoints from a stable
   source — the `claude.ai/design/<id>` URL, or an export (standalone HTML / `.zip` / PDF /
   screenshot). Never from the undocumented MCP.
2. **Render.** Launch the real app (the `run` / `verify` pattern) and open it in Chrome
   (claude-in-chrome) at the same breakpoints. Capture side-by-side per breakpoint.
3. **Compare on a rubric** (not on vibes). Structured dimensions: structure/layout;
   spacing & rhythm; typography (family/size/weight/leading); color & tokens; component
   states (hover/focus/active/disabled/loading/empty/error); responsive; motion; a11y
   (contrast, focus order, semantics). Each item: conforms / diverges (with the specific
   built-vs-intended values) / not-verifiable.
4. **Gap contract.** Before comparing, enumerate what the reference does **not** define
   (undefined states, motion, in-between breakpoints, dark mode, a11y specifics). These are
   decided with the craft skill and verified against the **craft bar**, not marked as design
   divergences — this keeps the gate fair and prevents false failures.
5. **Token discipline.** Explicitly verify the built code uses the design-system tokens
   (colors/typography/components) rather than hardcoded values — catches "looks right but
   bypasses the system," stronger than a pixel compare.
6. **Punch-list.** Divergences ranked by severity, with `file:line` where possible, intended
   value vs. built value. Pass = no blocking divergence; otherwise the list becomes the next
   build lot.
7. **Adversarial pass** (composed with `mission-control`). A skeptic re-checks for divergences
   the first pass missed, so "it looks the same" does not survive a single glance.

The detailed rubric lives in `references/fidelity-rubric.md`, loaded on demand so `SKILL.md`
stays lean.

## 5. What it ORCHESTRATES — composes, does not rebuild

- **Import.** Knows the confirmed commands (`/design-login`, `/design`, `/design-sync`) and the
  handoff-bundle concept; drives them; **degrades gracefully** when the MCP is unavailable
  (the known 404/401) — falling back to an exported HTML/zip or the design URL as reference.
  Never hard-fails on the flaky part.
- **Build.** Delegated to **`mission-control`** (calibrated lots in parallel) + **`test-discipline`**
  (pick the proof). The build lots invoke the **craft skill** — **`frontend-design` by default**
  (now shipped with Claude Code, so portable for the community), and the skill is **agnostic**:
  it uses `ui-ux-pro-max` when that is present/preferred.
  - **Reproduce-not-invent guardrail:** the Claude Design reference is **authoritative**. The
    craft skill refines the *how* and fills what the design leaves **undefined**; it never
    "corrects" the explicit design. The fidelity gate enforces this — a build that "improved"
    the design away from the reference is a divergence, flagged.
- **Close-out.** Knowledge pass (memory/docs). Code→Design push-back is **out of scope for v1**.

## 6. Interfaces and composition contract

- **Input:** a design reference (URL | export | screenshot) + a repo to build in.
- **Output:** a verdict (pass/fail) + a ranked punch-list.
- **Testable in isolation:** given a design reference and a running UI, does it produce an
  accurate divergence list?
- **Depends on:** `mission-control` (build orchestration), `test-discipline` (proof), a craft
  skill (`frontend-design`/`ui-ux-pro-max`), claude-in-chrome (render + screenshot), the
  `run`/`verify` app-launch pattern.

## 7. Structure and package wiring

New skill folder:
```
skills/design-fidelity/
  SKILL.md                    # lean: triggers, trajectory, rubric summary, composition, degradation, guardrail
  VERSION
  README.md                   # like mission-control's
  references/fidelity-rubric.md   # the detailed checklist, loaded on demand
```

Package release (Flight Deck 1.4.0):
- Bump the package `VERSION` to `1.4.0`.
- `CHANGELOG.md`: add the 1.4.0 entry.
- **Installer prompt** (README): add copying `skills/design-fidelity/` with the same
  diff/confirmation safety as the other skills.
- **Uninstaller prompt** (README): add removing `skills/design-fidelity/`.
- README "What's inside": one bullet for the new skill.
- **Not a 9th axis.** It specializes the verification axis (a companion, like `test-discipline`);
  the 8-weakness table does not change.

## 8. Robustness / degradation rules

- No hard dependency on the undocumented `claude-design` MCP tool surface.
- If the MCP or a slash command fails, fall back to export/URL as the reference and continue.
- The gate never blocks on a source it could not obtain; it reports "not-verifiable" honestly
  rather than guessing (Flight Deck: no silent gaps).

## 9. Decisions locked in

- **Name:** `design-fidelity` (descriptive trigger; aviation nod "final approach" in the README
  framing only).
- **Craft-skill default:** `frontend-design`, skill agnostic (uses `ui-ux-pro-max` if present).
- **Push-back code→design:** phase 2.
- **Community plugin packaging:** phase 2.

## 10. Phase 2 (out of this spec)

- Design-regression guard: persist the reference capture + verdict as an artifact to re-check
  later changes against the design.
- Code→Design push-back via `/design-sync`, under a review gate (never overwrite silently).
- Package Flight Deck as a distributable Claude Code plugin (`.claude-plugin/marketplace.json`)
  for the community marketplace, or keep the self-hosted installer.

## 11. Risks and open uncertainties

- The integration is **beta**; commands and the MCP may change. The skill mitigates by binding
  to the stable surface and degrading gracefully.
- The **handoff-bundle format** is not publicly specified; the skill treats it as opaque and
  works from renderable references (URL/export), not from parsing bundle internals.
- The auto-injected `claude_design` MCP is reported broken for some accounts; the skill must
  never assume it is present or working.

## 12. Success criteria

- On a real Claude Design → Claude Code build, the skill produces a browser-grounded pass/fail
  verdict and an actionable, ranked punch-list at the target breakpoints.
- It runs the build through `mission-control` + `test-discipline` + the craft skill without
  reimplementing them.
- It degrades to export/URL references when the MCP is unavailable, without hard-failing.
- `SKILL.md` stays lean (rubric detail in `references/`), consistent with Flight Deck's
  authoring rules.

## 13. Sources

- Claude Design launch: https://www.anthropic.com/news/claude-design-anthropic-labs
- Claude Design ↔ Code update (2026-06-17): https://claude.com/blog/claude-design-stays-on-brand-for-daily-work
- Get started with Claude Design: https://support.claude.com/en/articles/14604416-get-started-with-claude-design
- Claude Code — extend with skills: https://code.claude.com/docs/en/skills
- Claude Code — plugins: https://code.claude.com/docs/en/plugins
- Discover/install plugins: https://code.claude.com/docs/en/discover-plugins
- MCP beta breakage: https://github.com/anthropics/claude-code/issues/69313 · https://github.com/anthropics/claude-code/issues/69324
- Vercel send-to: https://vercel.com/changelog/claude-design-and-vercel
