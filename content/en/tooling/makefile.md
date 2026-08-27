---
title: "Makefile & Operations"
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

## Secrets Management

| Target               | Action                                          |
| :------------------- | :---------------------------------------------- |
| `make sops-edit`     | `SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops $(SOPS_FILE)` |
| `make sops-rekey`    | `SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops updatekeys $(SOPS_FILE)` |
| `make sops-view`     | `SOPS_AGE_KEY_FILE=$(SOPS_AGE_KEY_FILE) sops -d $(SOPS_FILE)` |

## Flake & maintenance

| Target               | Action                                          |
| :------------------- | :--------------------------------------------- |
| `make check`         | `nix flake check` (includes formatting/lint gates) |
| `make fmt`           | Format all `.nix` with `nix fmt` (RFC 166 nixfmt) |
| `make update`        | Update all flake inputs                          |
| `make update-nixpkgs`| Update only `nixpkgs`                            |
| `make trash`         | Delete >7d system generations + GC the store     |
| `make git`           | Interactively stage, commit, and push changes  |
| `make comm`          | `git add .` followed by `git commit -m "$$cm"`   |
| `make push`          | `git push` (wrapped in ssh-agent auth logic)     |

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

| Target               | Action                                          |
| :------------------- | :---------------------------------------------- |
| `make docs-serve`    | `$(MKDOCS) serve`                               |
| `make docs-build`    | `$(MKDOCS) build --strict`                      |
| `make docs-deploy`   | `rsync --delete -rv ./site/ $(DOCS_REMOTE):/$(DOCS_PROJECT)` |

For `docs-deploy`, it rsyncs `./site/` to `$(DOCS_REMOTE):/$(DOCS_PROJECT)` which defaults to `pgs.sh:/wiki`.

> [!NOTE]
> The wiki is now also deployed to Cloudflare via `wrangler.toml` (`npx wrangler deploy`, assets dir `./site`), so `docs-deploy` is the older pgs.sh path — both are valid and neither is removed.

> [!TIP] Recommended flow
> `make check` → `make build` → `make switch`. Use `make dry-activate` first when changing services
> to preview restarts.

> [!IMPORTANT] Push before you switch
> Every push to `main` that touches the closure builds it on CI and uploads the result to
> `volnixos.cachix.org` — see [Binary Cache & CI](../ci-cache/). Running `make switch` *before* the
> run goes green means building locally and then having CI rebuild the same paths. For anything
> larger than a one-line change, and especially after `make update`, push first, wait for the run,
> then switch: `make comm && make push` → `gh run watch` → `make switch`.
