---
title: Configuration (Ansible)
tags: [component/configuration, component/ansible]
created: 2026-09-17
---

# Configuration (Ansible)

> [!info] Scope
> This note covers `ansible/` in depth: the dynamic inventory mechanism, each
> first-party role's actual task flow, and variable precedence in practice.
> For the role catalog table and quickstart commands, see
> [[../../ansible/README.md|ansible/README.md]] — not repeated here.

## The inventory: how a Proxmox tag really becomes an Ansible group

Files in `ansible/inventory/` are numbered because Ansible merges directory
sources in lexical order, and later static files reference hosts the dynamic
source must have already discovered (`ansible/README.md:15-17`).

### `00_inv.proxmox.yml` — the dynamic source

```yaml
plugin: community.proxmox.proxmox
url: https://192.168.0.63:8006
user: "{{ lookup('community.sops.sops', 'vault/pve.sops.yaml', extract='[\"pve_ansible_api_user_name\"]')}}"
token_id: "{{ lookup('community.sops.sops', 'vault/pve.sops.yaml', extract='[\"pve_ansible_api_token_id\"]')}}"
token_secret: "{{ lookup('community.sops.sops', 'vault/pve.sops.yaml', extract='[\"pve_ansible_api_token_secret\"]')}}"
validate_certs: false
want_facts: true
keyed_groups:
  - key: proxmox_tags_parsed
    separator: ""
    prefix: ""
compose:
  ansible_host: >-
    proxmox_agent_interfaces[1]['ip-addresses'][0].split('/')[0]
    if proxmox_vmtype == 'qemu'
    else proxmox_lxc_interfaces[1]['inet'].split('/')[0]
want_proxmox_nodes_ansible_host: true
```
(`ansible/inventory/00_inv.proxmox.yml`, full file)

The credentials themselves come from `vault/pve.sops.yaml` — a symlink to
`secrets/pve.sops.yaml` (`ansible/vault/pve.sops.yaml -> ../../secrets/pve.sops.yaml`)
— decrypted via a `community.sops.sops` lookup with a jq-style `extract`
path. **Even the inventory file that queries Proxmox contains no plaintext
credential.**

`keyed_groups` with an **empty `separator` and `prefix`** is the crux of the
whole tag→group mechanism: a Proxmox tag named `media_platform` becomes an
Ansible group named exactly `media_platform`, with no prefix decoration. This
is what lets `modules/proxmox_vm`'s composed tag list (see [[provisioning]])
turn directly into inventory membership.

`ansible_host` is **computed**, not stored, and it hard-codes an assumption:
interface index `[1]` (not `[0]`) is the guest's primary address, for both
QEMU (`proxmox_agent_interfaces`) and LXC (`proxmox_lxc_interfaces`) guest
types. This mirrors the exact same `[1]` assumption in the Terraform module's
`ipv4_addresses[1][0]` output (see [[provisioning]]) — both tools agree that
index `0` is loopback.

`want_proxmox_nodes_ansible_host: true` means the plugin *also* discovers the
Proxmox node itself as an inventory host. That host is separately, statically
defined too (below) — Ansible merges same-named hosts from multiple sources,
so this is intentional layering, not a conflict, but it's easy to forget
there are two sources describing the same `pve` host.

> [!info] There's a commented-out `groups:` block
> Lines 14-19 of `00_inv.proxmox.yml` are commented-out example
> Jinja-conditional group rules (leftover from an earlier iteration —
> `rhce_proxy`, `media`, etc.). They're inert. The live mechanism is entirely
> the `keyed_groups` tag pass-through plus the static overlay files below.

### The static overlay files

| File | Role |
|---|---|
| `01_baremetal.ini` | The two physical hosts Proxmox can't discover about itself: `control` (192.168.0.60) and `pve` (192.168.0.63, `ansible_user=root`) |
| `10_observability.ini` | Composes `observability_node`/`observability_control`/`observability` from dynamic + static groups |
| `11_media_platform.ini` | `[media_platform]` → `media-1` |

