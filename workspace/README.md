# Terraform (`workspace/`)

Provisioning layer. Everything that creates or destroys infrastructure lives
here: Proxmox VE guests, OS templates, PCI hardware mappings, DNS records, and
application-level configuration exposed through service APIs.

Configuration of the operating system and the workloads inside these VMs is the
other half of the repo, in [`../ansible`](../ansible/README.md).

---

## Layering model

```
workspace/
├── modules/
│   └── proxmox_vm/                 # reusable, versioned-in-place VM factory
├── infrastructure/
│   └── _base/                      # shared, long-lived, cluster-wide primitives
└── deployments/
    └── media/
        ├── infrastructure/         # the VM(s) and their DNS, per deployment
        └── application/            # service configuration, applied after Ansible
```

Three layers, each with a distinct blast radius and change frequency.

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

Apply this stack first. Nothing else works without it.

### `modules/proxmox_vm` (the contract)

A single module every deployment goes through, rather than hand-rolled VM
resources per stack. It handles:

- **Template discovery by tag.** Queries `proxmox_virtual_environment_vms`
  filtered on `["template", var.template_os_tag]` and `template = true`, then
  clones the match. A `lifecycle.precondition` on the VM resource requires
  exactly one match and fails the plan with the names of every candidate
  otherwise. No deployment stack hardcodes a VM ID.
- **Cloud-init rendering.** Generates a per-VM snippet from
  `templates/cloud-init.yml.tpl` (override with `cloud_init_user_data_path`),
  injecting hostname, domain, default user, and the SSH public key.
- **Indexed naming.** `vm_count` + `vm_count_offset` produce `prefix-1`,
  `prefix-2`, and so on, so a second VM in an existing group starts at the right
  index instead of colliding.
- **Tag composition.** Merges `vm_default_tag_list` (`terraform`), the caller's
  `vm_tag_list`, `vm_group`, and `vm_name_prefix` into a deduplicated set. These
  tags are what Ansible's dynamic inventory later reads.
- **Additional disks.** A `map(object(...))` keyed by interface name, supporting
  both newly-created disks and attaching existing ones via `path_in_datastore`,
  with `size`/`iothread`/`discard` conditionally nulled when attaching.
- **DNS resolvers.** `dns_servers` sets the resolvers written into each VM's
  cloud-init network config (default `["192.168.0.1", "8.8.8.8"]`).
- **Conditional PCIe passthrough.** See below. Each `pcie_devices` entry sets
  `pcie` and `rombar` independently; both default to `true`.

Outputs `vm_id` and `primary_ip` are lists with one element per VM (the IPv4
address is the first non-loopback address reported by the guest agent). The
media deployment's Cloudflare record uses `primary_ip[0]`.

#### GPU passthrough is one variable

Passing a non-empty `pcie_devices` map flips three things at once:

```hcl
machine = local.gpu_passthrough ? "q35" : "pc"
bios    = local.gpu_passthrough ? "ovmf" : "seabios"
# ...plus a dynamically-created efi_disk block
```

PCIe passthrough requires `q35` and OVMF/UEFI, which in turn requires an EFI
disk. Coupling them to a single input removes the most common way to get a
passthrough VM wrong.

### `deployments/<name>/` (per workload)

Each deployment is split into two stacks because they have different
dependencies and different failure modes.

**`infrastructure/`** calls the `proxmox_vm` module and creates the VM, then
creates a Cloudflare `A` record pointing at `module.media_vm.primary_ip[0]`. It
looks the GPU mapping up as a *data source* rather than redefining it, so the
mapping stays owned by `_base`.

**`application/`** configures the running services themselves through their own
providers (`devopsarr/prowlarr`, `devopsarr/sonarr`, `devopsarr/radarr`):
host settings, authentication, root folders, the SABnzbd download client, and
the Prowlarr application links that sync indexers into Sonarr and Radarr.

This stack **runs after Ansible**, because its providers point at HTTP
endpoints that only exist once the containers are up. Keeping it separate means
a provider that cannot reach a service does not block a VM rebuild.

---

## Provider strategy

Both Proxmox-facing stacks declare the provider twice:

