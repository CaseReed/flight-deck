# design-fidelity Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `design-fidelity` skill to the Flight Deck package that governs the Claude Design to Claude Code handoff and proves, in a real browser, that the shipped UI matches the design, then wire it into the package for a 1.4.0 release.

**Architecture:** A verify-spine skill. It owns an independent, browser-grounded fidelity gate (design reference vs rendered UI) and orchestrates import and build by calling existing tools (confirmed slash commands, mission-control, test-discipline, a craft skill) rather than reimplementing them. The deliverables are markdown skill files plus package-integration edits. There is no code runtime and no automated test harness, so each task is verified by concrete read/grep acceptance checks, not by a unit-test framework.

**Tech Stack:** Markdown skill authoring (Claude Code `SKILL.md` convention), Flight Deck package conventions (installer/uninstaller prompts in README, CHANGELOG, the `skills/mission-control/VERSION` file read by the update-check hook). Authoring follows the `skill-creator` / `superpowers:writing-skills` conventions.

## Global Constraints

Copied verbatim from the spec and the package's own rules. Every task's requirements implicitly include this section.

- **No AI-authorship footprint** in any artifact or commit: no "Co-Authored-By", no AI tool signature, no `.claude/` path references in commit messages. The product names "Claude Design" and "Claude Code" are legitimate and required in the content; the ban is on AI *authorship* marks, not on naming the products.
- **No em-dash and no double-hyphen dash** anywhere (files, commits). Use commas, parentheses, or colons.
- **All artifacts in English.**
- **SKILL.md frontmatter convention** (matches `mission-control` and `test-discipline`): a `---` block with `name:` equal to the folder name and a folded `description: >-` scalar that includes what it does, the trigger phrases, and the opt-out phrases.
- **SKILL.md stays lean** (Flight Deck authoring rule, target under ~200 lines). The detailed rubric lives in `references/fidelity-rubric.md`, loaded on demand.
- **Package version** lives in `skills/mission-control/VERSION` (the update-check hook reads it as the installed release). Bump it to `1.4.0`. Do NOT add a per-skill `VERSION` to `design-fidelity`: the convention is that only `mission-control` carries the package version, and `test-discipline` has none.
- **Installer and uninstaller stay symmetric:** every skill the installer copies, the uninstaller removes, in every place each is listed (prompt steps and manual sections).
- **Skill invariants** (must be stated in the skill and preserved): the Claude Design reference is authoritative (reproduce, do not reinvent); depend only on stable primitives (design reference, rendered app, Chrome), never on the undocumented `claude-design` MCP internals; degrade gracefully when a command or the MCP is unavailable, reporting "not-verifiable" rather than guessing.

---

### Task 1: Scaffold `design-fidelity/` and author `SKILL.md`

**Files:**
- Create: `skills/design-fidelity/SKILL.md`

**Interfaces:**
- Produces: the skill's trigger surface and body. Later files rely on the folder name `design-fidelity` and the pointer `references/fidelity-rubric.md` (created in Task 2). The README (Task 3) and the package "What's inside" bullet (Task 4) summarize this file; keep the one-line purpose consistent: "a verified Claude Design to Claude Code bridge".

- [ ] **Step 1: Create the folder and write the frontmatter block**

Create `skills/design-fidelity/SKILL.md` starting with exactly this frontmatter (folded description, no em-dash):

```
---
name: design-fidelity
description: >-
  Governs the Claude Design to Claude Code handoff and proves, in a real
  browser, that the shipped UI matches the design. Owns an independent fidelity
  gate (design reference vs rendered UI, a structured rubric, a gap contract,
  token discipline, a ranked punch-list, and an adversarial re-check) and
  orchestrates the rest by calling the confirmed slash commands for import plus
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
---
```

- [ ] **Step 2: Write the body from this exact section skeleton**

Author concise prose (aim under 150 body lines) following `superpowers:writing-skills`. Use exactly these sections and cover exactly these points; do not add scope beyond them:

