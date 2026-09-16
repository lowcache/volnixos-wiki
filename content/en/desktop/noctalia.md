---
title: "Noctalia Architecture"
description: "Noctalia v5 is a native C++ Wayland shell, compositor-agnostic, with no QML RAM cost. How it is packaged as a flake input, configured and themed on NixOS."
weight: 20
---

The desktop shell is built on Noctalia (v5), a C++/native Wayland shell that is
compositor-agnostic. Noctalia completely replaces the previous QML-based shell, escaping the
~300MB/monitor QML RAM tax to provide a fast, memory-efficient environment.

## Configuration & Management

Noctalia is packaged via the `noctalia` flake input and enabled in `home/shell.nix:22`
(`programs.noctalia.enable`). The installed binary currently reports `noctalia v5.0.1`;
the flake input (`flake.nix:28`) tracks `github:noctalia-dev/noctalia` with no `?ref=`
pin, so that version drifts on `nix flake update` rather than staying put.

> [!NOTE]
> The configuration is maintained as a live out-of-store symlink at `~/.config/noctalia` pointing to `dots/noctalia`. Home Manager explicitly does not write files here.

## Core Features

Noctalia serves as the hub for the desktop's visual and interactive elements:
- **Bottom + Side Bar:** A bottom bar and a right-hand side bar (`order = ["bottom", "side"]` in `settings.toml:15`) that together frame the workspace.
- **Lock & Idle:** Robust lock/idle handling, providing the visual lock screen interface.
- **Media & Brightness:** Hardware control routing via `noctalia msg` IPC commands.
- **Wallpaper Picker:** Native desktop wallpaper integration.

### Desktop & Bar Layout w/ plugins

Per `~/.local/state/noctalia/settings.toml`, the bar is split into two positioned
panels rather than a single wrap-around frame:
- **Bottom Bar** (`[bar.bottom]`, `position = "bottom"`, `:35`): Full width, containing
  system monitors (cpu/cpu temp, gpu/gpu temp, RAM, SWAP, /persist, and Download graph)
  an off-centered clock & weather, tray, network, volume, battery, bluetooth and session
  widgets.
- **Side Bar** (`[bar.side]`, `position = "right"`, `:99`): Full height, housing an audio
  visualizer, workspaces, and the chosen plugins (oversized claude-companion pulse,
  calculator, clipboard, screenshot, prettier bound keys display, nix monitor, notes,
  and llama manager).
- **Dock:** A separate `position = "left"` panel (`:257`) — the app dock, not a bar.
- **Desktop:** An audio visualizer widget spans the length of the side bar at the edge
  that gives the effect of audio bars extending from the bar onto the desktop for when
  a window isn't at full screen.

> [!NOTE] Claude Code companion plugin (external)
>
> A Claude Code companion plugin for Noctalia is developed in a separate repository
> (`~/CodeRepo/noctalia-claude-plugin`) and is not managed by this flake or tracked in `dots/`.
> The source code can be found at the [Claude-Companion Dev Repo](https://github.com/lowcache/noctalia-claude-plugin) and the [Noctalia-Community-Plugins repo](https://github.com/noctalia-dev/community-plugins) 
> The Claude-Companion plugin can be installed through the plugins tab in the Noctalia Settings Window after turning the toggle for `Community-Plugins`
>

## Theming

Noctalia v5 themes the desktop itself. Selecting a scheme regenerates GTK 3 and
4, Qt 5 and 6, bat and Telegram themes on the fly, so the rest of the desktop
follows without any glue.

The custom Python color-engine in `dots/color-engine/` is not part of this
pipeline — Noctalia writes these natively — and the `make theme-apply` target
that used to drive it no longer exists. The engine is dormant rather than
harmless if run directly; see [Theming](../theming/) for what replaced it and
the hazard of running it against the live config.
