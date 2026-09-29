---
title: Secrets (SOPS + age)
tags: [component/secrets, component/security]
created: 2026-09-17
---

# Secrets (SOPS + age)

> [!info] Scope
> Which files hold which credentials (by key name only: SOPS leaves map keys
> in plaintext and encrypts only the values), which consumer reads which
> file, and which quality gate covers which leak path. No decrypted value
> appears here.

## The recipient binding

```yaml
creation_rules:
  - path_regex: '.*\.sops\.yaml$'
    age: age1zdcnr28uvud0k57mxeqvs8t07jrk7tz6hpfgauw0twdquwfh4yzshq4j7n
```
(`.sops.yaml`, full file)

One rule, one `age` recipient, applied to every path in the repo matching
`*.sops.yaml`. This is the entire trust root: the matching private key
(`SOPS_AGE_KEY_FILE`, per the root README's quickstart) decrypts every
secret in the repo, and nothing else does. Adding a second recipient means
adding it to this rule and re-encrypting each file with `sops updatekeys`.

## What each file holds, and who reads it

```
secrets/
├── pve.sops.yaml              # Proxmox API tokens (terraform, ansible, prometheus consumers) + pve_password
├── proxmox_id.sops.yaml       # SSH private key Terraform uses against the PVE host
├── proxmox_id.pub             # its public half
├── ansible_id.sops.yaml       # SSH private key for the guest automation account
├── ansible_id.pub             # its public half, seeded into guests via cloud-init
├── cloudflare.sops.yaml       # Cloudflare API token
└── media_platform.sops.yaml   # Application API keys and service credentials
```

Key *names* referenced by consuming code (every value is `ENC[...]`
ciphertext in the file):

| File | Keys | Consumer |
|---|---|---|
| `proxmox_id.sops.yaml` | `ssh_private_key` | Terraform, `_base` and `deployments/media/infrastructure`, through `ephemeral.sops_file.proxmox_id.data["ssh_private_key"]` in each stack's `providers.tf`. The `bpg/proxmox` provider uses this key over SSH against the Proxmox **host**, not a guest. |
| `ansible_id.pub` | (plaintext public key) | Terraform's `deployments/media/infrastructure/main.tf` reads it with `file()` and passes it to the `proxmox_vm` module as `ssh_public_key`; the cloud-init template writes it into the guest's `authorized_keys`. |
| `ansible_id.sops.yaml` | `ssh_private_key` | Encrypted copy of the private key that `ansible.cfg`'s `private_key_file = ~/.ssh/ansible_id` expects on the control machine. No code decrypts it at runtime; it provides the key's canonical, versioned home. |
| `cloudflare.sops.yaml` | `cloudflare_api_key` | Terraform only, through `ephemeral.sops_file.cloudflare` in `deployments/media/infrastructure/providers.tf` (provider auth). The DNS zone ID is a plain tfvar (`cloudflare_zone_id`). |
| `pve.sops.yaml` | `pve_ansible_api_url`, `pve_ansible_api_user_name`, `pve_ansible_api_token_id`, `pve_ansible_api_token_secret` | Ansible's **dynamic inventory plugin** (`ansible/inventory/00_inv.proxmox.yml`), through `community.sops.sops` lookups against the `vault/pve.sops.yaml` symlink |
| `pve.sops.yaml` (same file) | `pve_prometheus_api_user_name`, `pve_prometheus_api_token_id`, `pve_prometheus_api_token_secret` | The `observability_node` role's `templates/pve-exporter/pve.yml.j2`: a **separate, third token** scoped to what `pve-exporter` reads |
| `media_platform.sops.yaml` | `media_platform_{prowlarr,sonarr,radarr,sabnzbd}_api_key`, `media_platform_arr_webapp_{username,password}`, plus others referenced in role templates | Both Ansible (role templates, with `no_log: true` on every task that renders them) **and** Terraform's `deployments/media/application` stack, through `data.sops_file.media_platform` |

`pve.sops.yaml` holds three separate API tokens, one per consumer:
`pve_terraform_api_*`, `pve_ansible_api_*`, and `pve_prometheus_api_*`. See
[Engineering decisions](engineering-decisions.md) for the rationale
(blast-radius containment, one-file rotation).

## `media_platform.sops.yaml` feeds both tools from one source

The same API-key values appear in three places without anyone typing them
twice:

1. Ansible's `media_platform` role renders them into the Docker Compose
   environment (`PROWLARR__API__KEY`, `RADARR__API__KEY`,
   `SONARR__API__KEY`) in `roles/media_platform/templates/docker-compose.yml.j2`.
2. `configarr.yml.j2` references them through Configarr's `!env`
   indirection (`api_key: !env SONARR__API__KEY`). Configarr reads the value
   from its container's environment at runtime, so the rendered YAML on disk
   never contains it.
3. Terraform's `application` stack configures the *arr web UIs and
   Prowlarr's application links with
   `data.sops_file.media_platform.data["media_platform_sonarr_api_key"]`
   and its siblings (`workspace/deployments/media/application/main.tf`).

All three read one encrypted source, so rotating an API key is a single-file
edit that stays consistent across the running containers and the
Terraform-managed application config.

## Where decryption happens

**Terraform** uses the `carlpett/sops` provider in two forms:

- **`ephemeral "sops_file"`** in `_base` and `deployments/media/infrastructure`.
  Terraform decrypts the file in memory for the duration of the run and never
  records the value in the plan or state. Ephemeral values can feed provider
  configuration, locals, and write-only arguments, which covers the Proxmox
  SSH key and the Cloudflare API token.
- **`data "sops_file"`** in `deployments/media/application`. Its secrets feed
  resource arguments (`authentication.password`, `api_key`, and similar) on
  the `devopsarr` providers. Those providers mark the attributes `sensitive`,
  which hides them from plan output, but offer no write-only variants, so the
  values persist in that stack's state. Local, gitignored state keeps them
  off shared storage (see [Provisioning](provisioning.md)).

**Ansible** uses the `community.sops.sops` lookup plugin, called directly in
the inventory (`00_inv.proxmox.yml`), and the `community.sops.sops` **vars
plugin**, enabled in `ansible.cfg`
(`vars_plugins_enabled = host_group_vars, community.sops.sops`). Symlinks
place the encrypted files in the inventory tree rather than duplicating
them:

```
inventory/group_vars/media_platform.sops.yml -> ../../../secrets/media_platform.sops.yaml
vault/pve.sops.yaml                          -> ../../secrets/pve.sops.yaml
```

`secrets/` stays the one place a credential physically lives; everything else
points at it. Both tools decrypt in memory at load or plan time and write no
plaintext file.

## Which gate covers which leak path

| Leak path | Gate | Runs |
|---|---|---|
| A `*.sops.yaml` file committed unencrypted | `sops` hook (`squat/pre-commit-sops`), matching `\.sops\.ya?ml$`; fails when SOPS metadata or `ENC[...]` markers are missing | Local pre-commit and CI `hooks` job |
| A private key file (PEM and similar) committed anywhere in the tree | `detect-private-key` hook | Local pre-commit and CI `hooks` job |
| A secret value pasted in plaintext into any file, at any point in history | `gitleaks`, with `fetch-depth: 0` so it scans the **entire git history** | CI `gitleaks` job |

`yamllint` and `ansible-lint` exclude `**/*sops.yaml` and `**/*sops.yml`
(`.yamllint`, `.ansible-lint`), so the linters never parse ciphertext; the
`sops` hook alone checks encryption state. [CI and quality
gates](ci-quality-gates.md) lists every job and hook.
