# Home Manager Modules

The `lowcache` user environment is assembled in
[`home/`](https://github.com/lowcache/volnixos/tree/main/home).
[`home/default.nix`](https://github.com/lowcache/volnixos/blob/main/home/default.nix) is the entry
point and imports the rest:

```nix
imports = [
  ./persist.nix
  ./pkgs.nix
  ./scripts.nix
  ./shell.nix
  inputs.memd.homeManagerModules.default
];
```

| Module        | Responsibility                                                                |
| :------------ | :--------------------------------------------------------------------------- |
| `default.nix` | Session variables (Wayland backends, portals), GTK theme, cursor, Antigravity desktop entries |
| `pkgs.nix`    | User packages, grouped (dev, niri/Noctalia stack, fonts, terminal, AI CLIs) |
| `persist.nix` | Impermanence `/persist` mappings + out-of-store dotfile symlinks              |
| `scripts.nix` | Tor wrappers, agent-tool `~/.local/bin` symlinks (tether, agent-scaffold)      |
| `shell.nix`   | Fish (init/aliases/functions), git (SSH signing), starship, direnv, micro, ssh-agent |

## Common Portable Layer (`home/common/`)

`home/common/` is the portable layer shared between the laptop and the phone. `home/shell.nix`
imports it on volnix; [`droid/home.nix`](../phone/nix-on-droid.md#user-layer-droidhomenix) imports
it inside Nix-on-Droid, so both environments get the same shell and the same CLI core.

| File | Contents |
| :--- | :--- |
| `default.nix` | Aggregator — imports the other three |
| `fish.nix`    | Fish config, abbreviations, and the `agy` / `ai` / `ai-shell` helper functions |
| `packages.nix`| The portable CLI core (POSIX baseline, fish, git, ripgrep, jq, micro, sops, …) |
| `tools.nix`   | Shared tool configuration (micro, direnv, and friends) |

!!! warning "The aarch64 cache rule"
    Every package in `home/common/packages.nix` must have an **aarch64-linux build in the binary
    cache** — the phone builds on-device, where compiling anything substantial is not viable. This
    is why `nodejs` and `go` are deliberately excluded (no aarch64 substitute at the current rev,
    and ~300 MB respectively) and why `pandoc` and `ripgrep-all` stayed in `termUi`: between them
    they drag in a Haskell toolchain, ffmpeg, poppler and tesseract. Host-only tooling — Wayland
    utils, hardware control, Android forensics, GUI apps — stays in `home/pkgs.nix`.

## Session variables (`default.nix`)

A single `sessionVariables` set is applied to both `home.sessionVariables` and
`systemd.user.sessionVariables`. It sets the Wayland session (`XDG_SESSION_TYPE=wayland`, `QT_QPA_PLATFORM=wayland`,
`NIXOS_OZONE_WL=1`, `GTK_USE_PORTAL=1`, …). `XDG_CURRENT_DESKTOP` is deliberately **not** hardcoded —
`niri-session` exports it itself.

## Packages (`pkgs.nix`)

`home.packages` concatenates themed groups:

| Group        | Highlights                                                                  |
| :----------- | :------------------------------------------------------------------------- |
| `baseDev`    | gcc, cmake, go, nodejs, dart-sass                                           |
| `niriDesktop`| xwayland-satellite + file managers (caja, …), fuzzel, kitty, **floorp-bin**, spotify, vscodium, file-roller, grim/slurp/swappy |
| `typography` | material-symbols + a large Nerd Fonts selection                            |
| `termUi`     | Desktop-only CLI: gvfs, gh-\* helpers, tgpt, gpg-tui, ripgrep-all, pandoc, tor, flatpak, hardware control (brightnessctl, ddcutil, upower, acpi), android-tools, `volinit` |
| `nixAi`      | claude-code, claude-code-router, gemini-cli, codex, rtk, MCP servers (nixos, gateway, github, playwright, context7, …), `llm-agents` packages |
| `andronix`   | scrcpy, apktool, frida-tools (Android tooling)                              |

!!! note "`termUi` is the desktop remainder, not the base shell"
    The everyday CLI core — fish, git, gh, eza, bat, ripgrep, fd, jq, sops, micro, nil — moved to
    [`home/common/packages.nix`](#common-portable-layer-homecommon) so the phone gets it too.
    `termUi` is what stayed behind because it is desktop-only or too heavy for aarch64.

!!! note "Krita native Wayland"
    Krita runs as a native Wayland client under niri. Previously on Hyprland, it was wrapped to force `QT_QPA_PLATFORM=xcb` to avoid canvas freezes, but niri handles the native Wayland Qt6 client smoothly.

## Browsers

Brave is installed through the `programs.chromium` Home Manager module (in `shell.nix`), which both
provides the package (`package = pkgs.brave`) and applies Wayland/GPU command-line flags. Floorp
(`floorp-bin`) is the backup browser, added to `home.packages` in `pkgs.nix`.

## Persistence & symlinks (`persist.nix`)

See [Impermanence](../architecture/impermanence.md). This module declares the `/persist` directory and
file lists, the `mkOutOfStoreSymlink` dotfile mappings, and the `~/volnix` alias.

## Agent tooling (`scripts.nix`)

Symlinks graduated agent tools (`tether` from `CodeRepo/tether` and `agent-scaffold` from `.nix-config/scripts`) into `~/.local/bin` (out-of-store, live-editable). The `memd` tool and its `memd-sweep` timer are deployed declaratively via the `services.memd` module. See [Agent Toolchain](../tooling/agents.md).
