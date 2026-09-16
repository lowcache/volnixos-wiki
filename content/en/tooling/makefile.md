---
title: "Makefile & Operations"
description: "Using a Makefile as the operations layer on NixOS: one entry point for rebuild, update, check and rollback, instead of remembering raw nix commands."
weight: 10
---

The [`Makefile`](https://github.com/lowcache/volnixos/blob/main/Makefile) is the **canonical**
operations interface — prefer it over ad-hoc `nixos-rebuild` invocations. `HOST` defaults to `volnix`
(the only host). `make help` prints the live list, parsed straight out of the `##` comments in the
Makefile itself, so it can never drift from the real targets.

## System

| Target              | Action                                              |
| :------------------ | :-------------------------------------------------- |
| `make switch`       | Rebuild and switch the live system (needs `sudo`)   |
| `make switch-detached`| Switch as a detached system unit (survives mid-rebuild session teardown) |
| `make build`        | Build the configuration without switching           |
| `make test`         | Temporarily activate (no boot entry)                |
| `make dry-activate` | Preview service transitions                         |
| `make boot`         | Stage the rebuild for the next boot                 |

## Nix-on-Droid

| Target               | Action                                          |
| :------------------- | :---------------------------------------------- |
| `make droid-check`   | `nix eval --impure --raw '$(DROID_ATTR).config.home-manager.config.home.activationPackage.drvPath'` |
| `make droid-plan`    | `nix build --impure --dry-run '$(DROID_ATTR).config.home-manager.config.home.activationPackage'` |
| `make droid-switch`  | `nix-on-droid switch --flake .`                 |

`droid-check` and `droid-plan` run on the LAPTOP and only evaluate/dry-run; `droid-switch` must be run ON THE PHONE inside [Nix-on-Droid](../phone/nix-on-droid/).

## MicroVM guests

| Target              | Action                          |
| :------------------ | :------------------------------ |
| `make run-netgate`  | Start the Tor net-gate runner   |
| `make run-tailscale`| Start the Tailscale-vm runner   |
| `make gate-restart` | Restart the net-gate VM (REQUIRED after guest config changes) |

> [!IMPORTANT] Restart the guest after config changes
> `microvm@.service` carries `X-RestartIfChanged=false`, so `make switch` stages the new guest
> closure but leaves the OLD guest process running. A change to net-gate's guest config (torrc, the
> NAT rules, anything under `microvm.vms.net-gate.config`) has no effect until `make gate-restart`
> runs, and nothing warns you otherwise. `anon-box` is the exception: unit dependencies declared in
> `anonymous-mode.nix` re-emit `restartIfChanged`, so it does restart on a plain `make switch`.

## Anonymous Mode

Targets for `vol.anon-mode` — the net-gate Tor VM plus a uid jail — and the
[anon-box](../networking/anon-box/) workstation that rides on it. See
[Net-Gate & Anonymous Mode](../networking/net-gate/) for the L0–L5 readiness ladder these wrap.

| Target                  | Action                                                        |
| :----------------------- | :------------------------------------------------------------ |
| `make anon-status`      | Show jail, readiness, and path state (no sudo, no side effects) |
| `make anon-arm`         | Arm anonymous mode (runs the L0-L4 ladder; fails if unproven) |
| `make anon-disarm`      | Disarm (re-seal the jail and reap running workloads)          |
| `make anon-selftest`    | Prove the NEGATIVE paths (leak tests; needs an armed target)  |
| `make anon-shell`       | Enter the anon-box workstation VM (verifies L5 first)         |
| `make anon-box-rebuild` | Rebuild the workstation closure and restart it (after adding a tool) |
| `make anon-run`         | Run a command as the jailed workload, e.g. `CMD="curl -s example.com"` |
| `make anon-logs`        | Host-side ladder and jail journal                              |
| `make anon-guest-logs`  | net-gate guest tor journal (bootstrap, circuits, rejections)   |

## Secrets Management

