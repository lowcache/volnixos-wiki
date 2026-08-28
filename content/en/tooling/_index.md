---
layout: single
title: "Tooling"
description: "The tooling that operates this NixOS host: a Makefile ops layer, Fish functions, the coding-agent toolchain, and binary cache and CI."
weight: 70
---

The operational surface: the Makefile interface, fish shell functions, the agent
toolchain, and the CI build that keeps the binary cache warm.

- [Makefile & Operations](makefile/) — the canonical operations interface
- [Fish Functions](fish/) — shell helpers
- [Agent Toolchain](agents/) — memd, tether, agent-scaffold
- [Binary Cache & CI](ci-cache/) — the volnixos cachix cache and the build workflow that fills it
