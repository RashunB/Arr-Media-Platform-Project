# Terraform (`terraform/`)

Provisioning layer. Everything that creates or destroys infrastructure lives
here: Proxmox VE guests, OS templates, PCI hardware mappings, DNS records, and
application-level configuration exposed through service APIs.

Configuration of the operating system and the workloads inside these VMs is the
other half of the repo, in [`../ansible`](../ansible/README.md).

---

## Layering model

```
terraform/
├── infrastructure/
│   └── _base/                      # shared, long-lived, cluster-wide primitives
└── deployments/
    └── media/
        ├── infrastructure/         # the VM(s) and their DNS, per deployment
        └── application/            # service configuration, applied after Ansible

github.com/RashunB/terraform-proxmox-module
└── proxmox_vm                      # VM factory, consumed by git URL at a pinned SHA
```

Each layer has its own blast radius and change frequency. The VM module sits
outside this repo and has its own release cadence.

### `infrastructure/_base` (shared, rarely changes)

Cluster-wide primitives that every deployment consumes:

| Resource | Purpose |
|---|---|
| `proxmox_download_file.ubuntu24` / `.rocky9` | Pulls upstream cloud images into the Proxmox file datastore |
| `proxmox_virtual_environment_vm.*_template` | Converts each image into a tagged Proxmox template |
| `proxmox_hardware_mapping_pci.transcoding_gpu` | Cluster-level PCI mapping for the Intel GPU |

Each template carries `template` plus an OS tag (Ubuntu 24.04 also carries
`default`) and `lifecycle { prevent_destroy = true }`. Downloads set
`overwrite = false` so a re-apply never silently re-pulls a multi-gigabyte image.

Apply this module or have a target VM/node prepared. Not applying this will cause the rest of the infrastructure deployments to fail.

### `proxmox_vm` (the module contract)

