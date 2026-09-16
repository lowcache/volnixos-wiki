---
layout: single
title: "System"
description: "System-level NixOS configuration: hybrid Nvidia and AMD graphics, the local AI stack, and declarative MicroVM virtualization."
weight: 30
---

Host-level subsystems: the hybrid GPU stack, the local AI stack, audio and backup, and the
virtualization layer that runs the Windows guest and the anon-box microVM.

- [Hybrid GPU](gpu/) — AMD iGPU + NVIDIA RTX 4050 offload
- [AI Stack](ai-stack/) — CUDA Ollama, Open WebUI, Fooocus
- [Audio](audio/) — ALSA card routing, parked HDMI outputs
- [Backup](backup/) — restic backups to the external Seagate BUP Slim
- [Virtualization](virtualization/) — microVM and libvirt guests, shared host plumbing

Ollama, Open WebUI, audio, and backup are each declared through the option-typed module layer under
[`nixos/modules/`](https://github.com/lowcache/volnixos/blob/main/nixos/modules/default.nix), not as
ad hoc host config.
