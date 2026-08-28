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

That is wider coverage than this host ever built by hand, which is the whole
reason the local engine below stopped being run.

## The color-engine is superseded

`dots/color-engine/` still exists in the config repo and is **no longer used**.

It was written for Hyprland and the previous QML shell, where nothing propagated
a palette on its own and a global JSON scheme with a Python applier was the only
way to keep the bar, terminal and prompt in agreement. Noctalia v5 does that
natively, granularly enough that a second layer on top only adds a way for the
two to disagree.

The files are kept for reference, not because they run. `apply_theme.py` and the
palette it generated (`~/.config/noctalia/palettes/volnix.json`) were both last
touched on 2026-06-28.

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

The terminal is configured by a Home Manager generated `kitty.conf` in
`dots/kitty/`, independently of whatever themes the desktop:

- `fish` as the default shell
- "PunkMono Nerd Font" at size 11, with `symbol_map` for the Nerd Font PUA ranges
- Beam cursor with `cursor_trail`
- A custom bottom tab bar from `tab_bar.py`
- `allow_remote_control` with `listen_on unix:@mykitty`, which the old engine
  used to push colours live and which remains useful for scripting kitty
- Extra colourschemes in `dots/kitty_colorschemes/`

## Fonts

| Role | Family |
| :--- | :--- |
| Main | Google Sans Flex |
| Monospace | JetBrains Mono NF |
| Expressive | Space Grotesk |
| Reading | Readex Pro |
