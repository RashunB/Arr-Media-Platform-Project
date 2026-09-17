---
title: Provisioning (Terraform)
tags: [component/provisioning, component/terraform]
created: 2026-09-17
---

# Provisioning (Terraform)

> [!info] Scope
> This note covers `workspace/` in depth. For the top-level layering diagram
> and quickstart commands, see [[../../workspace/README.md|workspace/README.md]].
> This note does not repeat that content; it addresses the layer beneath it.

## The three-stack layering, and why it's three and not one

```
workspace/
├── modules/proxmox_vm/          # reusable VM factory (no state of its own)
├── infrastructure/_base/        # cluster-wide, rarely-changing primitives
└── deployments/media/
    ├── infrastructure/          # the VM + DNS record for this workload
    └── application/             # post-Ansible service configuration
```

Each of `_base`, `deployments/media/infrastructure`, and
`deployments/media/application` is its **own Terraform root module**, with
its own state and its own `init`/`plan`/`apply` lifecycle
(`workspace/README.md:174-187`). `modules/proxmox_vm` is not a stack at all;
it has no backend and is never applied directly, only called from a stack via
`module "media_vm" { source = "../../../modules/proxmox_vm" ... }`
(`workspace/deployments/media/infrastructure/main.tf:25-50`).

The split exists because the three layers have different failure domains:

- `_base` talks only to Proxmox. It owns the OS templates and the GPU
  hardware mapping, things every deployment depends on but nothing should
  redefine.
- `deployments/media/infrastructure` talks to Proxmox (to clone a VM) and to
  Cloudflare (to create a DNS record). Its dependency graph is entirely
  "things that exist before Ansible ever runs."
- `deployments/media/application` talks to the *arr HTTP APIs running inside
  the VM. Its provider blocks (`devopsarr/prowlarr`, `devopsarr/sonarr`,
  `devopsarr/radarr`, `workspace/deployments/media/application/providers.tf`)
  point at `http://{{ arr_host }}:{{ port }}`, which does not exist until
  Ansible has deployed and started the containers.

## `infrastructure/_base`: what it owns

Read `workspace/infrastructure/_base/main.tf` and `main-gpu.tf` directly.
Three resources are of consequence:

- `proxmox_download_file.ubuntu24` / `.rocky9` pull the upstream cloud images
  into the Proxmox file datastore, with `overwrite = false`
  (`main.tf:1-9`, `:49-57`); a re-apply never re-downloads a multi-gigabyte
  image.
- `proxmox_virtual_environment_vm.ubuntu24_template` /
  `.rocky9_template` convert each downloaded image into a Proxmox template
  (`template = true`, `started = false`), tagged
  `["terraform", "template", "ubuntu24", "default"]` and
  `["terraform", "template", "rocky9"]` respectively (`main.tf:11-47`,
  `:59-94`). Only Ubuntu 24.04 carries the `default` tag; that tag is what
  makes it the implicit choice when a deployment doesn't override
  `template_os_tag`.
- `proxmox_hardware_mapping_pci.transcoding_gpu` (`main-gpu.tf`) is a single,
  **cluster-scoped** PCI hardware mapping resource. See [[gpu-passthrough]]
  for the full mechanism. The resource is *defined* in `_base` and only ever
  *read* as a data source everywhere else
  (`workspace/deployments/media/infrastructure/main.tf:5-7`).

Both templates carry `lifecycle { prevent_destroy = true }`. This matters
because `modules/proxmox_vm` clones with `full = false`, a **linked** clone
(`modules/proxmox_vm/main.tf:55-58`). A linked clone is not an independent
copy of the disk; it depends on the template's base disk continuing to
exist. Destroying the template out from under a linked clone breaks every VM
cloned from it. `prevent_destroy` enforces that dependency, not just a
safeguard against the time cost of rebuilding the template.

## `modules/proxmox_vm`: the actual contract

This is the one module every deployment goes through
(`workspace/README.md:44-101`). Read `modules/proxmox_vm/variables.tf`,
`main.tf`, and `outputs.tf` together. What follows is what it decides
internally versus what it takes as input.

### Template discovery by tag, not VM ID

```hcl
data "proxmox_virtual_environment_vms" "templates" {
  tags = ["template", var.template_os_tag]
}
```
(`modules/proxmox_vm/main.tf:12-14`)

```hcl
template_vm_id = data.proxmox_virtual_environment_vms.templates.vms[0].vm_id
```
(`main.tf:19`)

No deployment stack hardcodes a VM ID anywhere. Rebuilding a template with a
new VM ID does not require touching any consuming stack; the query finds
whatever currently carries the tag pair.

> [!warning] `vms[0]` assumes exactly one match
> If more than one VM ever carries both the `template` tag and the requested
> `template_os_tag` (e.g., a half-cleaned-up rebuild left the old template
> tagged), Terraform silently clones whichever one the API returns first.
> There's no uniqueness check. Tag hygiene on templates is load-bearing.

