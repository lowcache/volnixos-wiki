---
title: "Binary Cache & CI"
description: "Binary cache and CI for a personal NixOS flake: what gets cached, how builds are pushed, and keeping rebuild times survivable on a volatile root."
weight: 40
---

Every push to `main` that can change the closure builds the whole `volnix` system on a GitHub
runner and pushes the result to **`volnixos.cachix.org`**. Hosts then pull that closure instead of
rebuilding it. The workflow is
[`.github/workflows/build.yml`](https://github.com/lowcache/volnixos/blob/main/.github/workflows/build.yml);
the trust side lives in
[`nixos/modules/nix-settings.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/modules/nix-settings.nix).

## Why this config needs its own cache

Most of the closure is already on public caches. A specific slice is not, and never will be:

| Path | On `cache.nixos.org`? | Why |
| :--- | :--- | :--- |
| `nvidia-x11`, `nvidia-open` | No | `unfreeRedistributable` — Hydra does not build unfree packages for anyone, on any kernel |
| `nvidia-open-<ver>-<kernel>` | No | Additionally bound to the exact kernel version, so even an unfree-permitting cache would need this kernel |
| `linux-cachyos-latest` | No | Out-of-tree kernel; served by the [lantian attic](#substituters), not by Hydra |

A store path's hash covers its entire dependency graph, so "NVIDIA built against *this* CachyOS
kernel with *these* nixpkgs" is a path that exists only where someone has published it. Nobody had.
Now this repo does:

```console
$ curl -so /dev/null -w '%{http_code}\n' https://volnixos.cachix.org/p7psxbs6gpxaixfrhqrb5s28fawgnxlh.narinfo
200
$ curl -so /dev/null -w '%{http_code}\n' https://cache.nixos.org/p7psxbs6gpxaixfrhqrb5s28fawgnxlh.narinfo
404
```

(`p7psx…` is `nvidia-x11-595.84-bin`.)

> [!NOTE]
> This is specificity, not specialness. The cache helps anyone running *this exact* combination,
> which is currently one laptop. The point is that the laptop stops rebuilding it.

## Substituters

`nix-settings.nix` declares five substituters, own cache first so that a hit costs one round-trip:

| Substituter | Supplies |
| :--- | :--- |
| `volnixos.cachix.org` | this closure: NVIDIA against the CachyOS kernel, patched packages, MicroVM runners |
| `nix-community.cachix.org` | community flakes |
| `cache.lix.systems` | the Lix daemon |
| `cache.numtide.com` | numtide packages (also used by [nix-on-droid](../../phone/nix-on-droid/#substituter)) |
| `attic.xuyh0120.win/lantian` | **the CachyOS kernel** |

> [!NOTE] `cuda-maintainers.cachix.org` was removed 2026-09-17
> It began answering `401` on `nix-cache-info`, so Lix rejected it as "not a binary cache" and
> warned on every command. Nothing was being substituted from it by then, so dropping it changed
> only the log noise. Re-add the URL and its public key together if the cache goes public again.

`cache.nixos.org` is not listed because Nix always consults it in addition to the configured set.

The public key for `volnixos.cachix.org` is in `nix-settings.nix` in plain text; that is what a
public key is for. The push side needs `CACHIX_AUTH_TOKEN`, a repo secret: a cache-scoped read/write
token from the `volnixos` cache's settings, which expires.

## Consuming the cache from another machine

Add the substituter and its key. Nothing else is required, and nothing about it is repo-specific:

```nix
nix.settings = {
  substituters = [ "https://volnixos.cachix.org" ];
  trusted-public-keys = [
    "volnixos.cachix.org-1:GUKpgN2Tzh67uYZtUaEsFr1U7UVLrFG1iCoF860CY5Y="
  ];
};
```

Or for a one-off build, without touching config:

```bash
nix build --extra-substituters https://volnixos.cachix.org \
  --extra-trusted-public-keys volnixos.cachix.org-1:GUKpgN2Tzh67uYZtUaEsFr1U7UVLrFG1iCoF860CY5Y= \
  .#nixosConfigurations.volnix.config.system.build.toplevel
```

## What the workflow does

| Step | Purpose |
| :--- | :--- |
| Free disk space | Removes ~25 GB of preinstalled runner toolchains; the closure does not fit otherwise |
| `install-nix-action` | Installs Nix, wires `access-tokens` for GitHub-hosted flake inputs |
| `cachix-action` | Authenticates to `volnixos`, and pushes every newly built path on exit |
| Checks (fmt + lint) | `formatting`, `lint` and `fish-syntax`. Runs first, so a lint failure costs a minute rather than the whole build. `anon-jail` is a VM test and runs only in `make check` (no KVM on the runner) |
| **Assert the kernel is a cache hit** | Dry-run gate, see below |
| Build volnix toplevel | The system closure |
| Build MicroVM runners | `net-gate` and `tailscale-vm` |

Every third-party action is pinned to a full commit SHA, with the release tag kept as a comment
(`actions/checkout@11d5960… # v4`), so a moved tag cannot change what runs.

A green run on a warm cache, measured on run `33043734080`. It is a historical measurement, from
before the checks moved to the front of the job, and is not representative of a CUDA build:

| Step | Time |
| :--- | ---: |
| Free disk space | 68 s |
| Kernel cache-hit assertion | 129 s |
| Build volnix toplevel | 164 s |
| MicroVM runners | 12 s |
| Checks | 5 s |
| **Wall clock** | **~7 min** |

Before the substituter list was correct, the same job compiled the kernel from source and hit the
timeout then in force (90 minutes).

## The kernel assertion

The job is only viable if the CachyOS kernel is a *download*. A source build of it does not finish
inside the GitHub Actions six-hour job limit, so the workflow asks before spending the time:

```bash
nix build --dry-run .#nixosConfigurations.volnix.config.system.build.toplevel 2>&1 | tee /tmp/dry.txt
if grep -qE "/nix/store/[a-z0-9]+-linux-cachyos-latest-[0-9.]+\.drv" /tmp/dry.txt; then
  echo "::error::the kernel ITSELF would be built from source"
  exit 1
fi
```

The pattern is anchored to the store path for a reason. Three other `cachyos` derivations are built
on every host legitimately, are cheap, and are in nobody's cache:

- `…-linux-cachyos-latest-<ver>-modules.drv` (per-config aggregation)
- `…-linux-cachyos-latest-<ver>-modules-shrunk.drv`
- `…-initrd-linux-cachyos-latest-<ver>.drv` (host-specific initrd)

An unanchored `linux-cachyos.*\.drv` matches the first two; `linux-cachyos-latest-[0-9.]+\.drv`
without the `/nix/store/<hash>-` prefix still matches the **initrd** as a substring. Both mistakes
failed real builds before the anchored form stuck.

`timeout-minutes` is now `360`, which is GitHub's own ceiling: hosted runners terminate any job at
six hours regardless of the setting, so it is a limit, not a budget. It used to be short (90, then
150, then 250 minutes) to fail fast if a substituter regressed and the kernel fell back to a source
build. The assertion above catches exactly that in about a minute, so a short timeout only capped
legitimate work. Run `35299186456` showed it: after a 623-commit nixpkgs jump, roughly 1,854 paths
had to be built from source, and the job was killed at 250 minutes while generating the last
systemd units, minutes from done.

> [!TIP]
> If this step fails, read the `nix config show substituters` output it prints first. A missing
> lantian attic is the usual cause, and the attic has returned transient `500`s.

## Substituters in CI: the ordering trap

The substituter list **cannot** live in `install-nix-action`'s `extra_nix_config`. Nix reads
configuration in this order, each layer overriding the last:

```text
/etc/nix/nix.conf   →   $NIX_USER_CONF_FILES   →   $NIX_CONFIG
```

`install-nix-action` writes `extra_nix_config` into `/etc/nix/nix.conf`. `cachix-action` then points
`NIX_USER_CONF_FILES` at a nix.conf of its own that **assigns** `substituters` rather than extending
it, which silently discards everything the first layer accumulated.

That is not theoretical. Run `33035377085` had the attic configured, logged it at install time, and
still compiled the kernel for 90 minutes using only `cache.nixos.org` and `volnixos`.

The fix is job-level `NIX_CONFIG`, which Nix reads *after* every config file:

```yaml
env:
  NIX_CONFIG: |
    extra-substituters = https://attic.xuyh0120.win/lantian https://nix-community.cachix.org …
    extra-trusted-public-keys = lantian:EeAUQ+… nix-community.cachix.org-1:mB9FSh9… …
```

`extra-substituters` appends; plain `substituters` replaces. Keep this list in sync with
`nix-settings.nix` — the guard exists partly to catch drift between the two.

## When the workflow does not run

```yaml
paths-ignore: ['**.md', 'docs/**', 'assets/**', 'LICENSE']
concurrency:
  group: build-${{ github.ref }}
  cancel-in-progress: true
```

`cancel-in-progress` is correct for real config changes: a superseded build is wasted work. It is
actively harmful for documentation, because a README push would start a pointless run *and* kill the
real build already in flight. Runs `33042848288` and `33043174328` were both lost that way. A
workflow that never starts cannot cancel anything, so `paths-ignore` is the actual fix.

## Order of operations

The cache only pays off if the runner builds *before* the host does:

```bash
make git      # push -> commit -> push, then hand off to a background CI poller
make switch   # now a download, not a build
```

`make git` doesn't block on the run: it hands off to `ci-poll`, a background systemd user unit that
feeds progress into the starship prompt (see [Starship Prompt](starship/)) instead of holding the
terminal. Use `make ci` to watch the run in the foreground instead — it also prints the
`paths-ignore` explanation when a docs-only push produced no run at all. Either way, wait for the run
to go green before `make switch`; switching first just means building locally and then having CI
rebuild the same thing. For a full `make update`, the difference is hours of laptop CPU versus a few
minutes of runner time and a download.

> [!NOTE]
> `make switch` needs no extra flags. `volnixos.cachix.org` is already the first substituter in
> `nix-settings.nix`, so an activated system picks up CI output automatically.

> [!NOTE]
> `cachix-action`'s upload runs as its own post step, after the rest of the job's steps complete, so
> the cache push for a run's paths finishes last regardless of where `cachix-action` appears in the
> job's step list.
