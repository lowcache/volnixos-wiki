---
name: Volatile NixOS Configuration
description: A service-manual drawing set — the machine documented as an exploded assembly, ink-reversed on a dark sheet.
colors:
  ink-stock: "#0b1016"
  ink-stock-2: "#101823"
  ink-stock-3: "#16202d"
  line: "#dfe6ef"
  line-2: "#97a3b4"
  line-3: "#7c8899"
  hairline: "#26313f"
  mark: "#ff3d8e"
  mark-dim: "#ff3d8e26"
  construction: "#5fb0d0"
  construction-dim: "#5fb0d033"
  caution-rule: "#d9a441"
typography:
  display:
    fontFamily: "Barlow Condensed, Barlow, ui-sans-serif, system-ui, sans-serif"
    fontSize: "clamp(3rem, 1.4rem + 7vw, 6rem)"
    fontWeight: 700
    lineHeight: 0.94
    letterSpacing: "-0.028em"
  headline:
    fontFamily: "Barlow Condensed, Barlow, ui-sans-serif, system-ui, sans-serif"
    fontSize: "clamp(2.4rem, 1.6rem + 3.4vw, 4.2rem)"
    fontWeight: 600
    lineHeight: 1.12
    letterSpacing: "-0.018em"
  title:
    fontFamily: "Barlow Condensed, Barlow, ui-sans-serif, system-ui, sans-serif"
    fontSize: "clamp(1.7rem, 1.35rem + 1.5vw, 2.3rem)"
    fontWeight: 600
    lineHeight: 1.12
    letterSpacing: "-0.005em"
  body:
    fontFamily: "Barlow, ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "17px"
    fontWeight: 400
    lineHeight: 1.65
    letterSpacing: "0.001em"
    fontFeature: "tabular-nums"
  label:
    fontFamily: "Barlow Condensed, Barlow, ui-sans-serif, system-ui, sans-serif"
    fontSize: "0.75rem"
    fontWeight: 600
    lineHeight: 1.2
    letterSpacing: "0.14em"
  figure:
    fontFamily: "JetBrains Mono, ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
    fontSize: "0.86em"
    fontWeight: 400
    lineHeight: 1.62
    letterSpacing: "0.01em"
    fontFeature: "tabular-nums"
rounded:
  none: "0px"
  balloon: "50%"
spacing:
  half: "4px"
  module: "8px"
  s3: "16px"
  s4: "24px"
  s5: "32px"
  s6: "48px"
  s7: "64px"
  s8: "96px"
  s9: "128px"
components:
  button-rebuild:
    backgroundColor: "transparent"
    textColor: "{colors.mark}"
    typography: "{typography.label}"
    rounded: "{rounded.none}"
    padding: "5px 16px"
  button-rebuild-hover:
    backgroundColor: "{colors.mark}"
    textColor: "{colors.ink-stock}"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.line-2}"
    typography: "{typography.label}"
    rounded: "{rounded.none}"
    padding: "7px 16px"
  button-ghost-hover:
    textColor: "{colors.line}"
  tag-figure:
    backgroundColor: "transparent"
    textColor: "{colors.mark}"
    typography: "{typography.figure}"
    rounded: "{rounded.none}"
    padding: "3px 8px"
  balloon-key:
    backgroundColor: "transparent"
    textColor: "{colors.line-2}"
    typography: "{typography.figure}"
    rounded: "{rounded.balloon}"
    height: "1.75rem"
    width: "1.75rem"
  balloon-key-lit:
    backgroundColor: "{colors.mark}"
    textColor: "{colors.ink-stock}"
  title-block:
    backgroundColor: "{colors.ink-stock-2}"
    textColor: "{colors.line}"
    rounded: "{rounded.none}"
    padding: "8px 16px"
  advisory-caution:
    backgroundColor: "{colors.construction-dim}"
    textColor: "{colors.mark}"
    typography: "{typography.label}"
    rounded: "{rounded.none}"
    padding: "8px 16px"
  detail-view:
    backgroundColor: "{colors.ink-stock-2}"
    textColor: "{colors.line}"
    typography: "{typography.figure}"
    rounded: "{rounded.none}"
    padding: "24px"