### Tag composition: what ends up on a VM

```hcl
vm_tag_list = distinct(concat(var.vm_tag_list, [var.vm_group, var.vm_name_prefix]))
tag_list    = distinct(concat(var.vm_default_tag_list, local.vm_tag_list))
```
(`main.tf:17-18`)

Final tag set = `vm_default_tag_list` (default `["terraform"]`) + whatever
tags the caller passed in `vm_tag_list` + `vm_group` + `vm_name_prefix`,
deduplicated. These tags are exactly what [[configuration]]'s
`community.proxmox.proxmox` inventory plugin later reads back as Ansible
group names. This is the entire Terraform-to-Ansible handoff mechanism; it
happens through Proxmox's own tag storage, not through any file either tool
writes for the other.

### The GPU-passthrough switch (see [[gpu-passthrough]] for the full mechanism)

```hcl
gpu_passthrough = length(var.pcie_devices) > 0
```
```hcl
machine = local.gpu_passthrough ? "q35" : "pc"
bios    = local.gpu_passthrough ? "ovmf" : "seabios"
```
(`main.tf:23`, `:52-53`)

A non-empty `pcie_devices` map flips machine type, BIOS, and (via a
`dynamic "efi_disk"` block, `main.tf:86-93`) adds an EFI disk, all three at
once, from one input. This is deliberate: PCIe passthrough does not work on
`i440fx` + SeaBIOS, so coupling the three removes the "passthrough VM with
the wrong machine type" failure mode entirely.

> [!bug] `rombar` is derived from `pcie`
> ```hcl
> dynamic "hostpci" {
>   for_each = var.pcie_devices
>   content {
>     device  = hostpci.value["device"]
>     mapping = hostpci.value["mapping"]
>     pcie    = hostpci.value["pcie"]
>     rombar  = hostpci.value["pcie"]
>   }
> }
> ```
> (`main.tf:76-84`) sets `rombar` (whether the device's ROM BAR is exposed to
> the guest) from the same value as `pcie` (whether the device uses the PCIe
> bus vs. legacy PCI). These are independent settings that both default to
> `true` in the current single-GPU configuration. `rombar` cannot be set
> independently of `pcie` through this module; if `pcie` were set `false` for
> a device, `rombar` would follow it to `false` as well.

### Indexed naming and the `additional_disks` contract

`vm_count` + `vm_count_offset` produce `"{prefix}-{index+offset}"` names
(`main.tf:46`), so a second VM added to an existing group starts at the right
number instead of colliding with `-1`.

`additional_disks` is `map(object(...))` keyed by interface name
(`variables.tf:70-85`), supporting two distinct modes per entry: a brand-new
disk (`size`, `iothread`, `discard` apply) or attaching an existing disk via
`path_in_datastore` (those three fields are conditionally nulled,
`main.tf:67-69`). One field, `path_in_datastore`, decides which mode a given
map entry is in.

### Outputs, and their limitation

```hcl
output "vm_id"     { value = proxmox_virtual_environment_vm.vms[0].vm_id }
output "primary_ip" { value = proxmox_virtual_environment_vm.vms[0].ipv4_addresses[1][0] }
```
(`outputs.tf:1-9`)

> [!warning] Outputs only ever describe the first VM
> Both outputs index `[0]` into the `vms` resource, which is itself indexed
> by `count`. If a caller sets `vm_count > 1`, the module still only exposes
> the ID and IP of the *first* VM created. Nothing downstream (the media
> deployment's Cloudflare `A` record, for instance, at
> `workspace/deployments/media/infrastructure/main-cf.tf:1-9`, consumes
> `module.media_vm.primary_ip` directly) can see VM 2, 3, etc. through the
> module's own outputs. Multi-VM groups work at the resource level but not
> at the output level. This is not documented anywhere else in the repo.

`ipv4_addresses[1][0]` (index `1`, not `0`) is deliberate: index `0` on a
Proxmox guest is loopback, so `[1]` is "the first real interface's first
address." The Ansible inventory plugin's `compose` block makes the same
assumption in reverse (see [[configuration]]).

### Cloud-init rendering

`proxmox_virtual_environment_file.cloud_config` (`main.tf:26-42`) renders
`templates/cloud-init.yml.tpl` per VM via `templatefile(...)`, injecting
`hostname`, `domain`, `default_user`, `ssh_public_key`. The template itself
(`modules/proxmox_vm/templates/cloud-init.yml.tpl`) creates the default user
with **passwordless sudo** (`sudo: "ALL=(ALL) NOPASSWD:ALL"`) and installs
`qemu-guest-agent`, enabling and starting it via `runcmd`. The guest agent is
not optional: the `primary_ip` output above depends on Proxmox's agent
channel reporting IPs back, which requires it to be running.

## Provider strategy: two aliases, one deliberately elevated

Every Proxmox-facing stack declares the `proxmox` provider twice
(`workspace/infrastructure/_base/providers.tf:27-53`,
`workspace/deployments/media/infrastructure/providers.tf:31-57`):

