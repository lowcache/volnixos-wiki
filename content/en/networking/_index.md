---
layout: single
title: "Networking & MicroVMs"
description: "Networking on NixOS through MicroVM guests: a Tailscale VM, a Tor net-gate, and the systemd-networkd TAP wiring that keeps them isolated."
weight: 20
---

Three isolated guests are declared in
[`nixos/vms.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/vms.nix) using
[`microvm.nix`](https://github.com/astro/microvm.nix) with the `cloud-hypervisor` backend:
`net-gate`, `tailscale`, and `anon-box`. `net-gate` and `tailscale` each get a static-IP tap facing
the host; `anon-box` sits behind `net-gate` on an unaddressed bridge instead (see below). The host
side is driven by `systemd-networkd`, and NetworkManager is told to leave the taps alone.

```mermaid
graph LR
    subgraph Host["volnix host · systemd-networkd"]
        H1["vm-netgate<br/>192.168.100.1/24"]
        H2["vm-tailscale<br/>192.168.101.1/24"]
        BR["br-anon bridge<br/>no host address"]
    end
    subgraph NG["net-gate · autostart"]
        T["Tor transparent proxy<br/>TransPort 9040 · SOCKS 9050 · DNSPort 5353"]
    end
    subgraph TSVM["tailscale · autostart"]
        TS["tailscaled<br/>IP forwarding"]
    end
    subgraph AB["anon-box · manual"]
        WS["workstation<br/>192.168.102.2/24"]
    end
    H1 <-->|"guest .100.2"| NG
    H2 <-->|"guest .101.2"| TSVM
    NG <-->|"vm-ngi .102.1"| BR
    BR <-->|"vm-anonbox"| AB
```

## Guests

| Guest       | Hypervisor       | Resources       | Host ↔ Guest                      | Autostart | Page                        |
| :---------- | :--------------- | :-------------- | :-------------------------------- | :-------- | :-------------------------- |
| `net-gate`  | cloud-hypervisor | 512 MB / 1 vCPU | `192.168.100.1` ↔ `192.168.100.2` | yes       | [Tor net-gate](net-gate/) |
| `tailscale` | cloud-hypervisor | 256 MB / 1 vCPU | `192.168.101.1` ↔ `192.168.101.2` | yes       | [Tailscale VM](tailscale/)|
| `anon-box`  | cloud-hypervisor | 2048 MB / 2 vCPU | vsock CID 12 only — host holds no address on `br-anon`; guest is `192.168.102.2` | no | [anon-box](anon-box/) |

## Host-side isolation

```nix
# NetworkManager must not touch the VM taps
networking.networkmanager.unmanaged = [
  "interface-name:vm-netgate"
  "interface-name:vm-tailscale"
];
```

> [!NOTE] `vm-ngi` and `vm-anonbox` are not in this list
> Both are handled by systemd-networkd networks `21-netgate-inner` and `22-anonbox-tap` instead,
> which enslave them to the unaddressed `br-anon` bridge rather than giving them a host-side IP.
> There's nothing for NetworkManager to interfere with there, so the omission is deliberate, not a
> gap to close.

The host `systemd-networkd` networks (`10-microvm-tap`, `11-tailscale-tap`) assign the gateway
addresses, enable `IPv4Forwarding`, and set `RequiredForOnline = "no"` so the taps never become the
host's default route. Static IPs are deliberate: DHCP would shift addresses on VM restart and break
the forwarding configuration. The two aren't symmetric otherwise: `10-microvm-tap` sets no
`IPMasquerade`, since a blanket masquerade there couldn't distinguish Tor's own egress from a
workload packet the guest failed to redirect — that narrower case is handled by `networking.nat`
instead — while `11-tailscale-tap` sets `IPMasquerade = "both"` so the guest's traffic reaches the
Tailscale coordination server.

## Runners

The guests are also exposed as flake packages:

```bash
make run-netgate     # nix run .#net-gate
make run-tailscale   # nix run .#tailscale-vm
```

> [!IMPORTANT] Fast shutdown
> Host-side overrides set `TimeoutStopSec` on the `microvm@*` and `microvm-virtiofsd@*` units
> (and force `Type = simple` on virtiofsd) so the guests tear down quickly at poweroff.

> [!NOTE] Windows 11 VM (not a MicroVM)
> A separate QEMU/KVM Windows 11 guest is declared in `nixos/windows-vm.nix` (imported by
> `nixos/hosts/volnix.nix:12`): libvirtd + virt-manager, SPICE USB redirection, and an emulated TPM 2.0.
> It is managed through virt-manager, independent of the `microvm.nix` stack. See
> [Virtualization](../system/virtualization/).