`10_observability.ini`'s key group is `observability_node`:

```ini
[observability_node:children]
observability_pve
proxmox_all_qemu
```

`proxmox_all_qemu` is an **implicit group the `community.proxmox.proxmox`
plugin creates automatically** for every guest of type `qemu`, independent of
any tag. This is the actual mechanism behind the README's "no inventory edit
needed" claim for monitoring — *every* VM Terraform creates lands in
`observability_node` purely by virtue of being a QEMU guest, whether or not
it carries any particular tag. See [[observability]] for what that group
membership triggers.

> [!warning] `media_platform` group membership is a static edit, not a tag
> `11_media_platform.ini` is a plain static `.ini` file with a literal
> hostname: `[media_platform]` / `media-1`. Unlike `observability_node`,
> there is no children/tag mechanism visible in the committed inventory
> files that would populate this group automatically from a Proxmox tag.
> Whether a tag-based dynamic group *could* also satisfy this membership
> depends on the exact value of `var.vm_group` passed into the Terraform
> module for this deployment — which lives in a gitignored `terraform.tfvars`
> file this vault cannot read. Treat "no Ansible edit needed to add a
> workload host" as true for observability membership, and **unverified** —
> possibly false — for workload-group membership like `media_platform`. If
> you scale past one media host, check `11_media_platform.ini` first.

### Inspecting the merged result

```bash
cd ansible
ansible-inventory --graph
ansible-inventory --host media-1
```
(`ansible/README.md:69-75`)

## `site.yml`: the entry point's real structure

```yaml
- import_playbook: sops.yml                 # tags: [sops, secrets]
- import_playbook: observability_control.yml # tags: [observability, control]
- import_playbook: observability_node.yml    # tags: [observability, node]
- import_playbook: media_platform.yml        # tags: [media_platform]
```
(`ansible/site.yml`, full file)

Import order matters: `sops.yml` runs against `hosts: localhost` first,
**every single run**, regardless of `--limit`, unless you explicitly exclude
its `sops`/`secrets` tags — it installs the `sops` CLI binary on the control
node via `community.sops.install` (`ansible/sops.yml`). This is a control-node
concern, not a managed-host concern; it's easy to misread as "installs SOPS
on every host" from the playbook name alone.

`observability_control.yml` and `observability_node.yml` both set
`force_handlers: true` at the play level
(`ansible/observability_control.yml:5`, `ansible/observability_node.yml:5`) —
a queued container-restart handler still fires even if a later task in the
same play fails. **`media_platform.yml` does not set `force_handlers`** — an
asymmetry worth knowing before you're debugging why a media-stack config
change didn't take effect after a partially-failed run.

Each subordinate playbook is a short, flat task list of `import_role` calls
with per-task tags:

```yaml
# media_platform.yml
- import_role: { name: docker_base }      # tags: docker
- import_role: { name: lvm_storage }      # tags: lvm
- import_role: { name: media_platform }   # tags: media_platform
```

Tags exist at two levels simultaneously — import-level in `site.yml` and
task-level inside each playbook — which is what lets
`ansible-playbook site.yml --tags media_platform` target a whole subsystem
while `--tags docker` reaches across every playbook that imports
`docker_base`.

## Role catalog: task flow and `argument_specs` per role

Every first-party role ships `meta/argument_specs.yml`. Ansible validates
role input against it **before the first task runs** — a malformed variable
fails at role entry with a typed error, not partway through a play
(`ansible/README.md:175-181`). Until role `README.md` files are filled in
(a named roadmap gap), these specs are the accurate reference for what a role
accepts.

### `docker_base`

```yaml
# tasks/main.yml
- import_role: { name: geerlingguy.docker }   # vars: docker_users: "{{ docker_base_users }}"
- import_role: { name: geerlingguy.pip }      # vars: pip_install_packages: [{name: docker}]
```

A two-line composition role, nothing more. `docker_base_users` (default
`[ansible]`) is the *only* input — this role's whole job is wiring the
vendored `geerlingguy.docker` role plus installing the `docker` Python
package that `community.docker` modules elsewhere in the repo need at
runtime.

