---
title: "Repo Layout & Modules"
description: "How this flake is laid out: the split between nixos/, home/ and modules/, and the conventions that keep a multi-host configuration navigable."
weight: 5
---

The NixOS side of the repo used to be one 576-line `configuration.nix`. It is now split into a
**module layer** (how a feature works) and a **host layer** (what this machine is). Home Manager was
already organized this way — concern-scoped files plus the shared `home/common/` layer — so only the
NixOS side needed the treatment.

## Layout

```text
nixos/
├── default.nix              aggregator: imports modules/ + hosts/volnix.nix
├── hosts/
│   └── volnix.nix           the instance: hostname, feature switches, machine values
├── modules/
│   ├── anonymous-mode.nix   option-typed: UID-marked Tor egress
│   ├── ai-stack.nix         option-typed: Ollama + Open WebUI
│   ├── boot.nix             Lanzaboote / initrd
│   ├── containers.nix       docker, fooocus OCI, waydroid
│   ├── desktop.nix          greetd/tuigreet, xdg portals
│   ├── networking.nix       NetworkManager, wifi, tether metrics
│   ├── nix-settings.nix     Lix daemon, substituters, GC, nixpkgs config ([Binary Cache & CI](../tooling/ci-cache/))
│   ├── packages.nix         systemPackages lists
│   ├── programs.nix         git safe.directory, nix-ld, niri, appimage, fish
│   ├── secrets.nix          the sops-nix block (see [Secrets](secrets/))
│   ├── services.nix         small service toggles (upower, asusd, flatpak, …)
│   ├── systemd.nix          manager tuning, tmpfiles scaffolding, build temp
│   └── users.nix            human accounts
├── hardware/asus-ryzen-nvidia/
├── vms.nix                  MicroVM guests ([Networking](../networking/))
├── windows-vm.nix
└── phone-agent/             already option-typed ([Phone](../phone/phone-agent/))
```

`flake.nix` imports `./nixos`; everything under `hosts/` sets options declared under `modules/`.
Adding a second host later means adding `hosts/<name>.nix` — the module layer does not change.

## Why two features got real options

Most modules are plain `config = { ... }` bodies in cohesive files — over-optionizing constants is
its own anti-pattern. Options exist only where coupling was previously *invisible*:

| Option set | Couples |
| :--------- | :------ |
| `vol.anon-mode.enable` (+ `uid`, `fwmark`, `routingTable`, `torVmAddress`) | The iptables owner-mangle rule, policy-routing unit, Tor SOCKS readiness gate, `anonymous.target`, and the isolation user — four distant sections before the split, now one file that arms or disarms as a unit. |
| `vol.ai-stack.ollama.exposeToTailscaleVm` | The `0.0.0.0` bind on Ollama AND the interface-scoped firewall exception on `vm-tailscale`. Flipping one switch moves both together, so they cannot drift apart. |

## Verification discipline

Refactors like this are proven behavior-neutral by derivation identity, not by eyeballing: the
rebuilt `system.build.toplevel` must produce the same store path as the running system. The module
split landed with `nix flake check` green and the toplevel store path unchanged — see
[Flake Inputs & Outputs](../reference/flake/) for the gates (`nixfmt`, `statix`, `deadnix`) that run
on every evaluation.
