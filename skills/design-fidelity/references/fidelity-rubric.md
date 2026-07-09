# Fidelity rubric

This file is the full expansion of the seven-move fidelity gate summarized in
`SKILL.md` section 3. It is the detailed, self-contained rubric a build lot reads
to run the check: what to compare, how to score each dimension, what counts as a
divergence, and what the gate emits when it fails. It does not restate the moves
themselves; read `SKILL.md` first for the trajectory, then use this file to run
move 3 (compare), move 4 (gap contract), move 5 (token discipline), move 6
(punch-list), and move 7 (adversarial re-check).

## 1. Breakpoints and capture

Verify at these breakpoints by default:

- Mobile: approximately 375px wide.
- Tablet: approximately 768px wide.
- Desktop: approximately 1280px wide.

If the design reference specifies its own breakpoints (a Claude Design frame set,
an explicit spec, or named states in the export), use those instead of, or in
addition to, the defaults above. Do not silently drop a defined breakpoint to
save time.

Both the reference and the rendered app are captured at each breakpoint before
comparison starts. The rendered app is captured through the Playwright MCP, the default
rendering tool for this gate. A dimension checked at only one breakpoint, or checked against
a reference screenshot that does not cover that breakpoint, is not-verifiable at
the missing breakpoint, not silently passed.

### Capture protocol

A wrong verdict often traces to a bad capture, not a bad build. Capture every screenshot so the frame is deterministic and readable, or the comparison downstream is worthless:

