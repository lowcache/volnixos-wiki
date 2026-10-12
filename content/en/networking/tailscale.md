---
title: "Tailscale VM"
description: "Running Tailscale in a dedicated MicroVM on NixOS instead of on the host: declarative setup, subnet routing, and why the VM boundary is worth it."
weight: 20
---

`tailscale` is an autostarting MicroVM that runs `tailscaled` with routing features enabled,
keeping the mesh-VPN daemon and its state isolated from the host. The host is **not** a tailnet node
itself — it reaches the tailnet by routing through this guest.

## Topology

The guest is declared in
[`nixos/vms.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/vms.nix), which now holds only
the MicroVM host settings and this guest; the anonymity guests moved to
[`nixos/modules/anonymous-mode/guests.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/modules/anonymous-mode/guests.nix).
Its addresses are options under `vol.tailscale-vm`, and the defaults are what this host uses:

| Option | Default |
| :--- | :--- |
| `tapInterface` | `vm-tailscale` |
| `subnet` | `192.168.101.0/24` |
| `hostAddress` | `192.168.101.1` (the guest's gateway and DNS, and where it DNATs tailnet ports) |
| `guestAddress` | `192.168.101.2` (the host's next hop to the tailnet) |

- Resources: `cloud-hypervisor`, 256 MB RAM, 1 vCPU, vsock CID `11`. The hypervisor, networkd,
  the guest firewall and `random.trust_cpu=on` come from the shared guest base,
  [`nixos/vm-guest-base.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/vm-guest-base.nix).
  The guest no longer imports sops-nix.
- `autostart = true` — the `microvm@tailscale` systemd unit brings the guest up at boot.
- Host-side static route `100.64.0.0/10 via 192.168.101.2` sends tailnet traffic into the guest.
- Tailscale state persists on the host at `/persist/var/lib/tailscale-vm`, shared into the guest over
  `virtiofs` (`→ /var/lib/tailscale`), so node identity survives guest restarts.

## Service

```nix
services.tailscale = {
  enable = true;
  useRoutingFeatures = "both";   # accept and advertise routes
};

boot.kernel.sysctl = {
  "net.ipv4.ip_forward" = 1;
  "net.ipv6.conf.all.forwarding" = 1;
};
```

The guest firewall opens UDP `41641` for the Tailscale WireGuard transport. `useRoutingFeatures = "both"`
plus IP forwarding lets the guest act as a subnet router / exit node.

The guest also advertises itself as an exit node (`--advertise-exit-node`), which makes `tailscaled`
install the forward/accept rules that let it route the host's traffic out over `tailscale0`. Admin
approval is not required for those local rules to be installed.

## Authentication

There is no interactive first-run step. The guest auto-joins the tailnet from a pre-placed key:

| Host path | Guest path |
| :--- | :--- |
| `/persist/var/lib/tailscale-vm/authkey` | `/var/lib/tailscale/authkey` (via the virtiofs state share) |

`services.tailscale.authKeyFile` points at the guest path, so no guest console is needed for first
auth. Node identity lives in the same persisted share and survives guest restarts.

## Publishing host services to the tailnet

The guest SNATs host-originated traffic (`192.168.101.0/24`) onto its own tailnet IP so peers route
replies back to the VM, and DNATs two ports inbound. The list is generated from the services' own
port options, so changing either port moves the forward with it:

```nix
forwardPorts =
  map
    (port: {
      proto = "tcp";
      sourcePort = port;
      destination = "${cfg.hostAddress}:${toString port}";
    })
    [
      config.services.ollama.port      # 11434
      config.phone-agent.pushPort      # 8463
    ];
```

Inbound `tailscale0:11434` therefore reaches the **host's** [Ollama](../system/ai-stack/). The
return path reuses the host's existing `100.64.0.0/10` route through this guest, so conntrack
un-DNATs the replies. This is what lets the [phone agent](../phone/phone-agent/) reach laptop
inference from the tailnet. The host firewall admits `:11434` on the tap only from the addresses in
`vol.ai-stack.ollama.tailnetClients` (see [AI Stack](../system/ai-stack/)).

`:8463` has the same shape and serves the phone-agent push server, enabled by
`phone-agent.enablePush` in [`nixos/hosts/volnix.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/hosts/volnix.nix).
The phone *pulls* files from the laptop over it, so laptop → phone transfer stays phone-initiated
and needs no inbound listener on the phone. Its host-side firewall exception lives in
`nixos/phone-agent/push.nix` and follows `phone-agent.enablePush`; see
[phone agent → Push](../phone/phone-agent/#push).

## Operating it

```bash
sudo systemctl start   microvm@tailscale
sudo systemctl restart microvm@tailscale
sudo systemctl stop    microvm@tailscale
```

> [!WARNING] Do not use `make run-tailscale` while the unit is active
> `make run-tailscale` (`nix run .#tailscale-vm`) launches a second runner that fights the
> systemd-managed instance over the same tap device and control socket. Since the guest
> autostarts, the Makefile target is for debugging a stopped VM only — stop the unit first.
