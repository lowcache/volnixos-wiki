---
title: "Secrets — sops-nix + age"
description: "Secrets on NixOS with sops-nix and age: key placement on an impermanent host, what must persist for decryption to work at boot, and how rotation goes."
weight: 40
---

Secrets are managed with [`sops-nix`](https://github.com/Mic92/sops-nix) and **age** identities. The
encrypted stores `nixos/host-secrets.yaml` (host) and `nixos/vm-secrets.yaml` (the `net-gate` guest,
wired in `nixos/modules/anonymous-mode/guests.nix`) are safe to commit; they are decrypted at
activation into `/run/secrets/<name>`.

The two files have different recipients, set in `nixos/.sops.yaml`:

| File | Encrypted to |
| :--- | :--- |
| `host-secrets.yaml` | the admin user's age key + the host key |
| `vm-secrets.yaml` | the admin user's age key + **net-gate's own key** |

The host key is deliberately absent from `vm-secrets.yaml`, and net-gate's key opens nothing in
`host-secrets.yaml`: the Tor-facing guest never holds a key that decrypts host secrets. Its key is
minted once on the host by the `net-gate-ssh-key` unit into the root-only
`/persist/var/lib/net-gate-ssh`, shared into the guest as `/etc/ssh` over virtiofs, and the unit
logs the matching age recipient for `.sops.yaml`.

> [!NOTE] `vm-secrets.yaml` currently holds only a placeholder
> `nixos/vm-secrets.yaml` contains a single `placeholder` key. The guest's sops wiring (own key,
> sops module) is kept so a guest secret can be added later without re-deriving the trust boundary.
> The legacy `secrets\.yaml$` rule is gone from `.sops.yaml`.

## Configuration

