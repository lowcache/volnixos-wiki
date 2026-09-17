---
title: "Backup"
description: "Plug-triggered restic backup to an external drive: label-addressed partitions, the empty-mount hazard it guards against, and why there is no LUKS in the path."
weight: 50
---

Backup is a 2 TB USB disk that lives in a drawer rather than in the machine. **Plugging it in is the
trigger** — nothing here ever runs on a timer. The module is
[`nixos/modules/backup.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/modules/backup.nix)
behind `vol.backup`.

## The drive

Three partitions, addressed by `LABEL` so USB port order and `/dev/sd?` naming never matter:

| Label | Filesystem | Holds |
| :--- | :--- | :--- |
| `RESCUE` | FAT32 | NixOS installer ISO — this module does not touch it |
| `MODELS` | ext4 | rsync mirror of the model weights restic deliberately skips |
| `VOLBAK` | ext4 | the restic repository |

> [!NOTE] No LUKS anywhere in this path
> restic encrypts its own repository — data *and* metadata — and model weights are not secret. That
> keeps the plug-in path free of an unlock step, and keeps `/persist` free of a keyfile that would be
> stolen alongside the drive it unlocks.

## What gets backed up

```nix
paths = [
  "/persist"
  "/home/lowcache/Storage"
];
```

Two sources, two devices. `/persist` carries the machine, including `~/.nix-config`; `~/Storage` is
the second NVMe. The `mkOutOfStoreSymlink`s that point from `/persist` into `Storage` are stored *as
symlinks*, so listing both captures nothing twice.

## The hazard it guards hardest

`~/Storage` is a separate NVMe, and therefore a mount point. If it fails to mount, the directory
still exists and is empty.

> [!CAUTION] An unguarded run would record a snapshot of nothing, then prune the real ones
> That is the failure this module is built around. The restic unit carries `RequiresMountsFor` plus
> an explicit mountpoint assertion in the script. The same reasoning covers the repository mount:
> without it, restic would happily initialize a fresh repository on the tmpfs root and report
> success.

## Options

| Option | Default | Purpose |
| :--- | :--- | :--- |
| `enable` | `false` | Plug-triggered external-drive backup. |
| `repoFsUuid` | *(host)* | Filesystem UUID of the repo partition. |
| `usbQuirks` | `[ ]` | `usb-storage` quirks applied for this bridge. |
| `passwordFile` | *(required)* | restic password, from [sops](../architecture/secrets/). |
| `paths` / `exclude` | *(host)* | What to snapshot and what to skip. |
| `pruneOpts` | *(host)* | Retention passed to `restic forget`. |
| `cooldownHours` | `12` | Skip a run if one already succeeded this recently. |
| `checkIntervalDays` | `30` | How often `restic check` reads real data. |
| `checkSubset` | *(host)* | How much data that check reads. |
| `powerOffWhenDone` | `true` | Spin the drive down when finished. |
| `notify` | `true` | Desktop notifications to the user session. |

Two host values are worth understanding rather than copying:

**`repoFsUuid` is a filesystem UUID, not a USB serial.** The serial this bridge reports differs
depending on which driver claims it, so matching on it is unreliable in exactly the situation you
need it to work.

**`usbQuirks = [ "0bc2:ac19:u" ]`** forces the Seagate BUP Slim bridge (ST2000LM007) onto BOT. Under
UAS it drops off the bus during sustained writes — which is to say, during a backup.

## Operating it

```bash
make backup          # run now, obeying the 12h cooldown
make backup-force    # run now regardless of the cooldown
make backup-mount    # mount the repo for manual restic work
make backup-umount   # unmount and power the drive down
```

`make backup` checks for `/dev/disk/by-label/VOLBAK` first and tells you if the drive is not
plugged in. `backup-force` works by removing the success stamp at
`/var/lib/vol-backup/last-success`, so the cooldown check has nothing to find.

Use `make backup-mount` when you need restic directly — restores, `snapshots`, `diff` — and
`make backup-umount` when you are done, which also spins the disk down before you unplug it.
