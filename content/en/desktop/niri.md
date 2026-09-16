---
title: "Niri Compositor & UWSM"
description: "Niri on NixOS: UWSM session management, greetd and tuigreet login, a live-edit config.kdl symlink, xwayland-satellite for X11, and the full keybind set."
weight: 10
---

The session is managed by the Universal Wayland Session Manager (UWSM). Login is handled via `greetd` and `tuigreet`, which launches the session. Niri is configured as the sole graphical session and is enabled via `programs.niri.enable` in [`nixos/modules/programs.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/modules/programs.nix), imported through `nixos/modules/default.nix`.

> [!NOTE]
> The configuration file is a live-edit out-of-store symlink pointing to `dots/niri/config.kdl` at `~/.config/niri`. Home Manager does not write files here.

## X11 Support

`xwayland-satellite` is packaged for legacy X11 app support (`home/pkgs.nix:72`), but
it is not wired to autostart — there is no systemd unit and no `spawn-at-startup`
for it in `config.kdl`. It is available on `$PATH` for Flatpak Qt5 apps (using the
xcb plugin) and xcb-only AppImages, but nothing launches it automatically.

## Keybinds

`config.kdl` binds around 128 keys; this page covers a selection. Treat
[`dots/niri/config.kdl`](https://github.com/lowcache/volnixos/blob/main/dots/niri/config.kdl)
as authoritative for anything not listed here.

### System & Launchers

App launchers are dynamically resolved via `~/.config/niri/scripts/launch_first_available.sh`.

| Action | Keybind |
|---|---|
| File Manager | `Mod` + `E` |
| Browser | `Mod` + `W` |
| Code Editor | `Mod` + `C` |
| Text Editor | `Mod` + `X` |
| Volume Mixer | `Ctrl` + `Mod` + `V` |
| Task Manager | `Ctrl` + `Shift` + `Escape` |
| Color picker (`hyprpicker`) | `Mod` + `Shift` + `C` |
| Session menu (`wlogout`) | `Ctrl` + `Alt` + `Delete` |

### Hardware & Session Controls

Media and brightness keys are routed via `noctalia msg` to integrate with the Noctalia shell.

| Action | Keybind |
|---|---|
| Toggle touchpad | `F10` |
| Media / Brightness | Hardware media keys |
| Lock session | `Mod` + `L` |

> [!TIP]
> While `Mod` + `L` triggers `loginctl lock-session`, the visual lock screen itself is provided by Noctalia.

### Workspace Management

| Action | Keybind |
|---|---|
| Move column to adjacent workspace | `Mod` + `Ctrl` + `Up` / `Down` |
| Move column to adjacent workspace (scroll) | `Mod` + `Ctrl` + `WheelScroll` |
| Send column to workspace N | `Mod` + `Alt` + `1`..`9` |
| Pull/push window into adjacent column | `Mod` + `Ctrl` + `Left` / `Right` (`consume-or-expel-window`) |

`Page_Up` / `Page_Down` are left unbound (`config.kdl:166-168`): on this ASUS chassis
those keys sit on the Fn layer and trigger Fn-lock, which interferes with `Mod+` binds.

### Other Notable Binds

| Action | Keybind |
|---|---|
| Screenshot (screen / region / window) | `Print` / `Shift`+`Print` / `Alt`+`Print` |
| Emoji picker | `Mod` + `Period` |
| Night light toggle | `Mod` + `Ctrl` + `N` |
| Dark / light theme toggle | `Mod` + `Ctrl` + `B` |
| Media / volume / brightness / keyboard backlight (XF86 keys) | work while the session is locked (`allow-when-locked=true`) |

## Quake Terminal

A fast drop-down terminal is provided using `kitten quick-access-terminal` and controlled by `dots/niri/scripts/quake.sh`.

| Action | Keybind |
|---|---|
| Toggle visibility | `Mod` + `Return` |
| Position terminal | `Mod` + `Shift` + `Return` |
| Adjust height | `Mod` + `Alt` + `Return` |
| Toggle orientation (landscape/portrait) | `Mod` + `Ctrl` + `Return` |

> [!WARNING]
> The terminal uses an `on-demand` focus policy in `quick-access-terminal.conf` so Niri keybinds can continue functioning while the terminal panel is active.