| Alias | Credential | Used for |
|---|---|---|
| `proxmox` (default) | Scoped API token | Everything a token can do |
| `proxmox.root` | `root@pam` username + password | Template creation, VM cloning |

The API token cannot perform cloning or template creation; Proxmox itself
restricts those operations to more privileged auth. Rather than granting the
whole stack root credentials, `modules/proxmox_vm/main.tf:1-9` declares
`configuration_aliases = [proxmox.root]`, forcing every caller to wire the
elevated alias in explicitly:

```hcl
providers = {
  proxmox      = proxmox
  proxmox.root = proxmox.root
}
```
(`deployments/media/infrastructure/main.tf:46-49`)

A caller that forgets this fails at `terraform init`, not partway through an
`apply`. The failure mode is pushed as early as possible.

Both provider blocks also configure `ssh { agent = true, username = "root",
private_key = local.proxmox_id_private_key }`, where
`proxmox_id_private_key` comes from `data.sops_file.proxmox_id` reading
`secrets/proxmox_id.sops.yaml` (see [[secrets]]). This is the SSH key the
`bpg/proxmox` provider itself uses for file-upload-style operations, entirely
separate from the SSH key Ansible later uses to reach the guest OS.

> [!warning] `insecure = true` and DNS are both hardcoded
> Every `provider "proxmox"` block sets `insecure = true` (self-signed lab
> CA) and the module's `initialization.dns.servers` is hardcoded to
> `["192.168.0.1"]` (`main.tf:127-129`) rather than exposed as a variable.
> Both are acceptable for a single-LAN homelab. Both require a source edit,
> not a tfvars change, to modify.

## State: local today, and why that's the top roadmap item

Terraform state is **local per stack directory** and gitignored
(`.gitignore:2-8`: `.terraform/`, `*.tfstate`, `*.tfstate.*`). Provider
lockfiles (`.terraform.lock.hcl`) **are** committed, so every `init`
resolves identical provider builds across machines and CI.

This is adequate for a single operator applying from one machine, but it is
the named prerequisite for two things that don't exist yet: CI ever running
`apply` (root README's "Known gaps and roadmap"), and anyone but the state
file's owner safely running `plan`. See [[ci-quality-gates]] for how
`terraform-validate` works around this today (`init -backend=false`, so CI
never needs real state or credentials at all).

## Deployment inputs are never plaintext for credentials

`*.tfvars` files are gitignored (`.gitignore`), so each stack's
non-default inputs are supplied locally, never committed. But the sensitive
inputs, SSH keys, API tokens, the Cloudflare token, are **not** tfvars at
all; they are read directly out of `secrets/*.sops.yaml` via the
`carlpett/sops` provider's `sops_file` data source, at plan time, in memory
(`data "sops_file" "proxmox_id"` pattern, repeated in every stack's
`providers.tf`/`main.tf`). See [[secrets]] for which file each stack reads.

## The application stack's coupling to an Ansible default

`workspace/deployments/media/application/variables.tf` defaults
`sabnzbd_port` to `6060` (`:70-73`). The `media_platform` Ansible role's own
default is `media_platform_sabnzbd_host_port: 8080`
(`ansible/roles/media_platform/defaults/main.yml:50-52`), but
`ansible/inventory/group_vars/media_platform:2` overrides it to `6060` for
this specific deployment. The Terraform application stack's default of
`6060` produces a working `sonarr_download_client_sabnzbd` /
`radarr_download_client_sabnzbd` configuration only because that Ansible
group_vars override exists. Changing one without the other configures
Sonarr/Radarr to talk to a SABnzbd port nothing is listening on. Nothing in
either the Terraform or Ansible source enforces this consistency.

## Check your understanding

- [ ] Explain why `modules/proxmox_vm` queries a template by
      `["template", var.template_os_tag]` instead of a hardcoded VM ID, and
      what operational problem that avoids on template rebuild.
- [ ] What three VM properties change together when `pcie_devices` goes from
      empty to non-empty, and why must they change together?
- [ ] Why does the module clone with `full = false`, and what does that imply
      about the `prevent_destroy` lifecycle block on the templates in `_base`?
- [ ] If you set `vm_count = 3` on the `proxmox_vm` module, what do
      `module.x.vm_id` and `module.x.primary_ip` actually give you, and what
      don't they give you?
- [ ] Trace how a tag ends up in Ansible's inventory: which Terraform locals
      compute the final tag list, and which variables feed into it?
- [ ] Why does every Proxmox-facing Terraform stack declare the provider
      twice, and what happens at `init` (not `apply`) if a module caller
      forgets to pass `proxmox.root` through?
- [ ] Where does Terraform get the SSH private key it uses against the
      Proxmox host itself, and how is that different from the key Ansible
      uses to reach guest VMs?
- [ ] Why is the media application stack's default `sabnzbd_port` coupled to
      a value set in an Ansible `group_vars` file rather than to the Ansible
      role's own default?
