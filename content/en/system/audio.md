---
title: "Audio"
description: "PipeWire and WirePlumber under vol.audio: Bluetooth codec priority, parking HDMI cards that bury the real outputs, and the stored-profile trap that silently defeats it."
weight: 40
---

Audio is owned by
[`nixos/modules/audio.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/modules/audio.nix)
behind `vol.audio`, rather than left to defaults. It turns on PipeWire with ALSA (including 32-bit
support) and the PulseAudio shim, and then does three specific things on top: it pins Bluetooth codec
priority, it stops browser tabs stealing the microphone, and it parks HDMI cards that would otherwise
bury the real outputs.

```nix
# nixos/hosts/volnix.nix
audio = {
  enable = true;
  parkedCards = [
    "alsa_card.pci-0000_01_00.1"
    "alsa_card.pci-0000_66_00.1"
  ];
};
```

## Options

| Option | Type | Default | Purpose |
| :--- | :--- | :--- | :--- |
| `enable` | `bool` | `false` | PipeWire/WirePlumber owned by this repo. |
| `pulseTools` | `bool` | `true` | Install `pactl`/`pacmd` clients alongside the shim. |
| `parkedCards` | `list of str` | `[ ]` | ALSA `device.name` values forced to the `off` profile. |
| `bluetooth.enable` | `bool` | follows `hardware.bluetooth.enable` | Bluetooth codec and policy drop-ins. |
| `bluetooth.codecs` | `list of str` | `ldac aptx_hd aptx aac sbc_xq sbc` | Codec priority, best first. |
| `bluetooth.autoswitchToHeadsetProfile` | `bool` | `false` | Whether an app grabbing the mic collapses A2DP to headset. |

`pulseTools` installs the PulseAudio *client* tools only — the daemon stays off and
`services.pulseaudio.enable` is untouched. Without that package there is no CLI able to list or
switch sinks, leaving `wpctl` as the only lever.

## Three drop-ins

The module writes three WirePlumber configuration fragments:

| File | Does |
| :--- | :--- |
| `50-bluez-codecs` | Codec priority list, hardware volume, mSBC |
| `51-bluez-policy` | `autoswitch-to-headset-profile`, quality-first profile preference |
| `52-park-cards` | Forces each `parkedCards` entry to `device.profile = "off"` |

Keeping `autoswitch-to-headset-profile` off is the difference between music staying in A2DP and a web
page dropping your headphones to 8 kHz headset mode the moment it touches `getUserMedia`.

## Parking cards

A card left on `pro-audio` publishes one sink per PCM. On this machine that means the HDMI outputs
fan out into `Pro 1` … `Pro 9` entries that bury the two real outputs in every selector. Parking sets
those cards to the `off` profile so they stop publishing at all.

> [!WARNING] A stored profile beats the module's rule
> `device.profile` takes absolute priority in WirePlumber's find-best-profile hook — but a profile
> already recorded in `~/.local/state/wireplumber/default-profile` is resolved **earlier** and wins.
> Enabling `parkedCards` on a machine that has already chosen profiles therefore changes nothing
> visible, and the module looks broken when it is not.
>
> Clear the stored pins once, when first parking a card:
>
> ```bash
> cp ~/.local/state/wireplumber/default-profile{,.bak}
> sed -i '/=pro-audio$/d' ~/.local/state/wireplumber/default-profile
> systemctl --user restart wireplumber
> ```
>
> Remove only the lines for the cards you are parking — leave entries for cards you actually use,
> such as the analog output's `output:analog-stereo+input:analog-stereo`.

Verify with:

```bash
wpctl status | sed -n '/Sinks:/,/Sources:/p'
```

The parked cards' `Pro` sinks should be absent, and the default should sit on a real output.
