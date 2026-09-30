---
title: Provisioning (Terraform)
tags: [component/provisioning, component/terraform]
created: 2026-09-17
---

# Provisioning (Terraform)

> [!info] Scope
> `terraform/` in depth. The top-level layering diagram and quickstart
> commands live in [terraform/README.md](../../terraform/README.md); this
> page covers the layer beneath them.

## Three stacks, not one

```
terraform/
├── modules/proxmox_vm/          # reusable VM factory (no state of its own)
├── infrastructure/_base/        # cluster-wide, rarely-changing primitives
└── deployments/media/
    ├── infrastructure/          # the VM + DNS record for this workload
    └── application/             # post-Ansible service configuration
```

`_base`, `deployments/media/infrastructure`, and
`deployments/media/application` are each **their own Terraform root
module**, with separate state and a separate `init`/`plan`/`apply` lifecycle.
`modules/proxmox_vm` is not a stack: it has no backend, and stacks call it
through `module "media_vm" { source = "../../../modules/proxmox_vm" ... }` in
`terraform/deployments/media/infrastructure/main.tf`.

The split follows the failure domains of the three layers:

- `_base` talks only to Proxmox. It owns the OS templates and the GPU
  hardware mapping: resources every deployment depends on and none
  redefines.
- `deployments/media/infrastructure` talks to Proxmox (to clone a VM) and to
  Cloudflare (to create a DNS record). Every dependency in its graph exists
  before Ansible runs.
- `deployments/media/application` talks to the *arr HTTP APIs inside the VM.
  Its provider blocks (`devopsarr/prowlarr`, `devopsarr/sonarr`,
  `devopsarr/radarr`) point at `http://<arr_host>:<port>`, which only
  answers after Ansible deploys and starts the containers.

## `infrastructure/_base`: what it owns

`terraform/infrastructure/_base/main.tf` and `main-gpu.tf` define three
resources of consequence:

- `proxmox_download_file.ubuntu24` / `.rocky9` pull the upstream cloud images
  into the Proxmox file datastore with `overwrite = false`, so a re-apply
  never re-downloads a multi-gigabyte image.
- `proxmox_virtual_environment_vm.ubuntu24_template` / `.rocky9_template`
  convert each image into a Proxmox template (`template = true`,
  `started = false`), tagged `["terraform", "template", "ubuntu24",
  "default"]` and `["terraform", "template", "rocky9"]`. Only Ubuntu 24.04
  carries `default`, which makes it the implicit choice when a deployment
  leaves `template_os_tag` at its default.
- `proxmox_hardware_mapping_pci.transcoding_gpu` (`main-gpu.tf`) is a single,
  **cluster-scoped** PCI hardware mapping. [GPU passthrough](gpu-passthrough.md)
  traces the full mechanism. `_base` *defines* the mapping; every other stack
  *reads* it as a data source.

Both templates carry `lifecycle { prevent_destroy = true }`. The module
clones with `full = false`, a **linked** clone, which depends on the
template's base disk for its lifetime. Destroying a template breaks every VM
cloned from it, so `prevent_destroy` enforces a real storage dependency, not
only the time cost of a rebuild.

## `modules/proxmox_vm`: the contract

Every deployment goes through this module. `variables.tf`, `main.tf`, and
`outputs.tf` together define what the module decides internally and what it
takes as input.

### Template discovery by tag, with a uniqueness check

```hcl
data "proxmox_virtual_environment_vms" "templates" {
  tags = ["template", var.template_os_tag]

  filter {
    name   = "template"
    values = ["true"]
  }
}

locals {
  matched_templates = data.proxmox_virtual_environment_vms.templates.vms
  template_vm_id    = try(data.proxmox_virtual_environment_vms.templates.vms[0].vm_id, null)
}
```
(`terraform/modules/proxmox_vm/main.tf`, excerpt)

No deployment stack hardcodes a VM ID. Rebuilding a template under a new VM
ID requires no change in any consuming stack; the query resolves whichever
template currently carries the tag pair. The `template = true` filter
excludes ordinary VMs that happen to share the tags.

