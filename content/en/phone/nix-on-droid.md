---
title: "Nix-on-Droid"
weight: 10
---

The phone runs a real Nix store, a real Home Manager profile, and the same fish shell as the
laptop — inside `com.termux.nix`, an Android app with no root, no systemd, and no Wayland. The
target is the flake output `nixOnDroidConfigurations.default`, declared in
[`flake.nix`](https://github.com/lowcache/volnixos/blob/main/flake.nix) and configured by
[`droid/`](https://github.com/lowcache/volnixos/blob/main/droid/).

```nix
nixOnDroidConfigurations.default = inputs.nix-on-droid.lib.nixOnDroidConfiguration {
  pkgs = import inputs.nixpkgs-droid {          # NOT inputs.nixpkgs
    system = "aarch64-linux";
    overlays = [
      inputs.nix-on-droid.overlays.default      # proot-static, termux shims
      inputs.llm-agents.overlays.shared-nixpkgs
      (import ./droid/backports.nix {           # see Backports
        unstable     = inputs.nixpkgs;
        unstablePkgs = import inputs.nixpkgs { system = "aarch64-linux"; ... };
        nix-on-droid-src = inputs.nix-on-droid;
      })
    ];
    config.allowUnfree = true;
  };
  modules          = [ ./droid ];
  extraSpecialArgs = { nix-on-droid = inputs.nix-on-droid; };
  home-manager-path = inputs.home-manager-droid.outPath;
};
```

`extraSpecialArgs` hands the flake input itself to the module tree. `droid/default.nix` needs it to
name a *path inside* nix-on-droid's source: the upstream module it disables. See
[Android integration shims](#android-integration-shims).

> [!CAUTION] The phone must never use `inputs.nixpkgs`
> The phone is pinned to `nixos-25.11` (glibc 2.40). Building it against the main unstable
> `nixpkgs` (glibc 2.42) produces a system whose every interactive shell starts *promptless and
> silently eats your keystrokes*. The reason is below, and it is not a matter of taste.

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
| `disabledModules` + `imports` | upstream `android-integration.nix` → `./android-integration.nix` | Upstream's copy bypasses the overlay. See [below](#android-integration-shims). |
| `home-manager.backupFileExtension` | `"hm-bak"` | The `etcBackupExtension` idea, applied to the Home Manager layer. |
| `home-manager.useGlobalPkgs` | `true` | One package set for both layers, the pinned one. |

### Substituter

```nix
substituters      = [ "https://cache.numtide.com" ];
trustedPublicKeys = [ "niks3.numtide.com-1:DTx8wZduET09hRmMtKdQDxNNthLQETkc/yaX7M4qK0g=" ];
```

These **append** to nix-on-droid's own `cache.nixos.org` + `nix-on-droid.cachix.org` rather than
replacing them. The entry is currently inert: at the `nixos-25.11` pin this cache cannot match those
paths anyway (its builds are keyed to llm-agents' own nixpkgs — precisely why that package set was
dropped), so it costs one extra 404 per substitution query. It is kept so the entry is correct and
signed if the pin ever lifts. `inputs.llm-agents.overlays.shared-nixpkgs` is still applied to the
phone's `pkgs` for the same reason: carried, resolvable, consumed by nothing.

### Android integration shims

`xdg-open`, `termux-wake-lock` and `termux-wake-unlock` are **on**, switched and running on the
device as of 2026-08-20. It took two separate fixes to get there, and applying only one of them
looks exactly like having applied neither.

Every option in the `android-integration` module depends on `termux-am`, which is one of
nix-on-droid's own packages — built from source with cmake, not a nixpkgs package. Upstream
publishes it prebuilt on `nix-on-droid.cachix.org`, but only against *upstream's* pinned nixpkgs, so
at the `nixos-25.11` pin the derivation hash does not match and the phone has to compile it. That
compile is a `fetchFromGitHub` directory source, so it died on exactly the proot `_defaultUnpack`
failure described in [backports](backports/). `prootUnpack` fixes the build.

Fixing the build is not enough. Upstream's module runs `pkgs.callPackage` on the
`termux-am` / `termux-tools` derivation files directly, which never consults the overlay, so the
patched packages get built and then ignored. The configuration replaces the module instead:

```nix
disabledModules = [ "${nix-on-droid}/modules/environment/android-integration.nix" ];
imports = [ ./android-integration.nix ];
```

`droid/android-integration.nix` is a copy of upstream's module with identical options and identical
implementation, differing only in that it reads the overlay's `pkgs.termux-am` and
`pkgs.termux-tools`. Those two are put into `pkgs` by
[`droid/backports.nix`](backports/#what-the-overlay-provides), which is why that overlay takes the
`nix-on-droid` flake as an argument. Because `termux-tools` is one derivation rather than eight,
a single `prootUnpack` override on it covers every shim it produces.

> [!NOTE] This is a fork of an upstream module
> `droid/android-integration.nix` has to be re-synced by hand whenever nix-on-droid changes the
> module's options. The cheaper alternative was a five-line `writeShellScriptBin "xdg-open"` calling
> `termux-am`, which gets the OAuth flow and nothing else. The full module won on the wake-lock pair.

| Shim | State | Reason |
| :--- | :--- | :--- |
| `xdg-open` | on | `claude` shells out to it for the OAuth browser flow. |
| `termux-wake-lock` | on | Android sleeps the device mid-agent-session otherwise. |
| `termux-wake-unlock` | on | Releases the lock again. |
| `am`, `termux-open`, `termux-open-url`, `termux-setup-storage`, `termux-reload-settings`, `unsupported` | off | Built, but not put on `PATH`. Nothing on the phone needs them. |

"Off" here means *not in `environment.packages`*, not *not built*. `termux-tools` is a single
derivation with eight outputs (`out`, `setup_storage`, `open`, `open_url`, `reload_settings`,
`wake_lock`, `wake_unlock`, `xdg_open`), and the module's `.enable` flags only pick which of those
outputs get installed. Enabling `xdg-open` compiles every shim in the list; turning the other five
on later costs a symlink, not a build. `xdg_open` is in fact a symlink to `$open/bin/termux-open`,
so the `termux-open` output is already in the closure whether or not its option is set.

> [!NOTE] This does not contradict the Termux:API boundary
> These shims broadcast Android intents at Nix-on-Droid's *own* package, so they work with the
> Termux app uninstalled. Termux:API is a separate permission surface that allowlists `com.termux`
> and nothing else, which is why the [phone-agent](phone-agent/) MCP server still has to live over
> there. Opening a URL is not reading a sensor.

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
[backports](backports/): `rtk`, `mcp-gateway`.

Explicitly excluded, each for a stated reason:

| Excluded | Reason |
| :--- | :--- |
| `github-copilot-cli` | No aarch64 build (evaluation error at this rev). |
| `antigravity` | Evaluates on aarch64, but it is a desktop Electron IDE and there is no display server — ~3.2 GB of GTK/X11 closure for a binary that cannot launch. |
| `memd`, `tether`, `agent-scaffold` | `home/scripts.nix` links these out of `/persist`, which does not exist on Android. They need a phone-local checkout first. |
| The whole `pkgs.llm-agents.*` set | At the 25.11 pin the cache hashes do not match, so Nix tries to build them natively under proot — which fails (see [backports](backports/)). |
| `context7-mcp`, `mcp-server-fetch`, `mcp-server-sequential-thinking`, `llmfit` | Unstable-only; same proot build failure. |

## Closure budget

Package choice in [`home/common/packages.nix`](../../reference/home-manager/#common-portable-layer-homecommon)
is constrained by what has an aarch64 substitute and by unpacked closure size. Storage is not the
binding constraint on a 512 GB phone; build time and RAM are. That is why the target is **zero
source builds**, and why `make droid-plan` is the check to run after touching the shared package
list. Anything in its "will be built" list that is not fish completions or `hm_*` glue means the
phone compiles it.

Four packages are held back from the shared layer for that reason, each with a stated cost:

| Kept desktop-only | Cost on the phone |
| :--- | :--- |
| `nodejs` | No aarch64 substitute at the current rev — the phone would compile it. |
| `go` | ~300 MB for a toolchain a phone rarely needs. |
| `pandoc` | Haskell toolchain, for micro's `preview` plugin backend. |
| `ripgrep-all` | Drags in ffmpeg, poppler and tesseract. |

The two backported Rust packages are the deliberate exception: `rtk` and `mcp-gateway` do compile
on-device, natively, in a few minutes each. See [backports](backports/).

> [!NOTE] The measured figures need re-taking
> `droid/README.md` carries a download/unpacked table measured 2026-08-02. Every row predates the
> tree it describes: `droid/agents.nix` dropped the `llm-agents` set and gained the two backports on
> 2026-08-03, and `home/common/` changed again on 2026-08-14. A laptop-side `make droid-plan` is not
> a substitute either, since it reports against volnix's substituters rather than the phone's. The
> number that counts comes from `make droid-plan` run on the device.

## Building and switching

```bash
# On the LAPTOP — evaluate only
make droid-check     # nix eval  ...home.activationPackage.drvPath
make droid-plan      # nix build --dry-run: what would be fetched vs compiled

# On the PHONE, inside Nix-on-Droid
make droid-switch    # nix-on-droid switch --flake .
```

> [!NOTE] The laptop cannot build the phone
> volnix has no `aarch64` emulation configured, so `droid-check` and `droid-plan` evaluate and
> dry-run only. `droid-check` is further limited to the **Home Manager layer**: the system layer's
> uid/gid probe is an import-from-derivation that can only run on the device. Actual builds and
> activation happen on the phone.

Both targets pass `--impure`, and so does `nix-on-droid` itself. That is upstream's constraint, not
a local shortcut: nix-on-droid references the bootstrap `proot-termux` binary with
`builtins.storePath`, which pure evaluation rejects. `nix-on-droid.sh` passes `--impure` for the
same reason.

### First switch on a fresh device

A clean install can also be switched straight from the remote, without cloning:

```bash
nix-on-droid switch --flake github:lowcache/volnixos
```

[`droid/nix.conf`](https://github.com/lowcache/volnixos/blob/main/droid/nix.conf) exists to be
installed to `~/.config/nix/nix.conf` *before* that first switch. It adds `cache.numtide.com` as a
trusted substituter, which `droid/default.nix` also declares — but `nix.substituters` is only
written to `/etc/nix/nix.conf` during activation, and the first switch has to build the generation
before it can activate it. The bootstrap file closes that window. It is not managed by
nix-on-droid, so it survives every activation.

> [!NOTE] That bootstrap is currently vestigial
> It mattered when `droid/agents.nix` installed the `pkgs.llm-agents.*` set: without the key,
> Nix reported `ignoring substitute ... because it's not signed by any of the keys`, fell back to
> building from source, and died minutes later unpacking `sqlalchemy-bigquery` under proot. The
> agent layer no longer installs any of those packages, so there is nothing left for that cache to
> serve — the same reason the [substituter entry](#substituter) is inert. The file is kept correct
> against the pin ever lifting.

## Debugging the phone from the laptop

The app's terminal is the only way in, but it does not have to be driven by hand. `adb shell input
text` types into the focused field, and two file channels move data in both directions:

```bash
adb push probe.sh /data/local/tmp/   # laptop → phone: world-readable, the app can read it
# in the app:
bash /android/data/local/tmp/probe.sh > /android/sdcard/out.txt 2>&1
adb shell cat /sdcard/out.txt        # phone → laptop: /sdcard is app-writable
```

`/android` is the host Android root; nix-on-droid binds it with `-b /:/android`.

Classifying an apparent hang is the case this was built for. `/proc/<pid>/stat` is readable for the
app's own processes: field 3 is the process state, and comparing field 5 (`pgrp`) against field 8
(`tpgid`) tells you whether a stopped process is merely sitting in a background process group.

> [!WARNING] `timeout` manufactures the false positive you are testing for
> Wrapping a probe in `timeout` puts it in a new process group, which makes `pgrp` and `tpgid`
> disagree — exactly the signature you were looking for. Use `timeout --foreground`.
