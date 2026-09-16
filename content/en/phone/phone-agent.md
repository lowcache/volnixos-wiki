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
| `pushPort` | `port` | `8463` | Port on `pushBindAddr`; needs a matching `forwardPorts` entry in `vms.nix`. |
| `pushBindAddr` | `str` | `192.168.101.1` | The MicroVM tap address — **never** `0.0.0.0`. |

## Services

The five capabilities do **not** map one-to-one onto services. What is actually declared:

| Unit | Type | Gated by | Trigger |
| :--- | :--- | :--- | :--- |
| `phone-ingest-sync` | user, oneshot | `enableIngestSync` | `phone-ingest-sync.timer` |
| `phone-ingest-sync.timer` | user, timer | `enableIngestSync` | `OnBootSec=2min`, `OnUnitActiveSec=2min` |
| `phone-ingest-watcher` | user, path | `enableIngestWatcher` | `<ingestDir>/staged/*.json` appears |
| `phone-proximity-daemon` | user, long-running | `enableProximityLock` | starts with the session |
| `phone-network-routing` | user, oneshot | `enableNetworkRouting` | **none — see below** |
| `phone-push-server` | user, long-running | `enablePush` | `wantedBy = default.target` |

The **MCP transport** has no service of its own and no independent toggle: it is the `phone-agent`
CLI plus the shared `nixos/phone-agent/scripts/phone-mcp-call.sh` dispatcher, governed globally by
`enable`.

Each service gets a pinned `PATH` containing only what it needs. The MCP-calling units get `curl`,
`coreutils` and `bash` (plus `niri` for proximity); `phone-push-server` gets `coreutils` alone,
because it does nothing but `exec` a Python interpreter. Tools used at only one call site — `jq`,
`util-linux`'s `logger`, `python3` — are referenced by store path instead of being put on `PATH`.

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

The scope is deliberately one directory. `pushBindAddr` is the tap address and **never** `0.0.0.0`;
reaching it from the tailnet requires the matching `:8463` `forwardPorts` entry in `vms.nix`.

Because it listens on a network, the unit is hardened like anything else exposed: `ProtectSystem =
"strict"`, `ProtectHome = "read-only"`, `RestrictAddressFamilies = [ "AF_INET" ]`,
`MemoryDenyWriteExecute`, a `@system-service` syscall filter, and `ReadOnlyPaths = [ pushDir ]` —
it serves files, it never accepts them. It restarts `on-failure` after 10 seconds.

The server also hardens the two things `http.server` gets wrong for this use: directory listings are
refused outright, and paths are `realpath`-resolved before opening, so a symlink pointing out of the
tree is answered `404` rather than `403` — a `403` would confirm the target exists. Token comparison
uses `hmac.compare_digest`, since a plain `==` leaks the token a byte at a time.

## Ingest

`phone-ingest-sync` runs 2 minutes after boot and every 2 minutes thereafter. For each file listed
by `phone.ingest.list` that is not already present locally, it calls `phone.ingest.fetch`,
base64-decodes the payload to `<ingestDir>/staged/.tmp.<name>`, computes its sha256, and moves it to
`<ingestDir>/staged/<name>` only if the hash matches the listing. On mismatch it removes the
temporary file and logs `sha mismatch for <name>` to stderr.

> [!CAUTION] Deletion happens before verification
> `phone.ingest.fetch` is called with `delete_after:true`, so the **phone-side copy is deleted as
> part of the fetch** — before the payload is decoded and before its sha256 is checked. If
> verification then fails, the local temp file is removed too and the file exists in neither
> place. A corrupted transfer is unrecoverable, not retryable.

`phone-ingest-watcher` is a systemd path unit watching `<ingestDir>/staged/*.json`; new files trigger
`scripts/ingest-watcher.sh` to process them.

## Proximity lock

`phone-proximity-daemon` polls the phone's IMU every `proximityIntervalSec`. When the inferred motion
state transitions from `on_desk`/`stationary` to `walking`/`in_pocket`, it runs
`niri msg action lock-screen` and records the event to syslog under the tag `phone-proximity`. The
unit restarts on failure after 10 seconds.

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
