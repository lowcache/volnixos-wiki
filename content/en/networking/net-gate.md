---
title: "Tor net-gate"
description: "A Tor gateway as a NixOS module: routing selected traffic through a net-gate VM, the firewall rules involved, and how it stays isolated from the host."
weight: 10
---

`net-gate` is an autostarting MicroVM that runs a **Tor transparent proxy**, isolating
anonymity-routed traffic in its own kernel and network namespace. It is declared, with its host
plumbing, in
[`nixos/modules/anonymous-mode/guests.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/modules/anonymous-mode/guests.nix),
and exists only when `vol.anon-mode.enable` is set.

## Topology

The guest is **two-legged**. The outer leg faces the host; the inner leg faces the
[anon-box](anon-box/) workstation across a bridge the host holds no address on.

| Leg | Tap | MAC | Guest address | Serves |
| :--- | :--- | :--- | :--- | :--- |
| Outer | `vm-netgate` | `02:00:00:00:00:01` | `192.168.100.2/24` | The host's uid jail (`192.168.100.1`) |
| Inner | `vm-ngi` | `02:00:00:00:00:03` | `192.168.102.1/24` | anon-box (`192.168.102.2`) |

Both networkd units inside the guest match **by MAC address**, not by interface name. The outer
network used to match `Name = "en* eth*"`, which was correct with one NIC and silently wrong with
two: the glob matches both, and networkd puts the outer address on whichever appears first. The
inner leg declares no `Gateway`, so the default route stays out the host tap — the guest's own path
to its guards.

- Resources: `cloud-hypervisor`, 512 MB RAM, 1 vCPU, vsock CID `10`.
- Only the outer leg is masqueraded, and only for the guest's own address: host `networking.nat`
  sets `internalIPs = [ "192.168.100.2/32" ]`. A workload packet the guest failed to redirect
  carries the tap address instead, finds no NAT, and dies with an unroutable private source.
- `10-microvm-tap` on the host deliberately sets **no** `IPMasquerade`, because that would SNAT the
  whole subnet and cannot tell those two cases apart.

The guest mounts three `virtiofs` shares from the host:

| Host path | Guest path | Purpose |
| :--- | :--- | :--- |
| `/persist/var/lib/net-gate-ssh` | `/etc/ssh` | net-gate's **own** SSH host key (its sops identity), never the host's |
| `/persist/var/lib/net-gate-tor` | `/var/lib/tor` | Tor's `DataDirectory` — consensus and entry guards |
| `/persist/var/log/net-gate-journal` | `/var/log/journal` | Persistent guest journal |

The last two are conditional on `vol.anon-mode.persistTorState` and
`vol.anon-mode.persistGuestJournal`, both default `true`. Persisting Tor state buys entry-guard
stability (fresh guards on every boot are an anonymity loss of their own) and a fast arm, at the
cost of a guard set and timestamps on disk: evidence of when this host used Tor, though not of what
it reached. `/persist` is now LUKS2-encrypted (see
[Impermanence](../../architecture/impermanence/#persist-at-rest-luks2)), so that record is readable
only with the container unlocked; the option's own description in `options.nix` still calls
`/persist` unencrypted. Persisting the journal is the only reason
the VM is observable at all after boot — a dead `tor.service` once went unnoticed for four days.

## Tor service

```nix
services.tor = {
  enable = true;
  client = {
    enable = true;
    socksListenAddress = {
      addr = "192.168.100.2";
      port = 9050;
      IsolateDestAddr = true;
    };
  };
  settings = {
    TransPort = [
      { addr = "192.168.100.2"; port = 9040; IsolateDestAddr = true; }
      { addr = "192.168.102.1"; port = 9040; IsolateDestAddr = true; }
    ];
    DNSPort = [
      { addr = "192.168.100.2"; port = 5353; }
      { addr = "192.168.102.1"; port = 5353; }
    ];
    SafeLogging = true;
    VirtualAddrNetworkIPv4 = "10.192.0.0/10";
    AutomapHostsOnResolve = true;
    ClientUseIPv6 = false;
  };
};
```

> [!WARNING] One listener per leg — and the SOCKS listener is not hand-rolled
> The SOCKS listener comes from `client.socksListenAddress`, **not** from `settings.SOCKSPort`.
> `client.enable` emits its own `SOCKSPort` from that option, and these settings are list-typed, so
> a hand-written second entry *merges* rather than overrides. torrc then carried two listeners on
> `9050`, and Tor died at startup on the second bind — listener bind failures are fatal.
> `ExecStartPre --verify-config` does not bind, so it passed, and the only symptom was a refused
> connection that the wrappers misreported as "arm it with `anon-on`".

`TransPort` and `DNSPort` each carry **two** listeners for the same reason in reverse: a
`redirect` rewrites the destination to the primary address of the interface the packet *arrived* on.
Host-jail traffic lands on `192.168.100.2`; workstation traffic lands on `192.168.102.1`. A listener
bound only to the outer address serves the host and silently blackholes the workstation.

`VirtualAddrNetworkIPv4` is `10.192.0.0/10`, not the more common `172.16.0.0/12`. Automapped
hostnames get an address out of this range and the workload then *connects* to it, so the range must
contain no address this host answers for: `ip rule` consults the `local` table at priority 0, ahead
of the jail's rule at priority 100, and a destination that is a local address never reaches the
jail's table. The `/12` collided with this host's own WAN address and with `docker0`
(`172.17.0.1/16`), which routed those connections to the host itself while the routing table still
looked entirely correct. Any host whose LAN sits inside `172.16.0.0/12` hits the same collision.

## Transparent proxy rules

The guest firewall opens TCP `9040` (TransPort) and `9050` (SOCKS5), plus UDP `5353` (DNSPort). The
enforcement rules are an nftables table, `ip anon-gateway`, with one generated rule set per client.
The host jail and the workstation get byte-identical treatment because both come from the same
function rather than two copies that can drift:

```nft
table ip anon-gateway {
  chain prerouting {
    type nat hook prerouting priority dstnat; policy accept;
    # per client, for src = 192.168.100.1 (subnet 192.168.100.0/24)
    #             and src = 192.168.102.2 (subnet 192.168.102.0/24)
    ip saddr <src> udp dport 53 redirect to :5353
    ip saddr <src> ip daddr <subnet> return
    ip saddr <src> meta l4proto tcp redirect to :9040
  }
  chain forward {
    type filter hook forward priority filter; policy drop;
  }
}
```

Order matters: DNS first, so queries aimed at the guest itself are bent into Tor's DNSPort before
the in-subnet `return` can exempt them; then `return` for the rest of the subnet, keeping the SOCKS
interface directly usable; then every remaining TCP flow into TransPort. nftables loads the table
atomically with the rest of the ruleset, so a firewall reload never leaves a window without it.
These rules replaced the earlier iptables `extraCommands`; the semantics did not change.

> [!IMPORTANT] The guest terminates traffic, it never routes it
> `boot.kernel.sysctl` pins `net.ipv4.ip_forward = 0` (plus the `all.forwarding` pair), and the
> `forward` chain's `policy drop` backs it so the invariant does not rest on a sysctl default. `redirect`
> makes a packet local *before* the forwarding decision, so anything the rules do not rewrite — UDP
> other than `:53`, ICMP, QUIC, anything Tor cannot carry — is dropped rather than forwarded. With
> two legs this stops being belt-and-braces and becomes the mechanism that prevents the workstation
> from being routed out the WAN.

## Per-app wrappers

[`home/scripts.nix`](https://github.com/lowcache/volnixos/blob/main/home/scripts.nix) installs
wrapper scripts. The three SOCKS wrappers point at the guest's proxy (`192.168.100.2:9050`) and
check VM reachability first, distinguishing "VM unreachable" from "VM up but `tor.service` down":

| Wrapper     | Behavior                                                                    |
| :---------- | :-------------------------------------------------------------------------- |
| `tor-brave` | Brave with `--proxy-server=socks5://…` and a dedicated `Brave-Browser-Tor` profile |
| `tor-curl`  | `curl -x socks5h://$creds@…`, with throwaway per-invocation credentials     |
| `tor-check` | Queries `check.torproject.org/api/ip` through the proxy                     |
| `anon-run`  | `exec`s `sudo anon-exec` — the enforced path, not the proxy                 |

The throwaway credentials on `tor-curl` and `tor-check` are stream isolation: a random
`anon<rand><rand>:x` per invocation gives each call its own circuit.

`anon-run` sets **no proxy variables**. Enforcement is the routing jail plus the guest's redirect
rules, so the workload does not need to know Tor exists — and an application that ignores proxy
settings cannot bypass it. The SOCKS interface remains available deliberately, through `tor-curl`
and `tor-brave`.

## Anonymous mode (`vol.anon-mode`)

Whole-process transparent routing is an option-typed module,
[`nixos/modules/anonymous-mode/`](https://github.com/lowcache/volnixos/tree/main/nixos/modules/anonymous-mode)
(`default.nix` for enforcement, `options.nix`, `scripts.nix`, `guests.nix`),
enabled per host with `vol.anon-mode.enable`. Its core invariant: an anonymous workload either
traverses the net-gate VM in a verified-ready state, or it has no network connectivity at all.
Armed and disarmed with the Fish abbreviations `anon-on` / `anon-off`
(`systemctl start` / `stop anonymous.target`).

- **UID isolation** — an `anon-user` (UID `10000`). An `ip rule uidrange 10000-10000 table 100
  priority 100` selects a private routing table for that uid, in both address families. The uid is
  a *policy selector*, not evidence that traffic was anonymised.
- **The blackhole floor** — `anon-jail` installs `blackhole default` at metric `1024` in table
  `100`, hung off `lo` so it outlives the tap. Arming adds a gateway default at metric `100`; the
  floor is never removed, so it simply wins again the moment the gateway route goes away. An empty
  table would fall through to `main` — that is, straight to the clearnet.
- **`anon-routing.service`** — replaces the blackhole default with `default via 192.168.100.2 dev
  vm-netgate src 192.168.100.1`, in the uidrange table. The `src` pin is what lets the guest's nat
  rules match the host's anonymous traffic by source instead of guessing an interface name.
  On-demand only, and `partOf` both `anonymous.target` and `microvm@net-gate.service`.

> [!CAUTION] Do not `systemctl start`/`stop anon-routing.service`
> The unit is not a safe handle on the route. Both `anon-check` and `anonymous.target` `Require=`
> it, and systemd stops a unit whose `Requires=` target is explicitly stopped — so stopping
> `anon-routing` tears down the whole stack (readiness stamp removed, `anon.slice` reaped), and
> starting it again restores only the route, leaving anonymous mode silently disarmed. Use
> `anon-on` / `anon-off`, or `make anon-arm` / `make anon-disarm`.

> [!NOTE] No netfilter on the host, and a guard against the rule that used to be there
> The previous design marked this uid's packets with an iptables *mangle* `OUTPUT` rule installed
> through `networking.firewall.extraCommands`, then policy-routed on fwmark `0x1`. `firewall-reload`
> deletes such a rule and only re-adds it when `firewall-start` runs, so most `make switch` runs
> opened a window where `anon-user` egress was unmarked and left over the clearnet. `ip rule
> uidrange` needs no netfilter at all. Because a route-type mangle chain re-runs the routing
> decision when it changes the mark, a *leftover* marking rule is worse than useless — it lets table
> `100` supply the source address and then re-routes the packet onto `main` for the device.
> `anon-jail` therefore reads the nftables ruleset and hard-fails if `skuid 10000` still appears;
> an unreadable ruleset is treated as unverified, not as clean.

Host-wide, `systemd.network.config.networkConfig` sets `ManageForeignRoutes = false` and
`ManageForeignRoutingPolicyRules = false`, because networkd reaps foreign routing policy rules on
link reconfiguration — and the net-gate tap is recreated on every VM restart.

## Readiness ladder

"The VM is running" is not "traffic is Tor'd". `anon-check.service` climbs a ladder before anything
is released, and re-seals on any failure:

| Level | Assertion |
| :--- | :--- |
| L0 | `microvm@net-gate.service` is active |
| L1/L2 | Something is listening on `192.168.100.2:9050` — not separable further without a control port in the guest |
| L3 | A request *through SOCKS* completes, so circuits exist and Tor is bootstrapped |
| L4a | The launcher really drops privileges: the confined process reports uid `10000` |
| L4b | The kernel's routing decision for that uid, queried *from inside the jail*, points at `vm-netgate`. Sends no packet |
| L4c | An unbound request as the jailed uid returns `"IsTor":true` |
| L5 | The **workstation's** own egress is Tor'd, asked of anon-box over vsock |

L1/L2 waits 30 iterations of a 2-second probe; L3's deadline is
`vol.anon-mode.bootstrapTimeout`, default **180 seconds** — a cold Tor with no cached consensus
needs well over a minute, and the first arm after the `DataDirectory` was created failed at 45s
while Tor was still bootstrapping.

Passing L4 writes `vol.anon-mode.readyStamp` (`/run/anon-mode/ready`). `anon-exec` refuses to launch
a workload without it, and `anon-shell` refuses to open a workstation shell without it. L5 is a
separate rung because the workstation is a different client of the same gateway — different source
address, different leg, different nat rules — so L4 passing says nothing about whether anon-box's
traffic is Tor'd. It is asked of the guest rather than simulated from the host, for the same reason
L4b queries from inside the jail: only the machine whose traffic it is can answer.

`anon-watch` re-runs the L4 probe periodically. With `vol.anon-mode.sealOnHealthLoss` (default
`true`), two consecutive failures while armed disarm the whole target: gateway route withdrawn,
stamp dropped, `anon.slice` reaped. The workload loses the network rather than continuing on a path
that can no longer be shown to anonymise it.

`sudo anon-selftest` proves the negative paths as well as the positive ones — including four
workstation assertions:

- the host holds **no** address on `br-anon`;
- the host therefore cannot ping the workstation at `192.168.102.2`;
- the workstation's egress is verifiably Tor'd (the L5 probe);
- the workstation has **exactly one** default route, and it points at `192.168.102.1`.

## Usage

Ad-hoc: use the per-app wrappers above, or point any SOCKS5-capable client at
`192.168.100.2:9050`. Transparent: send TCP to `192.168.100.2:9040` and DNS to
`192.168.100.2:5353`. `AutomapHostsOnResolve` + `VirtualAddrNetworkIPv4` provide `.onion` name
resolution. For a full kernel boundary rather than a uid boundary, use the
[anon-box](anon-box/) workstation.

> [!NOTE] Guest secrets
> The commented `wg-quick` scaffold and its `wg_private_key` placeholder are gone. The guest's sops
> wiring is kept: its own key, the sops module, and `nixos/vm-secrets.yaml`, which holds only a
> `placeholder`. That way a guest secret can be added later without re-deriving the trust boundary.
> See [Secrets](../../architecture/secrets/).

Start the runner directly with `make run-netgate` (`nix run .#net-gate`).
