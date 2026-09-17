---
title: Engineering Decisions
tags: [component/architecture, component/decisions]
created: 2026-09-17
---

# Engineering Decisions

> [!info] Scope
> The root README's "Engineering decisions" section states these rules and
> their one-line rationale. This note takes each rule further: what the
> rejected alternative actually was, and what concretely breaks, in this
> specific repo and not in the abstract, if the rule is violated.

## Never call Ansible from Terraform, or create VMs from Ansible

**The rule**: provisioning and configuration stay in separate tools with
independent state. No `local-exec` invoking `ansible-playbook`, no Ansible
module creating VMs (root README, "Engineering decisions").

**The alternative that was rejected**: a single `local-exec` provisioner (or
a Terraform `null_resource` with a trigger) that runs `ansible-playbook`
immediately after a VM resource is created, inside the same `apply`. This is
a common homelab pattern precisely because it's convenient: one command,
one tool invocation, done.

**Why it was rejected, concretely, for this repo**: `modules/proxmox_vm`'s
own outputs only expose the first VM created when `vm_count > 1` (see
[[provisioning]]). If Terraform were also responsible for kicking off
configuration, that same indexing gap would mean only VM 1 in a multi-VM
group ever got configured automatically. This is a silent partial failure,
not an error. Worse, Terraform's `local-exec` has no retry semantics matched
to Ansible's: a transient SSH failure during `ansible-playbook` would either
fail the whole `apply` (rolling back nothing, since the VM is already
created) or be swallowed depending on how the provisioner is written. The
actual seam used instead, Proxmox VM tags, has no such coupling: Terraform
writes tags and is done; Ansible reads them whenever it next runs, on its own
schedule, with its own retry/idempotency model.

