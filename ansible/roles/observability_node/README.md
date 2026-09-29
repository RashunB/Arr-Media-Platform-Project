# observability_node

Deploys the per-host half of the observability stack: node-exporter,
cAdvisor, a Dozzle agent, and Grafana Alloy on every host, plus
smartctl-exporter and pve-exporter where enabled. `observability_node.yml`
applies it after `docker_base` to the `observability_node` group, which
covers every QEMU guest automatically and the `pve` host through
`observability_pve`. [`observability_control`](../observability_control/README.md)
scrapes and aggregates what this role exposes.

## What it does

The task files run in this order (`tasks/main.yml`):

1. `alloy.yml` renders the Alloy configuration that ships container logs,
   and the host journal when `observability_node_alloy_journal_enabled` is
   true, to `observability_node_loki_remote_url`.
2. `pve_exporter.yml`, only when `observability_node_pve_exporter_enabled` is
   true, renders the pve-exporter configuration with the dedicated Prometheus
   API token from `secrets/pve.sops.yaml`.
3. `dozzle.yml` prepares the Dozzle agent, which the control host's hub
   connects to on `observability_node_dozzle_host_port`.
4. `compose.yml` renders `docker-compose.yml` and starts the project.

node-exporter runs with `network_mode: host`, `pid: host`, and the host root
filesystem mounted at `/host`. It enables the `cpu.info`, `systemd`, and
`processes` collectors. The `systemd` collector reads unit state over the
host D-Bus socket, bind-mounted read-only at
`/var/run/dbus/system_bus_socket`.

## Requirements

- `docker_base` applied first.
- `group_vars/observability_node` maps the shared values onto this role's
  prefixed variables; `group_vars/observability_pve` enables smartctl-exporter,
  pve-exporter, and journal shipping on the Proxmox host.

## Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `observability_node_root_dir` | str | `/opt` | Base directory for all service config and data. |
| `observability_node_node_exporter_name` | str | `node-exporter` | Name of node-exporter container/service |
| `observability_node_node_exporter_host_port` | int | `9100` | Host port for node-exporter container/service |
| `observability_node_cadvisor_name` | str | `cadvisor` | Name of cadvisor container/service |
| `observability_node_cadvisor_host_port` | int | `8080` | Host port for cadvisor container/service |
| `observability_node_smartctl_exporter_name` | str | `smartctl-exporter` | Name of smartctl-exporter container/service |
| `observability_node_smartctl_exporter_host_port` | int | `9633` | Host port for smartctl-exporter container/service |
| `observability_node_alloy_name` | str | `alloy` | Name of alloy container/service |
| `observability_node_alloy_host_port` | int | `12345` | Host port for alloy container/service |
| `observability_node_alloy_con_port` | int | `12345` | Internal port for alloy container/service |
| `observability_node_alloy_journal_enabled` | bool | `false` | Boolean for alloy picking up journal logs |
| `observability_node_loki_remote_url` | str | **required** | Remote url for loki endpoint |
| `observability_node_dozzle_name` | str | `dozzle` | Name of dozzle container/service |
| `observability_node_dozzle_host_port` | int | `7007` | Host port for dozzle container/service |
| `observability_node_smartctl_exporter_enabled` | bool | `false` | Toggle deployment of the smartctl-exporter service |
| `observability_node_pve_exporter_enabled` | bool | `false` | Toggle deployment of the pve-exporter service |
| `observability_node_pve_exporter_name` | str | `pve-exporter` | Name of pve-exporter container/service |
| `observability_node_pve_exporter_host_port` | int | `9221` | Host port for pve-exporter container/service |

## Example

```yaml
- name: Observability nodes
  hosts: observability_node
  become: true
  force_handlers: true
  tasks:
    - ansible.builtin.import_role:
        name: docker_base
    - ansible.builtin.import_role:
        name: observability_node
```
