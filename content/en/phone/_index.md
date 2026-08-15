---
layout: single
title: "Phone"
weight: 40
---

`volnix` treats a **Galaxy S26 Ultra** as a first-class part of the configuration rather than a
device that happens to be nearby. Three separate things live on that phone, and they are easy to
confuse because all three involve "Android" and "Nix". They are not the same thing and they do not
talk to each other.

| Layer | What it is | Android package | Declared in |
| :--- | :--- | :--- | :--- |
| [Nix-on-Droid](nix-on-droid/) | A real Nix store and Home Manager profile running on the phone | `com.termux.nix` | [`droid/`](https://github.com/lowcache/volnixos/blob/main/droid/) |
| [Phone Agent](phone-agent/) | An MCP server on the phone that the **laptop** calls over Tailscale | `com.termux` | [`nixos/phone-agent/`](https://github.com/lowcache/volnixos/blob/main/nixos/phone-agent/) |
| [Android VM](../system/virtualization/#android-vm-dormant) | A libvirt guest on the laptop — no physical phone involved | — | [`nixos/android-vm.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/android-vm.nix) |

> [!WARNING] Two different Termux apps
> The phone-agent MCP server runs in **Termux** (`com.termux`), *not* in Nix-on-Droid
> (`com.termux.nix`). This is forced, not stylistic: the Termux:API app authorizes only
> `com.termux`, so a sensor-reading server has to live in that package. Nix-on-Droid is a fork of
> Termux under its own package name and cannot reach Termux:API.

## Which direction does each one point?

The two live layers move in opposite directions, which is the fastest way to keep them straight.

```mermaid
graph LR
    subgraph Laptop["volnix (x86_64)"]
        HM["Home Manager<br/>home/common/"]
        PA["phone-agent module<br/>+ CLI"]
    end
    subgraph Phone["Galaxy S26 Ultra (aarch64)"]
        NOD["Nix-on-Droid<br/>com.termux.nix"]
        TX["Termux + MCP server<br/>com.termux"]
    end
    HM -->|"shared modules"| NOD
    PA -->|"HTTP/MCP over Tailscale"| TX
```

- **Nix-on-Droid** is *built and switched on the phone*. The laptop only evaluates it. Configuration
  flows laptop → phone as shared Nix modules.
- **Phone Agent** runs *on the laptop*, calling out to the phone. Data flows phone → laptop
  (sensors, ingested files).

## Shared ground

The one thing genuinely shared between laptop and phone is
[`home/common/`](https://github.com/lowcache/volnixos/blob/main/home/common/) — the portable Home
Manager layer (fish, shell tooling, base packages). `home/shell.nix` imports it on the laptop;
`droid/home.nix` imports it on the phone. Everything desktop-shaped is deliberately kept out of it.

## Start here

[Nix-on-Droid: the phone as a Nix host](nix-on-droid/)
[Phone Agent: the laptop's remote sensors](phone-agent/)
