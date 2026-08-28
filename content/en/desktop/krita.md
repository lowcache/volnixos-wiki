---
title: "Krita"
description: "Krita on a volatile NixOS root: Flatpak versus nixpkgs, where config and brush presets have to persist, and the Qt plugin problems worth knowing about."
weight: 40
---

Krita is the application on this machine that needed the most work to survive the impermanence layout. Four separate defects were involved, and only one of them was actually a Krita bug. The rest came from the machine being stateless in ways the application did not expect.

## The swap file pointed at the tmpfs root

This is the defect to steal. Everything else on this page is specific to one program; this one applies to any application that keeps its own scratch path.

Krita swaps image tiles to disk through a memory-mapped file. Two settings in `kritarc` control it:

```ini
maxSwapSize=10240
swaplocation=/tmp
```

That is a 10 GB ceiling on a swap file written to `/tmp`. On this machine `/` is a `tmpfs` sized at 4 GB, declared in [`nixos/hardware-configuration.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/hardware-configuration.nix):

```nix
"/" = {
  device = "none";
  fsType = "tmpfs";
  options = [ "defaults" "size=4G" "mode=755" ];
};
```

`/tmp` lives on that root. So Krita was configured to map up to 10 GB of swap into a 4 GB filesystem that is itself RAM. The swap file was not relieving memory pressure. It was competing for the same pages it was supposed to free.

The signal this produces is the useful part. When a `tmpfs` fills, a page fault against a memory-mapped file on it cannot be satisfied, and the kernel raises `SIGBUS` rather than `SIGSEGV`. `SIGBUS` is rare in desktop applications. If a program that mmaps a scratch file dies with signal 7 on an impermanent system, check where that scratch file lives before reading any further into the stack trace.

The fix is one line:

```ini
swaplocation=/home/lowcache/Storage/tmp/krita-swap
```

`~/Storage` is a disk partition, so the 10 GB ceiling is now backed by disk instead of RAM.

> [!IMPORTANT]
> Krita does not read `$TMPDIR`. [`home/default.nix`](https://github.com/lowcache/volnixos/blob/main/home/default.nix) already sets `TMPDIR` to `~/Storage/tmp` for the shell, and Krita ignored it, because the swap path is its own config key. Setting `TMPDIR` globally is not enough. Every application that stores a scratch, cache, or swap directory in its own config file has to be audited separately.

`kritarc` itself is persisted through an out-of-store symlink in [`home/persist.nix`](https://github.com/lowcache/volnixos/blob/main/home/persist.nix), so the corrected value survives a reboot. Home Manager does not write this file and will not correct it for you.

One caveat on the evidence. The mechanism and the configuration are confirmed by reading them. Attribution of specific past crashes is weaker: two Krita `SIGBUS` cores from July 2026 match this mechanism, but `systemd-coredump` had already discarded the core files, so there is no backtrace proving it. Treat the causal link as strongly indicated rather than demonstrated.

## Memory settings that look wrong and are not

The performance block in `kritarc` invites tampering. It should be left alone:

```ini
memoryHardLimitPercent=60.61
memoryPoolLimitPercent=0
memorySoftLimitPercent=2
```

Checked against `libs/image/kis_image_config.cpp` in Krita's source, the shipped defaults are `50.` for the hard limit, `0.0` for the pool, and `2.` for the soft limit. So a soft limit of 2 and a pool of 0 are stock values, not a misconfiguration.

The soft limit is also not a general swapping threshold, which is the natural misreading of the name. It is the *Swap Undo After* point, computed as 2% of the hard limit, and it governs when old undo states move to disk. The Internal Pool has been deprecated since Krita 4.4. The only non-default value here is the hard limit, raised from 50% to 60.61% of 22 GB, which is deliberate.

## Text tool: broken in 6.0.1, fixed in 6.0.2

Krita 6.0.1 could not render SVG text on this machine. Inserting a `<text>` shape logged `Failed to render glyph, freetype error` for every glyph and then aborted during the asynchronous projection render, after any Python call had already returned.

The error code was `84`. Qt prints integers in decimal, and FreeType's `include/freetype/fterrdef.h` defines `0x54` as `FT_Err_Invalid_Stream_Read`, so the engine was reporting a bad read against a font stream. That fits a truncated font file. One was found: `NoracleNerdFont-Regular.otf` had damaged `cmap` and `OS/2` tables and was quarantined out of the font path.

Quarantining it did not fix the crash on 6.0.1, which is the detail that matters. The crash outlived the corrupt font, so the font was a trigger and the version was the cause. Krita 6.0.2 (27 May 2026) shipped text fixes including type checking against potential crashes and an array index fix in text processing.

On 6.0.2.1 the engine works. Inserting SVG text across five families, including a Nerd Font and a color emoji font, against the full local font set of 3966 files, produced no glyph errors and no crash. `VectorLayer.toSvg()` returns a real `<text>` element, so the result is editable vector text rather than pixels.

> [!NOTE]
> `Shape.remove()` in the Python API segfaults on 6.0.2.1, inside `Shape::remove` calling `Document::document`. A plain `KoPathShape` crashes it as readily as a text shape, so this is a defect in the scripting bindings and not in the text engine. Avoid it in plugins.

## Font Gallery plugin

`font_gallery` is a local pykrita docker that lists every installed family rendered in its own face, with a search box. At 3966 fonts, the stock dropdown is not usable for browsing.

It used to rasterize. Double-clicking a font drew the text with `QPainter` into a `QImage` and pushed the pixels onto a paint layer, deliberately bypassing Krita's text engine to dodge the 6.0.1 crash. The output was flat pixels, so changing a word meant retyping and re-rendering a fresh layer.

Since the engine works, it now builds an SVG `<text>` document and inserts it with `createVectorLayer()` and `addShapesFromSvg()`. The output is a normal text shape, editable with the Text tool. Multi-line input becomes one `<tspan>` per line, and both the typed text and the family name are escaped through `xml.sax.saxutils`, so a family name containing an ampersand cannot break the document.

The plugin lives at `~/Storage/krita-master/krita/pykrita/font_gallery/`, reached through the `~/.local/share/krita` symlink in `home/persist.nix`.

## G'MIC context menu segfault

The G'MIC filter tree segfaults on the first right-click or stylus long-press. The bug is in the plugin rather than in Krita: `GmicQt::FiltersView::onCustomContextMenu` calls `deleteLater()` on context-menu pointers that the constructor leaves as `nullptr`, so any context-menu event dereferences null.

[`home/pkgs.nix`](https://github.com/lowcache/volnixos/blob/main/home/pkgs.nix) defines `krita-plugin-gmic-patched` with null guards around both calls, and `krita-wrapped` overrides `pkgs.krita` so the patched plugin is the one bundled. The override happens inside the wrapper to avoid a `buildEnv` collision, since two copies of `krita_gmic_qt.so` cannot coexist.

This patch is independent of Krita's version. Updating Krita will not retire it, because the defect is in a separate package.

## Driving Krita headlessly

Reproducing any of this without a GUI is possible but has two traps that cost real time.

Do not use the `offscreen` Qt platform. Krita segfaults under it during startup, in `KisClipboard::clipboardDataChanged` calling `QMimeData::hasImage`, because the offscreen platform has no clipboard. The crash has nothing to do with whatever you were testing. Run an `Xvfb` display and pass `-platform xcb` instead.

Isolate `TMPDIR`. Krita uses `QtSingleApplication`, so a second instance hands off to the running one and exits 0 in under half a second, which looks like a silent failure. `QtLocalPeer` derives its lock file and socket name from `QDir::tempPath()`, so pointing `TMPDIR` at a scratch directory gives a separate instance.

With `XDG_DATA_HOME`, `XDG_CONFIG_HOME`, and `TMPDIR` all redirected, a throwaway pykrita extension can create documents, insert shapes, force `refreshProjection()`, and export PNGs without touching the real profile. Enable it by writing `enable_<name>=true` under `[python]` in the scratch `kritarc`.

One API detail wastes time otherwise: `createNode(name, "vectorlayer")` returns a bare `Node` with no SVG methods. Use `createVectorLayer(name)` to get a `VectorLayer` that exposes `addShapesFromSvg()` and `toSvg()`.

## Version status

The installed version is 6.0.2.1. Krita 6.0.3 was released on 29 July 2026 with four further text fixes, covering a crash when deleting a text shape, vertical caret metrics, font family sorting, and font name deduplication.

None of those are defects hit here, and nixpkgs has not packaged it. PR [#546550](https://github.com/NixOS/nixpkgs/pull/546550) is open but unmerged, so the locked flake still evaluates Krita to 6.0.2.1. There is nothing to gain from forcing the upgrade yet.

The Hyprland-era XWayland wrapper is gone. Krita runs as a native Wayland client under niri, as recorded in [Troubleshooting](../../troubleshooting/) and [GPU](../../system/gpu/).