**What would break if violated**: state ownership becomes ambiguous. If a
`null_resource` in a Terraform stack tracked "has Ansible configured this
VM," that tracking would live in Terraform state, which is local and
gitignored (see [[provisioning]]). Anyone running Terraform from a different
machine would have no record of what had already been configured, and could
re-trigger `ansible-playbook` runs that fight with in-place config changes
(recall `sabnzbd.yml`/`bazarr.yml`'s `force: false` templating, designed
around Ansible controlling its own idempotent re-run cadence, not
Terraform's).

## Discover templates by tag, not by VM ID

**The rule**: `modules/proxmox_vm` queries
`proxmox_virtual_environment_vms` filtered on `["template", var.template_os_tag]`
(`modules/proxmox_vm/main.tf:12-14`), never a hardcoded numeric VM ID.

**The alternative that was rejected**: a `template_vm_id` variable, passed
explicitly into every deployment stack, pointing at a specific Proxmox VMID.
This is simpler to reason about at first: no data source, no tag dependency,
and is what most Terraform-for-Proxmox tutorials show.

**Why it was rejected**: rebuilding a template (say, to pick up a new Ubuntu
point release) creates a **new** Proxmox VM object with a **new** VMID, even
if the old template is destroyed. With a hardcoded ID, every deployment
stack referencing the old template would need a coordinated variable update,
applied in the right order, or would silently keep cloning from a template
that either no longer exists or is stale.

**What would break if violated**: worse than a coordinated update, the
`_base` stack's `lifecycle { prevent_destroy = true }` on both templates
means the *old* template physically cannot be destroyed through Terraform.
If VM IDs were hardcoded elsewhere and someone rebuilt a template anyway
(e.g., by tainting and re-applying just the template resource), the result
is two templates on disk: one tagged `default` and reachable by the tag
query, one orphaned and only reachable by anyone who still has its old ID
memorized. Tag-based discovery makes "which template is current" a single
source of truth (the tag), not a value that has to be kept in sync across
every consuming file.

## Keep `infrastructure` and `application` as separate Terraform stacks per deployment

**The rule**: `deployments/media/infrastructure` and
`deployments/media/application` are two independent state files, two
independent `init`/`plan`/`apply` cycles.

**The alternative that was rejected**: one combined stack, with the *arr
provider blocks (`devopsarr/prowlarr`, etc.) declared alongside the VM
resource, applied in one pass.

**Why it was rejected, concretely**: the `application` stack's providers
(`workspace/deployments/media/application/providers.tf`) point at
`http://{{ arr_host }}:{{ port }}`, plain HTTP endpoints served by
containers that don't exist until Ansible has run. A combined stack's `plan`
would fail immediately on provider initialization (Terraform providers
generally need to reach their target API even to *plan*, not just apply) for
any environment where Ansible hasn't run yet, including the very first
`apply` that creates the VM in the first place. Splitting into two stacks
means `infrastructure`'s plan/apply never depends on anything Ansible
manages.

**What would break if violated**: a rebuild of the media VM (destroy +
recreate, e.g., to change `vm_count` or disk layout) would be blocked by, or
tangled up with, the *arr application config in the same state graph. A
`terraform destroy` targeting the VM would need to reason about resources
(Prowlarr's sync links, Sonarr's download client config) that only make
sense once the replacement VM is back up and Ansible has re-run. Two stacks
means the infrastructure rebuild is unblocked by application-layer state
entirely: `application` requires a subsequent `apply` once Ansible catches
up, rather than one giant `apply` failing to converge.

## Use two Proxmox provider aliases: scoped token by default, `root` only where required

**The rule**: `proxmox` (API token) is the default provider; `proxmox.root`
(username+password) is passed explicitly via `configuration_aliases` only to
resources that need it: cloning and template creation
(`modules/proxmox_vm/main.tf:1-9`, `workspace/README.md:104-121`).

**The alternative that was rejected**: configure the whole stack with the
`root@pam` credential from the start, since it can do everything the token
can plus more. Fewer provider blocks, one credential to manage.

**Why it was rejected**: this is the highest-blast-radius credential in the
entire repo, full Proxmox admin. Every resource in a stack configured with
`root` by default has the *capability* to do anything to the cluster, even
resources that only ever touch, say, a DNS record. `configuration_aliases`
forces every module caller to opt a specific resource into elevated access
by explicitly wiring `proxmox.root` in the `providers = {}` block: an
auditable, greppable list of exactly which resources use the elevated
credential, rather than an implicit "everything could."

**What would break if violated**: nothing breaks functionally in the
short term. The failure mode this avoids is worse than a functional break:
if `root`'s password ever needed rotating or leaked (see [[secrets]] for how
`proxmox_password` and `proxmox_api_token` are separately sourced),
"everything uses `root` by default" means every single resource in every
stack is a potential blast radius, and there's no way to answer "what could
this credential actually touch" without reading every resource block. With
the alias pattern, the answer is `grep -rn "proxmox.root" workspace/`,
which returns the complete list. `modules/proxmox_vm/main.tf:45` (the VM
clone resource) is currently the only place inside the module itself.

## Let `pcie_devices` drive the machine type instead of setting it manually

**The rule**: a non-empty `pcie_devices` map switches the VM to `q35` +
`ovmf` and attaches an EFI disk automatically
(`modules/proxmox_vm/main.tf:23,52-53,86-93`). See [[gpu-passthrough]] for
the full trace.

**The alternative that was rejected**: expose `machine`, `bios`, and
"attach an EFI disk: yes/no" as three independent module variables, letting
a caller set them directly.

**Why it was rejected**: PCIe passthrough does not function on `i440fx` +
SeaBIOS. Three independent booleans means `2^3 = 8` possible combinations, of
which only 2 are actually valid (`pc`/`seabios`/no-EFI-disk, and
`q35`/`ovmf`/EFI-disk) and 6 are broken configurations a caller could
accidentally select, e.g., `q35` machine type with `seabios` still set, or
an EFI disk attached to a `pc`-type VM that doesn't expect one. Deriving all
three from one signal (whether `pcie_devices` is populated) collapses the
space down to exactly the 2 valid combinations; there is no variable
combination a caller can pass that produces a broken one.

**What would break if violated**: the class of failure common in
hand-rolled Proxmox Terraform configs elsewhere: a VM that boots, shows no
visible boot failure, but fails PCI passthrough because the BIOS type
doesn't support it, with the failure surfacing much later as "GPU
passthrough doesn't work" rather than as an `apply`-time error. See
[[gpu-passthrough]]'s note on the `rombar` field for an example of what
happens when *this same module* couples two settings that are *not*
actually always correlated (`rombar` following `pcie`): the "one variable,
multiple effects" pattern holds up specifically when the effects always
travel together, and becomes a liability when they don't.

