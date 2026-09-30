---
title: Engineering Decisions
tags: [component/architecture, component/decisions]
created: 2026-09-17
---

# Engineering Decisions

> [!info] Scope
> The root README's "Engineering decisions" section states each rule with a
> one-line rationale. This page adds the rejected alternative for each rule
> and the concrete failure in this repo if the rule were broken.

## Never call Ansible from Terraform, or create VMs from Ansible

**Rule**: provisioning and configuration stay in separate tools with
independent state. No `local-exec` invoking `ansible-playbook`, no Ansible
module creating VMs.

**Alternative**: a `local-exec` provisioner (or a `null_resource` with a
trigger) that runs `ansible-playbook` right after VM creation, inside the
same `apply`. The pattern is common in homelabs because it collapses
provisioning and configuration into one command.

**Reasoning**: Terraform's `local-exec` has no retry semantics that match
Ansible's. A transient SSH failure during `ansible-playbook` either fails
the whole `apply` (with the VM already created and nothing rolled back) or
disappears silently, depending on how the provisioner handles exit codes.
The seam this repo uses, Proxmox VM tags, has no such coupling: Terraform
writes tags and finishes; Ansible reads them on its next run, on its own
schedule, with its own idempotency model.

**Failure mode**: state ownership becomes ambiguous. A `null_resource`
tracking "Ansible has configured this VM" would live in Terraform state,
which is local and gitignored (see [Provisioning](provisioning.md)). A run
from a different machine would have no record of prior configuration and
could re-trigger `ansible-playbook` runs that fight in-place config. The
`media_platform` role's `force: false` templating for `sabnzbd.ini` and the
Bazarr config assumes Ansible controls its own re-run cadence, not
Terraform.

## Discover templates by tag, not by VM ID

**Rule**: `modules/proxmox_vm` queries `proxmox_virtual_environment_vms`
filtered on `["template", var.template_os_tag]` and `template = true`, never
a hardcoded numeric VM ID. A precondition requires exactly one match.

**Alternative**: a `template_vm_id` variable passed into every deployment
stack, pointing at a specific Proxmox VMID. It needs no data source and no
tag discipline, and most Terraform-for-Proxmox tutorials show it.

**Reasoning**: rebuilding a template (for a new Ubuntu point release, for
example) creates a **new** Proxmox VM object with a **new** VMID. With
hardcoded IDs, every consuming stack needs a coordinated variable update,
applied in order, or it keeps cloning from a template that no longer exists
or has gone stale.

**Failure mode**: `_base` sets `lifecycle { prevent_destroy = true }` on both
templates, so Terraform cannot destroy the old template. Hardcoded IDs plus a
template rebuild leave two templates on disk: the new one reachable by tag,
the old one reachable only by its remembered ID. Tag-based discovery makes
the tag the single source of truth for "which template is current", and the
uniqueness precondition turns a leftover duplicate into a plan-time error
listing both names.

## Keep `infrastructure` and `application` as separate Terraform stacks per deployment

**Rule**: `deployments/media/infrastructure` and
`deployments/media/application` hold independent state and run independent
`init`/`plan`/`apply` cycles.

**Alternative**: one combined stack, with the *arr provider blocks
(`devopsarr/prowlarr` and friends) declared alongside the VM resource and
applied in one pass.

**Reasoning**: the `application` stack's providers point at plain-HTTP
endpoints served by containers that exist only after Ansible runs. A combined
stack's `plan` fails at provider initialization in any environment where
Ansible has not yet run, including the first `apply` that creates the VM.
Two stacks keep `infrastructure`'s plan and apply independent of anything
Ansible manages.

**Failure mode**: a media VM rebuild (destroy and recreate, to change disk
layout for example) would share a state graph with the *arr application
config. A destroy targeting the VM would have to reason about Prowlarr sync
links and Sonarr download clients that only make sense once the replacement
VM is up and Ansible has re-run. With two stacks, the infrastructure rebuild
proceeds independently, and `application` converges on a later `apply`.

## Use two Proxmox provider aliases: scoped token by default, `root` only where required

**Rule**: `proxmox` (API token) is the default provider; `proxmox.root`
(username + password) reaches only the resources that need it, cloning and
template creation, through `configuration_aliases`.

**Alternative**: configure the whole stack with the `root@pam` credential,
since it can do everything the token can and more. Fewer provider blocks,
one credential.