From [`nixos/modules/secrets.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/modules/secrets.nix):

```nix
envSecrets = {
  GEMINI_API_KEY.secret = "gemini_api_key";
  OPENROUTER_API_KEY.secret = "openrouter_api_key";
  PHONE_AGENT_TOKEN.secret = "phone_agent_token";
  GH_TOKEN = {
    secret = "gh_token";
    wrap = pkgs.gh;
  };
};

sops = {
  # relative to the module file — the yaml lives one level up, in nixos/
  defaultSopsFile = ../host-secrets.yaml;
  defaultSopsFormat = "yaml";
  age.sshKeyPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
  secrets = lib.mapAttrs' (_: s: lib.nameValuePair s.secret { owner = username; }) envSecrets // {
    user_password = { neededForUsers = true; };
    root_password = { neededForUsers = true; };
    # …
  };
};
```

`username` is a module argument, not a literal — the module is written so a second host does not
have to rewrite every `owner`.

Thirteen secrets are declared:

| Secret                                 | Decryption target                              | Used by                                          |
| :------------------------------------- | :--------------------------------------------- | :----------------------------------------------- |
| `user_password`                        | user creation (`neededForUsers`)               | `users.users.<user>.hashedPasswordFile`           |
| `root_password`                        | user creation (`neededForUsers`)               | `users.users.root.hashedPasswordFile`             |
| `gemini_api_key`                       | `/run/secrets/gemini_api_key`                  | exported as `GEMINI_API_KEY` in every Fish shell  |
| `openrouter_api_key`                   | `/run/secrets/openrouter_api_key`              | exported as `OPENROUTER_API_KEY` in every Fish shell |
| `phone_agent_token`                    | `~/.config/phone-agent/token` (mode `0400`)    | exported as `PHONE_AGENT_TOKEN` in every Fish shell; read by the client at that path |
| `gh_token`                             | `/run/secrets/gh_token`                        | `GH_TOKEN` for `gh` only, via a wrapper; `mcp-gateway`'s start script |
| `apify_api_key`                        | `/run/secrets/apify_api_key`                   | file only, never exported                         |
| `twine_api_key`                        | `/run/secrets/twine_api_key`                   | file only; memd's `release.sh` reads `TWINE_API_KEY_FILE` |
| `buttondown_api_key_hotelevangelism`   | `/run/secrets/buttondown_api_key_hotelevangelism` | read by path via `BUTTONDOWN_API_KEY_FILE`, never exported |
| `buttondown_api_key_volatiletestimony` | `/run/secrets/buttondown_api_key_volatiletestimony` | read by path via `BUTTONDOWN_API_KEY_FILE`, never exported |
| `cloudflare_api_token`                 | `/run/secrets/cloudflare_api_token`            | `cat` into `CLOUDFLARE_API_TOKEN` for one `wrangler` invocation |
| `gsc_service_account`                  | `/run/secrets/gsc_service_account`             | Google Search Console service-account credentials |
| `restic_password`                      | `/run/secrets/restic_password` (root-owned)    | `vol.backup.passwordFile` in `nixos/hosts/volnix.nix` |

Two entries deviate from the default placement:

- **`phone_agent_token`** is the only secret with a custom `path` and `mode`. It is materialized
  straight to `~/.config/phone-agent/token` because that is where the client reads it, and
  `~/.config` is not a persisted path — sops re-materializes it at every activation, so it survives
  the tmpfs rollback by construction. See [Phone Agent](../phone/phone-agent/).
- **`restic_password`** declares no `owner`, so it stays root-owned: the backup runs as a system
  service, and a user-readable copy would put the key to every snapshot behind a compromised
  session. See [Backup](../system/backup/).

### Environment exposure: `envSecrets`

The default is file-first: a secret is decrypted to a file and read from that path, never exported.
Only a secret listed in the `envSecrets` attrset reaches an environment, and the one attrset
generates both the sops entry and the exposure, so the two cannot drift apart:

- **No `wrap`** — exported in every Fish shell. Reserved for keys several agent tools read
  implicitly: `GEMINI_API_KEY`, `OPENROUTER_API_KEY`, `PHONE_AGENT_TOKEN`. The generated
  `programs.fish.shellInit` line exports each one only if its runtime file is readable:

  ```fish
  test -r /run/secrets/gemini_api_key; and set -gx GEMINI_API_KEY (cat /run/secrets/gemini_api_key)
  ```

- **`wrap = pkg`** — exported only into that one command, through a same-named, high-priority
  wrapper that shadows it on `PATH`. `GH_TOKEN` reaches `gh` this way and no other process. The
  wrapper leaves an already-set variable alone.

## Keys

- **Host key** — decrypts at boot: `/persist/etc/ssh/ssh_host_ed25519_key` (converted to age via
  `ssh-to-age`).
- **User editing key** — `~/.config/sops/age/keys.txt` (mode `600`, persisted under
  `/persist`). `SOPS_AGE_KEY_FILE` is set in the Fish environment
  ([`home/common/fish.nix`](https://github.com/lowcache/volnixos/blob/main/home/common/fish.nix)),
  so editing needs no prefix:

```bash
sops edit nixos/host-secrets.yaml      # `sops <file>` alone just prints usage
```

## The two-place rule

> [!CAUTION] Secrets live in exactly two places
> 1. **sops-encrypted** — `nixos/host-secrets.yaml` / `nixos/vm-secrets.yaml` (committable
>    because encrypted).
> 2. **`/persist`** — never git-tracked.
>
> They are **never** placed under `dots/`, which is published publicly. As a safety net,
> `.gitignore` excludes `nixos/*.yaml`. Agent credentials (e.g. `~/.gemini`) live in persisted
> `$HOME` directories outside the repo, not under `dots/`.

**Adding a secret:** add it to `nixos/host-secrets.yaml`, then declare it in
`nixos/modules/secrets.nix`. A secret read by path goes in `sops.secrets` with an `owner`; one a tool
reads from the environment goes in `envSecrets`, with `wrap` unless several tools need it. Nothing is
hand-written into `home/shell.nix` any more.
