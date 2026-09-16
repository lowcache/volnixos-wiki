---
title: "Flake Inputs & Outputs"
description: "Every flake input this configuration pulls and every output it exposes: hosts, home configurations, overlays, and the packages built from them."
weight: 10
---

[`flake.nix`](https://github.com/lowcache/volnixos/blob/main/flake.nix) tracks `nixpkgs` on
`nixos-unstable` and composes the system from the inputs below. Most `*.nix` modules pin
`inputs.nixpkgs.follows = "nixpkgs"` to keep a single nixpkgs in the closure.

## Inputs

| Input                | Source                                   | Role                                   |
| :------------------- | :--------------------------------------- | :------------------------------------- |
| `nixpkgs`            | `nixos/nixpkgs/nixos-unstable`           | Package set                            |
| `home-manager`       | `nix-community/home-manager`             | User environment                       |
| `nixos-hardware`     | `NixOS/nixos-hardware`                    | Hardware profiles                      |
| `nix-cachyos-kernel` | `xddxdd/nix-cachyos-kernel`              | CachyOS kernel overlay (`pinned`)      |
| `impermanence`       | `nix-community/impermanence`             | Ephemeral root / `/persist`            |
| `lanzaboote`         | `nix-community/lanzaboote`               | UEFI Secure Boot                       |
| `microvm`            | `astro/microvm.nix`                       | Isolated VM guests                     |
| `noctalia`           | `github:noctalia-dev/noctalia`           | Noctalia v5 desktop shell              |
| `sops-nix`           | `Mic92/sops-nix`                          | Encrypted secrets                      |
| `volinit`            | `lowcache/volinit`                        | Shell welcome banner                   |
| `nur`                | `nix-community/NUR`                       | Community overlay                      |
| `llm-agents`         | `numtide/llm-agents.nix`                  | AI agent tooling overlay               |
| `memd`               | `lowcache/memd`                           | Project-memory daemon (HM module)      |
| `nixpkgs-droid`      | `nixos/nixpkgs/nixos-25.11`               | Phone package set (glibc 2.40 pin)     |
| `home-manager-droid` | `nix-community/home-manager/release-25.11`| Phone user environment                 |
| `nix-on-droid`       | `nix-community/nix-on-droid`              | Android (aarch64) target               |

These three are deliberately NOT on the main `nixpkgs`; see [Nix-on-Droid](../phone/nix-on-droid/) for the reason.

## Overlays

There is no top-level `nixpkgs.overlays`. The host list lives in an inline module inside
`nixosConfigurations.volnix.modules`, so it applies to volnix and nothing else:

```nix
nixpkgs.overlays = [
  inputs.nix-cachyos-kernel.overlays.pinned
  inputs.nur.overlays.default
  inputs.llm-agents.overlays.shared-nixpkgs
  (import ./nixos/overlays/brave.nix)
  (import ./nixos/overlays/pandas-stubs.nix)
];
```

A third overlay file, `nixos/overlays/ollama.nix`, pinned `ollama-cuda` and was deleted once CI
stayed green without it; a tombstone comment marks where it sat.

The phone target does not share this list. `nixOnDroidConfigurations.default` imports its own `pkgs`
from `nixpkgs-droid` with a separate set — `inputs.nix-on-droid.overlays.default`,
`inputs.llm-agents.overlays.shared-nixpkgs`, and `(import ./droid/backports.nix …)`. Only the
`llm-agents` overlay is common to both targets.

## Outputs

```mermaid
graph TD
    F["flake.nix"] --> V["nixosConfigurations.volnix"]
    F --> D["nixOnDroidConfigurations.default"]
    F --> NG["packages.x86_64-linux.net-gate"]
    F --> TS["packages.x86_64-linux.tailscale-vm"]
    F --> FM["formatter.x86_64-linux"]
    F --> CK["checks.x86_64-linux.*"]
    F --> T["templates.*"]
    V --> HM["home-manager.users.lowcache → ./home"]
```

| Output                                  | Description                                   |
| :-------------------------------------- | :-------------------------------------------- |
| `nixosConfigurations.volnix`            | The host (`x86_64-linux`)                     |
| `packages.x86_64-linux.net-gate`        | Tor MicroVM runner (`nix run .#net-gate`)     |
| `packages.x86_64-linux.tailscale-vm`    | Tailscale MicroVM runner                      |
| `formatter.x86_64-linux`                | `nixfmt-tree` wrapper (`nix fmt`)             |
| `checks.x86_64-linux.formatting`        | `nixfmt --check` gate for flake source        |
| `checks.x86_64-linux.lint`              | `statix` & `deadnix` gate for flake source    |
| `nixOnDroidConfigurations.default`      | Nix-on-Droid phone target (`aarch64-linux`), built on-device |
| `templates.*`                           | Project scaffolds for `nix flake init -t`     |

The host wires Home Manager as a NixOS module with `useGlobalPkgs` and `useUserPackages`, passing
`inputs` through `extraSpecialArgs`.

### Templates

`templates` is not per-system — a template is a directory of files to copy. Six are defined, each
with a `path` and a `description`: `go`, `hugo`, `lua`, `luau`, `python`, and `ruby`. There is
deliberately no `templates.default`, so the language has to be named:

```bash
nix flake init -t ~/.nix-config#ruby
```

See [Project Templates](../templates/) for what each one scaffolds.

## Maintenance

```bash
make check            # nix flake check, then tree-wide deadnix + statix
make fmt              # nix fmt
make update           # nix flake update (all inputs)
make update-nixpkgs   # nix flake update nixpkgs
nix flake update volinit
```