**Reasoning**: `root@pam` is the highest-blast-radius credential in the repo,
full Proxmox admin. A stack configured with `root` by default gives every
resource the *capability* to change anything in the cluster, including
resources that only touch a DNS record. `configuration_aliases` forces every
module call to opt a resource into elevated access explicitly in its
`providers = {}` block, which yields an auditable list of exactly which
resources hold the elevated credential.

**Failure mode**: nothing breaks functionally in the short term. The cost
shows up at credential rotation or compromise: with `root` everywhere,
answering "what can this credential touch" means reading every resource
block. With the alias pattern, `grep -rn "proxmox.root" terraform/` returns
the complete list. Inside the module, the VM clone resource is the only
consumer. [Provisioning](provisioning.md#deployment-inputs) covers how
`proxmox_password` and `proxmox_api_token` reach each stack.

## Let `pcie_devices` drive the machine type instead of setting it manually

**Rule**: a non-empty `pcie_devices` map switches the VM to `q35` + `ovmf`
and attaches an EFI disk automatically. [GPU passthrough](gpu-passthrough.md)
has the full trace.

**Alternative**: expose `machine`, `bios`, and "attach an EFI disk" as three
independent module variables.

**Reasoning**: PCIe passthrough does not function on `i440fx` + SeaBIOS.
Three independent settings give `2^3 = 8` combinations, of which only two are
valid (`pc`/`seabios`/no EFI disk, and `q35`/`ovmf`/EFI disk). The other six
are broken configurations, such as `q35` with `seabios`, or an EFI disk on a
`pc` VM. Deriving all three from one signal collapses the space to exactly
the two valid combinations.

**Failure mode**: the classic hand-rolled Proxmox failure: a VM that boots
cleanly but fails PCI passthrough because of its BIOS type, surfacing much
later as "GPU passthrough doesn't work" instead of as an `apply`-time error.

The same module shows where the pattern stops. `pcie` and `rombar` on each
`hostpci` device are independent Proxmox settings that do not always travel
together, so the module exposes them as separate fields rather than deriving
one from the other. One variable with several effects fits settings that
must always change together, and only those.

## Ship `meta/argument_specs.yml` with every first-party role

**Rule**: every first-party role validates its input against a typed spec
before the first task runs.

**Alternative**: rely on Jinja's runtime failures. An undefined variable
fails with `AnsibleUndefinedVariable` at the point of use, which can be task
40 of 60 in a long role.

**Reasoning**: `lvm_storage` accepts a single variable,
`lvm_storage_logical_volumes`, a **nested list of dicts** describing an
entire storage layout: VG name, LV name, backing PV device paths, filesystem
type, mount point, and four state flags per entry (see
[Configuration](configuration.md)). Without a typed spec, a typo in one
nested key (`pv` for `pvs`) surfaces only when the `community.general.lvg`
task runs, after the role has installed `lvm2` and possibly started changing
disk state. With `argument_specs`, the same typo fails at role entry, before
any task touches the host.

**Failure mode**: `lvm_storage`'s tasks are **destructive and stateful**:
volume group creation, filesystem formatting, mounting. Bad input caught
halfway (VG created, LV task fails) leaves a partially provisioned host for
the next run to reconcile, instead of a clean "nothing happened, fix the
input and re-run."

## Prefix role defaults and map shared values onto them from `group_vars`

**Rule**: role variables carry the role prefix (`media_platform_*`,
`observability_node_*`), and a parent `group_vars` file holds each shared
value once, unprefixed (see [Configuration](configuration.md)).

**Alternative**: unprefixed variable names shared directly across roles, for
example one `prometheus_host_port` that every role reads.

**Reasoning**: `observability_control` and `observability_node` are **two
different roles that both need the same set of ports**. The control role's
Prometheus builds its `file_sd` target files from the ports node exporters
listen on (see [Observability](observability.md)). With one shared name,
neither role can take a different value for the same concept without a
naming collision. The two-hop pattern keeps the canonical value in
`group_vars/observability`, and each role's `group_vars/observability_{control,node}`
maps it onto the role's own prefixed variable. The Dozzle ports show the
payoff: the control UI (`dozzle_host_port: 7070`) and the node agents
(`dozzle_node_port: 7007`) use different values, and the control role reads
each node's agent port from `hostvars`.

**Failure mode**: with a single shared variable, changing a port for one
role (running two cAdvisor instances on the control host during a migration,
for example) requires either inventing a new variable on the spot or letting
the change ripple into every role that reads the shared name.