- **Freeze motion.** Disable animations and transitions for the shot (Playwright's `animations: 'disabled'` screenshot option), and set the browser context to reduced motion (`reducedMotion: 'reduce'`). A frame caught mid-animation, or an entrance animation that never fired, reads as a broken or missing element when the build is fine.
- **Foreground the page before capturing.** A backgrounded or hidden tab throttles or pauses `requestAnimationFrame`, so scroll-in and mount animations stay stuck at their initial state (typically `opacity: 0`), and the screenshot shows content that looks absent. Bring the page to front (`page.bringToFront()`), or disable animations per the point above, before the shot. This one gotcha produces false "broken" reads that have nothing to do with the app.
- **Wait for the render to settle.** Wait for `load`, then for `document.fonts.ready`, then for a real app-ready signal (a key element visible, the skeleton or spinner gone), then a short buffer for late layout shifts. Do not wait on network idle; a single analytics beacon or long-poll never resolves it and the capture hangs or fires early.
- **Capture at readable resolution.** Use a 2x device scale factor (`deviceScaleFactor: 2`, or the Playwright MCP `scale: 'device'` option) so small UI text and fine spacing are legible in the frame. At 1x, 12-13px text is often too ambiguous for a reliable read.
- **Capture full page and each breakpoint.** Take a full-page shot to catch overflow and broken content below the fold, and a shot at each breakpoint from the set above, since layout defects are frequently breakpoint-specific. For a lazy-loading page, scroll the content into view first so a stitched full-page shot does not render blank regions.
- **Mask genuinely dynamic regions** (timestamps, avatars, live counters) with Playwright's `mask` option so variable content is not scored as a defect.

The captures are transient gate evidence; purge them once the user has signed off, per the close-out in `SKILL.md`.

## 2. Dimensions

Run every dimension below against both the reference and the render, at every
breakpoint from section 1 that applies to that dimension. For each checked item,
record one verdict:

- **conforms**: the built value matches the intended value, within the tolerance
  stated for that check.
- **diverges**: the built value does not match. Record both the intended value
  (from the reference) and the built value (from the render), specific enough
  that the divergence could be fixed without re-inspecting the reference.
- **not-verifiable**: the check could not be run. State why (reference does not
  show this state, breakpoint not captured, tool could not measure it, and so
  on). Never use not-verifiable to avoid a check that could have been run.

### 2.0 Reading a render before scoring it

The failure mode this gate exists to prevent is a confident "looks fine" on a render that is visibly broken. Vision models are documented to be weak at absolute single-image judgment and biased toward passing; these rules force the read onto actual evidence.

- **Describe before you judge.** Before scoring any dimension, describe literally what is visible in each region of the render (header, nav, hero, body, footer), one region at a time. State what is there, not whether it "looks right". A verdict that skips the description is not trustworthy.
- **Run the breakage-signature checklist first.** Before the dimensions below, check the render against the failure signatures listed under this subsection. Any hit is a blocking divergence on its own, regardless of how the dimensions score.
- **A PASS needs cited evidence, not a vibe.** Marking a dimension conforms requires naming the regions inspected and what confirms each rendered correctly. "Looks fine" with no cited region is not a valid conforms; treat it as not-verifiable until evidence is recorded.
- **Cross-reference the accessibility snapshot against the screenshot.** Pull the DOM and accessibility snapshot (Playwright MCP `browser_snapshot`) for the same state as the pixel capture. Any element the snapshot reports as present and visible that cannot be located in the screenshot is a near-mechanical rendering-bug signal (a zero-height container, a stuck `opacity: 0`, a z-index or overlap, an off-screen position). This catches the exact case where the markup is there but nothing painted, which a pixel-only read misses.
- **Zoom into anything suspicious.** When the coarse full-page read flags a region, re-capture that region alone (an element or clip screenshot) and judge the crop on its own. Small defects that vanish in a full-frame read become obvious zoomed in.

Breakage signatures, any one of which is a blocking divergence:

- Horizontal scroll, or content overflowing past the viewport edge.
- A container that should hold content rendering as a zero-height or collapsed empty strip.
- Unstyled flash left on screen: default serif text, unstyled buttons, raw browser defaults anywhere.
- Text with too little contrast to read, up to invisible text the same color as its background.
- Overlapping or clipped text: letters cut off, or text running behind another element.
- A broken or missing image: a broken-image icon, an alt-text box, or a blank rectangle where an image belongs.
- A layout collapsed to a single stacked column at a breakpoint that should render multi-column.
- Elements positioned off-screen or outside their intended container.
- A large unexplained empty gap, usually a collapsed sibling or a missing background.
- Console errors tied to the region under test, pulled alongside the screenshot.

### 2.1 Structure and layout

Checks:
- Element order and hierarchy match (what precedes what, what nests inside what).
- Grid or flex structure matches: number of columns or rows, alignment
  (start, center, end, stretch), and content grouping.
- Container widths and max-widths match, or the built value is a documented
  token/breakpoint-driven equivalent.
- No element is missing from the render that appears in the reference, and no
  element appears in the render that has no counterpart in the reference (unless
  covered by the gap contract in section 3).

Divergence: any of the above does not match, e.g. the reference shows a two-column
layout at desktop and the render is single-column, or a card's internal element
order is swapped.

### 2.2 Spacing and rhythm

Checks:
- Padding and margin on the outermost and inner containers, measured in the
  browser (computed styles via the Playwright MCP, or a ruler tool), compared to the reference's spacing.
- Gap between repeated items (list items, grid cells, stacked sections).
- Vertical rhythm: consistent spacing step between stacked blocks (e.g. section
  to section, heading to body).

Tolerance: within 2px or one token step (whichever is larger) counts as conforms.
Anything beyond that is a divergence.

Divergence: measured spacing differs from the reference by more than the
tolerance, or the render uses an inconsistent step where the reference uses a
consistent one (e.g. reference uses a uniform 16px vertical rhythm, render mixes
12px and 20px with no token backing either).

### 2.3 Typography

Checks, per text role (heading levels, body, caption, label, button text):
- Font family matches (including fallback stack intent, not just the first name).
- Font size matches, in px or the equivalent token.
- Font weight matches (e.g. regular vs medium vs semibold, not just "bold").
- Line height matches, in px or the unitless ratio the design specifies.
- Letter spacing matches when the reference specifies it.

Divergence: any of family, size, weight, or line-height differs from the
reference for a given text role. A close-but-not-equal value (e.g. reference
specifies 24px/1.3, render ships 22px/1.2) is a divergence, not a rounding
tolerance; record the exact intended and built values.

### 2.4 Color and tokens

Checks:
- Foreground, background, border, and accent colors match the reference's
  swatches (hex or token name) for each element role.
- State-driven color changes (hover tint, active shade, disabled opacity) match
  where the reference shows them.
- Colors resolve to design-system tokens, not raw hex values that happen to look
  right (this check overlaps with section 4, token discipline, but is scored
  here for the visual match itself).

Divergence: a rendered color differs from the reference's swatch beyond a minor
perceptual tolerance (a few units in RGB from compression artifacts is
acceptable; a different hue, a different shade step, or a wrong token is not).

### 2.5 Component states

Checks, for every interactive or stateful component the reference documents:
default, hover, focus, active, disabled, loading, empty, error.

For each state the reference shows explicitly:
- Visual treatment matches (color, border, shadow, icon, text change).
- The state is actually reachable in the render (e.g. a documented disabled
  state exists in code and can be triggered, not just described).

Divergence: a state the reference shows explicitly is missing from the render,
or is implemented but renders differently than shown (wrong hover color, no
focus ring where one is specified, error state missing the error message
styling).

States the reference does not show at all are not divergences here; they are
handled by the gap contract in section 3.

### 2.6 Responsive behavior across breakpoints

Checks, per breakpoint from section 1:
- Layout reflows the way the reference shows for that breakpoint (column count,
  stacking order, visibility of elements that are hidden or shown per
  breakpoint).
- Typography and spacing scale the way the reference shows, not left at the
  desktop values, and not scaled arbitrarily.
- Touch targets stay usable at mobile widths (see also section 2.8 for
  accessibility sizing).

Divergence: the render's behavior at a given breakpoint does not match the
reference's documented behavior at that breakpoint, e.g. the reference collapses
navigation into a menu icon under 768px and the render keeps the full nav bar.

### 2.7 Motion and interaction

Checks, for every animation or transition the reference documents (explicitly
specified, or shown via a prototype/video/annotation):
- Trigger matches (on load, on hover, on scroll, on click).
- Duration and easing are in the same family as specified (e.g. a fast snap vs a
  slow ease is a divergence even if the exact millisecond count is not
  specified).
- End state matches the reference's final frame.

Divergence: a documented animation is missing, uses a different trigger, or ends
in a visibly different state than the reference. Motion the reference does not
document is a gap-contract item (section 3), not a divergence.

### 2.8 Accessibility

Checks:
- Contrast ratio for text against its background meets WCAG AA (4.5:1 for normal
  text, 3:1 for large text at 18px+ regular or 14px+ bold) for every text/
  background pair the reference presents, measured with a contrast tool, not
  eyeballed.
- Focus order follows a logical reading/interaction order (tab through the
  render and confirm the order matches the visual and semantic structure).
- Semantic HTML and roles are used where the reference implies structure (a
  heading looks like a heading and is marked up as one, a button is a `button`
  element or has `role="button"`, a list is a list element).
- Interactive elements have accessible names (visible text, `aria-label`, or
  equivalent), not just visual icons with no label.

Divergence: a measured contrast ratio falls below the AA threshold for a pair the
reference presents as final (not a gap-contract placeholder), focus order skips
or misorders interactive elements, or a semantic role is missing where the
visual clearly implies one (e.g. a div styled as a button with no role, no
keyboard handler, and no accessible name).

## 3. Gap contract procedure

Run this before section 2's comparison starts, not after. The point is to decide,
up front, what the reference simply does not define, so those items are never
scored as divergences later.

Procedure:

1. Read the reference end to end (all frames, all breakpoints, all annotations)
   and list what it does not define. Common categories:
   - Interactive states not shown (e.g. reference has no hover or focus mockup).
   - Motion and transitions not specified.
   - Breakpoints in between the ones the reference covers (e.g. reference shows
     375px and 1280px only, nothing at 768px or at very wide screens).
   - Dark mode, when the reference is light-mode only, or vice versa.
   - Accessibility specifics: focus ring style, exact contrast values, ARIA
     details.
   - Edge-case content: very long strings, empty states, error copy, loading
     placeholders, when the reference only shows the happy path.
2. For each item on that list, decide the built behavior with the craft skill in
   use for the build (frontend-design or ui-ux-pro-max), following that skill's
   craft bar (its own conventions for states, motion, and accessibility
   defaults).
3. Record the list and the craft decision for each item alongside the punch-list
   (section 6), separately from the divergence entries. A gap-contract item is
   never scored conforms, diverges, or not-verifiable; it is out of the fidelity
   comparison entirely, and is instead checked against the craft skill's own bar
   (does the invented state or motion meet that skill's quality standard, not
   does it match a reference that does not exist).
4. If a build decision on a gap-contract item is later found to contradict
   something the reference does define elsewhere (e.g. an invented hover color
   that conflicts with the reference's defined accent token), that specific
   contradiction is a real divergence and moves into section 2's comparison, it
   does not stay a gap-contract item.

## 4. Token discipline

Checks:
- Every color used in the built code resolves to a design-system token (a CSS
  custom property, a Tailwind theme value, a component-library variable), not a
  literal hex, rgb, or named color.
- Every typography value (family, size, weight, line-height) resolves to a
  typography token or scale step, not a one-off literal.
- Every reusable visual pattern (button, card, input, badge) uses the
  design-system's component, not a hand-rolled equivalent that happens to look
  the same.

Divergence definition specific to this section: a hardcoded value that
duplicates an available token is a divergence, even when the rendered pixels
match the reference exactly. The visual match is necessary but not sufficient;
the source must route through the token, because a hardcoded duplicate silently
drifts the next time the token changes. Record the file and line of the
hardcoded value, the token it should have used, and the literal value found.

A hardcoded value is not a divergence only when no equivalent token exists for
that value; in that case, record it as a gap-contract item (section 3) with a
note that a new token may be warranted, rather than as a token-discipline
divergence.

## 5. Adversarial re-check protocol

Run this as a second, independent pass after sections 2 through 4 produce a
first-pass result set. The operating assumption for this pass: the first pass was
too lenient, and something was waved through.

Procedure:
1. Do not start from the first pass's punch-list. Re-open the reference and the
   render side by side and re-run the dimensions in section 2 from a skeptical
   stance, specifically targeting the categories most likely to hide a missed
   divergence:
   - Component states beyond default (hover, focus, active, disabled, loading,
     empty, error): re-trigger every state manually and compare again.
   - Responsive edges: check widths just above and below each breakpoint
     threshold, not only the exact breakpoint values, since layouts often break
     a few pixels off the named breakpoint.
   - Tokens: re-grep the changed files for hex codes, `rgb(`, `px` literals in
     typography or spacing, and inline styles that bypass the design system.
   - Rendering integrity: re-run the breakage-signature checklist from section 2.0, re-cross-reference the accessibility snapshot against the screenshot, and zoom into any region that looked borderline in the first pass.
2. Compare the adversarial pass's findings against the first pass's punch-list.
   Any item found in the adversarial pass that the first pass marked conforms is
   a first-pass miss; add it to the punch-list with its own severity, do not
   quietly merge it away.
3. If the adversarial pass finds nothing beyond the first pass across two
   consecutive dimensions, that is a signal the first pass was already thorough
   for this build, not a signal to stop checking the remaining dimensions.
4. The adversarial pass never removes a first-pass finding on its own authority;
   it only adds. If a first-pass finding looks wrong on re-inspection, it stays
   on the list marked for human confirmation rather than being silently dropped.

## 6. Punch-list output schema

The gate's output is a single ranked list. Each entry has these fields:

- **severity**: one of `blocking`, `major`, `minor`.
  - `blocking`: the divergence breaks the design's stated intent (wrong layout,
    missing required state, failing contrast, broken responsive behavior at a
    named breakpoint, hardcoded value where a token exists and drift is likely).
  - `major`: a clearly visible divergence that does not break intent but would
    be noticed by anyone comparing the two side by side (wrong spacing step,
    wrong font weight, wrong hover color).
  - `minor`: a small, low-visibility divergence (a few px off within a
    borderline tolerance, a token used correctly but at the wrong step,
    cosmetic-only motion timing difference).
- **file:line**: the location in the built code, when known. When the
  divergence cannot be traced to a specific location (e.g. a layout-level
  issue spanning a component), name the component or file instead and say why
  a line number is not applicable.
- **dimension**: which section 2 dimension (or section 4, token discipline)
  the entry belongs to.
- **intended value**: what the reference shows or specifies.
- **built value**: what the render actually shows.
- **suggested fix**: a concrete, actionable change, specific enough to hand to
  a build lot without further investigation (e.g. "change `padding: 12px` to
  the `space-4` token (16px) to match the reference's card padding").

Verdict rule: the gate passes when the punch-list has zero `blocking` entries.
Any `major` or `minor` entries are reported but do not block; they may still be
fixed as follow-up. When one or more `blocking` entries exist, the gate fails,
and the entire punch-list (blocking entries first, then major, then minor)
becomes the next build lot's input.
