---
title: "Repo Layout & Modules"
description: "How this flake is laid out: the split between nixos/, home/ and modules/, and the conventions that keep a multi-host configuration navigable."
weight: 5
---

The NixOS side of the repo used to be one 569-line `configuration.nix`. It is now split into a
**module layer** (how a feature works) and a **host layer** (what this machine is). Home Manager was
already organized this way — concern-scoped files plus the shared `home/common/` layer — so only the
NixOS side needed the treatment.

## Layout

```text
nixos/
├── default.nix              top aggregator: imports modules/ + hosts/volnix.nix
├── hosts/
│   └── volnix.nix           the instance: hostname, feature switches, machine values;
│                            also imports ../vms.nix, ../windows-vm.nix, ../phone-agent
├── modules/
│   ├── default.nix          module-layer aggregator: imports every file below
│   ├── anonymous-mode/      option-typed: uid-routed Tor egress + the anonymity guests
│   │   ├── default.nix      enforcement: policy routing, readiness ladder, anonymous.target
│   │   ├── options.nix      the vol.anon-mode.* declarations
│   │   ├── scripts.nix      shell tooling (anon-shell, anon-exec, anon-selftest, routing up/down, probes)
│   │   ├── guests.nix       net-gate + anon-box MicroVMs and their host plumbing
│   │   └── anon-vsock.py    vsock client for anon-shell
│   ├── ai-stack.nix         option-typed: Ollama + Open WebUI
│   ├── audio.nix            option-typed: PipeWire/WirePlumber, ALSA card parking
│   ├── backup.nix           option-typed: plug-triggered restic backup to an external drive
│   ├── boot.nix             Lanzaboote / initrd
│   ├── containers.nix       docker, fooocus OCI, waydroid
│   ├── desktop.nix          greetd/tuigreet, xdg portals
│   ├── networking.nix       NetworkManager, wifi, tether metrics
│   ├── nix-settings.nix     Lix daemon, substituters, nh clean (GC), nixpkgs config ([Binary Cache & CI](../tooling/ci-cache/))
│   ├── packages.nix         systemPackages lists
│   ├── persist-luks.nix     option-typed: LUKS2 /persist + USB-stick/key-chord unlock
│   ├── chordgate/           C source for the initrd key-chord reader (+ its test)
│   ├── programs.nix         git safe.directory, nix-ld, niri, appimage, fish
│   ├── secrets.nix          the sops-nix block (see [Secrets](secrets/))
│   ├── services.nix         small service toggles (upower, asusd, flatpak, …)
│   ├── systemd.nix          manager tuning, tmpfiles scaffolding, build temp
│   └── users.nix            human accounts
├── hardware/asus-ryzen-nvidia/   gpu.nix, kernel.nix, keyboard-rgb.nix
├── hardware-configuration.nix   filesystems, zram/swapfile, system-level persistence
├── .sops.yaml                   sops creation rules (see [Secrets](secrets/))
├── host-secrets.yaml            sops-encrypted host secrets
├── vm-secrets.yaml              sops-encrypted MicroVM secrets
├── vms.nix                  MicroVM host + the tailscale guest ([Networking](../networking/))
├── vm-guest-base.nix        settings shared by every MicroVM guest
├── tests/
│   └── anon-jail.nix        NixOS VM test behind checks.anon-jail
├── windows-vm.nix
└── phone-agent/             already option-typed ([Phone](../phone/phone-agent/))
```

`flake.nix` imports `./nixos`, whose `default.nix` pulls in the module layer and the host file.
Aggregation is split across two places: `nixos/default.nix` imports `./modules` and
`./hosts/volnix.nix`, and `nixos/hosts/volnix.nix` itself imports `../modules`, `../vms.nix`,
`../windows-vm.nix` and `../phone-agent`. Everything under `hosts/` sets options declared under
`modules/`. Adding a second host later means adding `hosts/<name>.nix` — the module layer does not
change.

## Why some features got real options

Most modules are plain `config = { ... }` bodies in cohesive files — over-optionizing constants is
its own anti-pattern. Options exist only where coupling was previously *invisible*:

| Option set | Couples |
| :--------- | :------ |
| `vol.anon-mode.enable` (among others: `uid`, `routingTable`, `rulePriority`, `torVmAddress`, `transPort`, `sealOnHealthLoss`, `workstation.*`) | The `ip rule uidrange` selector, policy-routing unit, Tor readiness gate, `anonymous.target`, the isolation user, and both anonymity guests (`net-gate`, `anon-box`). They were several distant sections before the split and are now one module directory that arms or disarms as a unit; with `enable` off, the guests are not defined at all. |
| `vol.ai-stack.ollama.exposeToTailscaleVm` (+ `tailnetClients`) | The `0.0.0.0` bind on Ollama AND the firewall exception on the tailscale tap, scoped to the listed tailnet addresses. Flipping one switch moves both together, so they cannot drift apart. |
| `vol.tailscale-vm.*` (`tapInterface`, `subnet`, `hostAddress`, `guestAddress`) | The tailscale guest's addressing, read by `vms.nix`, the Ollama firewall rule and `phone-agent.pushBindAddr`. |
| `vol.persistLuks.*` (`enable`, `uuid`, `stickGate.*`) | The initrd `cryptsetup` unit for `/persist`, and the USB-stick + key-chord unlock in front of it. See [Impermanence](impermanence/). |
| `vol.audio.enable` (+ `pulseTools`, `parkedCards`) | PipeWire, WirePlumber and the pulse shim, plus the per-card `off` profile rules. Which ALSA cards to park is a machine fact, so it lives in `hosts/volnix.nix` while the mechanism stays in the module. See [Audio](../system/audio/). |
| `vol.backup.enable` (among others: `repoFsUuid`, `usbQuirks`, `passwordFile`, `paths`, `exclude`, `pruneOpts`) | The udev rule keyed on the repo filesystem UUID, the mount units, the restic service and its mountpoint assertions — plugging the drive in is the whole trigger. See [Backup](../system/backup/). |

The option lists above are representative, not exhaustive; the declarations are the reference.

## Verification discipline

Refactors like this are proven behavior-neutral by derivation identity, not by eyeballing: the
rebuilt `system.build.toplevel` must produce the same store path as the running system. The module
split landed with `nix flake check` green and the toplevel store path unchanged — see
[Flake Inputs & Outputs](../reference/flake/) for the gates (`nixfmt`, `statix`, `deadnix`) that run
on every evaluation.
