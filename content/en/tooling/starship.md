---
title: "Starship Prompt"
description: "A two-bar Starship prompt drawn on Noctalia's Material 3 tonal ramp: how the gradient is built, how the palette is generated and spliced, and why the CI segment reads a file instead of the network."
weight: 25
---

The prompt is a hand-authored [`dots/starship/starship.toml`](https://github.com/lowcache/volnixos/blob/main/dots/starship/starship.toml)
(475 lines) whose colour block is machine-generated. It runs on `palette = "m3"` — Material 3 role
names and two 18-step tonal ramps emitted by [Noctalia](../desktop/noctalia/), not literal hex. A
colour-scheme change therefore moves the whole prompt with it and no hex is ever recomputed by hand.

`programs.starship.enable` is set in
[`home/common/tools.nix:77`](https://github.com/lowcache/volnixos/blob/main/home/common/tools.nix);
the config file itself is an out-of-store symlink to the repo copy so it can be edited live.

## Anatomy

<figure class="dw-fig" style="margin:2rem 0">
<svg viewBox="0 0 700 360" role="img" aria-labelledby="pr-t pr-d" style="width:100%;height:auto">
<title id="pr-t">Starship prompt anatomy</title>
<desc id="pr-d">The two bars, drawn separately. The left bar descends the primary tonal ramp from gold to near-black; the right bar climbs it back to gold. On screen they share one line, so the pair reads as a V with gold at both outer edges. Below them, the unbanded input line.</desc>
<g font-family="'Barlow Condensed',system-ui,sans-serif" font-size="11.5" fill="var(--dw-cons-dim)" letter-spacing="0.14em"><text x="16" y="52">LEFT BAR — AMBIENT</text><text x="16" y="162">RIGHT BAR — THE WORK</text><text x="16" y="286">INPUT LINE — UNBANDED</text></g>
<g fill="none" stroke="var(--dw-line-3)" stroke-width="0.75"><line x1="16" y1="60" x2="684" y2="60"/><line x1="16" y1="170" x2="684" y2="170"/><line x1="16" y1="294" x2="684" y2="294"/></g>
<g font-family="'JetBrains Mono',ui-monospace,monospace" font-size="15"><polygon points="16,70 196,70 218,118 38,118" fill="#fddeaf"/><text x="30" y="101" fill="#3f2d0c">Tuesday·02:14PM</text><polygon points="196,70 218,70 240,118 218,118" fill="#e0c295"/><polygon points="218,70 240,70 262,118 240,118" fill="#c3a77b"/><polygon points="240,70 360,70 382,118 262,118" fill="#a78d63"/><text x="256" y="101" fill="#000000">7.4 GiB</text><polygon points="360,70 382,70 404,118 382,118" fill="#8c734c"/><polygon points="382,70 404,70 426,118 404,118" fill="#715b35"/><polygon points="404,70 544,70 566,118 426,118" fill="#644f2b"/><text x="420" y="101" fill="#fff8f3">~/volnix</text><polygon points="544,70 566,70 588,118 566,118" fill="#584320"/><polygon points="566,70 586,70 608,118 588,118" fill="#4b3816"/><polygon points="586,70 604,70 626,118 608,118" fill="#3f2d0c"/><polygon points="604,70 620,70 642,118 626,118" fill="#271900"/><polygon points="620,70 634,70 656,118 642,118" fill="#1a0f00"/></g>
<g font-family="'JetBrains Mono',ui-monospace,monospace" font-size="15"><polygon points="88,180 104,180 82,228 66,228" fill="#1a0f00"/><polygon points="104,180 126,180 104,228 82,228" fill="#271900"/><polygon points="126,180 246,180 224,228 104,228" fill="#3f2d0c"/><text x="132" y="211" fill="#fddeaf">py 3.12</text><polygon points="246,180 268,180 246,228 224,228" fill="#4b3816"/><polygon points="268,180 290,180 268,228 246,228" fill="#584320"/><polygon points="290,180 428,180 406,228 268,228" fill="#644f2b"/><text x="296" y="211" fill="#fff8f3">main ● ci ok</text><polygon points="428,180 450,180 428,228 406,228" fill="#715b35"/><polygon points="450,180 472,180 450,228 428,228" fill="#8c734c"/><polygon points="472,180 572,180 550,228 450,228" fill="#a78d63"/><text x="480" y="211" fill="#000000">claude</text><polygon points="572,180 594,180 572,228 550,228" fill="#c3a77b"/><polygon points="594,180 616,180 594,228 572,228" fill="#e0c295"/><polygon points="616,180 684,180 662,228 594,228" fill="#fddeaf"/><text x="622" y="211" fill="#3f2d0c">impure</text></g>
<g font-family="'JetBrains Mono',ui-monospace,monospace" font-size="15"><text x="16" y="320" fill="var(--dw-cons)">fish ❯</text><text x="112" y="320" fill="var(--dw-cons-dim)">took 1.2s</text></g>
<g text-anchor="middle"><g fill="none" stroke="var(--dw-line-2)" stroke-width="1"><line x1="106" y1="70" x2="117" y2="34"/><circle cx="106" cy="22" r="12"/><line x1="300" y1="70" x2="311" y2="34"/><circle cx="300" cy="22" r="12"/><line x1="474" y1="70" x2="485" y2="34"/><circle cx="474" cy="22" r="12"/><line x1="164" y1="228" x2="175" y2="250"/><circle cx="164" cy="262" r="12"/><line x1="337" y1="228" x2="359" y2="250"/><circle cx="337" cy="262" r="12"/><line x1="500" y1="228" x2="533" y2="250"/><circle cx="500" cy="262" r="12"/><line x1="639" y1="180" x2="661" y2="152"/><circle cx="639" cy="140" r="12"/><line x1="40" y1="326" x2="40" y2="340"/><circle cx="40" cy="348" r="11"/></g><g fill="var(--dw-cons)" font-family="'Barlow Condensed',system-ui,sans-serif" font-size="13"><text x="106" y="27">01</text><text x="300" y="27">02</text><text x="474" y="27">03</text><text x="164" y="267">04</text><text x="337" y="267">05</text><text x="500" y="267">06</text><text x="639" y="145">07</text><text x="40" y="353">08</text></g></g>
</svg>
<figcaption><strong>01</strong> <code>$time</code> · <strong>02</strong> <code>$memory_usage</code> · <strong>03</strong> <code>$directory</code> — ambient state. <strong>04</strong> languages · <strong>05</strong> <code>$vcs</code> + <code>${custom.ci}</code> · <strong>06</strong> agent · <strong>07</strong> <code>$nix_shell</code> and <code>$direnv</code> — the work. <strong>08</strong> the input line: <code>$shell$sudo$character$cmd_duration</code>. The two bars share one terminal line, left-aligned and right-aligned respectively, so the pair reads as a V: gold at both outer edges, near-black where they meet.</figcaption>
</figure>

## One ramp, run twice

Both bars walk the same thirteen steps of the primary tonal scale. The left bar descends
`primary_13 → primary_1`; the right bar climbs `primary_1 → primary_13`. Read across, the line forms
a V — gold at both outer edges, near-black where the two bars approach each other.

Modules sit on every third step (`primary_13`, `primary_10`, `primary_7`, `primary_4`). The steps in
between carry no text; they sit under the separator glyphs, and those wedges are what make the bar
read as a gradient rather than four flat blocks.

> [!NOTE] Why the tonal ramp and not `primary → secondary → tertiary`
> Those three roles are bunched at the light end (L\* 82 / 72 / 67) and `tertiary` is sage, so any
> path through them spends ten of thirteen cells green and barely separates at the light end. The
> tonal ramp is one hue, evenly spaced by construction, and every cell is a Noctalia role — so the
> whole gradient follows a scheme change for free.

Text inverts at the midpoint, and the pairs are measured rather than eyeballed:

| Band | Text | Contrast |
| :--- | :--- | :--- |
| `primary_13` | `primary_4` | 10.2:1 |
| `primary_10` | `primary_0` | 6.6:1 |
| `primary_7` | `primary_15` | 7.4:1 |
| `primary_4` | `primary_13` | 10.2:1 |

`primary_10` is the squeeze: at L\*60 nothing warm clears 6:1 except pure black. The weakest pair
still beats the 5.5:1 of the neutral band it replaced.

## Split by subject

The two bars are divided by subject, not by convenience.

- **Left is ambient** — what is true of the terminal whatever you are doing: the clock, where you
  are, what the machine is carrying.
- **Right is the work** — toolchain at the dark end, then the repo, then the agent, then the Nix
  environment at the bright end, so the far-right edge of the line is always *what shell am I
  actually in*.

Neither bar grows into the other's subject, which is what keeps a prompt this dense readable: you
learn which half to look at before you read it. The input line carries only what is true of the
shell itself — which shell, and whether it is holding root.

## Separators

The slant tracks the tone. The left bar descends, so it is sheared with the `\` pair (`U+E0BE` head,
`U+E0B8` tail); the right bar ascends, so it uses the `/` pair (`U+E0BA` / `U+E0BC`). Only the two
head caps are half-painted — every interior cell carries a full foreground triangle over a
background fill, so the bar stays solid, just angled.

The sets below all tile the ramp without leaving a gap, so swapping is search-and-replace:

| Set | Glyphs | Character |
| :--- | :--- | :--- |
| Hard divider | `U+E0B6` / `U+E0B0` | the original |
| Slant | `U+E0BA` / `U+E0BC` | crispest |
| Trapezoid | `U+E0D4` / `U+E0D2` | |
| Flame | `U+E0C2` / `U+E0C0` | softest edge |
| Ice waveform | `U+E0CA` / `U+E0C8` | softest edge |
| Pixel dither | `U+E0C5`/`U+E0C4`, `U+E0C7`/`U+E0C6` | blends adjacent steps |
| Honeycomb | `U+E0CC` / `U+E0CC` | |
| Lego | `U+E0D1` / `U+E0CE` | |

## Where the palette comes from

The `[palettes.m3]` block is generated, not written. Noctalia renders it from the active Material 3
scheme through a repo-tracked template, and a small script splices it into the config between
markers:

```text
Noctalia M3 scheme
  └─ dots/noctalia/templates/starship-m3/template.toml
       └─ $XDG_CACHE_HOME/noctalia/starship-m3-palette.toml   (generated)
            └─ apply.sh  ──splices──>  dots/starship/starship.toml  [:417-475]
```

`apply.sh` drops any previous block including its markers, re-appends the freshly generated palette
between them, and writes **through** the symlink — a `mv` would replace the link with a regular file
and detach the config from the repo. Everything outside the markers, which is the entire
hand-authored format section, is left untouched.

`"starship"` was removed from Noctalia's `builtin_ids` when this landed: the community template
supersedes the builtin, and running both would have two writers on one file.

> [!WARNING] Do not hand-edit between the markers
> The block between `# >>> NOCTALIA M3 PALETTE >>>` and `# <<< NOCTALIA M3 PALETTE <<<` is
> overwritten on every apply. Edits there are lost silently. The dormant
> [color-engine](../desktop/theming/) is a live hazard to this block specifically: its
> `apply_theme.py` rewrites `palette = "m3"` to `palette = "current"`, and a greedy regex matching
> from the first `[palettes.` to end-of-file would delete the generated block and its markers
> outright, replacing 18 tonal steps with eight flat colours.

## The CI segment

`${custom.ci}` shows the GitHub Actions result for the last pushed commit. It never touches the
network:

```toml
shell   = ["sh"]
when    = "test -s $XDG_RUNTIME_DIR/volnixos-ci"
command = "cat $XDG_RUNTIME_DIR/volnixos-ci"
```

Starship runs a custom module's command on every prompt and kills it at 500 ms, so the polling
happens elsewhere: `ci-poll`
([`home/scripts.nix`](https://github.com/lowcache/volnixos/blob/main/home/scripts.nix)) runs in the
background, queries GitHub, and leaves one short line in tmpfs. `when` is the gate and `cat` is the
command — about 8 ms. `make git` starts the poller; `make ci` is the foreground watcher. See
[CI & binary cache](ci-cache/).

> [!IMPORTANT] `shell = ["sh"]` is load-bearing
> `STARSHIP_SHELL` here is fish, and in fish an unset `XDG_RUNTIME_DIR` makes the argument vanish
> entirely — leaving `test -s` testing the literal string `-s`, which is true. `cat` then gets no
> argument and blocks on stdin for the full 500 ms on every prompt. Under `sh` the same expression
> collapses to `/volnixos-ci`, `test -s` is false, and the segment simply hides.

## Inert presets

[`dots/starship/`](https://github.com/lowcache/volnixos/blob/main/dots/starship) also carries
`powerline.toml` and `rainbow.toml`. Neither is active and neither is M3 — they are stock upstream
Starship presets with self-contained hardcoded palettes (`catppuccin_mocha` and `gruvbox_dark`).
Nothing reads them and Noctalia does not theme them; they are reference copies only.
