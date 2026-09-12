---
type: host
hostname: control
ip: 192.168.0.60
os: Debian 12
role: control
status: active
tags: [host, baremetal, control, observability-control]
---

# control — 192.168.0.60

The primary control machine. Runs the entire observability stack in Docker Compose and acts as the
Ansible control node for the rest of the homelab.

## Services Running

| Service | Port | Purpose |
|---------|------|---------|
| [[prometheus\|Prometheus]] | 9090 | Metrics scraper + TSDB |
| [[grafana\|Grafana]] | 3000 | Dashboards |
| [[loki\|Loki]] | 3100 | Log aggregation |
| [[alloy\|Alloy]] | 12345 | Telemetry agent (logs + metrics) |
| [[dozzle\|Dozzle]] | 8080 | Docker log viewer |
| [[node-exporter\|node-exporter]] | 9100 | Host metrics |
| [[cadvisor\|cAdvisor]] | 8080 | Container metrics |
| [[smartctl-exporter\|smartctl-exporter]] | 9633 | Disk health |

## Ansible

- **Inventory group:** `observability_control` (child of `baremetal`)
- **Group vars:** `ansible/inventory/group_vars/observability_control/`
- **Playbook:** `ansible/playbooks/observability_control.yml`
- **Ansible connection:** `localhost` (local execution)

## Key Variables

```yaml
control_host_ip: "192.168.0.60"
cluster_name: homelab
alloy_journal_enabled: true   # from baremetal group
```

## Compose Stack

Location: `/opt/docker/observability/docker-compose.yml`
Template source: `ansible/playbooks/templates/control/observability/docker-compose.yml.j2`

## Notes

> [!note] SSH Key
> Ansible uses `~/.ssh/ansible_id` for remote hosts. Control runs locally so no SSH is used for this host.
