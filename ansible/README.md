# Ansible (`ansible/`)

Configuration layer. Everything that happens *inside* a host lives here: package
installation, storage, users, container runtimes, and the Docker Compose
workloads themselves.

Terraform in [`../workspace`](../workspace/README.md) creates the machines this
layer configures. The two never call each other; they
meet at Proxmox VM tags.

---

## Inventory: dynamic first, static overlay second

Files in `inventory/` carry numeric prefixes because Ansible merges a directory
in lexical order, and the static files reference hosts that the dynamic source
must discover first.

| File | Kind | Role |
|---|---|---|
| `00_inv.proxmox.yml` | dynamic | `community.proxmox.proxmox` plugin. Queries the PVE API for every guest |
| `01_baremetal.ini` | static | The two physical hosts, which Proxmox cannot report about itself |
| `10_observability.ini` | static | Composes observability groups from dynamic and static sources |
| `11_media_platform.ini` | static | Assigns discovered hosts to the media workload |

### How the Terraform handoff works

`00_inv.proxmox.yml` turns live Proxmox tags into Ansible groups:

```yaml
keyed_groups:
  - key: proxmox_tags_parsed
    separator: ""
    prefix: ""
```

With an empty prefix and separator, a Proxmox tag becomes a group of the same
name. Terraform's `proxmox_vm` module writes those tags at VM creation
(`vm_tag_list`, `vm_group`, `vm_name_prefix`, plus a `terraform` marker tag), so
a newly provisioned VM lands in the right groups with **no inventory edit at
all**.

The plugin computes each host's address rather than recording it, handling both
VM and container guests:

```yaml
compose:
  ansible_host: >-
    proxmox_agent_interfaces[1]['ip-addresses'][0].split('/')[0]
    if proxmox_vmtype == 'qemu'
    else proxmox_lxc_interfaces[1]['inet'].split('/')[0]
```

The static files then layer semantics on top. `observability_node`, for example,
is a group of children combining the Proxmox host with every discovered QEMU
guest:

```ini
[observability_node:children]
observability_pve
proxmox_all_qemu
```

Every QEMU guest Terraform creates joins `observability_node` without an
inventory edit.

The plugin's own credentials come from SOPS at inventory-parse time via
`community.sops` lookups, so even the inventory file contains no secret.

### Inspecting it

```bash
cd ansible
ansible-inventory --graph
ansible-inventory --host media-1
```

---

## Playbooks

| Playbook | Targets | Does |
|---|---|---|
| `site.yml` | everything | Entry point. Imports the four below in dependency order |
| `sops.yml` | `localhost` | Installs SOPS on the control node via `community.sops.install` |
| `observability_control.yml` | `observability_control` | Docker + the metrics/logs hub |
| `observability_node.yml` | `observability_node` | Docker + the per-host exporter set |
| `media_platform.yml` | `media_platform` | Docker + LVM + the media stack |

```bash
ansible-galaxy install -r requirements.yml   # collections, pinned by major version
ansible-playbook site.yml

ansible-playbook site.yml --tags media_platform
ansible-playbook site.yml --tags observability
ansible-playbook site.yml --check --diff       # dry run
```

`site.yml` declares tags at import level (`sops`, `observability`, `control`,
`node`, `media_platform`), and each playbook tags its role imports (`docker`,
`lvm`). A run targets either a whole subsystem or one concern across hosts.

All three host playbooks set `force_handlers: true`, so a container restart
queued by a config change still fires when a later task in the play fails.

---

## Role catalog

### First-party

| Role | Responsibility |
|---|---|
| `docker_base` | Thin composition layer over `geerlingguy.docker` and `geerlingguy.pip`, adding the `docker` Python SDK that the `community.docker` modules need |
| `lvm_storage` | Declarative PV to VG to LV to filesystem to mount pipeline, driven by one nested data structure |
| `media_platform` | Service user/group with fixed UID/GID, directory tree, per-app config templating, Intel GPU enablement, Compose deployment |
| `observability_control` | Prometheus, Loki, Grafana (with provisioned datasources and dashboards), Alloy, Dozzle, and a local exporter set |
| `observability_node` | node-exporter, cAdvisor, smartctl-exporter, Dozzle agent, Alloy, and conditionally pve-exporter |
| `nfs_server` | Export management. Available, not currently wired into a playbook |
| `nfs_client` | Mount management. Available, not currently wired into a playbook |

### Vendored

