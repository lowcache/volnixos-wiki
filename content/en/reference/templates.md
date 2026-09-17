---
title: "Flake Templates"
description: "Six language scaffolds shipped as flake templates: what each one gives you, why there is no default, and the shared devShell-plus-guarded-build shape."
weight: 40
---

The flake exposes six project scaffolds under `templates`, consumed with `nix flake init`. Each one
drops a `flake.nix`, an `.envrc`, a `.gitignore` and a `README.md` into an empty directory.

```bash
nix flake init -t ~/.nix-config#python
```

| Template | Gives you |
| :--- | :--- |
| `go` | Go devShell + guarded `buildGoModule` |
| `hugo` | Hugo site: hugo/go/wrangler + reproducible site build |
| `lua` | Lua plugin devShell (`lua5_4`, `shellcheck`, `stylua`) |
| `luau` | Luau plugin devShell + type-check gate |
| `python` | Python devShell via `withPackages` (pytest, ruff) |
| `ruby` | Ruby devShell (bundler) + reproducible `bundlerEnv` build |

> [!NOTE] There is no `templates.default`, on purpose
> A bare `nix flake init -t ~/.nix-config` would silently scaffold whichever template won the coin
> toss into the wrong project. Name the language.

## Shared shape

Every template is the same two-part idea: a devShell you work in, and a build that is guarded so an
unconfigured scaffold fails loudly instead of producing a broken derivation.

The `.envrc` is one line — `use flake` — so [direnv](../tooling/fish/) picks the shell up on `cd`.
`nix flake check` runs the language's gate.

## Per-template notes

**`go`** — devShell plus a `buildGoModule` that stays guarded until you fill in the module details,
so a fresh scaffold cannot silently build the wrong thing.

**`hugo`** — the toolchain this wiki itself uses: `hugo`, `go` (for Hugo modules), and `wrangler` for
deploys, plus a reproducible site build.

**`lua`** — `lua5_4` with `shellcheck` and `stylua`. Gates are list-based: you name the files to
check.

**`luau`** — the largest of the six. Its gate runs `luau-lsp analyze` with a definitions file rather
than the bare `luau-analyze` binary, because `luau-analyze` has no way to load definitions — so it
cannot see the API your plugin is written against, and would pass files it does not actually
understand. Discovery-driven: it finds your entry files rather than requiring a hand-maintained list.

**`python`** — `withPackages` rather than a requirements file, carrying `pytest` and `ruff`.

**`ruby`** — bundler in the devShell and `bundlerEnv` for the build, so the built artifact resolves
gems reproducibly instead of reaching out at build time.

> [!NOTE] `nix flake show` currently mislabels the luau gate
> The flake's output description for `luau` still reads "luau-analyze gate". The template moved to
> `luau-lsp analyze` and the description has not caught up.
