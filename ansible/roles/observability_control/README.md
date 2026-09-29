# observability_control

Deploys the central half of the observability stack on the `control` host:
Prometheus, Grafana, Loki, a Dozzle hub, and the same local exporters and
log shipper every node runs. `observability_control.yml` applies it after
`docker_base`. Its counterpart on every other host is
[`observability_node`](../observability_node/README.md).

## What it does

The task files run in this order (`tasks/main.yml`):

1. `prometheus.yml` renders `prometheus.yml` and one `file_sd` target file per
   entry in `observability_control_prometheus_file_sd_configs`. Each target
   file lists every `observability_node` host with that exporter's own port,
   read from the host's `hostvars`. Prometheus re-reads the files every 30
   seconds.
2. `grafana.yml` provisions the Prometheus and Loki datasources and copies the
   dashboards in `files/grafana/provisioning/dashboards/`.
3. `alloy.yml` and `loki.yml` render the Alloy and Loki configurations. Alloy
   ships container logs, and the host journal when
   `observability_control_alloy_journal_enabled` is true, to Loki.
4. `dozzle.yml` renders `DOZZLE_REMOTE_AGENT` from every `observability_node`
   host's address and `observability_node_dozzle_host_port`, so the hub
   reaches each node's agent.
5. `compose.yml` renders `docker-compose.yml` and starts the project.

Each rendered file notifies a restart handler for its service; the playbook
sets `force_handlers: true` so a later failure does not drop a pending
restart.

node-exporter runs with the `cpu.info`, `systemd`, and `processes`
collectors. The `systemd` collector reads unit state over the host D-Bus
socket, bind-mounted read-only at `/var/run/dbus/system_bus_socket`.

## Requirements

- `docker_base` applied first.
- `group_vars/observability` and `group_vars/observability_control` map the
  shared values (`cluster_name`, `control_host_ip`, ports) onto this role's
  prefixed variables. `control_host_ip` derives from the `control` host's
  `ansible_host` in `inventory/host_vars/`.

## Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `observability_control_cluster_name` | str | **required** | Cluster name for prometheus labeling |
| `observability_control_root_dir` | str | `/opt` | Base directory for all service config and data. |
| `observability_control_control_host_ip` | str | **required** | IP of node that will host control services |
| `observability_control_pve_node_ip` | str | none | Remote PVE IP |
| `observability_control_prometheus_name` | str | `prometheus` | Name of prometheus container/service |
| `observability_control_prometheus_host_port` | int | `9090` | Host port for prometheus container/service |
| `observability_control_node_exporter_name` | str | `node-exporter` | Name of node-exporter container/service |
| `observability_control_node_exporter_host_port` | int | `9100` | Host port for node-exporter container/service |
| `observability_control_cadvisor_name` | str | `cadvisor` | Name of cadvisor container/service |
| `observability_control_cadvisor_host_port` | int | `8080` | Host port for cadvisor container/service |
| `observability_control_smartctl_exporter_name` | str | `smartctl-exporter` | Name of smartctl-exporter container/service |
| `observability_control_smartctl_exporter_host_port` | int | `9633` | Host port for smartctl-exporter container/service |
| `observability_control_grafana_name` | str | `grafana` | Name of grafana container/service |
| `observability_control_grafana_host_port` | int | `3000` | Host port for grafana container/service |
| `observability_control_alloy_name` | str | `alloy` | Name of alloy container/service |
| `observability_control_alloy_host_port` | int | `12345` | Host port for alloy container/service |
| `observability_control_alloy_con_port` | int | `12345` | Internal port for alloy container/service |
| `observability_control_alloy_journal_enabled` | bool | `false` | Boolean for alloy picking up journal logs |
| `observability_control_loki_name` | str | `loki` | Name of loki container/service |
| `observability_control_loki_host_port` | int | `3100` | Host port for loki container/service |
| `observability_control_loki_remote_url` | str | `http://{{ observability_control_control_host_ip }}:{{ observability_control_loki_host_port }}/loki/api/v1/push` | Remote url for loki endpoint |
| `observability_control_dozzle_name` | str | `dozzle` | Name of dozzle container/service |
| `observability_control_dozzle_host_port` | int | `7070` | Host port for dozzle container/service |
| `observability_control_dozzle_agent_pve_ip` | str | none | Remote PVE IP for dozzle service |
| `observability_control_smartctl_exporter_enabled` | bool | `false` | Toggle deployment of the smartctl-exporter service |
| `observability_control_prometheus_file_sd_configs` | list of str | see `defaults/main.yml` | Exporters for which Prometheus file_sd target files are generated |

## Example

```yaml
- name: Observability control
  hosts: observability_control
  become: true
  force_handlers: true
  tasks:
    - ansible.builtin.import_role:
        name: docker_base
    - ansible.builtin.import_role:
        name: observability_control
```
