---
title: "Virtualization"
description: "MicroVM guests on NixOS: declarative hypervisor config, systemd-networkd TAP networking, and GPU passthrough for isolated workloads."
weight: 30
---

`volnix` runs guests on **two separate stacks**, chosen per workload:

| Stack | Guests | Why |
| :--- | :--- | :--- |
| `microvm.nix` + `cloud-hypervisor` | [`net-gate`](../networking/net-gate/), [`tailscale`](../networking/tailscale/), [`anon-box`](../networking/anon-box/) | Minimal Linux guests: fast boot, tiny footprint, declarative from the flake. |
| `libvirt` + QEMU/KVM | `windows-vm` | Needs UEFI (OVMF), emulated TPM 2.0, and SPICE — none of which the cloud-hypervisor path provides. |

The microVM guests are documented under [Networking](../networking/), since that is what they
are for. This page covers the libvirt side.

## Guest inventory

| Guest | Stack | Autostart | Imported? | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `net-gate` | microvm | `true` | yes | Tor proxy (opt-in) |
| `tailscale` | microvm | `true` | yes | Tailnet router / exit node |
| [`anon-box`](../networking/anon-box/) | microvm | `false` | yes | Anonymous workstation guest — 2048 MB / 2 vCPU, vsock CID `12`, `192.168.102.2` |
| `windows-vm` | libvirt | `onBoot = "ignore"` | yes | Windows 11 guest |

## Windows VM

[`nixos/windows-vm.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/windows-vm.nix) is a
self-contained QEMU/KVM + libvirt stack for a Windows 11 guest. It is kept out of `vms.nix` on
purpose: Windows 11 requires full QEMU with UEFI (OVMF, including Secure Boot variants) and an
emulated **TPM 2.0** via `swtpm`, and the cloud-hypervisor microVM path provides neither.

```nix
virtualisation.libvirtd = {
  enable = true;
  onBoot = "ignore";          # do not auto-start guests at boot
  onShutdown = "shutdown";
  qemu = {
    package = pkgs.qemu_kvm;
    runAsRoot = false;
    swtpm.enable = true;      # emulated TPM 2.0 (Win11 requirement)
  };
};
```

The module declares the **host stack only** — there is no declarative domain XML for Windows. The
guest itself is created and run through `virt-manager`. Also enabled: SPICE USB redirection (for
passing a USB device or webcam into the guest), the `libvirtd` and `kvm` groups for `lowcache`, and
the `virtio-win` driver ISO for the guest's storage/net/balloon drivers.

> [!NOTE] Backing it out is one line
> The module is deliberately standalone — `users.users.<name>.extraGroups` merges with the main
> user definition rather than conflicting with it. Removing the single `../windows-vm.nix` import
> at [`nixos/hosts/volnix.nix:12`](https://github.com/lowcache/volnixos/blob/main/nixos/hosts/volnix.nix)
> fully backs it out; nothing else in the config depends on it.

### Storage layout

The entire libvirt tree — domain definitions, nvram, swtpm state, and the heavy disk images — is
bind-mounted onto the dedicated Storage NVMe, a separate physical disk from `/nix` and `/persist`:

```nix
fileSystems."/var/lib/libvirt" = {
  device = "/home/lowcache/Storage/libvirt";
  fsType = "none";
  options = [ "bind" "x-systemd.requires-mounts-for=/home/lowcache/Storage" "nofail" ];
};
```

This keeps VM disk I/O off the system drive and survives the [tmpfs root](../architecture/impermanence/),
since Storage is itself persistent.

> [!WARNING] Why the bind goes through `/var/lib/libvirt`
> It would be simpler to point libvirt straight at the home directory. It does not work: `/home/lowcache`
> is `0700`, which blocks the `libvirt-qemu` user from reading the disk images. Binding through
> `/var/lib/libvirt` (root-owned, with libvirtd managing subdirectory permissions itself) sidesteps
> the permission problem. `nofail` means a missing Storage filesystem cannot wedge boot.

## Shared host plumbing

- **NetworkManager keeps its hands off.** `networking.networkmanager.unmanaged` blacklists the
  microVM taps (`vm-netgate`, `vm-tailscale`) so NM cannot renumber or tear down guest interfaces.
- **Fast shutdown.** `microvm@net-gate`, `microvm@tailscale`, and `microvm@anon-box` get
  `TimeoutStopSec = "10s"`; their paired `microvm-virtiofsd@*` units are forced to `Type = "simple"`
  with `TimeoutStopSec = "5s"`, so a reboot is not held up by a hung virtiofs daemon.
- **`systemd.network.wait-online` is disabled** host-wide.
- **Guest state lives on persistent storage** — `net-gate` and `tailscale` microVM state lives under
  `/persist` via virtiofs shares, and libvirt state sits on the Storage NVMe via the bind mount
  above. `anon-box` is the exception: its `/out` share points at
  `/home/lowcache/Storage/anon/out`, and its journal is deliberately `Storage = "volatile"` so
  nothing it logs outlives the guest.
