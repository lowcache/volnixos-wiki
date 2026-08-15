# Nix-on-Droid

The phone runs a real Nix store, a real Home Manager profile, and the same fish shell as the
laptop — inside `com.termux.nix`, an Android app with no root, no systemd, and no Wayland. The
target is the flake output `nixOnDroidConfigurations.default`, declared in
[`flake.nix`](https://github.com/lowcache/volnixos/blob/main/flake.nix) and configured by
[`droid/`](https://github.com/lowcache/volnixos/blob/main/droid/).

```nix
nixOnDroidConfigurations.default = inputs.nix-on-droid.lib.nixOnDroidConfiguration {
  pkgs = import inputs.nixpkgs-droid { ... };   # NOT inputs.nixpkgs
  modules = [ ./droid ];
  home-manager-path = inputs.home-manager-droid.outPath;
};
```

!!! danger "The phone must never use `inputs.nixpkgs`"
    The phone is pinned to `nixos-25.11` (glibc 2.40). Building it against the main unstable
    `nixpkgs` (glibc 2.42) produces a system whose every interactive shell starts *promptless and
    silently eats your keystrokes*. The reason is below, and it is not a matter of taste.

## Why the package set is pinned

glibc 2.42 reimplemented `isatty()` / `tcgetattr()` on top of the **TCGETS2** ioctl (termios2,
arbitrary baud rates). Android's SELinux ioctl allowlist for `untrusted_app` permits `TCGETS` but
**not** `TCGETS2`, so on-device the call returns `EACCES`. Every glibc-2.42 binary therefore
concludes it has no terminal: bash and fish start, decide they are non-interactive, print no prompt,
and read commands from the pty in silence. It reads exactly like a hang.

Measured on-device 2026-08-02 against a live pty (Nix-on-Droid, Android 16):

| ioctl | Number | Result | Probe |
| :--- | :--- | :--- | :--- |
| `TCGETS` | `0x5401` | OK | `tty` (coreutils 9.5, glibc 2.40) → `/dev/pts/0` |
| `TCGETS2` | `0x802C542A` | `EACCES` | `tty` (coreutils 9.11, glibc 2.42) → "not a tty" |

glibc sits at the root of the package graph, so patching it means rebuilding all of nixpkgs on a
phone. Pinning to a release that still ships glibc 2.40 costs nothing and stays fully cached.
Revisit once glibc falls back to `TCGETS` on `EACCES`.

### The three phone inputs

| Input | URL | Notes |
| :--- | :--- | :--- |
| `nixpkgs-droid` | `github:nixos/nixpkgs/nixos-25.11` | The glibc 2.40 pin. Deliberately not our `nixpkgs`. |
| `home-manager-droid` | `github:nix-community/home-manager/release-25.11` | `inputs.nixpkgs.follows = "nixpkgs-droid"` |
| `nix-on-droid` | `github:nix-community/nix-on-droid` | Tracks **master** — `release-24.05` is the newest tag and is ~2 years behind. |

`nix-on-droid`'s own inputs are redirected so the phone never resolves a second package set:

```nix
inputs = {
  nixpkgs.follows            = "nixpkgs-droid";
  home-manager.follows       = "home-manager-droid";
  nix-formatter-pack.follows = "";          # docs/formatter-only — dropped
  nmd.follows                = "";          # docs/formatter-only — dropped
  nixpkgs-docs.follows       = "nixpkgs-droid";
};
```

`nix-formatter-pack` and `nmd` are emptied rather than followed because the configuration never
evaluates nix-on-droid's `formatter`, `checks`, or docs outputs — carrying them would mean extra
locked revisions the phone has to resolve for nothing.

## System layer — `droid/default.nix`

| Setting | Value | Why |
| :--- | :--- | :--- |
| `terminal.font` | JetBrains Mono Nerd Font Mono | The app's built-in font has no Nerd Font glyphs, so starship's powerline separators render as tofu. |
| `environment.packages` | `procps`, `util-linux`, `hostname`, `which`, `curl`, `openssh` | Minimal system floor; everything else is user-scoped via Home Manager. |
| `environment.etcBackupExtension` | `".bak"` | Rename pre-existing `/etc` files instead of aborting activation. |
| `user.shell` | `${pkgs.fish}/bin/fish` | Same login shell as volnix. Must be a path to the exact binary. |
| `time.timeZone` | `America/New_York` | — |
| `system.stateVersion` | `"24.05"` | Read the nix-on-droid changelog before changing this. |
| `nix.extraOptions` | `flakes`, `fallback = true` | The phone builds nothing it can avoid building. |

### Substituter

```nix
substituters      = [ "https://cache.numtide.com" ];
trustedPublicKeys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
```

These **append** to nix-on-droid's own `cache.nixos.org` + `nix-on-droid.cachix.org` rather than
replacing them. The entry is currently inert: at the `nixos-25.11` pin this cache cannot match those
paths anyway (its builds are keyed to llm-agents' own nixpkgs — precisely why that package set was
dropped), so it costs one extra 404 per substitution query. It is kept so the entry is correct and
signed if the pin ever lifts.

### Termux-compat shims stay off

`termux-open`, `termux-open-url`, `termux-setup-storage`, `termux-wake-lock`, `xdg-open` and `am`
are all deliberately disabled. Enabling any of them pulls `termux-am`, which is one of
nix-on-droid's own packages — built from source with cmake, not a nixpkgs package. Upstream
publishes it prebuilt on `nix-on-droid.cachix.org`, but only against *upstream's* pinned nixpkgs, so
our derivation hash does not match and the phone would have to compile it. It cannot.

## User layer — `droid/home.nix`

Imports `../home/common` (the layer shared with the laptop) plus `./agents.nix`. Nothing
desktop-shaped is pulled in.

- **Programs:** `fish`, `fastfetch`, `wget`, `rsync`, `unzip`, `zip`, `tmux`.
- **Starship:** `xdg.configFile."starship.toml"` sources `../dots/starship/starship.toml` directly
  from the Nix store — Android has no `/persist`, so the laptop's impermanence
  `mkOutOfStoreSymlink` pattern does not apply here.
- **`manual.manpages.enable = false`** — rendering manpages is a laptop activity.
- **`shellInit`** sets `TMPDIR=$PREFIX/tmp` and `NIX_CONFIG_DIR=$HOME/.nix-config`, keeping scratch
  files inside the Termux sandbox root.
- **Aliases:** `droid-switch`, `droid-build`, `droid-rollback`, `cfg`. There is no `nixos-rebuild`
  alias — that command does not exist here.
- `home.username` / `home.homeDirectory` are intentionally left unset; the Nix-on-Droid module
  manages them.

## Agent layer — `droid/agents.nix`

Installed from the `25.11` pin: `claude-code`, `claude-code-router`, `codex`, `opencode` (kept as a
session-death fallback), `mcp-nixos`, `github-mcp-server`. Installed from
[backports](backports.md): `rtk`, `mcp-gateway`.

Explicitly excluded, each for a stated reason:

| Excluded | Reason |
| :--- | :--- |
| `github-copilot-cli` | No aarch64 build (evaluation error at this rev). |
| `antigravity` | Evaluates on aarch64, but it is a desktop Electron IDE and there is no display server — ~3.2 GB of GTK/X11 closure for a binary that cannot launch. |
| `memd`, `tether`, `agent-scaffold` | `home/scripts.nix` links these out of `/persist`, which does not exist on Android. They need a phone-local checkout first. |
| The whole `pkgs.llm-agents.*` set | At the 25.11 pin the cache hashes do not match, so Nix tries to build them natively under proot — which fails (see [backports](backports.md)). |
| `context7-mcp`, `mcp-server-fetch`, `mcp-server-sequential-thinking`, `llmfit` | Unstable-only; same proot build failure. |

## Building and switching

```bash
# On the LAPTOP — evaluate only
make droid-check     # nix eval  ...home.activationPackage.drvPath
make droid-plan      # nix build --dry-run: what would be fetched vs compiled

# On the PHONE, inside Nix-on-Droid
make droid-switch    # nix-on-droid switch --flake .
```

!!! note "The laptop cannot build the phone"
    volnix has no `aarch64` emulation configured, so `droid-check` and `droid-plan` evaluate and
    dry-run only. `droid-check` is further limited to the **Home Manager layer**: the system layer's
    uid/gid probe is an import-from-derivation that can only run on the device. Actual builds and
    activation happen on the phone.
