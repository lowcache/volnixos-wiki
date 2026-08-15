---
layout: single
title: "Volatile NixOS"
weight: 0
---

<div class="vol-hero">
  <img class="vol-banner" src="/assets/banner.png" alt="Volatile NixOS">
  <div class="vol-badges">
    <img src="https://img.shields.io/badge/NixOS-unstable-5277C3?style=for-the-badge&logo=nixos&logoColor=white" alt="NixOS unstable">
    <img src="https://img.shields.io/badge/Nix_daemon-Lix-3a3a3a?style=for-the-badge&logo=nixos&logoColor=88c0d0" alt="Lix">
    <img src="https://img.shields.io/badge/WM-niri-7E9CD8?style=for-the-badge&logoColor=white" alt="niri">
    <img src="https://img.shields.io/badge/Display-Wayland-FFB300?style=for-the-badge&logo=wayland&logoColor=white" alt="Wayland">
  </div>
  <p class="vol-tagline">STATELESS CONFIGURATION · TMPFS ROOT · DEV LOWCACHE</p>
</div>

A declarative, performance-tuned, **ephemeral** NixOS workstation built on Nix Flakes and the
[Lix](https://lix.systems) daemon. The root filesystem is a `tmpfs` wiped on every boot; all durable
state is mapped onto `/persist` through
[`impermanence`](https://github.com/nix-community/impermanence). On top sits a CachyOS low-latency
kernel, UEFI Secure Boot via Lanzaboote, `sops-nix` encrypted secrets, isolated `microvm.nix` network
gateways, CUDA-accelerated local AI, a niri + Noctalia v5 Wayland desktop, and a
[phone tier](phone/) that puts a Nix store on the handset.

<div class="vol-grid">
  <div class="vol-card">
    <h3>🧬 Ephemeral Root</h3>
    <p><code>tmpfs</code> root rebuilt clean each boot; durable state and live dotfiles mapped from <code>/persist</code>.</p>
    <p><a href="/architecture/impermanence/">Read more →</a></p>
  </div>
  <div class="vol-card">
    <h3>🔐 Secure Boot + Secrets</h3>
    <p>Lanzaboote UEFI Secure Boot and <code>sops-nix</code> + age encrypted secrets.</p>
    <p><a href="/architecture/secrets/">Read more →</a></p>
  </div>
  <div class="vol-card">
    <h3>🌐 MicroVM Gateways</h3>
    <p>Isolated <code>cloud-hypervisor</code> guests: a Tor transparent proxy and a Tailscale router.</p>
    <p><a href="/networking/">Read more →</a></p>
  </div>
  <div class="vol-card">
    <h3>🎨 Noctalia Desktop</h3>
    <p>niri compositor with the Noctalia v5 native Wayland shell and a JSON theme engine.</p>
    <p><a href="/desktop/">Read more →</a></p>
  </div>
  <div class="vol-card">
    <h3>🤖 Local AI Stack</h3>
    <p>CUDA Ollama + Open WebUI, GPU-passthrough Fooocus, and a custom agent toolchain.</p>
    <p><a href="/system/ai-stack/">Read more →</a></p>
  </div>
  <div class="vol-card">
    <h3>📱 Phone Tier</h3>
    <p>Nix-on-Droid on the handset and an MCP agent the laptop calls over Tailscale.</p>
    <p><a href="/phone/">Read more →</a></p>
  </div>
</div>

---

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

> [!NOTE] If you find this wiki helpful...
> If you find this wiki, repo, or nix configuration helpful it would be great if you could
> buy me a `beer`, `coffee`, a `house`, you know just what you can spare for the help, if any, I
> might have played on your own system. [Buy Me a Coffee](https://buymeacoffee.com/lowcache).

> [!NOTE] A portfolio, not a distro
> The `volnix` host targets a specific machine (AMD Ryzen + hybrid AMD iGPU / NVIDIA RTX 4050,
> ASUS laptop) and is published as **proof-of-work** — meant to be read and borrowed from, not
> installed wholesale.

[Architecture overview](architecture/) · [Browse the source](https://github.com/lowcache/volnixos)
