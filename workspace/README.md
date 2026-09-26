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

Templates are tagged (`template` + an OS tag, with `default` on Ubuntu 24.04)
and carry `lifecycle { prevent_destroy = true }`. Downloads set
`overwrite = false` so a re-apply never silently re-pulls a multi-gigabyte image.

Apply this stack first. Nothing else works without it.

### `modules/proxmox_vm` (the contract)

A single module every deployment goes through, rather than hand-rolled VM
resources per stack. It handles:

- **Template discovery by tag.** Queries `proxmox_virtual_environment_vms`
  filtered on `["template", var.template_os_tag]` and clones the result. No VM
  IDs are hardcoded anywhere in a deployment stack.
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
- **Conditional PCIe passthrough.** See below.

Outputs `vm_id` and `primary_ip` (the first non-loopback IPv4 from the guest
agent), which is what the Cloudflare DNS record consumes.

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
creates a Cloudflare `A` record pointing at `module.media_vm.primary_ip`. It
looks the GPU mapping up as a *data source* rather than redefining it, so the
mapping stays owned by `_base`.

**`application/`** configures the running services themselves through their own
providers (`devopsarr/prowlarr`, `devopsarr/sonarr`, `devopsarr/radarr`):
host settings, authentication, root folders, the SABnzbd download client, and
the Prowlarr application links that sync indexers into Sonarr and Radarr.

This stack **must run after Ansible**, because its providers point at HTTP
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
operations. Rather than giving the whole stack root credentials, the elevated
alias is passed explicitly and only to the resources that need it. The module
declares this requirement through `configuration_aliases = [proxmox.root]`, so a
caller that forgets to wire it up fails at `init` rather than at `apply`.

SSH connectivity for the provider's file operations uses a private key read from
SOPS at plan time, never from disk.

---

## State

Terraform state is **local** to each stack directory and is gitignored
(`*.tfstate`, `*.tfstate.*`, `.terraform/`). Provider lockfiles
(`.terraform.lock.hcl`) **are** committed, so every apply and every CI run
resolves identical provider builds.

Migrating to a locking remote backend is the top item on the roadmap in the
[root README](../README.md); it is the prerequisite for applying from CI.

---

## Inputs and secrets

`*.tfvars` files are gitignored, so each stack expects its variables to be
supplied locally. A stack's required inputs are the variables without defaults
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

The deployment stack additionally needs `vm_name_prefix`, `vm_count`,
`vm_group`, `vm_default_user`, `personal_domain`, and `additional_disks`.
`deployments/media/application` needs only `arr_host`; every other input has a
sensible default.

Secrets are never passed as variables. They are read at plan time from the
encrypted files in [`../secrets/`](../secrets) via the `carlpett/sops` provider:

| Stack | Reads |
|---|---|
| `infrastructure/_base` | `proxmox_id.sops.yaml` |
| `deployments/media/infrastructure` | `proxmox_id`, `ansible_id`, `cloudflare` |
| `deployments/media/application` | `media_platform.sops.yaml` |

You need `SOPS_AGE_KEY_FILE` pointing at the private key matching the recipient
in `.sops.yaml` before any `plan` or `apply` will succeed.

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

Order matters: `_base` -> `deployments/*/infrastructure` -> Ansible ->
`deployments/*/application`.

---

## Per-stack input/output reference

Every stack and module directory has its own `README.md` whose tables are
generated by [terraform-docs](https://terraform-docs.io) between
`<!-- BEGIN_TF_DOCS -->` markers, driven by
[`.terraform-docs.yaml`](.terraform-docs.yaml) and regenerated by the
`terraform_docs` pre-commit hook. Prose written above the marker is preserved.

- [`modules/proxmox_vm`](modules/proxmox_vm/README.md)
- [`infrastructure/_base`](infrastructure/_base/README.md)
- [`deployments/media/infrastructure`](deployments/media/infrastructure/README.md)
- [`deployments/media/application`](deployments/media/application/README.md)

Do not hand-edit inside the markers.

---

## Conventions

- Provider versions are pinned exactly; `required_version` is a floor (`>= 1.15`).
- Lockfiles are committed. Validation runs with `-lockfile=readonly`.
- Variables carrying credentials are marked `sensitive = true`.
- Shared, cluster-scoped resources are **defined** in `_base` and **read** as
  data sources everywhere else. A deployment stack never owns a cluster resource.
- Anything irreplaceable (OS templates) carries `prevent_destroy`.
- `terraform fmt` is enforced, not suggested.