| Alias | Credential | Used for |
|---|---|---|
| `proxmox` (default) | Scoped API token | Everything that a token has rights to |
| `proxmox.root` | Username + password | Template creation and VM cloning |

Proxmox does not permit API tokens to perform some cloning and template
operations. Rather than giving the whole stack root credentials, each stack
passes the elevated alias explicitly and only to the resources that need it. The
module declares this requirement through `configuration_aliases =
[proxmox.root]`, so a module call without the alias fails at `init` rather than
at `apply`.

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

A locking remote backend is the top item on the roadmap in the
[root README](../README.md) and the prerequisite for applying from CI.

---

## Inputs and secrets

`.gitignore` excludes `*.tfvars` files, so each stack reads its inputs from a local
`terraform.tfvars`. A stack's required inputs are the variables without defaults
in its `variables.tf`.

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

The deployment stack additionally requires `vm_name_prefix`, `vm_count`,
`vm_group`, `vm_default_user`, and `cloudflare_zone_id`, and accepts
`additional_disks`, `dns_servers`, `cpu`, `memory`, and `personal_domain` with
defaults. `deployments/media/application` requires only `arr_host`.

Credentials never pass through variables. Each stack reads them from the
encrypted files in [`../secrets/`](../secrets) through the `carlpett/sops`
provider:

| Stack | Reads | Mechanism |
|---|---|---|
| `infrastructure/_base` | `proxmox_id.sops.yaml` | `ephemeral "sops_file"` |
| `deployments/media/infrastructure` | `proxmox_id.sops.yaml`, `cloudflare.sops.yaml` | `ephemeral "sops_file"` |
| `deployments/media/infrastructure` | `ansible_id.pub` | `file()` (public key, not encrypted) |
| `deployments/media/application` | `media_platform.sops.yaml` | `data "sops_file"` |

Ephemeral values feed provider configuration only and never reach state. The
application stack passes its secrets into resource arguments (API keys, web UI
credentials), and the `devopsarr` providers expose those as `sensitive` rather
than write-only, so that stack keeps a `data` source and its state holds the
values.

`plan` and `apply` require `SOPS_AGE_KEY_FILE` pointing at the private key that
matches the recipient in `.sops.yaml`.

---

## Working in this directory

```bash
# per stack
terraform -chdir=workspace/infrastructure/_base init
terraform -chdir=workspace/infrastructure/_base plan
terraform -chdir=workspace/infrastructure/_base apply

# repo-wide checks, exactly what CI runs
terraform fmt -check -recursive workspace
cd workspace && tflint --init && tflint --recursive --format compact
```

`workspace/.tflint.hcl` enables the bundled `terraform` ruleset with the `all`
preset, which includes `terraform_documented_variables` and
`terraform_documented_outputs`: every variable and output carries a
`description`, and those descriptions populate the generated README tables.

Order matters: `_base` -> `deployments/*/infrastructure` -> Ansible ->
`deployments/*/application`.

---

## Per-stack input/output reference

Every stack and module directory has its own `README.md`.
[terraform-docs](https://terraform-docs.io) generates the tables between the
`<!-- BEGIN_TF_DOCS -->` markers from
[`.terraform-docs.yaml`](.terraform-docs.yaml), and the `terraform_docs`
pre-commit hook regenerates them. The hook leaves prose above the marker intact.

- [`modules/proxmox_vm`](modules/proxmox_vm/README.md)
- [`infrastructure/_base`](infrastructure/_base/README.md)
- [`deployments/media/infrastructure`](deployments/media/infrastructure/README.md)
- [`deployments/media/application`](deployments/media/application/README.md)

The markers enclose generated output only.

---

## Conventions

- Provider versions use exact pins; `required_version` sets a floor (`>= 1.15`).
- The repo commits lockfiles. Validation runs with `-lockfile=readonly`.
- Variables carrying credentials set `sensitive = true`.
- `_base` **defines** shared, cluster-scoped resources, and every other stack
  **reads** them as data sources. A deployment stack never owns a cluster resource.
- Anything irreplaceable (OS templates) carries `prevent_destroy`.
- CI enforces `terraform fmt`.