## Ship `meta/argument_specs.yml` with every first-party role

**The rule**: every first-party role validates its input against a typed
spec before the first task runs (`ansible/README.md:175-181`).

**The alternative that was rejected**: rely on Jinja's own runtime failures.
An undefined variable used in a template fails with an
`AnsibleUndefinedVariable` error at the point of use, which could be task 40
of 60 in a long role.

**Why it was rejected, concretely, for `lvm_storage`**: that role accepts a
single variable, `lvm_storage_logical_volumes`, that is a **nested
list-of-dicts** describing an entire storage layout: VG name, LV name,
backing PV device paths, filesystem type, mount point, and four independent
state flags per entry (`meta/argument_specs.yml:6-68`, see
[[configuration]]). Without a typed spec, a typo in one nested key (`pvs`
misspelled `pv`, say) would only surface when the `community.general.lvg`
task actually runs and Ansible complains about an undefined `item.pvs`,
potentially after the role has already run `apt install lvm2` and started
modifying disk state on a real host. With `argument_specs`, that same typo
fails at role entry, before any task executes, on a host where nothing has
been touched yet.

**What would break if violated**: the specific danger with `lvm_storage` is
that its tasks are **destructive and stateful**: volume group creation,
filesystem formatting, mounting. A malformed input caught halfway through
(e.g., VG created successfully, then the LV task fails on a typo) leaves a
host in a partially-provisioned state that the *next* run has to reconcile
correctly, rather than a clean "nothing happened, fix the input and
re-run."

## Prefix role defaults and map shared values onto them from `group_vars`

**The rule**: `media_platform_*`, `observability_node_*`, etc., with an
unprefixed shared value defined once in a parent `group_vars` file
(`ansible/README.md:156-169`, see [[configuration]] for the concrete
example).

**The alternative that was rejected**: unprefixed, role-agnostic variable
names shared directly across roles, e.g., a single `prometheus_host_port`
variable that both `observability_control`'s Prometheus container *and* any
other role that needs to know Prometheus's port both reference directly.

**Why it was rejected**: this repo runs `observability_control` and
`observability_node`, two **different roles that both need to know about
the same set of ports** (Prometheus, Loki, cAdvisor, etc., since the control
role's Prometheus needs to know what port node-level exporters listen on to
build its `file_sd` target files, see [[observability]]). If both roles
consumed one shared unprefixed variable name directly, there's no way for
one role to ever need a *different* value for that concept than the other
without a naming collision or an awkward override. The two-hop pattern,
`group_vars/observability` holds the canonical value, each role's
`group_vars/observability_{control,node}` maps it onto that role's own
prefixed variable, means `observability_control_cadvisor_host_port` and
`observability_node_cadvisor_host_port` are distinct variables that *happen*
to be set to the same value today, but could diverge without any
restructuring if they ever needed to.

**What would break if violated**: with a single shared variable instead,
changing a port for one role's purposes (say, running two cAdvisor instances
on the control host during a migration) would require either a new variable
name invented on the spot, or accepting that the change ripples to every
role referencing the old shared name, exactly the collision the prefix
convention exists to prevent.

## Check your understanding

- [ ] For the Ansible/Terraform separation rule: what specifically about
      `modules/proxmox_vm`'s own output limitation makes a combined
      `local-exec` approach worse here than in a hypothetical single-VM-only
      module?
- [ ] Why can't the `application` Terraform stack for media be merged into
      the `infrastructure` stack, in terms of what would happen at `plan`
      time on a from-scratch environment?
- [ ] What's the practical difference between "every resource could
      theoretically use `root`" and "resources that use `root` are
      `configuration_aliases`-gated," in terms of what you can `grep` for?
- [ ] Why does deriving machine type from `pcie_devices` collapse 8 possible
      configurations down to 2 valid ones? What are the invalid 6?
- [ ] Why does `argument_specs` validation matter more for `lvm_storage`
      specifically than it would for a role that only ever templates a
      config file and starts a container?
- [ ] Give a concrete scenario where `observability_control` and
      `observability_node` might need *different* values for "the same"
      port. Explain why the prefix + group_vars re-export pattern supports
      that without restructuring.
