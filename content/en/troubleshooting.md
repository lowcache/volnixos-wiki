---
title: "Troubleshooting & Known Workarounds"
description: "Known failures on this NixOS host and the workarounds that fixed them: boot, GPU, impermanence, and the errors worth searching for by message."
weight: 80
---

Active mitigations baked into the configuration, and notes on hardware-specific quirks.

## Krita G'MIC plugin crash (SIGSEGV on first right-click)

Krita is repackaged in
[`home/pkgs.nix`](https://github.com/lowcache/volnixos/blob/main/home/pkgs.nix) with `symlinkJoin` +
`makeWrapper`. The wrapper sets Wayland explicitly — Krita runs native Wayland under niri, with
better stylus/tablet support; the XWayland fallback this wrapper once forced was a Hyprland-era
mitigation for a canvas-freeze bug, and no longer applies now that Hyprland is gone:

```nix
krita-wrapped = pkgs.symlinkJoin {
  name = "krita";
  paths = [ (pkgs.krita.override { krita-plugin-gmic = krita-plugin-gmic-patched; }) ];
  nativeBuildInputs = [ pkgs.makeWrapper ];
  postBuild = ''
    wrapProgram $out/bin/krita \
      --set QT_QPA_PLATFORM wayland
  '';
};
```

The wrapper's current job is bundling a null-guard-patched G'MIC: the stock plugin SIGSEGVs on the
first right-click or stylus press in the filter tree (`FiltersView::onCustomContextMenu` calls
`deleteLater()` on a context-menu pointer that is still `nullptr`, a bug present upstream through
gmic-qt master as of 2026-07). The override applies
`overrides/gmic-qt-filtersview-nullptr-contextmenu.patch` and is an active workaround, dropped once
nixpkgs ships a fixed version.

## xdg-desktop-portal access errors

Symptom (file dialogs / file-roller failing):

```
GDBus.Error:org.freedesktop.DBus.Error.AccessDenied:
Portal operation not allowed: Unable to open /proc/[pid]/root
```

*Note: This originated under Hyprland, which is no longer the primary desktop, but is preserved for historical context.*

Per the note in
[`nixos/modules/services.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/modules/services.nix),
the root cause was Hyprland's `cap_sys_nice` wrapper leaking ambient `CAP_SYS_NICE` to clients, so the
capless portal failed the kernel's `cap_ptrace_access_check` when opening `/proc/<pid>/root`. The
failure was recorded on 2026-06-10 and is moot now that Hyprland has been replaced by niri; the
session bus uses `dbus-broker`, the default under `uwsm`.

> [!TIP] Temporary fallback
> If a portal regression resurfaces, launch the affected app with capabilities stripped:
> ```bash
> setpriv --ambient-caps -all --inh-caps -all <app>
> ```

## dGPU battery drain

The NVIDIA dGPU should reach RTD3 (0 W) suspend when idle. The Ollama daemon sets
`OLLAMA_KEEP_ALIVE=5m` so it unloads models and releases CUDA handles, allowing the card to power down.
Confirm idle power with `nvtop` / `cat /sys/bus/pci/devices/<dGPU>/power_state`.

## Slow shutdown / stuck units

`systemd.settings.Manager.DefaultTimeoutStopSec = "10s"` (5s for the user manager) caps unit stop
time, and the `decapitate-fuse-mounts` oneshot force-unmounts the xdg-document-portal FUSE at shutdown
to release `/nix`. MicroVM units carry their own `TimeoutStopSec` overrides for fast teardown.

## Secure Boot won't boot

If the machine fails to boot after enabling enforcing Secure Boot, confirm the generation is signed
**before** rebooting (`sbctl verify`) and that keys are enrolled (`sbctl status`). See
[Boot & Secure Boot](../architecture/boot/).

## MicroVM guest config not taking effect

`microvm@.service` carries `X-RestartIfChanged=false`, so `make switch` stages a MicroVM guest's new
closure without restarting the guest process — the OLD guest keeps running. For net-gate, a change
to its guest config (torrc, the NAT rules, anything under `microvm.vms.net-gate.config`) has no
effect until the guest is restarted, and nothing warns you. Run `make gate-restart` after such a
change. See [Net-Gate & Anonymous Mode](../networking/net-gate/).

> [!IMPORTANT] `make switch` alone does not restart net-gate
> Verifying anonymous-mode behavior against a guest that never picked up a config change has already
> cost one debugging session. `anon-box` is the exception — unit dependencies declared in
> `anonymous-mode.nix` re-emit `restartIfChanged`, so it does restart on a plain `make switch`.
