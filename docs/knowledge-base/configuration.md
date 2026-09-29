---
title: Configuration (Ansible)
tags: [component/configuration, component/ansible]
created: 2026-09-17
---

# Configuration (Ansible)

> [!info] Scope
> `ansible/` in depth: the dynamic inventory mechanism, each first-party
> role's task flow, and variable precedence in practice. The role catalog
> table and quickstart commands live in
> [ansible/README.md](../../ansible/README.md).

## The inventory: how a Proxmox tag becomes an Ansible group

Files in `ansible/inventory/` carry numeric prefixes because Ansible merges
directory sources in lexical order, and the static files reference hosts the
dynamic source must discover first.

### `00_inv.proxmox.yml`: the dynamic source

```yaml
---
plugin: community.proxmox.proxmox
url: "{{ lookup('community.sops.sops', 'vault/pve.sops.yaml', extract='[\"pve_ansible_api_url\"]')}}"
user: "{{ lookup('community.sops.sops', 'vault/pve.sops.yaml', extract='[\"pve_ansible_api_user_name\"]')}}"
token_id: "{{ lookup('community.sops.sops', 'vault/pve.sops.yaml', extract='[\"pve_ansible_api_token_id\"]')}}"
token_secret: "{{ lookup('community.sops.sops', 'vault/pve.sops.yaml', extract='[\"pve_ansible_api_token_secret\"]')}}"
validate_certs: false
want_facts: true
keyed_groups:
  - key: proxmox_tags_parsed
    separator: ""
    prefix: ""

# groups:
  # media: "'media' in (proxmox_tags_parsed|list)"

compose:
  ansible_host: >-
    proxmox_agent_interfaces[1]['ip-addresses'][0].split('/')[0]
    if proxmox_vmtype == 'qemu'
    else proxmox_lxc_interfaces[1]['inet'].split('/')[0]

want_proxmox_nodes_ansible_host: true
```
(`ansible/inventory/00_inv.proxmox.yml`, full file)

The API endpoint and credentials come from `vault/pve.sops.yaml`, a symlink to
`secrets/pve.sops.yaml`, decrypted through a `community.sops.sops` lookup with
a jq-style `extract` path. **The inventory file that queries Proxmox holds no
plaintext credential or address.**

`keyed_groups` with an **empty `separator` and `prefix`** drives the whole
tag-to-group mechanism: a Proxmox tag named `media_platform` becomes an
Ansible group named exactly `media_platform`, with no prefix decoration. The
`modules/proxmox_vm` composed tag list (see [Provisioning](provisioning.md))
therefore turns directly into inventory membership.

The plugin **computes** `ansible_host` rather than storing it, taking
interface index `[1]` (not `[0]`) as the guest's primary address for both
QEMU (`proxmox_agent_interfaces`) and LXC (`proxmox_lxc_interfaces`) guests.
The Terraform module's `ipv4_addresses[1][0]` output makes the same
assumption (see [Provisioning](provisioning.md)): index `0` is loopback.

`want_proxmox_nodes_ansible_host: true` makes the plugin also discover the
Proxmox node itself as an inventory host. `01_baremetal.ini` defines the same
`pve` host statically, and Ansible merges same-named hosts from multiple
sources, so the two definitions layer rather than conflict.

### `host_vars/`: per-host connection details

`01_baremetal.ini` lists host names only. Each bare-metal host's address and
connection user live in `ansible/inventory/host_vars/<host>.yml`, which
`.gitignore` excludes, so no LAN address enters the repo. Committed
`control.yml.example` and `pve.yml.example` files show the expected keys:

```yaml
---
ansible_host: 192.0.2.20
ansible_user: root
```
(`ansible/inventory/host_vars/pve.yml.example`, full file)

`group_vars/observability` derives `control_host_ip` and `pve_node_ip` from
`hostvars[...]['ansible_host']`, so every role that needs these addresses
reads them from `host_vars/` indirectly.

The commented `groups:` block holds example Jinja-conditional group rules
from an earlier iteration. Every line of it, including the `groups:` key, is
commented, so it has no effect; `keyed_groups` plus the static overlay files
below define all group membership.

### The static overlay files

| File | Role |
|---|---|
| `01_baremetal.ini` | The two physical hosts Proxmox cannot report about itself, `control` and `pve`, by name only; addresses and `ansible_user` come from `host_vars/` |
| `10_observability.ini` | Composes `observability_node`, `observability_control`, and `observability` from dynamic and static groups |
| `11_media_platform.ini` | `[media_platform]` containing `media-1` |

`10_observability.ini`'s key group is `observability_node`:

