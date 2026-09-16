---
title: "Secrets — sops-nix + age"
description: "Secrets on NixOS with sops-nix and age: key placement on an impermanent host, what must persist for decryption to work at boot, and how rotation goes."
weight: 40
---

Secrets are managed with [`sops-nix`](https://github.com/Mic92/sops-nix) and **age** identities. The
encrypted stores `nixos/host-secrets.yaml` (host) and `nixos/vm-secrets.yaml` (MicroVM guests, wired
in `nixos/vms.nix`) are safe to commit; they are decrypted at activation into `/run/secrets/<name>`.

> [!NOTE] `vm-secrets.yaml` currently holds only a placeholder
> `nixos/vm-secrets.yaml` contains a single `placeholder` key — the file exists so the
> host-key-only creation rule stays live, not because a guest secret is in use today. There is no
> `nixos/secrets.yaml`; `nixos/.sops.yaml` still carries a legacy `secrets\.yaml$` rule, ordered
> last because its regex is unanchored, kept only for transition.

## Configuration

From [`nixos/modules/secrets.nix`](https://github.com/lowcache/volnixos/blob/main/nixos/modules/secrets.nix):

```nix
sops = {
  # relative to the module file — the yaml lives one level up, in nixos/
  defaultSopsFile = ../host-secrets.yaml;
  defaultSopsFormat = "yaml";
  age.sshKeyPaths = [ "/persist/etc/ssh/ssh_host_ed25519_key" ];
  secrets = {
    user_password = { neededForUsers = true; };
    root_password = { neededForUsers = true; };
    gemini_api_key = { owner = username; };
    gh_token = { owner = username; };
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
| `gemini_api_key`                       | `/run/secrets/gemini_api_key`                  | exported as `GEMINI_API_KEY` in Fish              |
| `gh_token`                             | `/run/secrets/gh_token`                        | exported as `GH_TOKEN` in Fish                    |
| `apify_api_key`                        | `/run/secrets/apify_api_key`                   | exported as `APIFY_API_KEY` in Fish               |
| `openrouter_api_key`                   | `/run/secrets/openrouter_api_key`              | exported as `OPENROUTER_API_KEY` in Fish          |
| `twine_api_key`                        | `/run/secrets/twine_api_key`                   | exported as `TWINE_API_KEY` in Fish               |
| `phone_agent_token`                    | `~/.config/phone-agent/token` (mode `0400`)    | exported as `PHONE_AGENT_TOKEN`; read by the client at that path |
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

The API keys are exported at shell start in
[`home/shell.nix`](https://github.com/lowcache/volnixos/blob/main/home/shell.nix) only if the runtime
secret file is readable:

```fish
test -r /run/secrets/gemini_api_key
and set -gx GEMINI_API_KEY (cat /run/secrets/gemini_api_key)
```

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

**Adding a secret:** add it to `nixos/host-secrets.yaml` → declare `sops.secrets.<name>` in
`nixos/modules/secrets.nix` → consume it (e.g. export in `home/shell.nix`).
