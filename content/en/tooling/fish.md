---
title: "Fish Functions"
description: "The Fish shell functions that run this NixOS host: rebuild wrappers, garbage-collection helpers, and the abbreviations that replace a page of aliases."
weight: 20
---

The interactive shell is **Fish**, configured in
[`home/shell.nix`](https://github.com/lowcache/volnixos/blob/main/home/shell.nix). It exports toolchain
paths, decrypts API keys from `/run/secrets`, runs `volinit` on launch, and wraps `agy` to scaffold
projects before launch.

## Functions

Most of these live in
[`home/common/fish.nix`](https://github.com/lowcache/volnixos/blob/main/home/common/fish.nix);
`tablet` and `setwall` are host-specific and stay in `home/shell.nix`.

| Function    | Description                                                                   |
| :---------- | :--------------------------------------------------------------------------- |
| `setwall`   | Set wallpaper via `noctalia msg wallpaper-set` (wallpaper only — the colorscheme is Noctalia's, written from its own templates) |
| `tablet`    | Use a phone as a Krita pen tablet over USB (Weylus + `adb reverse` on port 1701) |
| `colorhex`  | Render colored swatches around hex codes in stdin/files/args                  |
| `extract`   | Universal archive extractor (`.tar.zst`, `.tar.xz`, `.zip`, `.deb`, …)        |
| `gpgkey`    | Generate a 4096-bit RSA GPG key and export the armored public key             |
| `rmspcs`    | Replace spaces with underscores in filenames recursively                      |
| `ai`        | Run a one-off tool from `llm-agents.nix` (`nix run …#<tool>`)                 |
| `ai-shell`  | Spawn an ephemeral shell with one or more `llm-agents.nix` tools              |
| `cd`        | `cd` that accepts a file path (changes to its directory)                      |

## Aliases (selection)

| Alias                       | Expands to                                                  |
| :-------------------------- | :--------------------------------------------------------- |
| `nx` / `nxup` / `nxfd`      | `nix` / `nix flake update` / `nix search nixpkgs`           |
| `nxsh`                      | `nix-shell -p`                                              |
| `nvrun`                     | PRIME render-offload prefix (run a command on the dGPU)     |
| `stbldff-on` / `stbldff-off`| Start / stop the Fooocus container                         |
| `wifi` / `wifilist`         | `nmtui` / `nmcli device wifi list`                          |
| `shutdown` / `bootbios`     | `systemctl poweroff` / `systemctl reboot --firmware`       |
| `anon-on` / `anon-off` (abbr)| Start / stop the anonymous target (Tor net-gate egress)    |
| `anon-status` (abbr)        | Status of the anonymous target and its jail/routing/check/watch units |

## Environment

```fish
set -gx EDITOR micro
set -gx BROWSER brave
set -gx PATH $HOME/.bin $HOME/.local/bin … $PATH
set -gx SOPS_AGE_KEY_FILE $HOME/.config/sops/age/keys.txt
# GEMINI_API_KEY / GH_TOKEN / PHONE_AGENT_TOKEN / APIFY_API_KEY sourced from
# /run/secrets when readable
```

> [!NOTE] Other programs
> `shell.nix` also configures git (SSH commit signing, LFS), direnv + nix-direnv, the micro
> editor (nil LSP, `nixfmt` on save), and the ssh-agent service. `programs.starship.enable` is
> set in [`home/common/tools.nix`](https://github.com/lowcache/volnixos/blob/main/home/common/tools.nix)
> instead. The prompt config includes a `[custom.ci]` module for CI status; see
> [Starship Prompt](../starship/) for the rest.
