---
title: Secrets (SOPS + age)
tags: [component/secrets, component/security]
created: 2026-09-17
---

# Secrets (SOPS + age)

> [!info] Scope
> This note does not read or reproduce any decrypted secret value. It maps
> which files hold which credentials (by key name only, since SOPS leaves
> map keys in plaintext by design — only the values are encrypted), which
> consumer reads which file, and exactly what the quality gates do and don't
> catch. `secrets/*.sops.yaml` is otherwise treated as opaque, per the
> instruction this vault was built under.

## The recipient binding

```yaml
# .sops.yaml
creation_rules:
  - path_regex: '**\.sops\.yaml$'
    age: age1zdcnr28uvud0k57mxeqvs8t07jrk7tz6hpfgauw0twdquwfh4yzshq4j7n
```
(`.sops.yaml`, full file)

One rule, one `age` recipient, applied to every path in the repo matching
`*.sops.yaml`. This is the entire trust root: anything encrypted for this
recipient can only be decrypted by whoever holds the matching private key
(`SOPS_AGE_KEY_FILE`, per the root README's quickstart). There is no
per-file or per-team recipient split today — one key opens every secret in
the repo.

## What's in each file, and who reads it

```
secrets/
├── pve.sops.yaml              # Proxmox API tokens (terraform, ansible, prometheus consumers)
├── proxmox_id.sops.yaml       # SSH key Terraform uses against the PVE host itself
├── ansible_id.sops.yaml       # SSH keypair seeded into guests via cloud-init
├── cloudflare.sops.yaml       # Cloudflare API token + zone ID
└── media_platform.sops.yaml   # Application API keys and service credentials
```
(`workspace/README.md:284-292`, confirmed against actual `ls` of `secrets/`)

Key *names* referenced by consuming code (not values — every value below is
`ENC[...]` ciphertext in the file itself):

| File | Keys referenced in source | Consumer |
|---|---|---|
| `proxmox_id.sops.yaml` | `ssh_private_key` | Terraform, both `_base` and every `proxmox`-facing deployment stack — `data.sops_file.proxmox_id.data["ssh_private_key"]` (`workspace/infrastructure/_base/providers.tf:19-25`, `workspace/deployments/media/infrastructure/providers.tf:23-29`). This is the key the `bpg/proxmox` provider uses over SSH against the Proxmox **host**, not a guest. |
| `ansible_id.sops.yaml` | `ssh_public_key` | Terraform's `deployments/media/infrastructure/main.tf:1-3,10` reads the **public** half and threads it into the `proxmox_vm` module as `ssh_public_key`, which the cloud-init template embeds in the new guest's `authorized_keys`. The matching private key is what `ansible.cfg`'s `private_key_file = ~/.ssh/ansible_id` expects to find locally — Ansible never reads this file directly, it's a pre-generated keypair on disk that Terraform's half is sourced from SOPS. |
| `cloudflare.sops.yaml` | `cloudflare_api_key`, `cloudflare_zone_id` | Terraform only — `deployments/media/infrastructure/providers.tf:60-66` (provider auth) and `main-cf.tf:2` (zone ID for the DNS record resource) |
| `pve.sops.yaml` | `pve_ansible_api_user_name`, `pve_ansible_api_token_id`, `pve_ansible_api_token_secret` | Ansible's **dynamic inventory plugin** (`ansible/inventory/00_inv.proxmox.yml:4-6`), via `community.sops.sops` lookup against the `vault/pve.sops.yaml` symlink |
| `pve.sops.yaml` (same file) | `pve_prometheus_api_user_name`, `pve_prometheus_api_token_id`, `pve_prometheus_api_token_secret` | The `observability_node` role's `pve-exporter/pve.yml.j2` template (`ansible/roles/observability_node/templates/pve-exporter/pve.yml.j2`) — a **separate, third token** from the same file, scoped to whatever Prometheus's `pve-exporter` needs read access to |
| `media_platform.sops.yaml` | `media_platform_{prowlarr,sonarr,radarr,sabnzbd}_api_key`, `media_platform_arr_webapp_{username,password}`, plus others referenced in role templates | Both Ansible (role templates, `no_log: true` on every task that renders them) **and** Terraform's `deployments/media/application` stack, via `data.sops_file.media_platform` |

`pve.sops.yaml` is the one file with three genuinely separate credentials —
`terraform`, `ansible`, and `prometheus` — each its own API token, confirmed
by the distinct `pve_ansible_api_*` vs. `pve_prometheus_api_*` key prefixes
referenced across `00_inv.proxmox.yml` and `pve.yml.j2`. See
[[engineering-decisions]] for the rationale (blast-radius containment,
one-file rotation).

## `media_platform.sops.yaml` feeds *both* tools identically — that's the point

The same API-key values under `media_platform.sops.yaml` show up in three
independent places without ever being typed by hand more than once:

1. Ansible's `media_platform` role renders them into the Docker Compose
   environment (`PROWLARR__API__KEY`, `RADARR__API__KEY`,
   `SONARR__API__KEY` — `roles/media_platform/templates/docker-compose.yml.j2`).
2. The same values are templated into `configarr.yml.j2`'s config via
   Configarr's own `!env` indirection (`api_key: !env SONARR__API__KEY`) —
   so Configarr reads the value from its container's environment at runtime,
   never storing it a second time inside the YAML file on disk.
3. Terraform's `application` stack configures the *arr web UIs and Prowlarr's
   application links using `data.sops_file.media_platform.data["media_platform_sonarr_api_key"]`
   directly (`workspace/deployments/media/application/main.tf`).

Because all three read the one encrypted source of truth, rotating an API
key is a single-file edit that stays consistent across the running
containers and the Terraform-managed application config — there's no
manual copy-paste step between "the container's env var" and "what
Terraform tells Prowlarr to expect."

## What actually decrypts, and where

- **Terraform**: `carlpett/sops` provider, `sops_file` data source, resolved
  at `plan`/`apply` time. The decrypted value lives only in Terraform's
  in-memory plan graph (and, notably, in **state** — state is not
  encrypted at rest by this setup; see [[provisioning]]'s note on state
  being local and gitignored, which is the only thing currently keeping
  plaintext-in-state off disk in a shared location).
- **Ansible**: `community.sops.sops` lookup plugin, invoked either directly
  in inventory (`00_inv.proxmox.yml`) or via the `community.sops.sops`
  **vars plugin**, enabled in `ansible.cfg`
  (`vars_plugins_enabled = host_group_vars, community.sops.sops`). Encrypted
  group vars are **symlinked** into the inventory tree rather than
  duplicated:
  ```
  inventory/group_vars/media_platform.sops.yml -> ../../../secrets/media_platform.sops.yaml
  vault/pve.sops.yaml                          -> ../secrets/pve.sops.yaml
  ```
  (confirmed via `readlink -f` on both symlinks) — `secrets/` stays the one
  place a credential physically lives; everything else is a pointer.

In both cases, decryption happens in memory at load/plan time. Nothing is
ever written to disk in plaintext by design, and there's no `.env` file to
accidentally leak.

## The orphaned Ansible Vault file — a real gap, not SOPS

> [!bug] `ansible/roles/observability_node/files/prometheus/pve.yml` is Ansible-Vault-encrypted, not SOPS, and isn't the file that's actually used
> The role's real PVE-exporter config comes from
> `templates/pve-exporter/pve.yml.j2`, rendered at
> `{{ observability_node_root_dir }}/pve-exporter/pve.yml` by
> `tasks/pve_exporter.yml`. But sitting alongside it in the role tree is a
> **second, tracked-in-git file**,
> `ansible/roles/observability_node/files/prometheus/pve.yml`, which opens
> with `$ANSIBLE_VAULT;1.2;AES256;pve` — this is `ansible-vault`-format
> encryption, a completely different mechanism from the SOPS pipeline this
> whole repo is built around. It is `git ls-files`-tracked (confirmed), so
> it's not an accident of a local checkout.
>
> Why this matters for the gate analysis below: the `sops` pre-commit hook
> only matches `'\.sops\.ya?ml$'` (`.pre-commit-config.yaml:49-51`) — this
> file doesn't match that pattern, so the hook never inspects it. It's
> AES256 ciphertext either way, so this isn't a live leak, but it means the
> repo has one file that a secret-hygiene reviewer would have to know to
> treat differently, and no tooling flags its existence as unusual. If
> anyone ever tried to "fix" it by decrypting it with `ansible-vault` and
> recommitting the plaintext version to "clean it up," nothing in CI would
> stop that commit — see the gap table below.

## Precisely which gate catches what

| Threat | Catches it? | Mechanism |
|---|---|---|
| A `secrets/*.sops.yaml` file committed **unencrypted** | **Yes** | `sops` pre-commit hook (`squat/pre-commit-sops`), run in CI's `hooks` job — parses the file and fails if SOPS metadata / `ENC[...]` markers aren't present |
| A private key file (PEM, etc.) committed anywhere in the tree | **Yes** | `detect-private-key` hook, same `hooks` CI job |
| A secret value pasted in **plaintext** into a `.tf`, `.yml`, or any non-`*.sops.yaml` file, anywhere in history | **Yes, but only in full-history scan, not pre-commit** | `gitleaks`, a dedicated CI job with `fetch-depth: 0` — scans the **entire git history**, not just the diff. This job has no local pre-commit equivalent at all. |
| A secret value pasted in plaintext into a file, **within the same PR/commit that also gets rejected on other grounds before push** | **Not guaranteed locally** | Pre-commit is optional to run locally (see [[ci-quality-gates]]); if you skip it, nothing stops you from `git push` with a plaintext secret sitting in a regular file, until CI's `gitleaks` job runs |
| The Ansible-Vault file above, if it were ever re-encrypted incorrectly or accidentally decrypted to plaintext and recommitted | **No** | Doesn't match `*.sops.yaml`, so the `sops` hook ignores it; `yamllint` and `ansible-lint` also explicitly **exclude** `**/*sops.yaml` and `**/*sops.yml` patterns (`.yamllint:9-14`, `.ansible-lint:14-20`) — but this file's actual name (`pve.yml`, no `sops` in the name) means it was never excluded from `yamllint`/`ansible-lint` scrutiny either; it would be treated as an ordinary YAML file, and both linters would almost certainly choke on its Vault header, yet neither is a secret-content check to begin with |
| A secret decrypted to a temp file during local development and left on disk | **No** | Nothing in this repo's tooling watches the filesystem outside the git tree; this is purely operator discipline |

> [!warning] "No plaintext secret ever touches git" is a design goal, not a guarantee enforced on every push
> The root README states this as a property of the system, and the design
> genuinely supports it — SOPS is used correctly for every secret currently
> in `secrets/`. But the *enforcement* of that property, for anything
> outside `secrets/*.sops.yaml` specifically, depends on `gitleaks`, which
> only runs in CI, after push. Locally, before push, only whatever you
> personally choose to run via `pre-commit run --all-files` stands between
> a plaintext paste and the remote. See [[ci-quality-gates]] for the full
> breakdown of what's optional versus enforced.

## Check your understanding

- [ ] How many separate credentials live inside `pve.sops.yaml`, and what's
      the naming pattern that distinguishes them?
- [ ] Why does `secrets/ansible_id.sops.yaml`'s key get read by *Terraform*,
      not Ansible — and what does Ansible use instead to authenticate the
      same keypair?
- [ ] Trace one API key from `media_platform.sops.yaml` through to three
      different places it ends up being used — what keeps all three in sync?
- [ ] What's the one `.sops.yaml` rule that governs every encrypted file in
      the repo, and what would happen if a second `age` recipient needed
      access?
- [ ] Which pre-commit/CI check would catch a plaintext secret pasted into a
      `.tf` file, and does it run before or after `git push`?
- [ ] What is `ansible/roles/observability_node/files/prometheus/pve.yml`,
      why doesn't the `sops` hook ever look at it, and is it actually used by
      any task?
- [ ] Where does a decrypted secret value physically exist at any point in
      the Terraform apply lifecycle, and is that location itself protected?