---

# Design System: Volatile NixOS Configuration

## Overview

**Creative North Star: "The Service Manual Drawing Set"**

A NixOS configuration is an exploded assembly drawing: every part named, numbered, separately removable, and nothing installed whole. The site is drawn as one. The primary scheme is the negative — white line on ink stock, the way a drawing reads on a light table at 2am, which is the recorded use scene. The light scheme is the paper positive, printed on drafting vellum. Neither is a "theme variant"; they are the two states of the same ink, and every token flips as a pair.

Hierarchy is *drawn*, not typeset. Rank comes from line weight, balloon diameter, hatch, and rule thickness — a sheet can rank itself with every piece of type at one size. Colour carries four roles and never decorates: stock, line, the mark, and construction. Nothing is rounded except callout balloons and the parts-list keys that reference them; radius is `0` globally and that is a hard invariant, not a default.

Two visual worlds were explicitly refused. The terminal-green hacker hero: rejected — this is a drawing, not a TTY. The gradient card grid of generic documentation themes: rejected — a card grid ranks nothing, and a drawing set ranks everything. The incumbent MkDocs-era yellow/green and space-nebula scheme is gone entirely and is not to be reintroduced in any part.

**Key Characteristics:**
- Reversed ink stock as the primary scheme; light is the paper positive of the same drawing.
- Hierarchy carried by drawn weight — line, hatch, balloon diameter — before type.
- Exactly one saturated colour, spent only on the single located item.
- Hard-ruled geometry: radius `0`, mitre joins, square caps, hairline keylines, dashed leaders.
- One 8px drawing module; type baselines included.
- One authored motion moment (the assembly inks on, then the volatile half is wiped and re-derived); everything else is a 150ms state change.

## Colors

Four roles, in a two-state reversal. The frontmatter carries the reversed (dark) values, which is the primary scheme; the paper-positive values are recorded per token in `.impeccable/design.json` under `colorMeta[*].positive`.

### Primary
- **Drawing Magenta** (`mark`): the only saturated colour on the site. It marks the one item that is located — the lit plate on the assembly, the current sheet in the nav, the sheet's own figure number, the search hit, the caret, the focus ring, the top-ranked advisory. It appears on a fraction of a percent of any screen and that scarcity is the whole mechanism.

### Secondary
- **Construction Cyan** (`construction`): construction only — leaders, datums, dimension lines, centre marks, link underlines, the accent colour of form controls. It says "this line was drawn to build the drawing," never "this content matters." Measured at 5.15:1 on vellum in its positive form (`#26647f` on `#e9e4d7`).

### Tertiary
- **Caution Amber** (`caution-rule`): reserved for exactly one place — the WARNING rung of the advisory ladder, one step below CAUTION. It exists so the ladder has three distinguishable rungs without spending magenta twice.

### Neutral
- **Ink Stock** (`ink-stock`, `ink-stock-2`, `ink-stock-3`): the sheet, the inset detail view, and the raised plate face. Three tones, not a gradient.
- **Line** (`line`): body text and the drawn outline of a part — the full-strength ink.
- **Line 2** (`line-2`): secondary lettering, hatch strokes, quiet nav. The emphasis colour where magenta would be wrong.
- **Line 3** (`line-3`): captions, drafting labels, table headers, the lowest-rank lettering. This is the floor: `#7c8899` on ink measures 5.31:1, and its positive `#5a626d` on vellum measures 4.86:1. Nothing on the site sets text below this tone.
- **Hairline** (`hairline`): every keyline, cell rule, and panel border.

### Tonal ramp
Surface tone is never a free-form alpha. Six named steps (`--dw-t1` … `--dw-t6`) run from the stock toward the line and flip polarity with the scheme (black-alpha on vellum, white-alpha on ink). Hover fills, table zebra, panel washes and the body graticule all draw from these steps.

### Named Rules
**The One Located Item Rule.** Magenta means "this is the one" — the lit part, the sheet you are on, the result you searched for, the advisory you must not skip. One per view. It is never emphasis, never decoration, never a brand accent, and it is absent from the code syntax palette by rule.

