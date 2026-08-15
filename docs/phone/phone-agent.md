# Phone Agent

The `phone-agent` NixOS module wires `volnix` to a **Galaxy S26 Ultra** running a Termux-based MCP
server, turning the phone into a set of remote tools and sensors the laptop can call over Tailscale.
The module lives in
[`nixos/phone-agent/`](https://github.com/lowcache/volnixos/blob/main/nixos/phone-agent/) and is
imported and enabled from
[`nixos/configuration.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/configuration.nix).

It provides four capabilities plus a `phone-agent` CLI for ad-hoc tool calls:

- **MCP transport** — HTTP MCP over Tailscale, bearer-token authenticated.
- **Ingest** — periodic pull of staged files off the phone, integrity-checked.
- **Proximity lock** — lock the laptop when the phone leaves the desk (lock only).
- **Network routing** — derive a routing profile from the phone's current SSID (opt-in, off by default).

!!! note "Scope"
    This page documents the **laptop side** (the NixOS module declared in this repo). The phone-side
    MCP server is built on-device with Claude Code and is out of scope here — see
    [`nixos/phone-agent/README.md`](https://github.com/lowcache/volnixos/blob/main/nixos/phone-agent/README.md)
    and the phone repo's `PHONE-ENV.md` for that half. The MCP server runs in **Termux**
    (`com.termux`), not in [Nix-on-Droid](nix-on-droid.md) — see the
    [two-Termux warning](index.md).

## Wiring

```nix
# nixos/configuration.nix
imports = [ ./phone-agent ];

phone-agent = {
  enable = true;
  phoneTailscaleIP = "100.101.229.9";               # from the Tailscale Android app
  tokenFile = config.sops.secrets.phone_agent_token.path;
};
```

The bearer token is a [sops-nix](../architecture/secrets.md) secret (`phone_agent_token`) materialized
at runtime; its value must match `~/.config/phone-agent/token` on the phone. `tokenFile` is typed
`str`, not `path`, on purpose — a `path` literal would copy the secret into the world-readable Nix
store. The module asserts `tokenFile` is set.

## Options

| Option | Type | Default | Purpose |
| :--- | :--- | :--- | :--- |
| `enable` | `bool` | `false` | Master switch for the subsystem. |
| `phoneTailscaleIP` | `str` | `100.101.229.9` | Tailscale IP of the phone MCP server. |
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

## Services

The four capabilities do **not** map one-to-one onto services. What is actually declared:

| Unit | Type | Gated by | Trigger |
| :--- | :--- | :--- | :--- |
| `phone-ingest-sync` | user, oneshot | `enableIngestSync` | `phone-ingest-sync.timer` |
| `phone-ingest-sync.timer` | user, timer | `enableIngestSync` | `OnBootSec=2min`, `OnUnitActiveSec=2min` |
| `phone-ingest-watcher` | user, path | `enableIngestWatcher` | `<ingestDir>/staged/*.json` appears |
| `phone-proximity-daemon` | user, long-running | `enableProximityLock` | starts with the session |
| `phone-network-routing` | user, oneshot | `enableNetworkRouting` | **none — see below** |

The **MCP transport** has no service of its own and no independent toggle: it is the `phone-agent`
CLI plus the shared `scripts/phone-mcp-call.sh` dispatcher, governed globally by `enable`.

Each service gets a pinned `PATH` containing only what it needs — `curl`, `coreutils`, `bash`, `jq`,
and, for proximity, `niri` and `util-linux` (for `logger`).

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

## MCP gateway backend

The module writes a template to `/etc/phone-agent/gateway-peer.example.yaml` and emits a build-time
**warning** to register it — `~/.config/mcp-gateway/gateway.yaml` is hand-managed, so the module
surfaces the values rather than editing it for you:

```yaml
backends:
  phone-agent:
    transport: http
    url: http://<phoneTailscaleIP>:8462/mcp
    # Authorization: Bearer $(cat <tokenFile>)
    namespace: phone
```

!!! note "The warning is unconditional"
    It is emitted via `lib.optional true …`, so it fires on **every** evaluation where
    `phone-agent.enable` is true — including long after you have registered the backend. It is a
    permanent reminder, not a one-shot prompt.

## Ingest

`phone-ingest-sync` runs 2 minutes after boot and every 2 minutes thereafter. For each file listed
by `phone.ingest.list` that is not already present locally, it calls `phone.ingest.fetch`,
base64-decodes the payload to `<ingestDir>/staged/.tmp.<name>`, computes its sha256, and moves it to
`<ingestDir>/staged/<name>` only if the hash matches the listing. On mismatch it removes the
temporary file and logs `sha mismatch for <name>` to stderr.

!!! danger "Deletion happens before verification"
    `phone.ingest.fetch` is called with `delete_after:true`, so the **phone-side copy is deleted as
    part of the fetch** — before the payload is decoded and before its sha256 is checked. If
    verification then fails, the local temp file is removed too and the file exists in neither
    place. A corrupted transfer is unrecoverable, not retryable.

`phone-ingest-watcher` is a systemd path unit watching `<ingestDir>/staged/*.json`; new files trigger
`scripts/ingest-watcher.sh` to process them.

## Proximity lock

`phone-proximity-daemon` polls the phone's IMU every `proximityIntervalSec`. When the inferred motion
state transitions from `on_desk`/`stationary` to `walking`/`in_pocket`, it runs
`niri msg action lock-screen` and records the event to syslog under the tag `phone-proximity`. The
unit restarts on failure after 10 seconds.

!!! warning "Lock only — no auto-unlock"
    There is no safe programmatic unlock, so the daemon never unlocks. `allowUnlock` is experimental
    and intentionally a no-op: it only logs unlock *intent*, it does not unlock the session.

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

!!! warning "Nothing triggers this service"
    `phone-network-routing` is a `oneshot` with no `wantedBy`, no timer, and no path unit. Enabling
    `enableNetworkRouting` declares the unit but nothing ever starts it — it has to be invoked by
    hand (`systemctl --user start phone-network-routing`) or wired to a trigger. The
    `phone-network-profile@<profile>.service` it tries to start is likewise not declared anywhere,
    which is why that call is suffixed `|| true`.

!!! info "Ceiling"
    Profile derivation and the runtime file are in place; wiring the profile through to the
    [net-gate microvm](../networking/net-gate.md) is not yet implemented. The source carries a
    matching `[CEILING]` marker.