1. **When this fires (and when it does not).** Fires on the triggers above and, on a session where mission-control is active, when a Claude Design URL / export / handoff bundle is the input. It does NOT invent a design from scratch (that is Claude Design's or a craft skill's job); it reproduces and verifies an existing design. Honor the opt-out phrases.
2. **The trajectory it governs** (one line each, emphasize compose-not-rebuild): import, build, verify (the owned core), close-out.
3. **The fidelity gate (owned core).** Summarize the seven moves: (1) capture the authoritative reference from a stable source (the `claude.ai/design/<id>` URL or an export: standalone HTML, `.zip`, PDF, screenshot); (2) render the real app and open it in Chrome at the target breakpoints, side by side; (3) compare on the rubric; (4) apply the gap contract; (5) check token discipline; (6) emit a ranked punch-list; (7) run an adversarial re-check. Point to `references/fidelity-rubric.md` for the full rubric; do not inline the full rubric here.
4. **Composition contract.** Build is delegated to `mission-control` (calibrated lots) and `test-discipline` (pick the proof); build lots invoke the craft skill, `frontend-design` by default, `ui-ux-pro-max` when present or preferred. State the reproduce-not-invent guardrail: the reference is authoritative; craft fills undefined gaps and never overrides the explicit design; a build that drifts from the reference is a divergence and is flagged.
5. **Degradation and stable-primitives rule.** No hard dependency on the undocumented `claude-design` MCP; on MCP or command failure, fall back to an export or the design URL as the reference and continue; never block on a source it could not obtain, report "not-verifiable" honestly (no silent gaps).
6. **Close-out.** Run the Flight Deck knowledge pass (memory, CLAUDE.md, project docs). Code-to-design push-back is out of scope (phase 2).

- [ ] **Step 3: Verify the frontmatter and triggers**

Run:
```bash
cd /Users/jtavernier/Desktop/flight-deck
awk 'NR==1{print} /^name:/{print} /^description:/{print}' skills/design-fidelity/SKILL.md | head -3
grep -c -E 'implement this Claude Design design|verify design fidelity|without design-fidelity|skip the fidelity check' skills/design-fidelity/SKILL.md
```
Expected: line 1 is `---`; a `name: design-fidelity` line; a `description: >-` line; the grep count is `>= 3` (triggers and opt-out present).

- [ ] **Step 4: Verify the lean-and-clean constraints**

Run:
```bash
cd /Users/jtavernier/Desktop/flight-deck
wc -l skills/design-fidelity/SKILL.md
grep -nE '—|--' skills/design-fidelity/SKILL.md && echo "DASH FOUND (fix)" || echo "no forbidden dash"
grep -c 'references/fidelity-rubric.md' skills/design-fidelity/SKILL.md
```
Expected: line count under ~200; "no forbidden dash"; the rubric pointer count is `>= 1`.

- [ ] **Step 5: Commit**

```bash
cd /Users/jtavernier/Desktop/flight-deck
git add skills/design-fidelity/SKILL.md
git commit -m "feat(design-fidelity): add skill body and triggers"
```

---

### Task 2: Author `references/fidelity-rubric.md`

**Files:**
- Create: `skills/design-fidelity/references/fidelity-rubric.md`

**Interfaces:**
- Consumes: the seven-move summary in `SKILL.md` (Task 1). This file is the full expansion the SKILL.md pointer resolves to.
- Produces: the rubric dimensions, the gap-contract procedure, the token-discipline checks, the adversarial protocol, and the punch-list output schema that the fidelity gate emits.

- [ ] **Step 1: Write the rubric file from this exact skeleton**

Create the file covering exactly these parts, concrete and checkable (no vague "check quality" lines):

