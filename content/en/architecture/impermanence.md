---
title: "Impermanence & Persistence"
description: "A tmpfs root wiped on every boot, with nix-community/impermanence declaring exactly what survives. What persists, what does not, and where the traps are."
weight: 20
---

The root filesystem is a volatile `tmpfs`, rebuilt clean on every boot via
[`nix-community/impermanence`](https://github.com/nix-community/impermanence). Nothing outside the Nix
store and explicitly-declared persistence survives a reboot.

```mermaid
graph LR
    BOOT["boot"] --> TMP["/ (tmpfs)<br/>wiped clean"]
    PERSIST["/persist<br/>real disk"] -->|bind / symlink| TMP
    REPO["/persist/.../.nix-config/dots"] -->|mkOutOfStoreSymlink| CFG["~/.config/*"]
    EDIT["edit dotfile"] --> REPO
    REPO -.live, no rebuild.-> CFG
```

## What persists

Persistence is declared in two layers. The **system layer** lives in
[`nixos/hardware-configuration.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/hardware-configuration.nix)
under `environment.persistence."/persist"` (`hideMounts = true`):

| Category         | Paths                                                                        |
| :--------------- | :--------------------------------------------------------------------------- |
| Identity & keys  | `/etc/ssh`, `/etc/machine-id` (file), `/etc/secureboot`, `/var/lib/sbctl`     |
| Networking       | `/var/lib/NetworkManager`, `/etc/NetworkManager/system-connections`, `/var/lib/bluetooth` |
| Service state    | `/var/lib/nixos`, `/var/lib/greetd`, `/var/log`, `/etc/asusd`, `/var/lib/cardwire`, `/var/lib/fwupd` |
| Virtualization   | `/var/lib/microvm`, `/var/lib/docker`, `/var/lib/waydroid`                    |
| Apps             | `/var/lib/flatpak`, `/var/lib/private/open-webui`                             |

`/etc/ssh` matters more than it looks: the host SSH key persisted there is the age identity
sops-nix decrypts with at boot (see [Secrets](secrets/)), and `/etc/secureboot` holds the
Lanzaboote PKI bundle (see [Boot & Secure Boot](boot/)).

The **user layer** is declared in
[`home/persist.nix`](https://github.com/lowcache/volnixos/blob/main/home/persist.nix) under
`home.persistence."/persist"`. Categories include:

| Category    | Examples                                                                 |
| :---------- | :----------------------------------------------------------------------- |
| Credentials | `.ssh`, `.gnupg`, `.config/sops`, `.local/share/keyrings`                |
| Tooling     | `.cargo`, `.rustup`, `.npm`, `.local/share/go`, `.foundry`, `.solc-select` |
| App state   | `.config/BraveSoftware`, `.config/VSCodium`, `.config/spotify`, `.config/obsidian`, `.ollama`, `.claude`, `.omo`, `.var/app`, `.local/share/noctalia`, `.local/state/noctalia`, `.local/share/waydroid`, `.local/share/opencode` |
| GTK & cursor | `.config/gtk-3.0`, `.config/gtk-4.0`, `.local/share/icons`, `.icons/default` (written by the Noctalia Cursor plugin, see [Theming](../desktop/theming/)) |
| Password mgr | `.config/rbw`, `.config/Bitwarden`, `.local/share/rbw`                   |
| MCP gateway | `.mcp-gateway` (runtime state: OAuth client id, refresh tokens), `.config/mcp-gateway` (config) |
| Caches      | `.cache/pip`, `.cache/noctalia`, `.cache/nvidia`, `.cache/llmfit`       |
| Home dirs   | `Documents`, `Pictures`, `Downloads`, `Projects`, `CodeRepo`, `unDevel`, `AppImage`, `ZAP-Sessions`, `.bin` |
| Memory tool | `.config/memd`, `.local/state/memd`                                       |
| Single files | `.claude.json` (Claude Code state, lives outside `~/.claude`); `.config/environment.d/90-xcursor.conf` (`XCURSOR_*` for the `systemd --user` session, written by the Cursor plugin) |

> [!NOTE] Cache root lives off the tmpfs
> `xdg.cacheHome` is redirected to `~/Storage/.cache` (see `home/persist.nix` /
> `home/default.nix`), so caches don't fill the ~4 GB tmpfs root. The `.cache/*` persistence
> entries above remain as a safety net for apps that hardcode `~/.cache` and ignore XDG.
> (`.config/niri` and `.config/noctalia` are **not** in this list — they are out-of-store
> symlinks, covered below.)

## Out-of-store symlinks

User dotfiles are **not** copied into the Nix store. Instead,
[`home/persist.nix`](https://github.com/lowcache/volnixos/blob/main/home/persist.nix) maps them with
`config.lib.file.mkOutOfStoreSymlink` from the repo checkout into `~/.config/`:

```nix
xdg.configFile."niri".source =
  config.lib.file.mkOutOfStoreSymlink
    "/persist${config.home.homeDirectory}/.nix-config/dots/niri";
```

> [!TIP] Why out-of-store
> Edits to the tracked dotfiles take effect **immediately** — inotify hot-reload works across the
> symlink — without a `home-manager` rebuild, while the files remain version-controlled. This is the
> same philosophy applied to the agent tooling binaries in
> [`home/scripts.nix`](https://github.com/lowcache/volnixos/blob/main/home/scripts.nix).

### Redirected to `~/Storage`

`~/Storage` is a separate NVMe, not part of `/persist`. Several large, re-downloadable trees are
**not** persisted through impermanence at all — `home.file` points them at `~/Storage` with
`mkOutOfStoreSymlink` instead:

| Path              | Target                     | Why not `/persist`                                          |
| :---------------- | :------------------------- | :---------------------------------------------------------- |
| `~/Android`       | `~/Storage/Android`        | Android Studio SDK, multiple GB and re-downloadable          |
| `~/.android`      | `~/Storage/.android`       | AVD root — emulator disk images                              |
| `~/.thunderbird`  | `~/Storage/thunderbird`    | Profile root incl. local mail stores; IMAP caches grow without bound |
| `~/.local/share/krita` | `~/Storage/krita-master/krita` | Build tree, not state                                   |
| `~/.config/kritarc`, `~/.config/kritadisplayrc` | `~/Storage/krita-master/` | Kept beside the Krita tree they configure |
| `~/Pictures/fromAi/outputs` | `~/Storage/ai-generation/fooocus/outputs` | Generated image output          |

> [!WARNING] A path is a symlink or a persisted directory — never both
> impermanence bind-mounts refuse a non-canonical target, so anything listed in `home.file` as an
> out-of-store symlink must stay out of `home.persistence."/persist".directories`.

### No imperative Nix profile

The `nix-env` profile is retired. `~/.local/state/nix/profiles` is no longer persisted and the
`~/.nix-profile` link is no longer pinned, so there is no imperative profile to install into: a
package is either declared, or run ad hoc with `nix shell` / `,` (comma, from `nix-index-database`).
`.config/systemd/user` is not persisted either; user units come from Home Manager, including
`mcp-gateway` (see [Agent Toolchain](../tooling/agents/#mcp-servers)).

## `/persist` at rest: LUKS2

The root is tmpfs, so `/persist` is the only place machine state and secrets live at rest, and it is
encrypted. [`nixos/modules/persist-luks.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/modules/persist-luks.nix)
opens a LUKS2 container in the initrd as `cryptpersist` and mounts `/dev/mapper/cryptpersist` on
`/persist` (overriding the raw partition named in `hardware-configuration.nix`). `/boot` and `/nix`
stay plaintext. The container's UUID was fixed in advance with `cryptsetup luksFormat --uuid`, so the
config could be built before the container existed; the migration ran from a live USB in 2026-09,
and `vol.persistLuks.enable` was flipped afterwards. TRIM is allowed (`allowDiscards`): it leaks
which blocks are in use, not their contents.

> [!WARNING] `~/Storage` is not encrypted
> Only `/persist` is. `~/Storage` is a separate plaintext volume, so everything redirected there,
> including anon-box's output in `~/Storage/anon/out`, is at rest in the clear. The config records
> this as a known, accepted gap.

### The stick gate

With `vol.persistLuks.stickGate.enable`, the unlock key is not typed. It is a 64-byte blob read from
a fixed offset on a USB stick, concatenated with a held-modifier key chord read from evdev in
the initrd:

1. The `stick-gate` initrd unit runs before `systemd-cryptsetup@cryptpersist`. It waits up to
   `stickWait` seconds (default 10) for the stick at its `/dev/disk/by-id` path and reads the blob at
   `offset`. On this host the blob sits in the last MiB of the NixOS live-installer stick, past the
   ISO, so the stick stays bootable.
2. It grabs every keyboard, blinks Caps Lock, and records one chord for up to `timeout` seconds
   (default 60): each non-modifier key pressed while modifiers are held, with left and right
   modifiers merged. The chord ends when all modifiers are released.
3. It writes blob ‖ chord to `/run/cryptsetup-keys.d/cryptpersist.key`, which `systemd-cryptsetup`
   picks up on its own.
4. `stick-gate-wipe` erases that key file after the container opens and before switch-root, because
   `/run` survives switch-root and auto-discovered key files are never erased.

The gate never fails the boot. A missing stick, an all-zero (never enrolled) blob or a chord
timeout leaves no key file, and `systemd-cryptsetup` falls back to the normal passphrase prompt. The reader is
[`chordgate`](https://github.com/lowcache/volnixos/blob/main/nixos/modules/chordgate/chordgate.c),
a small C program built in the module with `runCommandCC`; its unit test runs at build time, so a
failing test fails the build. `chordgate enroll` captures the chord twice and requires at least
8 steps.

## The `~/volnix` alias

`home/persist.nix` also creates a **non-hidden** symlink `~/volnix → /persist$HOME/.nix-config`. The
Antigravity CLI rejects hidden paths as workspace folders, so the [agent tether](../tooling/agents/)
delegates with `~/volnix` as the working directory.

> [!WARNING] Secrets never live in `dots/`
> `dots/` is published in the public repo. Secrets belong only in `nixos/host-secrets.yaml` /
> `nixos/vm-secrets.yaml` (sops-encrypted) or under `/persist` (never git-tracked). See
> [Secrets](secrets/).