The repo commits `geerlingguy.docker` and `geerlingguy.pip` under `roles/`
rather than resolving them at runtime, so a play never depends on Galaxy being
reachable and git history records the exact role version.

### Role internals worth noting

**`lvm_storage`** takes the entire storage layout as one list of dicts and walks
it through four imported task files (`install` -> `volumes` -> `filesystem` ->
`mount`). Per-item `vg_state`, `lv_state`, `fs_state`, and `mount_state` keys
mean the same structure can create or tear down storage.

**`media_platform`** does more than run Compose. It creates a `media` user and
group at a fixed UID/GID 6000 so container and host file ownership line up, then
templates real application config (`sabnzbd.ini`, Bazarr's `config.yml`,
Configarr's quality profiles) before first start, so services come up configured
rather than needing a manual setup wizard. The `gpu.yml` task installs
`intel-media-va-driver-non-free`, `vainfo`, and `intel-gpu-tools`, adds the
service user to `video` and `render`, and flushes a reboot handler immediately
so the GPU is usable within the same run.

**`observability_control`** ships Grafana dashboards as JSON in `files/` and wires
them through Grafana's provisioning directory, so dashboards are version
controlled rather than clicked into existence and lost on a container rebuild.
Prometheus uses file-based service discovery, with one templated target file per
exporter type.

---

## Variable conventions

### Namespacing and re-export

Role defaults carry the role name as a prefix (`media_platform_*`,
`observability_node_*`). A parent `group_vars` file defines each shared value
once, unprefixed, and the child file maps it onto role variables:

```yaml
# group_vars/observability        (the shared truth)
prometheus_host_port: 9090

# group_vars/observability_control (mapped onto the role's interface)
observability_control_prometheus_host_port: "{{ prometheus_host_port }}"
```

Changing a port is a one-line edit that propagates to every role, template, and
scrape config, while roles keep collision-free, self-documenting interfaces.

`group_vars/observability_pve` shows the override pattern: the Proxmox host
inherits everything from `observability`, then flips on `pve_exporter`,
`smartctl_exporter`, and journal log collection for itself alone.

### Input validation

Every first-party role has `meta/argument_specs.yml`. Ansible validates role
input against it before the first task runs, so a malformed variable produces a
typed error at role entry rather than a confusing failure partway through a
play. These specs are the authoritative reference for what each role accepts.

---

## Secrets

`ansible.cfg` enables the SOPS vars plugin:

```ini
vars_plugins_enabled = host_group_vars, community.sops.sops
```

Symlinks place encrypted group variables in the inventory without duplicating
them:

```
inventory/group_vars/media_platform.sops.yml -> ../../../secrets/media_platform.sops.yaml
vault/pve.sops.yaml                          -> ../../secrets/pve.sops.yaml
```

The plugin decrypts in memory at var-load time. The inventory plugin uses
`community.sops.sops` lookups for its own API credentials. Neither writes
plaintext to disk, and `secrets/` stays the single place a credential lives.

Decryption requires `SOPS_AGE_KEY_FILE` pointing at the matching `age` private
key.

---

## Connection model

From `ansible.cfg`:

| Setting | Value | Why |
|---|---|---|
| `remote_user` | `ansible` | The unprivileged account cloud-init seeds into every guest |
| `private_key_file` | `~/.ssh/ansible_id` | Matches `secrets/ansible_id.pub`, which Terraform injects through cloud-init |
| `become` | `true`, via `sudo` | Escalation at the play level, not baked into the login user |
| `interpreter_python` | `/usr/bin/python3` | Silences discovery warnings and pins behavior across Ubuntu and Rocky |
| `forks` | `10` | Parallelism across the fleet |

The public key lives in `secrets/ansible_id.pub` and the private key in
`secrets/ansible_id.sops.yaml`. Terraform's cloud-init template seeds the public
key into every guest, so no manual key distribution step exists.

---

## Adding a role

The repo ships a Galaxy skeleton that enforces its own conventions, wired up in
`ansible.cfg`:

```ini
[galaxy]
role_skeleton = ./template_role
init_path = ./roles
```

```bash
cd ansible
ansible-galaxy role init my_new_role
```

The skeleton scaffolds `meta/argument_specs.yml` alongside the usual
directories, so every new role starts with validated input.

---

## Linting

```bash
ansible-lint -c ../.ansible-lint          # from ansible/
yamllint .                                # from the repo root
pre-commit run --all-files                # everything, as CI runs it
```

`ansible-lint` and `yamllint` both run as dedicated CI jobs on every pull
request. The full gate list is in the [root README](../README.md).