The VM resource enforces a single match:

```hcl
lifecycle {
  precondition {
    condition = length(local.matched_templates) == 1
    error_message = format(
      "Expected exactly one VM tagged [\"template\",%q] with template = true, found %d: %s.",
      var.template_os_tag,
      length(local.matched_templates),
      jsonencode([for t in local.matched_templates : t.name]),
    )
  }
}
```

Zero or several matches fail the plan and list the candidate names, so a
stale template left over from a rebuild surfaces at plan time instead of
becoming the clone source. `try(..., null)` keeps the local from erroring
before the precondition reports.

### Tag composition: what ends up on a VM

```hcl
vm_tag_list = distinct(concat(var.vm_tag_list, [var.vm_group, var.vm_name_prefix]))
tag_list    = distinct(concat(var.vm_default_tag_list, local.vm_tag_list))
```

Final tag set = `vm_default_tag_list` (default `["terraform"]`) + the
caller's `vm_tag_list` + `vm_group` + `vm_name_prefix`, deduplicated. The
`community.proxmox.proxmox` inventory plugin in
[Configuration](configuration.md) reads these tags back as Ansible group
names. This is the entire Terraform-to-Ansible handoff: it runs through
Proxmox's own tag storage, not through any file either tool writes for the
other.

### The GPU-passthrough switch

```hcl
gpu_passthrough = length(var.pcie_devices) > 0

machine = local.gpu_passthrough ? "q35" : "pc"
bios    = local.gpu_passthrough ? "ovmf" : "seabios"

dynamic "hostpci" {
  for_each = var.pcie_devices
  content {
    device  = hostpci.value["device"]
    mapping = hostpci.value["mapping"]
    pcie    = hostpci.value["pcie"]
    rombar  = hostpci.value["rombar"]
  }
}
```

A non-empty `pcie_devices` map flips machine type, BIOS, and (through a
`dynamic "efi_disk"` block) adds an EFI disk, all from one input. PCIe
passthrough does not work on `i440fx` + SeaBIOS, so coupling the three
removes the "passthrough VM with the wrong machine type" failure mode.

Each `pcie_devices` entry carries `pcie` (PCIe vs. legacy PCI bus) and
`rombar` (ROM BAR exposure to the guest) as separate optional fields, both
defaulting to `true`. The two are independent Proxmox settings, so the
module exposes them independently. See
[GPU passthrough](gpu-passthrough.md) for the full chain.

### Indexed naming and the `additional_disks` contract

`vm_count` + `vm_count_offset` produce `"{prefix}-{index+offset}"` names, so
a second VM added to an existing group starts at the next number instead of
colliding with `-1`.

`additional_disks` is a `map(object(...))` keyed by interface name,
supporting two modes per entry: a new disk (`size`, `iothread`, `discard`
apply) or an existing disk attached through `path_in_datastore` (the module
nulls those three fields). `path_in_datastore` alone decides which mode an
entry takes.

### Outputs

```hcl
output "vm_id" {
  description = "Proxmox VMID(s)"
  value       = proxmox_virtual_environment_vm.vms[*].vm_id
}

output "primary_ip" {
  description = "First non-loopback IPv4 address(es) of VM(s)"
  value       = proxmox_virtual_environment_vm.vms[*].ipv4_addresses[1][0]
}
```
(`terraform/modules/proxmox_vm/outputs.tf`, full file)

Both outputs are lists with one element per VM, so `vm_count > 1` exposes
every VM's ID and address. The media deployment's Cloudflare record in
`main-cf.tf` consumes `module.media_vm.primary_ip[0]`.

`ipv4_addresses[1][0]` takes index `1` deliberately: index `0` on a Proxmox
guest is loopback, so `[1]` is the first real interface's first address.
The Ansible inventory plugin's `compose` block makes the same assumption
(see [Configuration](configuration.md)).

### Cloud-init rendering

