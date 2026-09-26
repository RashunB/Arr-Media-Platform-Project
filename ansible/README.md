# Ansible (`ansible/`)

Configuration layer. Everything that happens *inside* a host lives here: package
installation, storage, users, container runtimes, and the Docker Compose
workloads themselves.

The machines being configured are created by Terraform in
[`../workspace`](../workspace/README.md). The two never call each other; they
meet at Proxmox VM tags.

---

## Inventory: dynamic first, static overlay second

Files in `inventory/` are numbered because Ansible merges a directory in
lexical order, and the static files reference hosts that the dynamic source has
to have discovered first.

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

Host addressing is computed rather than recorded, handling both VM and container
guests:

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

Adding a monitored host is therefore a Terraform tag change, not an Ansible one.

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

Tags are declared at import level in `site.yml` (`sops`, `secrets`,
`observability`, `control`, `node`, `media_platform`) and again per-role inside
each playbook (`docker`, `lvm`), so you can target either a whole subsystem or
one concern across hosts.

Both observability playbooks set `force_handlers: true`, so a container restart
queued by a config change still fires even if a later task in the play fails.

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

`geerlingguy.docker` and `geerlingguy.pip` are committed under `roles/` rather
than resolved at runtime, so a play never depends on Galaxy being reachable and
the exact role version is visible in git history.

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

Role defaults are prefixed with the role name (`media_platform_*`,
`observability_node_*`). Shared values are defined unprefixed once in a parent
`group_vars` file and mapped onto role variables in the child:

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
play. Until the role `README.md` files are filled in, these specs are the
authoritative reference for what each role accepts.

---

## Secrets

`ansible.cfg` enables the SOPS vars plugin:

```ini
vars_plugins_enabled = host_group_vars, community.sops.sops
```

Encrypted group variables are symlinked into the inventory rather than
duplicated:

```
inventory/group_vars/media_platform.sops.yml -> ../../../secrets/media_platform.sops.yaml
vault/pve.sops.yaml                          -> ../secrets/pve.sops.yaml
```

The plugin decrypts in memory at var-load time. The inventory plugin uses
`community.sops.sops` lookups for its own API credentials. Nothing is written
to disk in plaintext, and `secrets/` stays the single place a credential lives.

Export `SOPS_AGE_KEY_FILE` before running anything.

---

## Connection model

From `ansible.cfg`:

| Setting | Value | Why |
|---|---|---|
| `remote_user` | `ansible` | The unprivileged account cloud-init seeds into every guest |
| `private_key_file` | `~/.ssh/ansible_id` | Matches the public key in `secrets/ansible_id.sops.yaml` that Terraform injects |
| `become` | `true`, via `sudo` | Escalation at the play level, not baked into the login user |
| `interpreter_python` | `/usr/bin/python3` | Silences discovery warnings and pins behavior across Ubuntu and Rocky |
| `forks` | `10` | Parallelism across the fleet |

The SSH keypair is generated once, stored encrypted, injected into guests by
Terraform's cloud-init template, and consumed here. No manual key distribution.

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
directories, so validated input is the default for a new role rather than
something to remember later.

---

## Linting

```bash
ansible-lint -c ../.ansible-lint          # from ansible/
yamllint .                                # from the repo root
pre-commit run --all-files                # everything, as CI runs it
```

`ansible-lint` and `yamllint` both run as dedicated CI jobs on every pull
request. The full gate list is in the [root README](../README.md).
