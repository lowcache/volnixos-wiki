---
title: "Agent Toolchain"
description: "The coding-agent toolchain on this host: which agents are installed, how their MCP servers are sandboxed, and where per-project memory is kept."
weight: 30
---

A toolchain for AI-agent sessions on this host. `memd` and `tether` have each graduated to their
own repo under `~/CodeRepo` rather than living inside `volnixos`. `tether` is put on `PATH` as an
out-of-store symlink in `~/.local/bin` by
[`home/scripts.nix`](https://github.com/lowcache/volnixos/blob/main/home/scripts.nix); `memd` is
brought in as a flake input's Home Manager module instead. Both are available in **every** project,
not just this repo.

```mermaid
flowchart LR
    SS["agent CLI session"] --> MEM[".memory/ (memd init)"]
    MEM --> CUR["memd curator<br/>distills transcripts"]
    CUR --> FILES["state · decisions · mistakes · todo .md"]
    CLAUDE["Claude (orchestrator)"] -->|brief| TETHER["tether"]
    TETHER -->|agy: pro/flash tiers| GEM["Gemini (worker)"]
    TETHER -->|free/free-big/free-fast tiers| OC["opencode (worker)"]
    GEM -->|RESULT / EVIDENCE / BLOCKERS| CLAUDE
    OC -->|RESULT / EVIDENCE / BLOCKERS| CLAUDE
```

## memd — project-memory curator

`memd` (its own repo at `~/CodeRepo/memd`) autonomously distills AI session transcripts into a
project's `.memory/` files. It is deployed as a home-manager module (`services.memd`), running from
the pinned `/nix/store` copy with automatic periodic sweep timers.

| File                  | Holds                                              |
| :-------------------- | :------------------------------------------------ |
| `.memory/state.md`    | Live status, configs, ports, active workarounds    |
| `.memory/decisions.md`| Canonical architecture decisions                   |
| `.memory/mistakes.md` | Append-only audit log of bugs/issues               |
| `.memory/todo.md`     | Open tasks                                          |
| `.memory/inbox/`      | Write interface — drop dated notes for the curator |

- **Read** the memory files at session start. **Write** only by dropping a markdown note in
  `.memory/inbox/`; the next sweep ingests and deletes it.
- A `memd-sweep` systemd **user timer** (~30 min, managed by `services.memd` in `home/default.nix`)
  catches up stale projects, ingests inboxes, prunes oversized files, and detects new git repos.
- Session hooks (`SessionStart`, `SessionEnd`, `PreCompact`) wire memd into Claude Code.

> [!CAUTION] Never hand-edit `.memory/`
> The curator maintains invariants (frontmatter, append-only `mistakes.md`, size budgets, per-project
> locks, apply-then-advance cursors). Manual edits race the background runs. Scaffold with
> `memd init`, never by hand.

## tether — task delegation

`tether` (standalone tool in its own repo, `~/CodeRepo/tether`; put on `PATH` as
`~/.local/bin/tether` by [`home/scripts.nix`](https://github.com/lowcache/volnixos/blob/main/home/scripts.nix))
lets Claude (the **orchestrator**) hand scoped task briefs to a worker model. The worker executes
literally and reports in a `RESULT / EVIDENCE / BLOCKERS` format.

```bash
tether run [-m pro|pro-low|flash|flash-high|flash-low|free|free-big|free-fast] [-d DIR] [-t TASK] [-y] [-f FILE]... [-o OUT] [--timeout SECS] "BRIEF"
tether ask  [-m TIER] [-d DIR] [-f FILE]... [--timeout SECS] "QUESTION"
tether continue TASK [-y] [-f FILE]... [-o OUT] [--timeout SECS] "FOLLOW-UP"
tether status [TASK] | transcript TASK [N] | log [N] | models [--probe]
```

- `pro|pro-low|flash|flash-high|flash-low` route to Gemini via `agy`. `free|free-big|free-fast`
  route to a second worker backend, `opencode`, configured against OpenRouter's free tier
  (`home/scripts.nix:260-284`) — bulk delegation that costs no Gemini quota.
- Default workdir is `$PWD`; paths under `~/.nix-config` auto-map to the non-hidden `~/volnix` alias
  (the Antigravity CLI rejects hidden workspace paths).
- `-f FILE` embeds a file's contents inline so the worker never tool-reads it (avoids the read-timeout)
  and the bytes never enter the orchestrator's context; `-o OUT` writes the report to a file.
- The full contract is in `~/CodeRepo/tether/PROTOCOL.md`.

> [!NOTE] Never delegate
> Architecture decisions, `.memory/` curation, destructive/system operations, and final
> user-facing answers stay with the orchestrator.

> [!NOTE] agent-scaffold retired
> `agent-scaffold`, which rendered `.model/{CLAUDE,AGENTS,GEMINI}.md` at each git root, was retired
> on 2026-10-10 along with the `agy` Fish wrapper that invoked it. The config repo's own agent
> guides now sit at its root (`CLAUDE.md`, `AGENTS.md`, `GEMINI.md`) and `dots/CLAUDE.md`, and
> `.model/` is no longer ignored globally.

> This documentation site itself was produced with this toolchain — the Desktop section was drafted by
> Gemini through `tether`.

## MCP Servers

`mcp-gateway` is installed via the `nixAi` package group (`home/pkgs.nix:153`), alongside the
backends it fronts: `mcp-nixos`, `github-mcp-server`, `markitdown-mcp`, `playwright-mcp`,
`context7-mcp`, `mcp-server-filesystem`, `open-websearch`, and `mcp-server-fetch`. Its config lives
at `~/.config/mcp-gateway/gateway.yaml`, and its runtime state (OAuth client ids and refresh tokens
for remote backends) in `~/.mcp-gateway`. Both are persisted in `home/persist.nix`; without the
second, every reboot forces re-authorization.

It runs as a declared Home Manager user service,
[`home/mcp-gateway.nix`](https://github.com/lowcache/volnixos/blob/main/home/mcp-gateway.nix)
(`Restart = "always"`, wanted by `default.target`). Its start script reads the sops `gh_token` at
launch and exports it as both `GITHUB_TOKEN` and `GITHUB_PERSONAL_ACCESS_TOKEN`, which
`gateway.yaml` expands, so no token is ever written to the store. Backends are spawned by name
(`npx`, `uvx`, `mcp-*`), so the unit's `PATH` is the system and per-user profiles. The module also
force-claims `~/.config/systemd/user/mcp-gateway.service` and its `default.target.wants` link, which
the old hand-written unit occupied.

`phone-agent` is deliberately **not** one of the gateway's backends. A gateway-peer config for it
was removed in 2026-08 (`nixos/phone-agent/default.nix:14-20`): it shipped a stale schema and
failed its auth test, so phone-agent stays a standalone MCP server rather than being routed through
the gateway.

## Environment & Secrets

- **`nixAi` tools**: Installed via the `nixAi` package group in `home/pkgs.nix` (includes `rtk`, `mcp-nixos`, `markitdown-mcp`, `open-websearch`, etc.).
- **Fish helpers**: The `ai` and `ai-shell` functions in `home/common/fish.nix` allow running `llm-agents.nix` tools dynamically on-the-fly.
- **Agent secrets**: generated from the `envSecrets` attrset in
  [`nixos/modules/secrets.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/modules/secrets.nix)
  (see [Secrets](../architecture/secrets/)). Every Fish shell exports only `GEMINI_API_KEY`,
  `OPENROUTER_API_KEY` and `PHONE_AGENT_TOKEN`. `GH_TOKEN` is set only for `gh`, through a wrapper.
  `APIFY_API_KEY` and `TWINE_API_KEY` are no longer exported; they exist only as files under
  `/run/secrets`.
