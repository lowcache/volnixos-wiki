---
title: "Dotfiles"
description: "The dotfiles behind this setup, including the Noctalia v5 and Niri configs, and how out-of-store symlinks keep them live-editable under Home Manager."
weight: 30
---

The [`dots/`](https://github.com/lowcache/volnixos/tree/main/dots) tree holds all user-space
configuration. Its children are symlinked into `~/.config/` with
`config.lib.file.mkOutOfStoreSymlink` (see [Impermanence](../architecture/impermanence/)), so edits
apply live without a rebuild.

```text
dots/
├── .memory/             # memd project memory (state/decisions/mistakes/todo + inbox)
├── .model/              # agent-scaffold guides (CLAUDE.md etc.)
├── cava/                # audio visualizer: shaders + gradient themes
├── fastfetch/           # system info fetch (config.jsonc)
├── fuzzel/              # application launcher (fuzzel.ini + theme)
├── color-engine/        # JSON theme engine: apply_theme.py + themes/
├── kitty/              # terminal: kitty.conf + tab_bar.py + current.conf
├── kitty_colorschemes/  # extra kitty colorschemes
├── niri/                # niri compositor: config.kdl, scripts, quake terminal
├── noctalia/            # Noctalia v5 shell: config.toml + templates/starship-m3/
├── starship/            # prompt: starship.toml + three inert reference configs
└── wlogout/             # Wayland logout menu (layout + style.css)
```

Most of these are detailed in the [Desktop](../desktop/) section. A quick reference:

| Dotfile             | Notable settings                                                          |
| :------------------ | :----------------------------------------------------------------------- |
| `niri/`             | Keybinds, window rules, startup apps, IPC scripts, and Kitty quake terminal |
| `noctalia/`         | Noctalia v5 shell config (`config.toml`) + the `templates/starship-m3/` prompt template |
| `color-engine/`     | JSON theme engine (`apply_theme.py`); themes mapped to Noctalia, Kitty, and Starship |
| `kitty/`            | PunkMono Nerd Font, fish shell, custom bottom tab bar, `listen_on unix:@mykitty` for live theming |
| `fuzzel/`           | Google Sans Flex, overlay layer, rounded borders                         |
| `wlogout/`          | Six session actions (lock, logout, suspend, hibernate, reboot, shutdown) |
| `cava/`             | Spectrum shaders + an 8-stop `tricolor` gradient theme                    |
| `starship/`         | Two-line powerline prompt on the Noctalia M3 palette, `cmd_duration` notifications |
| `fastfetch/`        | Auto logo, full module list (os/host/kernel/cpu/gpu/memory/…)            |

## The prompt palette (`starship/` + `noctalia/templates/starship-m3/`)

[`dots/starship/starship.toml`](https://github.com/lowcache/volnixos/blob/main/dots/starship/starship.toml)
is the live prompt and sets `palette = "m3"`. It does not define those colors itself. Noctalia owns
Material 3 palette emission, and
[`dots/noctalia/templates/starship-m3/apply.sh`](https://github.com/lowcache/volnixos/blob/main/dots/noctalia/templates/starship-m3/apply.sh)
splices the generated `[palettes.m3]` block into `starship.toml` between markers, leaving the
hand-authored format section untouched. Every color in the prompt is therefore an M3 role name
(`primary_7`, `primary_15`, …) that follows the shell's current theme. This replaced an earlier
custom-palette layer at `noctalia/palettes/volnix.json`, which was dropped.

The `[custom.ci]` module renders CI state for the last pushed commit. Starship kills a custom
module's command at 500 ms, so it never touches the network: `ci-poll` (see
[Home Manager Modules](../home-manager/#agent-and-shell-scripting-scriptsnix)) polls GitHub in the
background and leaves one short line in `$XDG_RUNTIME_DIR`, which the module `cat`s. The segment
hides when that file is empty.

> [!WARNING] `powerline.toml` and `rainbow.toml` are not live
> The `starship/` directory also holds `powerline.toml`, `rainbow.toml`, and `starship.b.toml`.
> Only `starship.toml` is read. `powerline.toml` and `rainbow.toml` are stock upstream starship
> presets with hardcoded palettes — `catppuccin_mocha` and `gruvbox_dark` respectively — kept as
> reference. They are **not** M3-driven, and editing them changes nothing.

## Independent dotfiles history

`dots/` can be published with its own history without a separate repository, using `git subtree`. The
[Makefile](../tooling/makefile/) wraps the workflow:

```bash
make dots-log                       # history scoped to dots/ (no remote needed)
make dots-split                     # regenerate the dots-history projection branch
make dots-remote URL=<git-url>      # add the standalone 'dotfiles' remote (once)
make dots-push                      # publish dots/ to dotfiles/main
make dots-pull                      # merge changes back into dots/
```

> [!WARNING] No secrets in `dots/`
> `dots/` is public — only declarative config is tracked. Runtime credentials and agent state (for
> example `~/.gemini`) live outside the repo as persisted `$HOME` directories, never in `dots/`.