```ini
[observability_node:children]
observability_pve
proxmox_all_qemu
```

`proxmox_all_qemu` is an **implicit group the `community.proxmox.proxmox`
plugin creates** for every guest of type `qemu`, independent of tags. Every
VM Terraform creates lands in `observability_node` by virtue of being a QEMU
guest. [Observability](observability.md) covers what that membership
triggers.

`media_platform` membership comes from `11_media_platform.ini`, a static
file listing `media-1`. Additional media hosts join by name in that file.

### Inspecting the merged result

```bash
cd ansible
ansible-inventory --graph
ansible-inventory --host media-1
```

## `site.yml`: the entry point

```yaml
---
- name: Setup SOPS on control
  ansible.builtin.import_playbook: sops.yml
  tags: [sops]

- name: Setup observability control
  ansible.builtin.import_playbook: observability_control.yml
  tags: [observability, control]

- name: Setup observability node
  ansible.builtin.import_playbook: observability_node.yml
  tags: [observability, node]

- name: Setup media platform
  ansible.builtin.import_playbook: media_platform.yml
  tags: [media_platform]
```
(`ansible/site.yml`, full file)

Import order matters. `sops.yml` runs against `hosts: localhost` first on
every run, regardless of `--limit`, unless `--skip-tags sops` excludes it. It
installs the `sops` CLI on the control node through `community.sops.install`:
a control-node concern, not a managed-host one.

All three host playbooks (`observability_control.yml`,
`observability_node.yml`, `media_platform.yml`) set `force_handlers: true` at
the play level, so a queued container-restart handler still fires when a
later task in the same play fails.

Each host playbook is a short, flat list of `import_role` calls with
per-task tags:

```yaml
---
- name: Media Platform
  hosts: media_platform
  become: true
  force_handlers: true
  tasks:
    - name: Install and configure Docker
      ansible.builtin.import_role:
        name: docker_base
      tags: docker

    - name: Configure LVM
      ansible.builtin.import_role:
        name: lvm_storage
      tags: lvm

    - name: Deploy Media Platform
      ansible.builtin.import_role:
        name: media_platform
      tags: media_platform
```
(`ansible/media_platform.yml`, full file)

Tags exist at two levels at once: import level in `site.yml` and task level
inside each playbook. `ansible-playbook site.yml --tags media_platform`
targets a whole subsystem, while `--tags docker` reaches across every
playbook that imports `docker_base`.

## Role catalog: task flow and `argument_specs`

Every first-party role ships `meta/argument_specs.yml`. Ansible validates role
input against it **before the first task runs**, so a malformed variable fails
at role entry with a typed error, not partway through a play. These specs are
the reference for what each role accepts.

### `docker_base`

```yaml
# tasks/main.yml, condensed
- import_role: { name: geerlingguy.docker }   # vars: docker_users: "{{ docker_base_users }}"
- import_role: { name: geerlingguy.pip }      # vars: pip_install_packages: [{name: docker}]
```

A two-step composition role. `docker_base_users` (default `[ansible]`) is its
only input. The role wires the vendored `geerlingguy.docker` role and
installs the `docker` Python package that `community.docker` modules
elsewhere in the repo need at runtime.

### `lvm_storage`

```yaml
# tasks/main.yml, condensed
import_tasks: install.yml      # apt: lvm2
import_tasks: volumes.yml      # community.general.lvg, then .lvol, looped
import_tasks: filesystem.yml   # community.general.filesystem, looped
import_tasks: mount.yml        # ansible.posix.mount, looped
```

The whole storage layout is **one variable**,
`lvm_storage_logical_volumes`: a list of dicts, each describing a full
PV-to-VG-to-LV-to-filesystem-to-mount pipeline. Per-item `vg_state`,
`lv_state`, `fs_state`, and `mount_state` keys let the same data structure
tear storage down as easily as create it: setting the states to `absent` and
re-running removes it.

> [!tip] `required: true` with an empty-list default
> `meta/argument_specs.yml` marks `lvm_storage_logical_volumes`
> `required: true`, and `defaults/main.yml` sets it to `[]`.
> `argument_specs` validation checks that a final value exists after
> defaults apply, not that the caller supplied one. With no override, the
> role satisfies its required variable and does nothing, because looping
> over an empty list is a no-op in every task file.

`ansible/inventory/group_vars/media_platform` is the current consumer: a
single VG (`vg.media`) built from two `scsi-SQEMU...` disk-by-id paths, ext4,
mounted at `/opt/media_platform`.

### `media_platform`