1. **Breakpoint set.** State the default breakpoints to verify (mobile ~375px, tablet ~768px, desktop ~1280px, plus any the design specifies) and that both the reference and the render are captured at each.
2. **Dimensions**, each with concrete checks and what counts as a divergence: structure/layout; spacing and rhythm; typography (family, size, weight, line-height); color and tokens; component states (default, hover, focus, active, disabled, loading, empty, error); responsive behavior across the breakpoints; motion and interaction; accessibility (contrast ratios, focus order, semantics/roles). For each item the verdict is one of: conforms / diverges (record intended value vs built value) / not-verifiable (say why).
3. **Gap contract procedure.** Before comparing, enumerate what the reference does not define (undefined states, motion, in-between breakpoints, dark mode, a11y specifics). These are decided with the craft skill and verified against the craft bar, NOT recorded as design divergences.
4. **Token discipline.** Verify the built code uses the design-system tokens (colors, typography, components) rather than hardcoded values; a hardcoded value that duplicates a token is a divergence.
5. **Adversarial re-check protocol.** A second pass that assumes the first pass was too lenient and actively hunts for missed divergences, especially in states, responsive edges, and tokens.
6. **Punch-list output schema.** Each entry: severity (blocking / major / minor), `file:line` when known, dimension, intended value, built value, suggested fix. Verdict rule: pass = no blocking entries; otherwise the punch-list becomes the next build lot.

- [ ] **Step 2: Verify coverage and cleanliness**

Run:
```bash
cd /Users/jtavernier/Desktop/flight-deck
for kw in "Breakpoint" "typography" "states" "Gap contract" "token" "Adversarial" "Punch-list" "severity"; do
  printf '%-14s ' "$kw"; grep -qi "$kw" skills/design-fidelity/references/fidelity-rubric.md && echo present || echo MISSING
done
grep -nE '—|--' skills/design-fidelity/references/fidelity-rubric.md && echo "DASH FOUND (fix)" || echo "no forbidden dash"
```
Expected: every keyword `present`; "no forbidden dash".

- [ ] **Step 3: Commit**

```bash
cd /Users/jtavernier/Desktop/flight-deck
git add skills/design-fidelity/references/fidelity-rubric.md
git commit -m "feat(design-fidelity): add the fidelity rubric reference"
```

---

### Task 3: Author the skill `README.md`

**Files:**
- Create: `skills/design-fidelity/README.md`
- Read for style: `skills/mission-control/README.md`

**Interfaces:**
- Consumes: the skill purpose and triggers from `SKILL.md` (Task 1). Keep the one-line purpose identical to Task 1 and to the package bullet in Task 4.

- [ ] **Step 1: Write the README mirroring the mission-control README structure**

Read `skills/mission-control/README.md` for tone and structure, then write `skills/design-fidelity/README.md` with these sections: a one-line purpose ("a verified Claude Design to Claude Code bridge"); what it does (the fidelity gate and the compose-not-rebuild orchestration); what is inside (`SKILL.md`, `references/fidelity-rubric.md`); usage and triggers (copy the trigger and opt-out phrases from the frontmatter); how it composes (mission-control, test-discipline, the craft skill, the reproduce-not-invent guardrail); requirements (Claude Code with skills; claude-in-chrome for the render step; a Claude Design reference as input). No em-dash.

- [ ] **Step 2: Verify style match and cleanliness**

Run:
```bash
cd /Users/jtavernier/Desktop/flight-deck
grep -qi "verified Claude Design" skills/design-fidelity/README.md && echo "purpose present" || echo "purpose MISSING"
grep -qi "mission-control" skills/design-fidelity/README.md && grep -qi "frontend-design" skills/design-fidelity/README.md && echo "composition present" || echo "composition MISSING"
grep -nE '—|--' skills/design-fidelity/README.md && echo "DASH FOUND (fix)" || echo "no forbidden dash"
```
Expected: "purpose present"; "composition present"; "no forbidden dash".

- [ ] **Step 3: Commit**

```bash
cd /Users/jtavernier/Desktop/flight-deck
git add skills/design-fidelity/README.md
git commit -m "docs(design-fidelity): add skill README"
```

---

### Task 4: Wire `design-fidelity` into the package for 1.4.0

