---
title: "Volatile NixOS"
weight: 0
---

A declarative, performance-tuned, **ephemeral** NixOS workstation built on Nix Flakes and the
[Lix](https://lix.systems) daemon. The root filesystem is a `tmpfs` wiped on every boot; all durable
state is mapped onto `/persist` through
[`impermanence`](https://github.com/nix-community/impermanence). On top sits a CachyOS low-latency
kernel, UEFI Secure Boot via Lanzaboote, `sops-nix` encrypted secrets, isolated `microvm.nix` network
gateways, CUDA-accelerated local AI, a niri + Noctalia v5 Wayland desktop, and a
[phone tier](phone/) that puts a Nix store on the handset.

Every part in the drawing above is documented on its own sheet. Take the one you came for.

## Quick start

```bash
# Clone
git clone https://github.com/lowcache/volnixos.git ~/.nix-config
cd ~/.nix-config

# Validate, then build/switch via the canonical Makefile interface
make check          # nix flake check
make build          # build without switching
sudo make switch    # rebuild + switch the live system (HOST=volnix)
```

> [!CAUTION] A portfolio, not a distro
> The `volnix` host targets a specific machine (AMD Ryzen + hybrid AMD iGPU / NVIDIA RTX 4050,
> ASUS laptop) and is published as **proof-of-work** — meant to be read and borrowed from, not
> installed wholesale. Lift the mechanism you need; do not adopt the tree.

> [!NOTE] If you find this wiki helpful
> If this wiki, repo, or Nix configuration helped you, it would be great if you could
> buy me a `beer`, `coffee`, a `house` — you know, whatever you can spare for the help, if any, I
> might have played on your own system. [Buy Me a Coffee](https://buymeacoffee.com/lowcache).

[Architecture overview](architecture/) · [Browse the source](https://github.com/lowcache/volnixos)