### `lvm_storage`

```yaml
# tasks/main.yml
import_tasks: install.yml      # apt: lvm2
import_tasks: volumes.yml      # community.general.lvg, then .lvol — looped
import_tasks: filesystem.yml   # community.general.filesystem — looped
import_tasks: mount.yml        # ansible.posix.mount — looped
```

The whole storage layout is **one variable**,
`lvm_storage_logical_volumes`, a list of dicts each describing a full
PV→VG→LV→filesystem→mount pipeline. Per-item `vg_state` / `lv_state` /
`fs_state` / `mount_state` keys (`meta/argument_specs.yml:46-68`) mean the
same data structure can tear down storage as easily as create it — flip the
states to `absent` and re-run.

> [!tip] `required: true` with an empty-list default is not a contradiction
> `meta/argument_specs.yml:6-10` marks `lvm_storage_logical_volumes`
> `required: true`, while `defaults/main.yml:2` sets it to `[]`. This isn't a
> bug: `argument_specs` validation checks whether a final value exists after
> defaults are applied, not whether the caller explicitly supplied one. In
> practice the role always "satisfies" its required variable even if nobody
> overrides it — it just does nothing, because looping over an empty list is
> a no-op in every task file.

The only consumer today is `ansible/inventory/group_vars/media_platform`,
which defines a single VG (`vg.media`) built from two `scsi-SQEMU...`
disk-by-id paths, ext4, mounted at `/opt/media_platform`.

### `media_platform`

```yaml
# tasks/main.yml
import_tasks: users.yml             # group `media_platform` (gid 6000), user `media` (uid 6000)
import_tasks: media_directories.yml # data tree + per-service /config/<svc>/data dirs, mode 2775
import_tasks: sabnzbd.yml           # templates sabnzbd.ini, force: false
import_tasks: configarr.yml         # templates configarr config.yml, mode 0440
import_tasks: bazarr.yml            # templates bazarr config.yaml, force: false
import_tasks: gpu.yml               # driver packages + video/render groups + immediate reboot
import_tasks: compose.yml           # renders docker-compose.yml + .env, docker_compose_v2
```

This role does more than run Compose — it's the one role in the repo that
pre-seeds real application config so services come up already configured
instead of hitting a first-run setup wizard
(`ansible/README.md:135-138`). Two details worth internalizing:

- `sabnzbd.yml` and `bazarr.yml` both template their config with **`force:
  false`** — the file is written once and never overwritten by a later run,
  so in-app changes a user makes through the web UI survive re-running the
  playbook.
- `configarr.yml`'s templated file gets mode `0440` — read-only, no write
  even for the owning user — which is consistent with Configarr's `!env`
  indirection (see [[gpu-passthrough]] and below): the file never needs
  in-place edits because secrets are pulled from the container's environment
  at runtime, not baked into the file.