**The Construction Line Rule.** Cyan is drawing apparatus. If the reader would be worse off with the line erased *and* the line describes content rather than geometry, it is not cyan.

**The Named Step Rule.** No ad-hoc `rgba()` surfaces. Any tint is one of the six ramp steps, so every surface in both schemes is on the same six-tone ladder.

## Typography

**Display Font:** Barlow Condensed (with Barlow, then system sans)
**Body Font:** Barlow (with system sans)
**Label/Mono Font:** JetBrains Mono, for measured figures and code

**Character:** Barlow is an industrial/transport grotesk — the same lineage as drafting stencil lettering — so a drawing's labels and its prose share one lettering standard, which is exactly how a real drawing set behaves. Condensed sets everything the drawing writes on itself: headings, keys, tags, the title block. JetBrains Mono is reserved for anything *measured*: sheet numbers, revisions, balloon numerals, code.

Eight self-hosted `woff2` latin subsets, ~191 KB total, in `static/fonts/`. Zero external font requests. The two above-the-fold faces (Barlow Condensed 600, Barlow 400) are preloaded; the rest arrive on demand.

### Hierarchy
- **Display** (700, `clamp(3rem, 1.4rem + 7vw, 6rem)`, line-height 0.94, tracking -0.028em): the cover sheet masthead only. One per site.
- **Headline** (600, `clamp(2.4rem, 1.6rem + 3.4vw, 4.2rem)`, 1.12): the sheet title on an interior page.
- **Title** (600, `clamp(1.7rem, 1.35rem + 1.5vw, 2.3rem)` for h2, `clamp(1.32rem, 1.15rem + 0.7vw, 1.6rem)` for h3, 1.12): in-sheet zone titles. `h2` is ruled off above with a hairline.
- **Body** (400, 17px, 1.65, tabular numerals): running prose, bound to a 68ch measure. `h4` continues at 1.16rem; `h5`/`h6` drop to 0.9rem uppercase at 0.1em tracking.
- **Label** (600, 0.75rem, uppercase, 0.14em tracking, `line-3`): drafting lettering — tags, title-block keys, parts-list layer names, table headers. Never used for running prose. A heavier variant (700, 0.82rem, 0.18em) rules off a zone heading.
- **Figure** (400, 0.86em, tabular, mono): anything measured — sheet numbers, revisions, balloon numerals, dimension figures. Code blocks set at 0.86rem / 1.62.

### Named Rules
**The One Lettering Standard Rule.** The drawing's labels and its prose come from one family. Introducing a second display face breaks the fiction that the page and the drawing were lettered by the same hand.

**The Drawn Weight Rule.** Rank is carried by line weight, rule thickness, hatch, and balloon diameter before it is carried by type. A sheet should still rank correctly with every heading set at one size. Font-weight is a tiebreaker, never the primary signal.

## Layout

One 8px drawing module (`--dw-mod`), with a 4px half-step for optical work only. The spacing scale is 4 · 8 · 16 · 24 · 32 · 48 · 64 · 96 · 128px (`--dw-s1` … `--dw-s9`). Nothing sits off the module, type baselines included, and the body carries a faint 32px graticule (four modules) printed in the lightest ramp step so the grid is visible as drafting stock rather than implied.

**Vertical rhythm:** one rule governs prose — 24px between siblings, 96px above a heading, 24px below it. Space above a heading always exceeds space below, so a zone reads as belonging to its title.

**Measure:** 68ch (`--dw-measure`) binds *running text only* — paragraphs, lists, blockquotes, headings. Diagrams, detail views (code) and schedules (tables) are drawings and take the full width of the sheet.

**Containers:** the sheet caps at 1320px (`--dw-sheet-max`); with the permanent left index the article column caps at 1200px. The contents rail is 264px, the cover's parts list 360px, the title block 640px.

**Breakpoints:**
- `≤519px` — the wordmark subtitle drops; header gap and padding tighten. The mark plus the name carry identity.
- `≤743px` — the assembly's leaders, balloons and dimensions drop out (micro-type in a scaled drawing is worse than no type); the parts list carries the numbering, which is the same information. The viewBox crops to the parts still drawn. The datum stays, because the datum carries the thesis. Tables scroll horizontally with `nowrap`.
- `≥744px` — tables wrap normally.
- `≥1024px` — header nav appears, in-article nav buttons disappear; the contents rail becomes a sticky column; the assembly splits to drawing + 360px parts list; padding steps up (`--padding` 12→16px, header 60→68px).
- `≥1280px` — the left index becomes a permanent 300px fixed column and continues the header's band and double rule across its own width.

