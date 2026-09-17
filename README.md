# Homelab Infrastructure

[![CI](https://github.com/RashunB/Homelab-Infra/actions/workflows/ci.yml/badge.svg)](https://github.com/RashunB/Homelab-Infra/actions/workflows/ci.yml)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.15-7B42BC?logo=terraform&logoColor=white)](https://developer.hashicorp.com/terraform)
[![Ansible](https://img.shields.io/badge/Ansible-core-EE0000?logo=ansible&logoColor=white)](https://docs.ansible.com/)
[![Proxmox VE](https://img.shields.io/badge/Proxmox-VE-E57000?logo=proxmox&logoColor=white)](https://www.proxmox.com/)
[![SOPS](https://img.shields.io/badge/secrets-SOPS%20%2B%20age-2ea44f)](https://github.com/getsops/sops)

Provision and configure a homelab on Proxmox VE with Terraform and Ansible —
bare metal to a monitored, GPU-accelerated application stack, driven entirely
by code.

- **Terraform** provisions VMs on Proxmox VE.
- **Ansible** configures them, using a dynamic inventory built from
  Terraform-applied tags — no hardcoded host list to maintain.
- Every change is linted, validated, security-scanned, and secret-scanned in
  CI before it merges.
- No plaintext secret ever touches git.

Jump to [Quickstart](#quickstart) to bring up a deployment.

---

## Highlights

| | |
|---|---|
| **Provisioning** | Terraform against the Proxmox VE API, layered into a shared base, a reusable VM module, and per-deployment stacks |
| **Configuration** | Ansible with 7 first-party roles, all validated by `argument_specs` |
| **Inventory** | Dynamic, from live Proxmox tags. Terraform writes the tags, Ansible reads them. No host list to maintain |
| **Secrets** | SOPS with `age`, consumed natively by both Terraform (provider) and Ansible (vars plugin) |
| **Observability** | Prometheus, Loki, Grafana, Alloy, cAdvisor, node/smartctl/PVE exporters, hub-and-spoke across every host |
| **Hardware** | Intel GPU passed through to the VM via PCI hardware mapping for VA-API transcoding |
| **Quality gates** | 8 CI jobs plus a pre-commit suite: lint, format, validate, IaC misconfiguration scan, full-history secret scan |

---

## Architecture

Color key used across every diagram below: 🟣 control-plane tooling ·
🟠 Proxmox VE / VM workloads · 🔵 per-host agents · 🟢 secrets (SOPS + age) ·
⚫ CI automation · 🔴 blocked / failure path.

### Provisioning flow

```mermaid
flowchart LR
    subgraph CTRL["Control plane"]
        TF["Terraform"]
        ANS["Ansible"]
        SOPS[("SOPS + age<br/>secrets/")]
    end

    subgraph PVE["Proxmox VE host"]
        TPL["Cloud image templates<br/>Ubuntu 24.04 / Rocky 9"]
        VM["Guest VMs<br/>tagged on creation"]
        GPU["PCI hardware mapping<br/>Intel GPU"]
    end

    SOPS -.->|sops_file data source| TF
    SOPS -.->|community.sops vars plugin| ANS
    TF -->|downloads image, builds| TPL
    TPL -->|linked clone + cloud-init| VM
    GPU -->|hostpci passthrough| VM
    VM -->|"proxmox inventory plugin: tags become groups"| ANS
    ANS -->|Docker Compose workloads| VM

    classDef ctrl fill:#7B42BC,color:#fff,stroke:#5a2f8f
    classDef secrets fill:#2ea44f,color:#fff,stroke:#1f7a37
    classDef proxmox fill:#E57000,color:#fff,stroke:#b35800
    class TF,ANS ctrl
    class SOPS secrets
    class TPL,VM,GPU proxmox
```

### Runtime topology

```mermaid
flowchart TB
    subgraph CONTROL["control (observability_control)"]
        PROM["Prometheus"]
        LOKI["Loki"]
        GRAF["Grafana"]
        DOZ["Dozzle"]
    end

    subgraph MEDIA["media-1 (media_platform)"]
        JF["Jellyfin"]
        ARR["Prowlarr / Sonarr / Radarr<br/>Bazarr / Configarr"]
        SAB["SABnzbd"]
        SEERR["Seerr"]
        LVM[("LVM volume<br/>/opt/media_platform")]
    end

    subgraph NODES["Every managed host (observability_node)"]
        NE["node-exporter"]
        CAD["cAdvisor"]
        ALLOY["Grafana Alloy"]
        SMART["smartctl-exporter"]
        PVEX["pve-exporter (Proxmox only)"]
    end

    NE -->|scrape| PROM
    CAD -->|scrape| PROM
    SMART -->|scrape| PROM
    PVEX -->|scrape| PROM
    ALLOY -->|push logs| LOKI
    PROM --> GRAF
    LOKI --> GRAF
    MEDIA --- NODES

    classDef ctrl fill:#7B42BC,color:#fff,stroke:#5a2f8f
    classDef proxmox fill:#E57000,color:#fff,stroke:#b35800
    classDef node fill:#0969da,color:#fff,stroke:#0550ae
    class PROM,LOKI,GRAF,DOZ ctrl
    class JF,ARR,SAB,SEERR,LVM proxmox
    class NE,CAD,ALLOY,SMART,PVEX node
```

### CI / secrets trust flow

```mermaid
flowchart TD
    DEV["Commit<br/>secrets/*.sops.yaml stays encrypted"]
    PC["pre-commit<br/>sops · detect-private-key · lint"]
    BLOCK["Blocked — fix and re-push"]
    PUSH["git push"]
    CI["GitHub Actions<br/>8 quality gates"]
    GATE{"All gates pass?"}
    MERGE["Merge to main"]
    APPLY["terraform apply /<br/>ansible-playbook"]
    DECRYPT["SOPS + age decrypt<br/>in memory only, never to disk"]

    DEV --> PC
    PC -->|encrypted, clean| PUSH
    PC -->|plaintext secret or lint fail| BLOCK
    PUSH --> CI
    CI --> GATE
    GATE -->|yes| MERGE
    GATE -->|no| BLOCK
    MERGE --> APPLY
    APPLY --> DECRYPT

    classDef ctrl fill:#7B42BC,color:#fff,stroke:#5a2f8f
    classDef secrets fill:#2ea44f,color:#fff,stroke:#1f7a37
    classDef ci fill:#24292f,color:#fff,stroke:#000
    classDef blocked fill:#cf222e,color:#fff,stroke:#82071e
    class DEV,PUSH,MERGE,APPLY ctrl
    class PC,CI,GATE ci
    class DECRYPT secrets
    class BLOCK blocked
```

This is the guarantee behind [Secrets management](#secrets-management) and
[Quality gates](#quality-gates) below: a decrypted secret exists only in the
memory of the process applying it, never on disk and never in git history.

---

## Repository layout

```
.
├── workspace/                  # Terraform  ->  see workspace/README.md
│   ├── modules/proxmox_vm/     #   reusable VM module (cloud-init, disks, PCI passthrough)
│   ├── infrastructure/_base/   #   shared, long-lived: OS templates, GPU hardware mapping
│   └── deployments/media/
│       ├── infrastructure/     #   the media VM + Cloudflare DNS record
│       └── application/        #   *arr application config as code (post-Ansible)
│
├── ansible/                    # Ansible  ->  see ansible/README.md
│   ├── inventory/              #   layered: dynamic Proxmox plugin + static overlays
│   ├── roles/                  #   7 first-party roles + 2 vendored
│   ├── template_role/          #   galaxy skeleton enforcing the repo's role conventions
│   └── site.yml                #   top-level entry point
│
├── secrets/                    # SOPS-encrypted, age-recipient controlled
├── .github/workflows/ci.yml    # 8 quality gates
├── .pre-commit-config.yaml     # the same gates, locally, before you push
└── trivy.yaml / .ansible-lint / .yamllint
```

The two halves are documented separately because they solve different problems
and have different lifecycles:

- **[`workspace/README.md`](workspace/README.md)** covers provisioning: state,
  stack layering, the module contract, and GPU passthrough.
- **[`ansible/README.md`](ansible/README.md)** covers configuration: inventory
  composition, the role catalog, variable conventions, and secret injection.

---

## Quickstart

### Prerequisites

| Tool | Notes |
|---|---|
| Terraform `>= 1.15` | Pinned provider versions, lockfiles committed |
| `ansible-core` | Collections installed from `ansible/requirements.yml` |
| `sops` + `age` | You need the private key matching the recipient in `.sops.yaml` |
| Proxmox VE | API token for Terraform, a second token for Ansible inventory |
| `pre-commit` | Optional locally, enforced in CI |

Tooling installers for the Terraform-side binaries (trivy, terraform-docs,
tflint) are collected in [`terraform_precommit.txt`](terraform_precommit.txt).

### 1. Decrypt-capable environment

```bash
export SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt
sops -d secrets/pve.sops.yaml >/dev/null   # smoke test
```

### 2. Build the shared base (once)

```bash
terraform -chdir=workspace/infrastructure/_base init
terraform -chdir=workspace/infrastructure/_base apply
```

This downloads the Ubuntu 24.04 and Rocky 9 cloud images, converts them into
Proxmox templates, and registers the GPU hardware mapping. Both templates carry
`prevent_destroy`.

### 3. Provision a deployment

```bash
terraform -chdir=workspace/deployments/media/infrastructure init
terraform -chdir=workspace/deployments/media/infrastructure apply
```

### 4. Configure everything

```bash
cd ansible
ansible-galaxy install -r requirements.yml
ansible-playbook site.yml
```

No inventory file needs editing to make the new VM reachable: Terraform tagged it,
the Proxmox inventory plugin discovers it and turns its tags into groups, and it
joins the monitored fleet through group children. Static overlays in
`ansible/inventory/` assign it to a specific workload group.

### 5. Apply application-level config

```bash
terraform -chdir=workspace/deployments/media/application init
terraform -chdir=workspace/deployments/media/application apply
```

Runs last by design, because it configures services that Ansible has to have
started first.

---

## Quality gates

Every push and pull request runs these. The same checks are available locally
through `pre-commit run --all-files`.

| Job | What it protects |
|---|---|
| `ansible-lint` | Role and playbook correctness, idempotency smells, FQCN usage |
| `yaml-lint` | YAML style across the whole repo |
| `terraform-static` | `terraform fmt -check -recursive` plus recursive TFLint |
| `terraform-validate` | Matrix `init -backend=false` + `validate` across all three stacks |
| `trivy` | IaC misconfiguration scanning of `workspace/` |
| `gitleaks` | Secret scanning across the **full git history**, not just the diff |
| `actionlint` | The workflow files themselves |
| `hooks` | Whitespace/EOF hygiene, private key detection, verifies every `*.sops.yaml` is actually encrypted |

All third-party actions are pinned to commit SHAs rather than tags.

---

## Secrets management

- No plaintext secret is ever committed. `.sops.yaml` binds every
  `*.sops.yaml` file in the repo to a single `age` recipient.
- Both Terraform and Ansible read the encrypted files directly — there is no
  decrypt-to-disk step and no `.env` to leak.

```
secrets/
├── pve.sops.yaml              # Proxmox API tokens (terraform, ansible, prometheus: one each)
├── proxmox_id.sops.yaml       # SSH key Terraform uses against the PVE node
├── ansible_id.sops.yaml       # SSH keypair seeded into guests via cloud-init
├── cloudflare.sops.yaml       # Cloudflare API token + zone ID
└── media_platform.sops.yaml   # Application API keys and service credentials
```

- **Terraform** reads them with the `carlpett/sops` provider as a `sops_file` data source.
- **Ansible** reads them with the `community.sops` vars plugin and lookup, wired
  in through symlinks under `inventory/group_vars/`.
- **CI** enforces it: the `sops` pre-commit hook fails on any unencrypted
  `*.sops.yaml`, `detect-private-key` blocks stray keys, and `gitleaks` audits
  the entire history.

- Separate API tokens per consumer: keeps blast radius small and makes
  credential rotation a one-file change.

---

## Engineering decisions

Rules this repo follows, and why — read these before proposing a change that
seems to cut a corner.

**Never call Ansible from Terraform, or create VMs from Ansible.** Provisioning
and configuration stay in separate tools with independent state — no
`local-exec` calling `ansible-playbook`, no Ansible module creating VMs.
- **How:** the seam is Proxmox VM tags. Terraform's `vm_tag_list` becomes a
  `keyed_groups` entry in Ansible's inventory plugin, which becomes a playbook
  target. To add a host to a role, change its tag — not an inventory file.

**Discover templates by tag, not by VM ID.** The `proxmox_vm` module queries
`proxmox_virtual_environment_vms` filtered on
`["template", var.template_os_tag]`.
- **Why:** rebuilding a template doesn't require touching every deployment
  stack that consumes it.

**Keep `infrastructure` and `application` as separate Terraform stacks per
deployment.**
- **Why:** they have different dependency graphs — infrastructure talks to
  Proxmox and Cloudflare, application talks to service APIs that only exist
  after Ansible has started the containers.
- **Benefit:** a failed application apply can't block a VM rebuild, and plan
  times stay honest.

**Use two Proxmox provider aliases: a scoped API token by default, `root`
username/password only where required.**
- **Why:** VM cloning and template creation need privileges the API token
  can't hold. Confining the elevated credential to exactly those resources
  keeps it out of the rest of the repo.

**Let `pcie_devices` drive the machine type — don't set it manually.** A
non-empty `pcie_devices` switches the VM to `q35` + `ovmf` and attaches an EFI
disk automatically.
- **Why:** PCIe passthrough doesn't work on the `i440fx` + SeaBIOS default.
  One variable controls both, so there's no incompatible combination to get
  wrong.

**Ship `meta/argument_specs.yml` with every first-party role.**
- **Why:** bad input fails at role entry with a typed error instead of
  halfway through a play. It's also what lets `lvm_storage` safely accept a
  nested list-of-dicts describing entire volume groups.

**Prefix role defaults (`media_platform_*`, `observability_node_*`) and map
shared values onto them from `group_vars`.**
- **Why:** one place to change a port, no collisions between roles.

---

## Known gaps and roadmap

Deliberately listed. These are the things a reviewer would ask about.

- [ ] **Remote state.** Terraform state is currently local. Migrating to a
      locking backend is the highest-value next change, and the prerequisite
      for running `apply` from CI.
- [ ] **CI is plan-only.** Workflows validate and scan but never apply. Automated
      `plan` output on pull requests is the next step.
- [ ] **Role documentation.** Role `README.md` files are still galaxy skeleton
      boilerplate. The `argument_specs.yml` files are the accurate reference
      until those are written.
- [ ] **No test harness.** Molecule scenarios for the first-party roles, plus
      `terraform test` for the module, would close the loop.
- [ ] **TLS.** Proxmox providers run with `insecure = true` against the lab CA,
      and services are served over plain HTTP behind the LAN boundary.
- [ ] **Re-enable the full pre-commit CI job** and the `terraform-docs` diff
      check, both currently commented out in `ci.yml` (the docs action generates
      output that does not match local runs).
- [ ] **Backups.** No automated backup or restore path for application state or
      Terraform state yet.

---

## License

Personal project. No license granted; see the repository owner.