`proxmox_virtual_environment_file.cloud_config` renders
`templates/cloud-init.yml.tpl` per VM through `templatefile(...)`, injecting
`hostname`, `domain`, `default_user`, and `ssh_public_key`. The template
creates the default user with **passwordless sudo**
(`sudo: "ALL=(ALL) NOPASSWD:ALL"`) and installs `qemu-guest-agent`, enabling
and starting it through `runcmd`. The `primary_ip` output depends on the
guest agent reporting addresses back to Proxmox.

The `initialization.dns` block takes its resolvers from `var.dns_servers`
(default `["1.1.1.1", "8.8.8.8"]`); the media stack passes its own
`dns_servers` variable through.

## Provider strategy: two aliases, one elevated

Every Proxmox-facing stack declares the `proxmox` provider twice
(`terraform/infrastructure/_base/providers.tf`,
`terraform/deployments/media/infrastructure/providers.tf`):

| Alias | Credential | Used for |
|---|---|---|
| `proxmox` (default) | Scoped API token | Everything a token can do |
| `proxmox.root` | `root@pam` username + password | Template creation, VM cloning |

Proxmox restricts cloning and template creation to more privileged
authentication than an API token carries. Rather than granting the whole
stack root credentials, the module declares
`configuration_aliases = [proxmox.root]`, which forces every module call to
wire the elevated alias explicitly:

```hcl
providers = {
  proxmox      = proxmox
  proxmox.root = proxmox.root
}
```

A module call without the alias fails at `terraform init`, not partway
through an `apply`.

Both provider blocks set `insecure = var.proxmox_insecure` (default `true`,
for the lab's self-signed certificate) and configure `ssh { agent = true,
username = "root", private_key = local.proxmox_id_private_key }`.
`proxmox_id_private_key` comes from `ephemeral "sops_file" "proxmox_id"`,
which decrypts `secrets/proxmox_id.sops.yaml` in memory without writing the
value to state (see [Secrets](secrets.md)). The `bpg/proxmox` provider uses
this key for file-upload operations against the Proxmox host, separate from
the key Ansible uses to reach guest operating systems.

## State: local per stack

Terraform state is **local per stack directory**, and `.gitignore` excludes
it (`.terraform/`, `*.tfstate`, `*.tfstate.*`). The repo commits provider
lockfiles (`.terraform.lock.hcl`), so every `init` resolves identical
provider builds across machines and CI.

CI never runs `apply`; that would require a locking remote backend. The
`terraform-validate` CI job runs
`init -backend=false`, so validation needs no real state or credentials (see
[CI and quality gates](ci-quality-gates.md)).

## Deployment inputs

`.gitignore` excludes `*.tfvars`, so each stack reads non-default inputs from
a local `terraform.tfvars`. Each stack commits a `terraform.tfvars.example`
listing its required inputs with placeholder values.

- **Proxmox API credentials** (`proxmox_api_token`, `proxmox_password`) are
  `sensitive` tfvars. They live only in the local, gitignored
  `terraform.tfvars`; Terraform uses them for provider configuration and never
  writes them to state.
- **Provider SSH key and Cloudflare API token** come from
  `ephemeral "sops_file"` resources in each stack's `providers.tf`.
- **The guest SSH public key** comes from `secrets/ansible_id.pub` through
  `file()`; a public key needs no encryption.
- **The Cloudflare zone ID and record name** are required tfvars
  (`cloudflare_zone_id`, `cloudflare_record_name`).
- **Application secrets** in `deployments/media/application` come from
  `data "sops_file" "media_platform"`, because they feed resource arguments
  rather than provider configuration.

## Coupling between the application stack and Ansible

`terraform/deployments/media/application/variables.tf` defaults
`sabnzbd_port` to `6060`. The `media_platform` role's own default is
`media_platform_sabnzbd_host_port: 8080`
(`ansible/roles/media_platform/defaults/main.yml`), and
`ansible/inventory/group_vars/media_platform` overrides it to `6060` for this
deployment. The two values must match for the
`sonarr_download_client_sabnzbd` and `radarr_download_client_sabnzbd`
resources to reach SABnzbd; changing one side requires changing the other.
