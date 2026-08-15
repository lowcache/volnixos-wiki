# Virtualization

`volnix` runs guests on **two separate stacks**, chosen per workload:

| Stack | Guests | Why |
| :--- | :--- | :--- |
| `microvm.nix` + `cloud-hypervisor` | [`net-gate`](../networking/net-gate.md), [`tailscale`](../networking/tailscale.md) | Minimal Linux gateways: fast boot, tiny footprint, declarative from the flake. |
| `libvirt` + QEMU/KVM | `windows-vm`, `android-vm` *(dormant)* | Needs UEFI (OVMF), emulated TPM 2.0, and SPICE — none of which the cloud-hypervisor path provides. |

The two network gateways are documented under [Networking](../networking/index.md), since that is
what they are for. This page covers the libvirt side.

## Guest inventory

| Guest | Stack | Autostart | Imported? | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| `net-gate` | microvm | `true` | yes | Tor proxy (opt-in) |
| `tailscale` | microvm | `true` | yes | Tailnet router / exit node |
| `windows-vm` | libvirt | `onBoot = "ignore"` | yes | Windows 11 guest |
| `android-vm` | libvirt | n/a | **no** | Android 15 guest — see [below](#android-vm-dormant) |

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

!!! note "Backing it out is one line"
    The module is deliberately standalone — `users.users.<name>.extraGroups` merges with the main
    user definition rather than conflicting with it. Removing the single `./windows-vm.nix` import
    from `configuration.nix` fully backs it out; nothing else in the config depends on it.

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

This keeps VM disk I/O off the system drive and survives the [tmpfs root](../architecture/impermanence.md),
since Storage is itself persistent.

!!! warning "Why the bind goes through `/var/lib/libvirt`"
    It would be simpler to point libvirt straight at the home directory. It does not work: `/home/lowcache`
    is `0700`, which blocks the `libvirt-qemu` user from reading the disk images. Binding through
    `/var/lib/libvirt` (root-owned, with libvirtd managing subdirectory permissions itself) sidesteps
    the permission problem. `nofail` means a missing Storage filesystem cannot wedge boot.

## Android VM (dormant)

[`nixos/android-vm.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/android-vm.nix) is a
685-line libvirt module for an Android 15 (API 35) x86_64 guest with GApps, aimed at Play Integrity
and banking-app testing. It is thorough — pinned CPU flags, TPM 2.0 for the Android Keystore,
virtio-gpu with virgl 3D, a virtiofs host share, a NAT network on `192.168.102.0/24`, ADB
auto-connect, snapshot save/restore, and a suite of `android-vm-*` helper scripts (setup, start,
stop, Magisk install, boot patching, root hiding, fingerprint reset, Play Integrity check).

!!! danger "Not part of the built system"
    `configuration.nix` imports `./vms.nix`, `./windows-vm.nix`, and `./phone-agent` — **not**
    `./android-vm.nix`. None of the above is active: no domain is defined, no network is created,
    and none of the `android-vm-*` commands are on `PATH`. The file is staged work, not a feature.

A second blocker sits behind the first: the `sha256` hashes for the Android system image and the
Magisk APK are placeholder values (`sha256-AAAA…`), so the fetches would fail even once the module
is imported. Bringing it up means adding the import, filling in both real hashes, and then running
`android-vm-setup` to convert the images to qcow2 and define the domain.

!!! note "Unrelated to the phone"
    Despite the name, this guest has nothing to do with the physical phone. It shares no
    configuration with [Nix-on-Droid](../phone/nix-on-droid.md) or the
    [phone agent](../phone/phone-agent.md) — it is an emulated Android running on the laptop.

## Shared host plumbing

- **NetworkManager keeps its hands off.** `networking.networkmanager.unmanaged` blacklists the
  microVM taps (`vm-netgate`, `vm-tailscale`) and the libvirt bridges (`virbr-android`,
  `vnet-android`) so NM cannot renumber or tear down guest interfaces.
- **Fast shutdown.** `microvm@net-gate` and `microvm@tailscale` get `TimeoutStopSec = "10s"`; their
  paired `microvm-virtiofsd@*` units are forced to `Type = "simple"` with `TimeoutStopSec = "5s"`,
  so a reboot is not held up by a hung virtiofs daemon.
- **`systemd.network.wait-online` is disabled** host-wide.
- **Guest state lives on persistent storage** — microVM state under `/persist` via virtiofs shares,
  libvirt state on the Storage NVMe via the bind mount above.