| Target               | Action                                          |
| :------------------- | :---------------------------------------------- |
| `make sops-edit`     | `SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops $(SOPS_FILE)` |
| `make sops-edit-vm`  | Decrypt and edit VM secrets (host key only)      |
| `make sops-rekey`    | `SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops updatekeys $(SOPS_FILE)` |
| `make sops-view`     | `SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops -d $(SOPS_FILE)` |
| `make sops-view-vm`  | Print decrypted VM secrets without an editor     |

## Backup

External-drive backup targets (see [Backup](../system/backup/)) — `backup` and `backup-force` run
the same systemd unit udev starts on drive plug-in, so a manual run and an automatic one share one
code path:

| Target               | Action                                                     |
| :------------------- | :----------------------------------------------------------- |
| `make backup`        | Run the external-drive backup now (obeys the 12h cooldown)   |
| `make backup-force`  | Run it now even if a backup succeeded within the cooldown    |
| `make backup-mount`  | Mount the repo for manual restic work (restore, snapshots)   |
| `make backup-umount` | Unmount and power down the drive                              |

## Flake & maintenance

| Target               | Action                                          |
| :------------------- | :--------------------------------------------- |
| `make check`         | `nix flake check`, then separate `deadnix --fail .` and `statix check .` passes over the whole tree |
| `make fmt`           | Format all `.nix` with `nix fmt` (RFC 166 nixfmt) |
| `make update`        | Update all flake inputs                          |
| `make update-nixpkgs`| Update only `nixpkgs`                            |
| `make trash`         | Delete >7d system generations + GC the store     |
| `make git`           | Push, commit, push — then hand off to a background CI poller |
| `make ci`            | Watch the CI run for `HEAD` in the foreground (blocks; `make git` polls instead) |
| `make comm`          | `git add .` followed by `git commit -m "$$cm"`   |
| `make push`          | `git push` (wrapped in ssh-agent auth logic)     |

`nix flake check` only evaluates git-tracked files under the flake's own `${self}`, so `make check`
runs `deadnix` and `statix` again as separate passes over the whole tree to catch what that misses.

`make git` pushes, prompts for and makes a commit, then pushes again (`push` → `comm` → `push`), and
on success hands off to `ci-poll` rather than blocking on `gh run watch`. `ci-poll` runs as a
background systemd user unit and feeds run progress into the starship prompt (see
[Starship Prompt](starship/)) instead of holding the terminal. `make ci` is the foreground
alternative — it locates the run for `HEAD` and attaches with `gh run watch`, printing the
`paths-ignore` explanation instead if a docs-only push produced no run at all.

## Dotfiles subtree

Independent history for `dots/` in a single repo — see [Dotfiles](../reference/dotfiles/):

```bash
make dots-log | dots-split | dots-remote URL=… | dots-push | dots-pull
```

## Themes

The JSON colorscheme engine (see [Theming](../desktop/theming/)):

```bash
python3 dots/color-engine/check_theme.py <theme.json>
python3 dots/color-engine/apply_theme.py <theme.json> [true]      # 2nd arg = verbose
python3 dots/color-engine/make_theme.py '#1e1e2e' '#cba6f7' --name "My Theme" [--out PATH] [--from FILE] [--apply] [--force]
```

The Makefile targets that used to wrap these were removed; call the scripts directly.

## Documentation Wiki

The wiki is its own repo now (`~/CodeRepo/blogs/wiki`), alongside the other sites. Its
serve/build/deploy targets live in that repo's own Makefile — this repo no longer wraps them.

> [!TIP] Recommended flow
> `make check` → `make build` → `make switch`. Use `make dry-activate` first when changing services
> to preview restarts.

> [!IMPORTANT] Push before you switch
> Every push to `main` that touches the closure builds it on CI and uploads the result to
> `volnixos.cachix.org` — see [Binary Cache & CI](../ci-cache/). Running `make switch` *before* the
> run goes green means building locally and then having CI rebuild the same paths. For anything
> larger than a one-line change, and especially after `make update`, push first, wait for the run,
> then switch: `make git` → `make switch`. `make git` already hands the wait off to the background
> `ci-poll`; run `make ci` instead to block on it in the foreground.
