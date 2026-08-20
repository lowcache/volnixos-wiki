---
title: "Backports & the proot unpack bug"
weight: 20
---

[`droid/backports.nix`](https://github.com/lowcache/volnixos/blob/main/droid/backports.nix) is an
overlay that rebuilds a small number of unstable-only tools against the phone's pinned
(glibc 2.40) package set. It exists because the [glibc pin](nix-on-droid/#why-the-package-set-is-pinned)
cuts the phone off from anything that only lives in `nixos-unstable`, and because building *any*
directory source on-device hits a proot bug.

## What the overlay provides

Four packages, for two different reasons. `rtk` and `mcp-gateway` are true backports: unstable
package *expressions* re-instantiated against the pinned set. `termux-am` and `termux-tools` are
not backports at all. They are nix-on-droid's own packages, rebuilt here so they exist in `pkgs`
where an overlay can reach them.

| Package | Expression from | Why |
| :--- | :--- | :--- |
| `rtk` | unstable, `pkgs/by-name/rt/rtk` | Token-optimising CLI proxy. Rust; builds on-device in a few minutes. |
| `mcp-gateway` | unstable, `pkgs/by-name/mc/mcp-gateway` | The reason the phone is worth doing at all — it fronts the phone-agent MCP server, so an agent running **on** the phone reaches Termux:API over loopback with no Tailscale hop. |
| `termux-am` | the `nix-on-droid` flake source | Not in nix-on-droid's overlay; upstream only ever `callPackage`s it from inside its `android-integration` module. Building it here exposes it as `pkgs.termux-am`, patched. |
| `termux-tools` | the `nix-on-droid` flake source | Same, and it takes `termux-am` from the overlay rather than upstream's unpatched one. One derivation with eight outputs, one per shim, so a single override patches all of them. |

That is what the overlay's third argument is for:

```nix
{
  unstable,          # the nixpkgs-unstable SOURCE tree (for its package expressions)
  unstablePkgs,      # unstable instantiated for aarch64 (for its newer rustc only)
  nix-on-droid-src,  # the nix-on-droid flake (for termux-am / termux-tools)
}:
```

The two backports are pulled from unstable by path and re-instantiated against the pinned set:

```nix
rtk         = prootUnpack (fromUnstable "/pkgs/by-name/rt/rtk/package.nix" { });
mcp-gateway = prootUnpack (
  fromUnstable "/pkgs/by-name/mc/mcp-gateway/package.nix" { rustPlatform = newerRust; }
);
```

The two termux packages are built straight out of the nix-on-droid source tree:

```nix
termux-am    = prootUnpack (
  final.callPackage "${nix-on-droid-src}/pkgs/android-integration/termux-am.nix" { }
);
termux-tools = prootUnpack (
  final.callPackage "${nix-on-droid-src}/pkgs/android-integration/termux-tools.nix" {
    termux-am = final.termux-am;
  }
);
```

> [!NOTE] Building them is only half of it
> Putting patched packages in `pkgs` does nothing on its own, because upstream's
> `android-integration` module calls `pkgs.callPackage` on the derivation files directly and never
> looks at the overlay. The module is replaced too. See
> [Android integration shims](nix-on-droid/#android-integration-shims).

## The proot unpack bug

nixpkgs' `_defaultUnpack` copies a directory `src` with `cp`, which creates the destination
directory and then `chmod`s it. Under proot on-device, that `chmod` returns **`ENOENT` even though
the directory exists**, and the build dies.

> [!WARNING] It is not about preserving the source mode
> The obvious fix does not work. `cp --no-preserve=mode,ownership` still fails, because `cp` is
> still applying a mode to a directory it created. The fix has to stop `cp` from creating the
> directory at all.

`prootUnpack` overrides `_defaultUnpack` to pre-create the destination directory itself and copy
only the *contents* into it:

```bash
_defaultUnpack() {
  ...
  cp -r --no-preserve=mode,ownership "$fn"/. "$destDir"/
}
```

### Cargo needs a second fix

Rust derivations bypass the override entirely: `cargoSetupPostUnpackHook` runs its own `cp -Lr`
before `_defaultUnpack` is ever consulted, and hits the same `chmod` failure. That hook has a second
branch — when `cargoVendorDir` is set, it assumes the vendor tree already exists inside the source
and skips the copy. So the overlay stages the vendor tree by hand in `postUnpack` and sets:

```nix
cargoVendorDir = "vendor";
```

> [!CAUTION] `cargoVendorDir` is load-bearing
> This is not an inert environment variable. Removing it puts `cargoSetupPostUnpackHook` back on
> its `cp -Lr` path and the build fails again.

## Borrowing a newer rustc

`25.11` ships rustc 1.91.1. `mcp-gateway` declares `rust-version = 1.95` and cargo refuses to build
below it. The overlay borrows the newer compiler *only*:

```nix
newerRust = final.makeRustPlatform { inherit (unstablePkgs) rustc cargo; };
```

`makeRustPlatform` keeps the **pinned** stdenv and cc wrapper, so the produced binary still links
glibc 2.40 and keeps a working `isatty()`. Running a glibc-2.42 rustc during the build is harmless:
the TCGETS2 bug only breaks terminal detection, and a compiler does not care whether it has a tty.

## Why the rest of the agent stack is not backported

The same proot failure is what disqualifies the wider `pkgs.llm-agents.*` set and the unstable-only
MCP servers — see the exclusion table in
[Nix-on-Droid](nix-on-droid/#agent-layer--droidagentsnix). `prootUnpack` makes those buildable in
principle, but "buildable" means ~40 real packages compiled on a phone under proot. Backporting is
deliberately kept to the two packages that carry their weight.