Below 1024px both sidebars are off-canvas drawers (`min(86vw, 320px)`) over a blurred scrim, sliding in over 0.28s and not at all under reduced motion.

### Named Rules
**The Module Rule.** Every dimension resolves to a multiple of 8px, or to the single 4px half-step. A value that is neither is a bug, not a refinement.

**The Measure Binds Text Rule.** The 68ch measure is a property of running prose. Never apply it to a drawing, a table, or a code block — those are figures and get the sheet.

## Elevation & Depth

The system is flat by material and deep by drawing. There is no ambient shadow vocabulary: surfaces are separated by hairline keylines, the six-step tonal ramp, and drawn line weight. Two shadows exist and both are structural, not atmospheric — a sheet lifting off the board, and the double rule a drawing border is made of.

Real Z lives in the assembly. Plate stroke-width ramps from **1.625px at the base of the stack to 0.95px at the top**, driven by a per-plate `--depth-n` that counts down from the top, so nearer parts draw heavier. Under a pointer the same depth factor scales a parallax offset, so the stack has an actual axis rather than a painted one.

### Shadow Vocabulary
- **Sheet lift** (`box-shadow: 0 18px 44px -18px #00000099, 0 2px 6px -2px #0000005c`): a panel lifted off the board. Offset and blur only.
- **Drawing border** (`box-shadow: inset 0 -3px 0 -2px var(--dw-hair), inset 0 -1px 0 0 var(--dw-line-3)`): the header's and footer's edge. A drawing border is a double rule, not a shadow — this is a rule drawn with the shadow property.

### Named Rules
**The No Halo Rule.** Depth is offset plus blur. A drawing sheet lifts off the board; it does not emit light. No glow, no coloured shadow, no neon, no spread on a saturated colour.

## Shapes

Radius is `0` globally, including on inherited theme surfaces, the search box, and every button. The only circles in the system are callout balloons and the parts-list keys that reference them — a circle therefore *means* "this is a keyed callout," and using one anywhere else spends that meaning.

Strokes are hard: `stroke-linejoin: miter`, `stroke-linecap: square`, no rounded corners on drawn geometry. Line weights come off a fixed four-step ramp — hair 0.5px, thin 1px, medium 1.5px, heavy 2.5px (`--dw-lw-*`) — used for keylines, active markers, advisory escalation, and focus rings respectively.

Drawn balloons on the assembly are 15 units radius for a standard part, 18 for the datum plate, 13 for the detached sub-assembly; the HTML parts-list key is a 1.75rem circle. Diameter is a rank signal, matching the line-weight ramp.

Dashes are semantic, not stylistic: `14 5 3 5` is a centre line (the assembly axis), `8 4` is a datum, `6 4` is a leader, `5 4` is a remote/network link, `3 3` is a witness line, `3 2.5` marks a volatile plate on the wordmark.

### Named Rules
**The Ruled Not Rounded Rule.** Radius `0` everywhere. A circle is a callout balloon. If a new component wants a radius, it wants to be something this world does not contain.

**The Hatch Is State Rule.** 45° hatch means "lives above the tmpfs datum; destroyed and re-derived every boot." Solid fill means it persists. Hatch is never texture, never decoration, and must never disagree with `volatile:` in `data/en/assembly.yaml`.

## Components

### Buttons
- **Shape:** square (`0`), 1px hairline border, transparent fill.
- **Rebuild (the one primary control):** magenta lettering inside a magenta hairline box, 5px/16px padding, condensed uppercase at 0.14em. Hover inverts to a magenta fill with stock-coloured lettering. Disabled drops to 0.45 opacity while the wipe runs.
- **Ghost (`.btn`, in-article nav):** `line-2` on a hairline border; hover raises the text to full `line` and the border to `line-3`. Colour never becomes the hover signal on its own.
- **Hover / Focus:** all state transitions are 150ms on `--dw-ease`. Focus is a 1.5px magenta outline at 3px offset, globally, on `:focus-visible`.