**Files:**
- Modify: `skills/mission-control/VERSION` (bump to `1.4.0`)
- Modify: `CHANGELOG.md` (add the `[1.4.0]` entry and its link)
- Modify: `README.md` (What's inside bullet; installer prompt steps 2 and 3; uninstaller prompt steps 1 and 2; manual install and manual uninstall)

**Interfaces:**
- Consumes: the folder `skills/design-fidelity/` and its one-line purpose from Tasks 1-3.
- Produces: a releasable package where the installer copies and the uninstaller removes `design-fidelity`, symmetrically, and the update-check version reads `1.4.0`.

- [ ] **Step 1: Bump the package version**

Overwrite `skills/mission-control/VERSION` so its entire content is exactly:
```
1.4.0
```

- [ ] **Step 2: Add the CHANGELOG entry**

In `CHANGELOG.md`, insert this block immediately after line 7 (the blank line under the intro, above `## [1.3.1] - 2026-07-07`):

```markdown
## [1.4.0] - 2026-07-07

### Added

- **design-fidelity skill**: a verified Claude Design to Claude Code bridge. It
  owns an independent, browser-grounded fidelity gate (design reference vs the
  rendered UI, a structured rubric, a gap contract, token discipline, a ranked
  punch-list, and an adversarial re-check) and orchestrates import and build by
  calling the confirmed slash commands, mission-control, test-discipline, and a
  craft skill (frontend-design by default, ui-ux-pro-max when present), rather
  than reimplementing them. The Claude Design reference stays authoritative and
  the skill depends only on stable primitives, never on the undocumented beta
  claude-design MCP internals.

```

Then add the version link. In the link list at the bottom, insert this line immediately above the `[1.3.0]:` line:
```markdown
[1.4.0]: https://github.com/CaseReed/flight-deck/releases/tag/v1.4.0
```

- [ ] **Step 3: Add the "What's inside" bullet in README**

In `README.md`, immediately after the `skills/test-discipline/` bullet (the block ending "Called by mission-control's code lots, and usable on its own."), insert this bullet:

```markdown
- **skills/design-fidelity/** : the design-handoff companion. Governs the Claude
  Design to Claude Code handoff and proves, in a real browser, that the shipped
  UI matches the design. It owns an independent fidelity gate (design reference
  vs the rendered UI, a structured rubric, a gap contract, token discipline, a
  ranked punch-list, an adversarial re-check) and orchestrates the build through
  mission-control, test-discipline, and a craft skill (frontend-design by
  default), reproducing the design rather than reinventing it.
```

- [ ] **Step 4: Wire the installer prompt (README)**

In the installer prompt, step 2, replace:
```
Look for ~/.claude/skills/mission-control/ and ~/.claude/skills/test-discipline/, check whether
```
with:
```
Look for ~/.claude/skills/mission-control/, ~/.claude/skills/test-discipline/, and ~/.claude/skills/design-fidelity/, check whether
```

In the installer prompt, step 3, replace:
```
Copy skills/mission-control/ and skills/test-discipline/ from the clone into ~/.claude/skills/. If either folder already exists there, show me a diff against the incoming version before doing anything, and ask whether to overwrite, skip, or merge.
```
with:
```
Copy skills/mission-control/, skills/test-discipline/, and skills/design-fidelity/ from the clone into ~/.claude/skills/. If any of these folders already exists there, show me a diff against the incoming version before doing anything, and ask whether to overwrite, skip, or merge.
```

- [ ] **Step 5: Wire the uninstaller prompt (README)**

In the uninstaller prompt, step 1 inventory, replace:
```
   - ~/.claude/skills/mission-control/ and ~/.claude/skills/test-discipline/ (either real folders or symlinks)
```
with:
```
   - ~/.claude/skills/mission-control/, ~/.claude/skills/test-discipline/, and ~/.claude/skills/design-fidelity/ (either real folders or symlinks)
```

In the uninstaller prompt, step 2, replace:
```
2. Remove the skills. Delete ~/.claude/skills/mission-control/ and ~/.claude/skills/test-discipline/, whether each is a real folder or a symlink.
```
with:
```
2. Remove the skills. Delete ~/.claude/skills/mission-control/, ~/.claude/skills/test-discipline/, and ~/.claude/skills/design-fidelity/, whether each is a real folder or a symlink.
```

- [ ] **Step 6: Wire the manual install and manual uninstall (README)**

In "Manual install", step 1, replace:
```
1. Copy `skills/mission-control/` and `skills/test-discipline/` into
```
with:
```
1. Copy `skills/mission-control/`, `skills/test-discipline/`, and `skills/design-fidelity/` into
```

In "Manual uninstall", step 1, replace:
```
1. Remove `~/.claude/skills/mission-control/` and `~/.claude/skills/test-discipline/`
```
with:
```
1. Remove `~/.claude/skills/mission-control/`, `~/.claude/skills/test-discipline/`, and `~/.claude/skills/design-fidelity/`
```

- [ ] **Step 7: Verify version, changelog, and installer/uninstaller symmetry**

Run:
```bash
cd /Users/jtavernier/Desktop/flight-deck
echo "VERSION: $(cat skills/mission-control/VERSION)"
grep -c '## \[1.4.0\]' CHANGELOG.md
grep -c '\[1.4.0\]: https' CHANGELOG.md
echo "installer design-fidelity mentions: $(grep -c 'skills/design-fidelity/\|skills\\design-fidelity' README.md)"
echo "design-fidelity path count in README: $(grep -c 'design-fidelity' README.md)"
```
Expected: `VERSION: 1.4.0`; the `## [1.4.0]` count is `1`; the link count is `1`; `design-fidelity` appears in README multiple times (What's inside + installer steps 2 and 3 + uninstaller steps 1 and 2 + both manual sections, so `>= 7`).

- [ ] **Step 8: Verify symmetry explicitly (every skill copied is also removed)**

Run:
```bash
cd /Users/jtavernier/Desktop/flight-deck
for s in mission-control test-discipline design-fidelity; do
  ic=$(grep -c "skills/$s/\|skills/$s\b" README.md)
  printf 'skill %-16s README mentions: %s\n' "$s" "$ic"
done
grep -nE '—|--' CHANGELOG.md README.md skills/mission-control/VERSION && echo "DASH FOUND (fix)" || echo "no forbidden dash"
```
Expected: all three skills appear in README (design-fidelity present in both installer and uninstaller); "no forbidden dash".

- [ ] **Step 9: Commit**

```bash
cd /Users/jtavernier/Desktop/flight-deck
git add skills/mission-control/VERSION CHANGELOG.md README.md
git commit -m "feat: wire design-fidelity into package for 1.4.0"
```

---

## Self-Review

**1. Spec coverage:**
- Fidelity gate (reference, render, rubric, gap contract, token discipline, punch-list, adversarial): Task 1 (summary) + Task 2 (full rubric). Covered.
- Orchestration (import with degradation, build via mission-control/test-discipline/craft skill, reproduce-not-invent guardrail): Task 1 sections 2, 4, 5. Covered.
- Structure (SKILL.md lean, VERSION scheme, README, references): Tasks 1-3, with the VERSION correction (package version in mission-control/VERSION, no per-skill VERSION) captured in Global Constraints and Task 4 Step 1. Covered.
- Package wiring (VERSION bump, CHANGELOG, README What's inside + installer + uninstaller): Task 4. Covered.
- Not a 9th axis: no edit touches the eight-weakness table (lines 14-23) or the intro count; confirmed by scope of Task 4 edits. Covered.
- Phase 2 items (push-back, regression guard, plugin packaging): explicitly excluded, stated in Task 1 section 6 and not implemented. Covered.

**2. Placeholder scan:** No "TBD"/"TODO"/"handle edge cases" style placeholders. Prose-authoring steps specify exact frontmatter, exact section skeletons, and exact required content points; mechanical edits give verbatim old/new strings. No gaps.

**3. Type/name consistency:** Folder `design-fidelity` and pointer `references/fidelity-rubric.md` are identical across Tasks 1-4. The one-line purpose "a verified Claude Design to Claude Code bridge" is identical in Task 1, Task 3, and Task 4. Craft-skill default `frontend-design` (agnostic to `ui-ux-pro-max`) is consistent. VERSION target `1.4.0` consistent in Global Constraints and Task 4.