```yaml
# tasks/main.yml, condensed
import_tasks: users.yml             # group `media_platform` (gid 6000), user `media` (uid 6000)
import_tasks: media_directories.yml # data tree + per-service /config/<svc>/data dirs, mode 2775
import_tasks: sabnzbd.yml           # templates sabnzbd.ini, force: false
import_tasks: configarr.yml         # templates configarr config.yml, mode 0440
import_tasks: bazarr.yml            # templates bazarr config.yaml, force: false
import_tasks: gpu.yml               # driver packages + video/render groups + immediate reboot
import_tasks: compose.yml           # renders docker-compose.yml + .env, docker_compose_v2
```

This role pre-seeds real application config so services come up already
configured instead of opening a first-run setup wizard.

- `sabnzbd.yml` and `bazarr.yml` template their config with **`force:
  false`**. Ansible writes each file once and never overwrites it, so changes
  made through the web UI survive later playbook runs.
- `configarr.yml` writes its config with mode `0440`, read-only even for the
  owner. Configarr resolves secrets through `!env` indirection from the
  container's environment at runtime (see [Secrets](secrets.md)), so the
  file never needs in-place edits.

`gpu.yml` installs `linux-modules-extra-{{ ansible_kernel }}`, notifies the
`Reboot` handler, and then **immediately** calls
`ansible.builtin.meta: flush_handlers` at the end of the task file. The
reboot happens within the same `media_platform` role run, before
`compose.yml` starts containers that mount `/dev/dri`. Under Ansible's normal
handler timing the reboot would wait until the end of the play, and the new
kernel modules would not load before the containers start.

[GPU passthrough](gpu-passthrough.md) connects this to the Terraform-side PCI
passthrough and the Jellyfin container's device mount.

### `observability_control` and `observability_node`

Both roles share one shape: a `tasks/<service>.yml` per service that creates
directories, templates config, and notifies a per-service restart handler,
followed by a final `compose.yml` task that renders the full
`docker-compose.yml` and runs `docker_compose_v2` with `state: present`.

`observability_control` also ships Grafana dashboards as static JSON under
`files/grafana/provisioning/dashboards/` and wires them through Grafana's
file-based provisioning (`provider.yml` in the same directory), so dashboards
live in version control rather than in a container volume.
[Observability](observability.md) covers the full topology and the
Prometheus file-based service discovery mechanism.

## Variable conventions: namespacing and re-export

Role defaults carry the role name as a prefix (`media_platform_*`,
`observability_node_*`, `observability_control_*`). A parent `group_vars`
file holds each shared value **once, unprefixed**, and the child file maps it
onto each role's prefixed interface:

```yaml
# group_vars/observability        (the shared value)
prometheus_host_port: 9090

# group_vars/observability_control (mapped onto the role's interface)
observability_control_prometheus_host_port: "{{ prometheus_host_port }}"
```

A port change is a one-line edit in `group_vars/observability` that
propagates to every role, template, and scrape config that references it,
while the roles keep collision-free, self-documenting variable names.
`group_vars/observability_pve` shows the override pattern: it inherits
everything from `observability` and turns on exactly three booleans for the
PVE host (`observability_node_alloy_journal_enabled`,
`observability_node_pve_exporter_enabled`,
`observability_node_smartctl_exporter_enabled`).

The precedence is standard Ansible `group_vars` precedence (child group wins
over parent). The *pattern*, unprefixed shared value to prefixed role
variable one hop apart, is this repo's own convention.

## Connection model

From `ansible/ansible.cfg` (excerpt):

| Setting | Value | Purpose |
|---|---|---|
| `remote_user` | `ansible` | The unprivileged account cloud-init seeds into every guest (see [Provisioning](provisioning.md)) |
| `private_key_file` | `~/.ssh/ansible_id` | Pairs with `secrets/ansible_id.pub`, which Terraform injects through cloud-init |
| `become` | `true` globally, through `sudo` | Escalation at the connection-config level, not per play |
| `interpreter_python` | `/usr/bin/python3` | Identical behavior across Ubuntu and Rocky targets |
| `forks` | `10` | Parallelism across the fleet |
| `vars_plugins_enabled` | `host_group_vars, community.sops.sops` | Both the standard `group_vars`/`host_vars` loader and the SOPS vars plugin act as vars sources |

The `[galaxy]` section (`role_skeleton = ./template_role`,
`init_path = ./roles`) makes `ansible-galaxy role init my_new_role` scaffold
a role that already has a `meta/argument_specs.yml` stub from
`ansible/template_role/meta/argument_specs.yml.j2`, so every new role starts
with validated input.