`gpu.yml` installs `linux-modules-extra-{{ ansible_kernel }}` and notifies
the `Reboot` handler, then **immediately** calls
`ansible.builtin.meta: flush_handlers` at the end of the task file
(`tasks/gpu.yml:28-29`) — forcing the reboot to happen within the *same*
`media_platform` role run, before `compose.yml` starts containers that mount
`/dev/dri`. Without that explicit flush, the reboot would be deferred to the
end of the whole play (Ansible's normal handler timing) and the freshly
installed kernel modules wouldn't be loaded yet when the containers start.

See [[gpu-passthrough]] for how this connects to the Terraform-side PCI
passthrough and the Jellyfin container's device mount.

### `observability_control` and `observability_node`

Both follow the same shape — one `tasks/<service>.yml` per service, each
creating directories, templating config, notifying a per-service restart
handler, followed by a final `compose.yml` task that renders the full
`docker-compose.yml` and runs `docker_compose_v2` with `state: present`.

`observability_control` additionally ships Grafana dashboards as static JSON
under `files/grafana/provisioning/dashboards/` and wires them through
Grafana's file-based provisioning
(`roles/observability_control/files/grafana/provisioning/dashboards/provider.yml`)
— dashboards are version-controlled, not clicked into existence and lost on
a container rebuild. See [[observability]] for the full topology, the
Prometheus file-based service discovery mechanism, and several concrete
template bugs found while reading these roles.

## Variable conventions: namespacing and the re-export pattern

Role defaults are prefixed with the role name
(`media_platform_*`, `observability_node_*`, `observability_control_*`).
Shared values live **once, unprefixed**, in a parent `group_vars` file and
get mapped onto each role's prefixed interface in the child:

```yaml
# group_vars/observability        (the shared truth)
prometheus_host_port: 9090

# group_vars/observability_control (mapped onto the role's interface)
observability_control_prometheus_host_port: "{{ prometheus_host_port }}"
```
(`ansible/inventory/group_vars/observability:29-30`,
`ansible/inventory/group_vars/observability_control:7-8`)

Changing a port is a one-line edit in `group_vars/observability` that
propagates through every role, template, and scrape config that references
it — while the roles themselves keep collision-free, self-documenting
variable names. `group_vars/observability_pve` demonstrates the override
pattern cleanly: it inherits everything from `observability` and then flips
on exactly three booleans for the PVE host alone
(`observability_node_alloy_journal_enabled`,
`observability_node_pve_exporter_enabled`,
`observability_node_smartctl_exporter_enabled`).

This precedence is standard Ansible group_vars precedence (child group wins
over parent), but the *pattern* — unprefixed shared value → prefixed
role-interface value, one hop apart — is the repo's own convention, not
something Ansible gives you for free.

## Connection model

From `ansible.cfg` (`ansible/ansible.cfg`, full file):

| Setting | Value | Why |
|---|---|---|
| `remote_user` | `ansible` | The unprivileged account cloud-init seeds into every guest (see [[provisioning]]'s cloud-init template) |
| `private_key_file` | `~/.ssh/ansible_id` | Matches the public key in `secrets/ansible_id.sops.yaml` that Terraform injects via cloud-init |
| `become` | `true` globally, via `sudo` | Escalation at the connection-config level, not baked per-play |
| `interpreter_python` | `/usr/bin/python3` | Pins behavior identically across Ubuntu and Rocky targets |
| `forks` | `10` | Parallelism across the fleet |
| `vars_plugins_enabled` | `host_group_vars, community.sops.sops` | Both the normal `group_vars`/`host_vars` loader and the SOPS lookup plugin are active as vars sources |

The `[galaxy]` section (`role_skeleton = ./template_role`,
`init_path = ./roles`) means `ansible-galaxy role init my_new_role` scaffolds
a role that already has a `meta/argument_specs.yml.j2` stub
(`ansible/template_role/meta/argument_specs.yml.j2`) — validated input is the
default for a new role, not something to remember to add later.

## Check your understanding

- [ ] Without looking it up: which single YAML setting in
      `00_inv.proxmox.yml` turns a Proxmox tag into an Ansible group of the
      same name, and what would change if `prefix` were set to something
      non-empty?
- [ ] Which implicit group does the `community.proxmox.proxmox` plugin create
      for every QEMU guest, and which static inventory file wires it into
      `observability_node`?
- [ ] Is `media_platform` group membership driven by a Terraform tag or a
      static file today? What would you need to check to be sure?
- [ ] Why does `sops.yml` run against `localhost`, and what does it actually
      install — SOPS on every managed host, or something narrower?
- [ ] Why is `lvm_storage_logical_volumes` marked `required: true` in
      `argument_specs.yml` even though its role default is an empty list —
      is that a contradiction?
- [ ] What does `force: false` on the `sabnzbd.ini` and Bazarr config
      templates actually protect against on a second playbook run?
- [ ] Why does `gpu.yml` call `meta: flush_handlers` instead of letting the
      normal end-of-play handler timing apply the pending reboot?
- [ ] Trace a port value from `group_vars/observability` through to a
      rendered template — how many hops, and why is the value not just set
      directly on the role default?
