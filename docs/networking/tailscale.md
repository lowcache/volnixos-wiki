# Tailscale VM

`tailscale` is an autostarting MicroVM that runs `tailscaled` with routing features enabled,
keeping the mesh-VPN daemon and its state isolated from the host. The host is **not** a tailnet node
itself — it reaches the tailnet by routing through this guest.

## Topology

- Host tap `vm-tailscale` → `192.168.101.1/24`; guest → `192.168.101.2/24`.
- Resources: `cloud-hypervisor`, 256 MB RAM, 1 vCPU, vsock CID `11`.
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

## Publishing Ollama to the tailnet

The guest SNATs host-originated traffic (`192.168.101.0/24`) onto its own tailnet IP so peers route
replies back to the VM, and DNATs one port inbound:

```nix
networking.nat.forwardPorts = [
  { proto = "tcp"; sourcePort = 11434; destination = "192.168.101.1:11434"; }
];
```

Inbound `tailscale0:11434` therefore reaches the **host's** [Ollama](../system/ai-stack.md). The
return path reuses the host's existing `100.64.0.0/10` route through this guest, so conntrack
un-DNATs the replies. This is what lets the [phone agent](../phone/phone-agent.md) reach laptop
inference from the tailnet.

## Operating it

```bash
sudo systemctl start   microvm@tailscale
sudo systemctl restart microvm@tailscale
sudo systemctl stop    microvm@tailscale
```

!!! warning "Do not use `make run-tailscale` while the unit is active"
    `make run-tailscale` (`nix run .#tailscale-vm`) launches a second runner that fights the
    systemd-managed instance over the same tap device and control socket. Since the guest
    autostarts, the Makefile target is for debugging a stopped VM only — stop the unit first.