Every deployment builds its VMs through one module, maintained in
[RashunB/terraform-proxmox-module](https://github.com/RashunB/terraform-proxmox-module).
A deployment stack references it by commit SHA:

```hcl
module "media_vm" {
  source = "git::https://github.com/RashunB/terraform-proxmox-module.git?ref=<sha>"
  # ...
}
```

The SHA pin makes every module upgrade an explicit, reviewable diff in the
consuming stack. Module changes land in the module repository first, then the
`?ref=` here moves to the new commit. The module sets provider version floors
(`>= 0.113.1`) and leaves exact pins to the root stacks that call it.

The module handles:

| Concern | Behavior |
|---|---|
| Template discovery | Queries `proxmox_virtual_environment_vms` filtered on `["template", var.template_os_tag]` and `template = true`, then clones the match. A `lifecycle.precondition` requires exactly one match and fails the plan with every candidate's name otherwise. No stack hardcodes a VM ID |
| Cloud-init | Renders a per-VM snippet from the module's `templates/cloud-init.yml.tpl` (override with `cloud_init_user_data_path`), injecting hostname, domain, default user, and the SSH public key |
| Naming | `vm_count` + `vm_count_offset` produce `prefix-1`, `prefix-2`, and so on, so a second deploytment in an existing group starts at the next index |
| Tags | Merges `vm_default_tag_list` (`terraform`), the caller's `vm_tag_list`, `vm_group`, and `vm_name_prefix` into a deduplicated set. Ansible's dynamic inventory reads these tags |
| Disks | `additional_disks`, a `map(object(...))` keyed by interface name. An entry creates a new disk or, with `path_in_datastore`, attaches an existing one |
| Network | `network_device_bridge` (default `vmbr0`), `network_device_model` (default `virtio`), and `dns_servers` (default `["1.1.1.1", "8.8.8.8"]`). Addressing defaults to DHCP |
| PCIe passthrough | `pcie_devices`, covered below. Each entry sets `pcie` and `rombar` independently |

Outputs `vm_id` and `primary_ip` are lists with one element per VM. On DHCP,
`primary_ip` is the first non-loopback address the guest agent reports. The
media deployment's Cloudflare record uses `primary_ip[0]`.

#### GPU passthrough is one variable

A non-empty `pcie_devices` map flips three settings at once:

```hcl
machine = local.gpu_passthrough ? "q35" : "pc"
bios    = local.gpu_passthrough ? "ovmf" : "seabios"
# ...plus a dynamically-created efi_disk block
```

PCIe passthrough requires `q35` and OVMF/UEFI, and OVMF requires an EFI disk.
Coupling all three to one input removes the most common way to build a
passthrough VM wrong.

### `deployments/<name>/` (per workload)

Each deployment splits into two stacks with different dependencies and
different failure modes.

**`infrastructure/`** calls the `proxmox_vm` module to create the VM, then
creates a Cloudflare `A` record named by `cloudflare_record_name` and pointing
at `module.media_vm.primary_ip[0]`. Files split by concern: `main.tf` holds the
module call, `main-gpu.tf` builds `pcie_devices` from the GPU mapping, and
`main-dns.tf` holds the record. The stack reads the GPU mapping as a data
source, so `_base` keeps ownership of it.

**`application/`** configures the running services through their own providers
(`devopsarr/prowlarr`, `devopsarr/sonarr`, `devopsarr/radarr`): host settings,
authentication, root folders, the SABnzbd download client, and the Prowlarr
application links that sync indexers into Sonarr and Radarr.

The application stack **runs after Ansible**, because its providers point at
HTTP endpoints that exist only once the containers are up. A provider that
cannot reach a service never blocks a VM rebuild.

---

## Provider strategy

Both Proxmox-facing stacks declare the provider twice:

| Alias | Credential | Used for |
|---|---|---|
| `proxmox` (default) | Scoped API token | Everything a token has rights to |
| `proxmox.root` | Username + password | Template creation and VM cloning |

Proxmox does not permit API tokens to perform some cloning and template
operations. Each stack passes the elevated alias explicitly, and only to the
resources that need it. The module declares the requirement through
`configuration_aliases = [proxmox.root]`, so a module call without the alias
fails at `init` instead of partway through `apply`.

SSH connectivity for the provider's file operations uses a private key from an
`ephemeral "sops_file"` resource, which Terraform decrypts in memory and never
writes to state. `insecure` comes from `var.proxmox_insecure` (default `true`
for the lab's self-signed certificate).

---

## State

Terraform state is **local** to each stack directory, and `.gitignore` excludes
it (`*.tfstate`, `*.tfstate.*`, `.terraform/`). The repo **does** commit provider
lockfiles (`.terraform.lock.hcl`), so every apply and every CI run resolves
identical provider builds.

CI validates and never applies. Applying from CI requires a locking remote
backend.

---

## Inputs and secrets

`.gitignore` excludes `*.tfvars` files, so each stack reads its inputs from a
local `terraform.tfvars`. A stack's required inputs are the variables without
defaults in its `variables.tf`, and each stack commits a
`terraform.tfvars.example` to copy from.

`infrastructure/_base` and `deployments/media/infrastructure` both need:

```hcl
proxmox_endpoint  = "https://<pve-host>:8006"
proxmox_api_token = "<user>!<token-id>=<secret>"  # sensitive
proxmox_user      = "root@pam"
proxmox_password  = "<password>"                  # sensitive
proxmox_node_name = "<node>"
datastore_infra   = "<disk-datastore>"
datastore_files   = "<file-datastore>"
```

Both also accept `proxmox_insecure` (default `true`).

The deployment stack also requires `vm_name_prefix`, `vm_group`,
`vm_default_user`, `cloudflare_zone_id`, and `cloudflare_record_name`, and
accepts `vm_count`, `additional_disks`, `dns_servers`, `cpu`, `memory`, and
`personal_domain` with defaults. `deployments/media/application` requires only
`arr_host`.

The Proxmox API token and password are the only credentials that travel as
variables, marked `sensitive`. Every other credential comes from the encrypted
files in [`../secrets/`](../secrets) through the `carlpett/sops` provider:

| Stack | Reads | Mechanism |
|---|---|---|
| `infrastructure/_base` | `proxmox_id.sops.yaml` | `ephemeral "sops_file"` |
| `deployments/media/infrastructure` | `proxmox_id.sops.yaml`, `cloudflare.sops.yaml` | `ephemeral "sops_file"` |
| `deployments/media/infrastructure` | `ansible_id.pub` | `file()` (public key, not encrypted) |
| `deployments/media/application` | `media_platform.sops.yaml` | `data "sops_file"` |

Ephemeral values feed provider configuration only and never reach state. The
application stack passes its secrets into resource arguments (API keys, web UI
credentials). The `devopsarr` providers mark those `sensitive` and offer no
write-only variant, so that stack keeps a `data` source and its state holds the
values.

`plan` and `apply` require `SOPS_AGE_KEY_FILE` pointing at the private key that
matches the recipient in `.sops.yaml`.

---

## Working in this directory

```bash
# per stack
terraform -chdir=terraform/infrastructure/_base init
terraform -chdir=terraform/infrastructure/_base plan
terraform -chdir=terraform/infrastructure/_base apply

# repo-wide checks, exactly what CI runs
terraform fmt -check -recursive terraform
cd terraform && tflint --init && tflint --recursive --format compact
```

`terraform/.tflint.hcl` enables the bundled `terraform` ruleset with the `all`
preset, which includes `terraform_documented_variables` and
`terraform_documented_outputs`. Every variable and output carries a
`description`, and those descriptions populate the generated README tables.

Apply order: `_base` -> `deployments/*/infrastructure` -> Ansible ->
`deployments/*/application`.

---

## Per-stack input/output reference

Every stack directory has its own `README.md`.
[terraform-docs](https://terraform-docs.io) generates the tables between the
`<!-- BEGIN_TF_DOCS -->` markers from
[`.terraform-docs.yaml`](.terraform-docs.yaml), and the `terraform_docs`
pre-commit hook regenerates them. The hook leaves prose above the marker intact.

- [`infrastructure/_base`](infrastructure/_base/README.md)
- [`deployments/media/infrastructure`](deployments/media/infrastructure/README.md)
- [`deployments/media/application`](deployments/media/application/README.md)

The module's own input and output reference lives in its repository's
[README](https://github.com/RashunB/terraform-proxmox-module#readme).

---

## Conventions

- Root stacks pin exact provider versions. The module sets floors.
  `required_version` sets a floor everywhere (`>= 1.15`).
- The repo commits lockfiles. Validation runs with `-lockfile=readonly`.
- Variables carrying credentials set `sensitive = true`.
- `_base` **defines** shared, cluster-scoped resources, and every other stack
  **reads** them as data sources. A deployment stack never owns a cluster resource.
- Anything irreplaceable (OS templates) carries `prevent_destroy`.
- CI enforces `terraform fmt`.
