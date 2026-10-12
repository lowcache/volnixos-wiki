---
title: "AI Stack"
description: "The local AI stack on NixOS: model serving, the MCP tooling around it, and how the pieces are wired declaratively rather than pinned by hand."
weight: 20
---

`volnix` runs a local, CUDA-accelerated AI stack plus a custom agent toolchain. The model services are
declared in
[`nixos/modules/ai-stack.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/modules/ai-stack.nix)
and enabled for this host from
[`nixos/hosts/volnix.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/hosts/volnix.nix) (lines 101-108).

## Ollama + Open WebUI

The module exposes a small option-typed interface rather than flat `services.*` toggles, so a host
turns each piece on independently:

```nix
vol.ai-stack = {
  ollama = {
    enable = true;
    exposeToTailscaleVm = true;
    tailnetClients = [ config.phone-agent.phoneTailscaleIP ];
  };
  open-webui.enable = true;
};
```

`ollama.enable` expands, via `lib.mkMerge` / `lib.mkIf`, into the actual service:

```nix
services.ollama = {
  enable = true;
  package = pkgs.ollama-cuda;
  home = "/home/${username}/Storage/ollama";
  modelsDir = "/home/${username}/Storage/ollama/models";
};
```

`ollama.exposeToTailscaleVm = true` — set on this host — binds Ollama to `host = "0.0.0.0"` so the
[Tailscale VM](../networking/tailscale/) can reach it for the phone agent while WAN stays closed.
The firewall exception is narrower than the interface. The guest only DNATs, so the host sees each
tailnet peer's own `100.x` address, and opening `11434` on the whole tap would admit the entire
tailnet. Instead, one rule per address in `tailnetClients` accepts `11434` from that peer on the
tailscale tap (`config.vol.tailscale-vm.tapInterface`), and nothing else gets through. On this host
the only client is the phone.

```nix
services.open-webui = {
  enable = true;
  port = 8080;
  environment.OLLAMA_API_BASE_URL = "http://127.0.0.1:11434";
};
```

Ollama runs as the `lowcache` user, so `~/Storage/ollama` keeps its owner, but it sees only that
directory. Upstream sets `ProtectHome = true`; here it is forced to `"tmpfs"` with
`BindPaths = [ ollamaDir ]`, so the rest of `/home` is an empty tmpfs inside the unit. The
environment is set through `services.ollama.environmentVariables`:

| Variable                     | Effect                                                      |
| :--------------------------- | :--------------------------------------------------------- |
| `OLLAMA_FLASH_ATTENTION=1`   | Flash attention                                            |
| `OLLAMA_KEEP_ALIVE=5m`       | Unload idle models → release CUDA → dGPU RTD3 (0 W) suspend |
| `OLLAMA_NUM_PARALLEL=1`      | Single parallel request                                    |
| `CUDA_VISIBLE_DEVICES=0`     | Pin to the RTX 4050                                         |

`OLLAMA_ORIGINS` is deliberately unset. `*` let any web page open in the browser call the API on
`127.0.0.1:11434` and read the replies; loopback is a trusted interface, so the firewall never
applied. Ollama's default admits only local origins, and nothing here needs more. Open WebUI calls
Ollama from its backend (`OLLAMA_API_BASE_URL`), not from the browser, so it needs no CORS. The
check applies only to requests that carry an `Origin` header, which browsers add; server-side callers
such as Open WebUI's backend normally send none. Checked on 2026-09-19 against Ollama 0.34.0 with
`OLLAMA_ORIGINS` unset:

| Request | Response |
| :--- | :--- |
| `Origin: https://attacker.example` | `403` |
| `Origin: http://localhost:3000` | `200`, `Access-Control-Allow-Origin: http://localhost:3000` |
| no `Origin` header | `200` |

Open WebUI is reachable at `http://127.0.0.1:8080`; `ffmpeg` is injected into its `PATH` for media
handling.

> [!TIP] VRAM fit (RTX 4050, 6 GB)
> `llama3.1:8b` Q4 is the practical interactive ceiling. MoE models such as `gpt-oss-20b` (MXFP4)
> also run — active experts in VRAM, inactive experts offloaded to RAM.

## Fooocus (Stable Diffusion)

A non-autostarting Docker OCI container provides image generation with GPU passthrough:

```nix
virtualisation.oci-containers.containers."fooocus" = {
  # Pinned by digest (was :latest).
  image = "ghcr.io/lllyasviel/fooocus@sha256:a1c3251054a3…";
  autoStart = false;
  ports = [ "127.0.0.1:7865:7865" ];
  volumes = [ "/home/lowcache/Storage/ai-generation/fooocus:/content/data" ];
  environment = {
    CMDARGS = "--listen";
    DATADIR = "/content/data";
    config_path = "/content/data/config.txt";
    path_checkpoints = "/content/data/models/checkpoints/";
    path_loras = "/content/data/models/loras/";
    path_outputs = "/content/data/outputs/";
  };
  extraOptions = [ "--device" "nvidia.com/gpu=0" ];
};
```

The port is published on loopback only, because a Docker published port bypasses the NixOS firewall:
Docker's NAT rules forward the traffic before `nixos-fw` sees it, which the NixOS option docs for
`virtualisation.oci-containers.containers.<name>.ports` say directly. An unprefixed `7865:7865`
exposed the unauthenticated UI to every network the laptop joined while the container ran. The UI is
at `http://127.0.0.1:7865`. `CMDARGS = "--listen"` stays: it binds `0.0.0.0` *inside* the container,
which the port mapping needs. The host side is what's restricted. To bump the image, `docker pull`
the `:latest` tag and copy the `RepoDigest` from `docker image inspect`.

Control it with the Fish aliases `stbldff-on` / `stbldff-off` (start/stop `docker-fooocus.service`).
Outputs persist via the symlink `~/Pictures/fromAi/outputs → ~/Storage/ai-generation/fooocus/outputs`.

## Agent CLIs

The user package set in
[`home/pkgs.nix`](https://github.com/lowcache/volnixos/blob/main/home/pkgs.nix) bundles AI tooling in its
`nixAi` group: `rtk`, `claude-code`, `claude-code-router`, `antigravity-cli` and `llmfit` directly,
plus these from the `llm-agents.nix` overlay: `omo-ai`, `oh-my-opencode`, `claude-desktop`,
`ccstatusline`, `claude-plugins`, `cc-switch-cli`, `opencode`, `prime-agent`, `happy-coder`,
`freebuff`, and `bb-app`. `t3code` and `t3code-desktop` were dropped on 2026-09-18: they depend on
`codex`, which is not prebuilt here (the `llm-agents` input follows this flake's nixpkgs, so every
derivation is rehashed and misses `cache.numtide.com`) and took 223 minutes of `rustc` on the CI
runner. Alongside these sit several MCP servers (`mcp-nixos`, `mcp-gateway`, `github-mcp-server`,
`markitdown-mcp`, `playwright-mcp`, `context7-mcp`, `mcp-server-filesystem`, `open-websearch`,
`mcp-server-fetch`). The
`ai` / `ai-shell` Fish functions run any `llm-agents.nix` tool on the fly. The custom
curation/delegation layer is documented in [Agent Toolchain](../tooling/agents/).
