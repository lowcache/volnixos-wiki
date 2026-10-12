---
title: "Hybrid GPU"
description: "Hybrid Nvidia and AMD graphics on NixOS: PRIME offload configuration, driver selection, and getting Wayland sessions onto the right GPU."
weight: 10
---

`volnix` is an ASUS laptop with a **hybrid dual-GPU** configuration: an AMD HawkPoint2 iGPU and an
NVIDIA RTX 4050 Mobile dGPU. Both drivers are loaded, and the niri session renders on the iGPU by
default for battery efficiency.

## Driver setup

```nix
boot.kernelModules = [ "amdgpu" "nvidia" "nvidia_modeset" "nvidia_uvm" "nvidia_drm" ];
services.xserver.videoDrivers = [ "nvidia" "amdgpu" ];
```

The two lines come from separate files: `kernelModules` from
[`nixos/hardware/asus-ryzen-nvidia/kernel.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/hardware/asus-ryzen-nvidia/kernel.nix)
(line 5), `videoDrivers` from
[`nixos/hardware/asus-ryzen-nvidia/gpu.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/hardware/asus-ryzen-nvidia/gpu.nix)
(line 37).

[`home/default.nix`](https://github.com/lowcache/volnixos/blob/main/home/default.nix) sets no
NVIDIA render variables (`__NV_PRIME_RENDER_OFFLOAD`, `GBM_BACKEND`, `__GLX_VENDOR_LIBRARY_NAME`, …),
so the compositor stays on the AMD iGPU. The commented-out block that used to sit there is gone.
Per-command offload is available through the `nvrun` alias:

```fish
nvrun glxinfo        # __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia glxinfo
```

## Power management

The dGPU is kept idle and allowed to reach **RTD3 (0 W) suspend** whenever possible. The Ollama daemon
unloads models after `OLLAMA_KEEP_ALIVE=5m`, releasing CUDA handles so the card can power down (see
[AI Stack](ai-stack/)).

GPU mode switching is handled by `services.cardwired`, not `supergfxd`. The two are alternatives,
not companions: `supergfxd` unbinds the dGPU's PCI device to switch modes, while `cardwired` blocks
access with eBPF/LSM and leaves the nvidia driver loaded. It needs `bpf` in `security.lsm` (the
nixpkgs default) and Wayland, both of which hold here.

```nix
cardwired = {
  enable = true;
  settings = {
    battery_auto_switch = true;            # on battery, drop to integrated; AC restores *_mode
    external_display_auto_switch = true;   # keep dGPU-wired outputs usable in integrated mode
  };
};
```

Its state lives in `/var/lib/cardwire`, which is persisted in `hardware-configuration.nix`;
otherwise manual-mode GPU state would die with the tmpfs root.

> [!NOTE] ASUS services
> `services.asusd` is enabled for ASUS hardware control and owns `platform_profile` and CPU EPP.
> `services.supergfxd` is disabled (see above), and so is `services.power-profiles-daemon`, which
> would race `asusd` over `/sys/firmware/acpi/platform_profile`. Keyboard RGB bypasses `asusd`
> entirely; see below.

## Keyboard RGB

[`nixos/hardware/asus-ryzen-nvidia/keyboard-rgb.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/hardware/asus-ryzen-nvidia/keyboard-rgb.nix)
writes the TUF keyboard's lighting straight to the kernel's asus-wmi interface instead of going
through `asusd`. `rog-aura` 6.5.0 registers exactly one mode (Static) for the "ASUS TUF Gaming A16"
family, so `asusctl aura effect breathe` and the rest report success and change nothing. That was
checked by sweeping all twelve `asusctl` effects and watching `current_mode` stay on Static. The EC
itself does more. Writing `/sys/class/leds/asus::kbd_backlight/kbd_rgb_mode` directly gives two real
effects beyond Static, `breathe` (1) and `colour-cycle` (2). Mode 3 is accepted but renders a fixed
purple and ignores the colour, so the module does not offer it, and 4–7 are accepted and do nothing.

The write happens in an `asus-keyboard-rgb` oneshot ordered after `asusd`, because `asusd` writes
Static on startup and would otherwise land last. A second copy, `asus-keyboard-rgb-resume`, runs on
the way out of suspend, hibernate and hybrid-sleep, since resume re-initialises the LED controller.
`persistToEc` (default `true`) writes with `cmd=1`, so the EC also keeps the mode across a power
cycle. The host sets:

```nix
hardware.asus.keyboardRgb = {
  enable = true;
  mode = "breathe";   # mode 1: one colour swelling in and out
  speed = "low";
};
```

## Stability workarounds

| Symptom                                     | Mitigation                                              |
| :------------------------------------------ | :----------------------------------------------------- |
| AMD display-core glitches                   | `amdgpu.dcdebugmask=0x10` ([kernel params](../architecture/kernel/)) |
| Ryzen + hybrid-GPU C-state instability      | `processor.max_cstate=1`                                |
| Krita Qt6 canvas freeze on Wayland (Hyprland) | Unconditional native Wayland under niri resolves this — no xcb fallback needed. Krita gets `QT_QPA_PLATFORM=wayland` from the session environment (`home/default.nix`). ([Troubleshooting](../troubleshooting/)) |

## Containers & libraries

- Docker exposes the dGPU to containers via `--device nvidia.com/gpu=0` (see the Fooocus container in
  [AI Stack](ai-stack/)).
- `programs.nix-ld` ships CUDA, Vulkan, VA-API, and OpenGL libraries so unpatched binaries and
  AppImages find GPU userspace at runtime. Its NVIDIA userspace is `config.hardware.nvidia.package`,
  the driver built for the running CachyOS kernel, not stock `linuxPackages`.
- Diagnostics installed: `nvtopPackages.nvidia`, `vulkan-tools`, `libva-utils`, `clinfo`,
  `nvidia-vaapi-driver`.
