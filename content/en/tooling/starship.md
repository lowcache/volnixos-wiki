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

<figure class="dw-fig">
<svg viewBox="0 0 880 300" role="img" aria-labelledby="pr-t pr-d"
     style="width:100%;height:auto;font-family:'Barlow Condensed',system-ui,sans-serif">
  <title id="pr-t">Starship prompt anatomy</title>
  <desc id="pr-d">One prompt line. The left bar descends the primary tonal ramp from gold to
  near-black; the right bar climbs the same ramp back to gold, so the line reads as a V. Below it,
  the unbanded input line carries the shell, root state, and command duration.</desc>

  <g fill="none" stroke="var(--dw-line-3)" stroke-width="var(--dw-lw-hair,0.75)">
    <line x1="24" y1="62" x2="856" y2="62"/>
    <line x1="24" y1="212" x2="856" y2="212"/>
  </g>
  <g font-size="11" fill="var(--dw-cons-dim)" letter-spacing="0.14em">
    <text x="24" y="54">PROMPT LINE — left_format · right_format</text>
    <text x="24" y="204">INPUT LINE — unbanded, terminal ground</text>
  </g>

  <!-- left bar: descends, "\" shear -->
  <g font-family="'JetBrains Mono',ui-monospace,monospace" font-size="12.5">
    <polygon points="40,90 168,90 178,126 50,126" fill="#fddeaf"/>
    <text x="62" y="113" fill="#3f2d0c">Tuesday·02:14PM</text>
    <polygon points="168,90 196,90 206,126 178,126" fill="#e0c295"/>
    <polygon points="196,90 224,90 234,126 206,126" fill="#c3a77b"/>
    <polygon points="224,90 330,90 340,126 234,126" fill="#a78d63"/>
    <text x="246" y="113" fill="#000000">  7.4 GiB</text>
    <polygon points="330,90 358,90 368,126 340,126" fill="#8c734c"/>
    <polygon points="358,90 386,90 396,126 368,126" fill="#715b35"/>
    <polygon points="386,90 486,90 496,126 396,126" fill="#644f2b"/>
    <text x="406" y="113" fill="#fff8f3">~/volnix</text>
    <polygon points="486,90 508,90 518,126 496,126" fill="#584320"/>
    <polygon points="508,90 526,90 536,126 518,126" fill="#4b3816"/>
    <polygon points="526,90 542,90 552,126 536,126" fill="#3f2d0c"/>
    <polygon points="542,90 556,90 566,126 552,126" fill="#271900"/>
    <polygon points="556,90 568,90 578,126 566,126" fill="#1a0f00"/>
  </g>

  <!-- right bar: ascends, "/" shear -->
  <g font-family="'JetBrains Mono',ui-monospace,monospace" font-size="12.5">
    <polygon points="612,90 700,90 690,126 602,126" fill="#3f2d0c"/>
    <text x="616" y="113" fill="#fddeaf">󰌠 3.12</text>
    <polygon points="700,90 716,90 706,126 690,126" fill="#4b3816"/>
    <polygon points="716,90 730,90 720,126 706,126" fill="#584320"/>
    <polygon points="730,90 806,90 796,126 720,126" fill="#644f2b"/>
    <text x="736" y="113" fill="#fff8f3"> main ●</text>
    <polygon points="806,90 820,90 810,126 796,126" fill="#715b35"/>
    <polygon points="820,90 834,90 824,126 810,126" fill="#8c734c"/>
    <polygon points="834,90 856,90 846,126 824,126" fill="#a78d63"/>
  </g>

  <!-- input line -->
  <g font-family="'JetBrains Mono',ui-monospace,monospace" font-size="12.5"
     fill="var(--dw-cons)">
    <text x="40" y="243">fish ❯ </text>
    <text x="118" y="243" fill="var(--dw-cons-dim)">took 1.2s</text>
  </g>

  <!-- balloons -->
  <g font-size="10.5" text-anchor="middle">
    <g fill="none" stroke="var(--dw-line-2)" stroke-width="var(--dw-lw-thin,1)">
      <line x1="104" y1="90" x2="104" y2="74"/><circle cx="104" cy="66" r="9"/>
      <line x1="282" y1="126" x2="282" y2="146"/><circle cx="282" cy="154" r="9"/>
      <line x1="440" y1="90" x2="440" y2="74"/><circle cx="440" cy="66" r="9"/>
      <line x1="650" y1="126" x2="650" y2="146"/><circle cx="650" cy="154" r="9"/>
      <line x1="762" y1="90" x2="762" y2="74"/><circle cx="762" cy="66" r="9"/>
      <line x1="68" y1="243" x2="68" y2="262"/><circle cx="68" cy="270" r="9"/>
    </g>
    <g fill="var(--dw-cons)" font-family="'Barlow Condensed',system-ui,sans-serif">
      <text x="104" y="70">01</text><text x="282" y="158">02</text>
      <text x="440" y="70">03</text><text x="650" y="158">04</text>
      <text x="762" y="70">05</text><text x="68" y="274">06</text>
    </g>
  </g>

  <g font-size="11" fill="var(--dw-measure)" text-anchor="middle"
     font-family="'Barlow Condensed',system-ui,sans-serif" letter-spacing="0.08em">
    <text x="573" y="113">▸ ◂</text>
    <text x="573" y="172">the V meets here</text>
  </g>
</svg>
<figcaption>

**01** `$time` · **02** `$memory_usage` · **03** `$directory` — the left bar, ambient state.
**04** languages, then `$vcs` + `${custom.ci}` · **05** agent, `$nix_shell`, `$direnv` — the right
bar, the work. **06** the input line: `$shell$sudo$character$cmd_duration`, unbanded.

</figcaption>
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
