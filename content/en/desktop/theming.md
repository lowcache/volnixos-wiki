---
title: "Theming"
description: "Noctalia v5 themes the desktop itself, writing GTK 3 and 4, Qt 5 and 6, bat and Telegram themes from its own palette. The old color-engine is superseded."
weight: 30
---

Noctalia v5 handles theming natively. Pick a scheme in Noctalia and it writes
theme files for the rest of the desktop, so nothing else has to be wired up.

## What Noctalia writes

Changing the scheme regenerates these, live:

| Target | File |
| :--- | :--- |
| GTK 3 | `~/.config/gtk-3.0/noctalia.css` |
| GTK 4 | `~/.config/gtk-4.0/noctalia.css` |
| Qt 5 | `~/.config/qt5ct/colors/noctalia.conf` |
| Qt 6 | `~/.config/qt6ct/colors/noctalia.conf` |
| bat | `~/.config/bat/themes/noctalia.tmTheme` |
| Telegram | `~/.config/telegram-desktop/themes/noctalia.tdesktop-theme` |

That table covers the templates detailed individually on this page. The full set is
`theme.templates.builtin_ids` and `theme.templates.community_ids` in
`~/.local/state/noctalia/settings.toml`: builtin — `cava`, `gtk3`, `gtk4`, `kitty`,
`niri`, `qt` — plus 13 community templates, including `starship-m3` (see
[Starship](#starship) below), `bat`, `telegram`, `fuzzel`, `micro`, `vscode`,
`brave`, `discord`, `claude-code`, `codex`, and `opencode`.

That is wider coverage than this host ever built by hand, which is the whole
reason the local engine below stopped being run.

## The color-engine is dormant, and destructive if run

`dots/color-engine/` still exists in the config repo and is not part of the
theming pipeline — Noctalia writes its own targets natively (see above).

It was written for Hyprland and the previous QML shell, where nothing propagated
a palette on its own and a global JSON scheme with a Python applier was the only
way to keep the bar, terminal and prompt in agreement. Noctalia v5 does that
natively, granularly enough that a second layer on top only adds a way for the
two to disagree.

The files are kept for reference, not because they run. `apply_theme.py` was
last touched on 2026-06-28. The palette directory it used to write to,
`dots/noctalia/palettes/`, has since been deleted from the repo — Noctalia's
live palette now comes from `source = "community"`, `community_palette = "Cream
Autumn"` in `~/.local/state/noctalia/settings.toml`, not from a generated JSON
file.

> [!WARNING] Do not run `apply_theme.py` against the live config
> Dormant does not mean harmless.
> [`apply_theme.py`](https://github.com/lowcache/volnixos/blob/main/dots/color-engine/apply_theme.py)
> `:132` rewrites `palette = "m3"` back to `palette = "current"` in
> `dots/starship/starship.toml`, and `:146`'s
> `re.sub(r'\[palettes\..*\](\n.*)*', ...)` matches from the first `[palettes.`
> to the end of the file — deleting the file's entire M3 palette block, not
> just the section it means to replace.

> [!WARNING]
> Earlier revisions of this page told you to theme the system with
> `make theme-apply THEME=<name>`. **That target no longer exists in the
> Makefile.** If you found this page through a search result quoting that
> command, it is stale and the command will fail. Use Noctalia's own scheme
> selection instead.

The engine's scripts, if you are reading the repo and want to know what they
were: `apply_theme.py` mapped a JSON palette across applications through a
`TECHNICAL_MAP`, `check_theme.py` validated theme structure and hard-failed on
bad hex or dangling references, and `make_theme.py` generated a full theme
including a 16-colour terminal set from two hex arguments.

## Kitty

`~/.config/kitty` is an out-of-store symlink to
[`dots/kitty`](https://github.com/lowcache/volnixos/tree/main/dots/kitty)
(`home/persist.nix:19`), not a Home Manager generated file. `kitty.conf:68`
does `include themes/noctalia.conf` — kitty is one of Noctalia's builtin
template targets (`kitty` in `theme.templates.builtin_ids`, see above), not
themed independently of the desktop:

- `fish` as the default shell
- "PunkMono Nerd Font" at size 11, with `symbol_map` for the Nerd Font PUA ranges
- Beam cursor with `cursor_trail`
- A custom bottom tab bar from `tab_bar.py`
- `allow_remote_control` with `listen_on unix:@mykitty`, useful for scripting
  kitty independently of the included Noctalia theme
- Extra colourschemes in `dots/kitty_colorschemes/`

## Starship

The prompt runs on `palette = "m3"`, driven by the repo-tracked
`dots/noctalia/templates/starship-m3/` template rather than Noctalia's builtin
`starship` template — which reads only the 8 terminal ANSI hues and was
removed from `theme.templates.builtin_ids` because this template supersedes
it. See [Starship Prompt](../tooling/starship/) for the rest.

## Fonts

| Role | Family |
| :--- | :--- |
| Main | Google Sans Flex |
| Monospace | JetBrains Mono NF |
| Expressive | Space Grotesk |
| Reading | Readex Pro |