### Cards / Containers
There are no cards. Content sits in ruled panels: 1px hairline border, `ink-stock-2` fill, `0` radius, 24px internal padding for detail views and 16px for advisory bodies. A panel is distinguished from the sheet by its keyline and one ramp step, never by a shadow.

### Inputs / Fields
Search is themed as a first-class surface through the full Pagefind `--pf-*` set rather than left on component defaults: stock background, hairline border, `0` radius, 34px input height, Barlow at 0.95rem, magenta focus border and magenta hit marks, and a 2px magenta outline at 3px offset. Its stylesheet must load *before* the token layer, since it ships `:root` defaults that would otherwise win.

### Navigation
- **Header:** condensed 600 at 0.94rem, `line-2`, with a 1.5px transparent bottom border. Hover fills that border with `line-3`; active fills it with magenta and reveals the sheet number in mono magenta — the number is shown only for the sheet you are inside, where it tells you something.
- **Left index (the drawing-set index):** `<details>` groups with condensed uppercase summaries and a rotating chevron; items are indented against a hairline spine. The current sheet gets three simultaneous signals — magenta spine, `mark-dim` wash, and a filled 9px balloon in the margin — so the state survives monochrome and colour blindness.
- **Contents rail:** 0.88rem at `line-3` against a hairline spine; the active entry thickens its spine to 1.5px and raises to full `line`.

### Advisories
The five GitHub alert types are mapped onto the service-manual ladder **NOTE < CAUTION < WARNING**, and severity is carried by drawn weight rather than by a coloured slab. NOTE/TIP take a cyan header on ramp step 2 at 1px. IMPORTANT takes a `line-2` header at 1px. WARNING escalates to a 1.5px amber rule with a 45° hatched header band. CAUTION escalates to a 2.5px magenta rule with a magenta-hatched band. The ranking survives greyscale printing and colour-blind reading because the rule thickness and the hatch carry it.

### Detail Views (code)
A fenced block is drawn as an inset panel: hairline border, `ink-stock-2` fill, 24px padding, mono at 0.86rem/1.62, with an inset 1px highlight. The window header carries a `Detail` marker in condensed uppercase against a dashed rule instead of macOS traffic lights, which are explicitly suppressed. The syntax palette uses two hues only — construction cyan and pencil sand — plus the tonal ramp, so a code block reads as part of the drawing. **Magenta is absent from the syntax palette by rule.**

### Title Block (signature)
The ruled panel a drawing carries in its lower-right corner: 1.5px `line-3` border, `ink-stock-2` fill, cells divided by hairlines, keys in drafting label lettering and values in condensed 600 (mono for figures — sheet, rev, scale). It is also the **support rail**: repository link, support ask, and sibling-blog link live here because attribution lives in the title block by drawing convention, not because a rail was invented for them. It always carries real author content, which is why a sponsor slot could later occupy it without reflow and without sitting next to a tool recommendation in the prose. Right-aligned at 640px from 1024px up.

### Exploded Assembly (signature)
The cover sheet's general-assembly drawing: ten plates on a vertical axis in a 1000×780 viewBox, leaders running right to numbered balloons, a keyed parts list beside. Geometry is computed server-side in Hugo, so the whole drawing exists in the served HTML — it renders with JS off, prints, and is crawlable.

The drawing is deliberately two layers: the SVG plates are pointer affordances (`tabindex="-1"`, `aria-hidden`), and the HTML parts list is the accessible, keyboard-navigable equivalent carrying the same links and the real text. Neither is a lesser version — a parts drawing *is* a figure plus a keyed parts list, so the split is the source form, not a concession. Hovering or focusing either half lights the other.

A datum line drawn only in the margins separates 4 persisting parts from 6 volatile ones; the exploded intervals are dimensioned with witness lines, arrowheads and rotated figures. The detached phone sub-assembly is drawn solid, not hatched — it is a separate machine and keeps its state through a `volnix` reboot — and joins the network plate by a dashed remote link. The datum plate wears magenta on arrival so "magenta = the one located item" is learnable before any interaction; any real interaction takes over.

