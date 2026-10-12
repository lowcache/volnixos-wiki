---
title: "Phone Agent"
description: "Running a coding agent from an Android phone against a NixOS host: the MCP bridge, session handling, and what is realistic on aarch64."
weight: 30
---

The `phone-agent` NixOS module wires `volnix` to a **Galaxy S26 Ultra** running a Termux-based MCP
server, turning the phone into a set of remote tools and sensors the laptop can call over Tailscale.
The module lives in
[`nixos/phone-agent/`](https://github.com/lowcache/volnixos/blob/main/nixos/phone-agent/) and is
imported and enabled from
[`nixos/hosts/volnix.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/hosts/volnix.nix).

It provides five capabilities plus a `phone-agent` CLI for ad-hoc tool calls:

- **MCP transport** — HTTP MCP over Tailscale, bearer-token authenticated.
- **Ingest** — periodic pull of staged files off the phone, integrity-checked.
- **Push** — one read-only directory served on the tailnet for the phone to pull from (opt-in).
- **Proximity lock** — lock the laptop when the phone leaves the desk (lock only).
- **Network routing** — derive a routing profile from the phone's current SSID (opt-in, off by default).

> [!NOTE] Scope
> This page documents the **laptop side** (the NixOS module declared in this repo). The phone-side
> MCP server was built on-device with and is out of scope here — see
> [`nixos/phone-agent/README.md`](https://github.com/lowcache/volnixos/blob/main/nixos/phone-agent/README.md)
> and the phone repo's `PHONE-ENV.md` for that half. The MCP server runs in **Termux**
> (`com.termux`), not in [Nix-on-Droid](nix-on-droid/) — see the
> [two-Termux warning](./).

## Wiring

```nix
# nixos/hosts/volnix.nix
imports = [ ../phone-agent ];

phone-agent = {
  enable = true;
  phoneTailscaleIP = "100.x.x.x";                   # from the Tailscale Android app
  tokenFile = config.sops.secrets.phone_agent_token.path;
  enablePush = true;                                # serve ~/push for the phone to pull
};
```

The bearer token is a [sops-nix](../architecture/secrets/) secret (`phone_agent_token`) materialized
at runtime; its value must match `~/.config/phone-agent/token` on the phone. `tokenFile` is typed
`str`, not `path`, on purpose — a `path` literal would copy the secret into the world-readable Nix
store. The module asserts `tokenFile` is set.

## Options

| Option | Type | Default | Purpose |
| :--- | :--- | :--- | :--- |
| `enable` | `bool` | `false` | Master switch for the subsystem. |
| `user` | `str` | the flake's `username` | The one user whose `systemd --user` manager runs the units. |
| `phoneTailscaleIP` | `str` | *(host-specific)* | Tailscale IP of the phone MCP server. |
| `port` | `port` | `8462` | Phone MCP server port. |
| `tokenFile` | `str` | *(required)* | Path to the sops bearer-token file. |
| `ingestDir` | `str` | `/home/lowcache/ingest` | Laptop dir mirroring staged phone output. |
| `ollamaHost` | `str` | `volnix` | Hostname the phone uses to reach this laptop's Ollama (documentation only). |
| `enableIngestSync` | `bool` | `true` | Periodic pull of staged files. |
| `enableIngestWatcher` | `bool` | `true` | Process staged files as they land. |
| `enableProximityLock` | `bool` | `true` | Lock on phone-away. |
| `enableNetworkRouting` | `bool` | `false` | SSID-derived routing profile. |
| `proximityIntervalSec` | `int` | `5` | IMU poll interval for proximity. |
| `allowUnlock` | `bool` | `false` | Experimental; logs intent only (see below). |
| `enablePush` | `bool` | `false` | Serve `pushDir` on the tailnet for the phone to pull. |
| `pushDir` | `str` | `/home/lowcache/push` | The one directory served. Nothing else is reachable. |
| `pushPort` | `port` | `8463` | Port on `pushBindAddr`; the module opens it on the tailscale tap, and the tailscale guest forwards it. |
| `pushBindAddr` | `str` | `config.vol.tailscale-vm.hostAddress` (`192.168.101.1`) | The MicroVM tap address — **never** `0.0.0.0`. |

## Services

The five capabilities do **not** map one-to-one onto services. What is actually declared:

| Unit | Type | Gated by | Trigger |
| :--- | :--- | :--- | :--- |
| `phone-ingest-sync` | user, oneshot | `enableIngestSync` | `phone-ingest-sync.timer` |
| `phone-ingest-sync.timer` | user, timer | `enableIngestSync` | `OnBootSec=2min`, `OnUnitActiveSec=2min` |
| `phone-ingest-watcher` | user, path | `enableIngestWatcher` | `<ingestDir>/staged/*.json` appears |
| `phone-proximity-daemon` | user, long-running | `enableProximityLock` | `wantedBy = graphical-session.target` |
| `phone-network-routing` | user, oneshot | `enableNetworkRouting` | **none — see below** |
| `phone-push-server` | user, long-running | `enablePush` | `wantedBy = default.target` |

The **MCP transport** has no service of its own and no independent toggle: it is the `phone-agent`
CLI plus the shared `nixos/phone-agent/scripts/phone-mcp-call.sh` dispatcher, governed globally by
`enable`. [`nixos/phone-agent/client.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/phone-agent/client.nix)
wraps that dispatcher once, as `phone-call`, with the phone's address and token baked in. Every unit
and the CLI call the phone through it (`client.call`), and the health checks build their URL from
`client.url`, so the address and token are declared in one place rather than copied into each unit.

Units are installed into `/etc/systemd/user`, so every user manager would start them, greetd's
`greeter` included. Each unit except `phone-network-routing` therefore carries `ConditionUser = <user>`.

Each script gets a `PATH` holding only what it calls:

| Script | `PATH` |
| :--- | :--- |
| `phone-call` (shared client) | `bash`, `curl`, `coreutils`, `jq` |
| `phone-ingest-sync` | `curl`, `coreutils`, `jq` |
| `phone-ingest-watcher` | `jq`, `coreutils` |
| `phone-proximity-daemon` | `jq`, `curl`, `coreutils`, `niri`, `util-linux` (`logger`) |
| `phone-network-routing` | `jq`, `coreutils` |
| `phone-push-server` | `python3`, `coreutils` |
| `phone-agent` CLI | `jq` |

## The `phone-agent` CLI

`phone-agent <tool> [args-json]` calls a phone MCP tool and pretty-prints the result (errors surface
as `{error: …}`); run it with no arguments for a usage menu:

```bash
phone-agent phone.system.ping
phone-agent phone.sensor.read_imu '{"sample_count":10}'
phone-agent phone.npu.transcribe '{"audio_path":"/tmp/test.wav"}'
```

Health check the transport directly with `curl -sf http://<phoneTailscaleIP>:<port>/health`. The
services do the same check with a 3-second timeout and exit silently if it fails, so an unreachable
phone is a no-op rather than an error.

> [!NOTE] Not fronted by mcp-gateway
> The laptop's phone-agent is a **standalone MCP server**, reached directly by the CLI and the
> units above. An earlier `mcp-gateway.nix` submodule shipped a gateway-backend example and an
> unconditional warning to register it; it was removed in 2026-08 because the example used a stale
> schema (`transport:` / `url:` / `namespace:` are not valid mcp-gateway 3.3.2 keys) and the
> gateway route failed its auth test. Nothing needs registering. The phone's *own* mcp-gateway is
> a separate deployment — see [backports](backports/).

## Push

`phone-push-server` is the only path by which files move **laptop → phone**, and it does not reverse
the model: it is a read-only HTTP server bound to the MicroVM tap, serving exactly one directory
(`pushDir`, default `~/push`) behind the same bearer token as the MCP transport. The laptop never
initiates — **the phone pulls**. As `nixos/hosts/volnix.nix` puts it, "the phone pulls from `~/push`,
the laptop never pushes unsolicited."

The scope is deliberately one directory. `pushBindAddr` is the tap address and **never** `0.0.0.0`.
Reaching it from the tailnet takes two pieces, and both now follow `pushPort` with nothing to edit
by hand:

1. the tailscale guest's `forwardPorts` DNAT, which `vms.nix` generates from `services.ollama.port`
   and `phone-agent.pushPort` (see [Tailscale](../networking/tailscale/));
2. a host firewall exception on the tailscale tap, which `push.nix` declares itself when
   `enablePush` is set:

```nix
networking.firewall.interfaces.${config.vol.tailscale-vm.tapInterface}.allowedTCPPorts = [
  cfg.pushPort
];
```

Before 2026-09-19 the second piece was missing. The host firewall (whose `trustedInterfaces` are only
`lo` and `waydroid0`) refused the DNAT'd connections, so push was unreachable from the tailnet even
with `enablePush = true`.

Because it listens on a network, the unit is hardened like anything else exposed: `ProtectSystem =
"strict"`, `ProtectHome = "read-only"`, `RestrictAddressFamilies = [ "AF_INET" ]`,
`MemoryDenyWriteExecute`, a `@system-service` syscall filter, and `ReadOnlyPaths = [ pushDir ]` —
it serves files, it never accepts them. It restarts `on-failure` after 10 seconds.

The server also hardens the two things `http.server` gets wrong for this use: directory listings are
refused outright, and paths are `realpath`-resolved before opening, so a symlink pointing out of the
tree is answered `404` rather than `403` — a `403` would confirm the target exists. Token comparison
uses `hmac.compare_digest`, since a plain `==` leaks the token a byte at a time.

## Ingest

`phone-ingest-sync` runs 2 minutes after boot and every 2 minutes thereafter. The phone retires a
file only after the laptop holds a verified copy:

1. For each file listed by `phone.ingest.list` (up to 50) that is not already present locally, call
   `phone.ingest.fetch` with `delete_after:false`. The phone keeps its copy in `~/ingest/staged`.
2. Base64-decode the payload to `<ingestDir>/staged/.tmp.<name>` and compare its sha256 with the
   listing. On a match, move it to `<ingestDir>/staged/<name>`.
3. Call `phone.ingest.fetch` again with `delete_after:true`. That *moves* the phone's copy to
   `~/ingest/staged-delivered`; it does not delete it.

The cost is that **every file crosses the link twice**. The phone server exposes only `list` and
`fetch`, so retiring a file means a second fetch. A phone-side acknowledgement tool would make it one
transfer; none exists.

Failures are per file. A fetch error, a hash mismatch or a failed retire is logged to stderr
(`fetch failed for <name>`, `sha mismatch for <name>`, `retire failed for <name>`), counted, and
skipped, so the rest of the batch still runs. At the end the unit exits 1 with
`N file(s) failed; will retry next run`, and shows as failed in `systemctl --user status`. Nothing
is lost: an unverified file is still in the phone's `staged` and is retried on the next run, and a
file verified on an earlier run whose retire failed is retired on the next one.

Two more cases:

- A delivered file re-staged under the same name with different content is logged as
  `name collision for <name>; left on phone`. It is not counted as a failure and the local copy is
  never overwritten.
- File names come from the phone and become paths on the laptop, so an empty name, `.`, `..`, or
  anything containing `/` is refused (`refusing unsafe name from phone`) and counted as a failure.

The phone server reports tool errors as HTTP 200 with `{"error": …}` in the result text, not as MCP
`isError`. The script therefore counts a fetch as successful only if the reply carries
`content_b64` (first fetch) or `sha256` (retire). An unreachable phone is still a silent no-op: the
health check fails and the unit exits 0.

> [!NOTE] Before 2026-09-19
> The first fetch used `delete_after:true`, so the phone gave up its copy before the laptop had
> verified anything. Files stranded that way may still be in the phone's `~/ingest/staged-delivered`;
> moving one back to `staged` gets it re-synced.

`phone-ingest-watcher` is a systemd path unit watching `<ingestDir>/staged/*.json`; new files trigger
`scripts/ingest-watcher.sh` to process them.

## Proximity lock

`phone-proximity-daemon` polls the phone's IMU every `proximityIntervalSec`, skipping the read when
the health check fails. When the inferred motion state transitions from `on_desk`/`stationary` to
`walking`/`in_pocket`, it runs `niri msg action lock-screen` and records the event to syslog under
the tag `phone-proximity`. A failed read does not overwrite the previous state, otherwise
`on_desk → unknown → walking` would never lock. The unit restarts on failure after 10 seconds.

It is wanted by `graphical-session.target`, not `default.target`: `default.target` starts before the
compositor exports `NIRI_SOCKET`/`WAYLAND_DISPLAY`, and `niri msg` cannot lock without them.

> [!WARNING] Lock only — no auto-unlock
> There is no safe programmatic unlock, so the daemon never unlocks. `allowUnlock` is experimental
> and intentionally a no-op: it only logs unlock *intent*, it does not unlock the session.

## Network routing

Off by default. When enabled, `phone-network-routing` reads the phone's current Wi-Fi SSID
(`phone.sensor.read_modem`), maps it to a profile, writes the result to
`/run/user/$UID/phone-agent/network-profile`, and attempts to start
`phone-network-profile@<profile>.service`.

The SSID mapping is hardcoded in the module:

| SSID | Profile |
| :--- | :--- |
| `HomeWiFi`, `MyHomeNetwork` | `home` |
| `CoffeeShop_WiFi`, `University_WiFi` | `untrusted` |
| anything else (including unreadable) | `secure` |

> [!WARNING] Nothing triggers this service
> `phone-network-routing` is a `oneshot` with no `wantedBy`, no timer, and no path unit. Enabling
> `enableNetworkRouting` declares the unit but nothing ever starts it — it has to be invoked by
> hand (`systemctl --user start phone-network-routing`) or wired to a trigger. The
> `phone-network-profile@<profile>.service` it tries to start is likewise not declared anywhere,
> which is why that call is suffixed `|| true`.

> [!IMPORTANT] Ceiling
> Profile derivation and the runtime file are in place; wiring the profile through to the
> [net-gate microvm](../networking/net-gate/) is not yet implemented. The source carries a
> matching `[CEILING]` marker.