**Motion contract.** One authored moment, not scattered effects. On scroll-in, plates ink on bottom-upward (`stroke-dasharray` normalised via `pathLength="1"`, 70ms per plate); leaders and dimensions fade in on their plate's beat rather than inking, because inking would overwrite their dash. On **Rebuild**, the hatching is stripped, the volatile plates lift off the stack and go, and only the volatile half is re-inked — the plates below the datum never move, because only the volatile half was destroyed. Everything else on the site is a 150ms state change.

Under `prefers-reduced-motion: reduce`, the drawing is complete and legible from the first frame, parallax never runs, and Rebuild still works as an instant state swap that announces its result through a polite live region. Nothing on the page carries meaning that exists only while it moves.

### Icons
One authored line set on a 960 grid with `stroke-width: 64`, `stroke-linecap: square`, `stroke-linejoin: miter`, no fill — the same drawing hand as the assembly. `vol-*` are the section icons; the remainder shadow E25DX's filled Material Symbols so no glyph from the theme's set renders. Rendered at 15–17px, they inherit `currentColor`.

### Named Rules
**The Drawn State Rule.** Every state that means something is carried by a drawn mark — a balloon, a spine, a hatch, a rule weight — in addition to any colour change. Colour alone never carries state.

**The One Authored Moment Rule.** The site has exactly one piece of choreography: the assembly inking on and rebuilding. Anything else that moves is a 150ms transition on a state change.

## Do's and Don'ts

### Do:
- **Do** build every new surface from the `--dw-*` tokens. `assets/css/theme.css` shadows E25DX's own token file wholesale; every custom property the theme's component CSS reads is redefined there, so removing one silently un-styles part of the theme.
- **Do** rank with drawn weight first — the 0.5/1/1.5/2.5px line ramp, hatch, balloon diameter — and let type sizes stay close.
- **Do** carry every meaningful state with a drawn mark as well as a colour (see the active index item: spine, wash, and balloon).
- **Do** keep radius at `0` and reserve circles for callout balloons and their parts-list keys.
- **Do** resolve every dimension to the 8px module, using the 4px half-step only for optical corrections.
- **Do** set drafting labels in condensed 600, 0.75rem, uppercase, 0.14em tracking, at `line-3` — and only for labels, never running prose.
- **Do** gate all motion behind `prefers-reduced-motion` and announce through a live region anything the motion was the only carrier of.
- **Do** keep the hatch honest: it must always agree with `volatile:` in the parts data.
- **Do** keep body text at or above the `line-3` tone; it is the measured floor (5.31:1 reversed, 4.86:1 positive).

### Don't:
- **Don't** spend magenta on anything but the single located item. Not on the masthead lede (which is deliberately `line-2`), not on a brand accent, not in the code syntax palette, not as decoration.
- **Don't** use construction cyan to emphasise content. It draws geometry — leaders, datums, dimensions, link underlines — and nothing else.
- **Don't** introduce glow, coloured shadow, spread on a saturated colour, or a gradient used as a colour wash. Gradients exist here only as drawn hatch and the sheet graticule.
- **Don't** add a radius, a rounded join, or a rounded cap to anything.
- **Don't** add a third type family or a display face outside Barlow / Barlow Condensed / JetBrains Mono, and don't add an external font or CDN request — the set is self-hosted and the origin is closed.
- **Don't** reintroduce the retired MkDocs-era yellow/green or nebula imagery, a terminal-green hero, or a gradient card grid. All three are confirmed rejections.
- **Don't** restyle E25DX's chrome by overriding it. Its header, footer, sidebar and layout CSS are deliberately not loaded; the shell is rebuilt in `assets/css/vol/chrome.css` in the drawing's grammar, while the ids and classes its JavaScript queries (`#left-sidebar`, `#right-sidebar`, `#article-nav`, `.btn`, `.open`, `.model-open`, `#off-canvas-model`) are kept exactly.
- **Don't** invent a second meaning for a drawing convention. Hatch is volatility, a dashed line is construction, a circle is a callout, magenta is the located item. A convention that means two things means neither.
