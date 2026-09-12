---
type: host
hostname: monitoring-1
ip: dynamic
os: Debian 12
role: vm-node
status: active
tags: [host, vm, observability-nodes, proxmox-vm]
---

# monitoring-1 — dynamic IP (VM on PVE)

First VM node running on [[pve]]. Demonstrates the pattern for all future VM fleet members:
Alloy agent + node-exporter + cAdvisor + smartctl-exporter, pointed at the control stack.

## Services Running

| Service | Port | Purpose |
|---------|------|---------|
| [[alloy\|Alloy]] | — | Telemetry agent → [[loki\|Loki]] |
| [[node-exporter\|node-exporter]] | 9100 | Host metrics → [[prometheus\|Prometheus]] |
| [[cadvisor\|cAdvisor]] | 8080 | Container metrics |
| [[smartctl-exporter\|smartctl-exporter]] | 9633 | Disk health |

## Ansible

- **Inventory group:** `observability_nodes` (standalone, not child of baremetal)
- **Group vars:** `ansible/inventory/group_vars/observability_nodes/`
- **Playbook:** `ansible/playbooks/observability_node.yml`

## Key Variables

```yaml
alloy_journal_enabled: false   # VMs don't have systemd journal accessible
pve_exporter_enabled: false    # Not a hypervisor
loki_remote_url: "http://{{ control_host_ip }}:3100/loki/api/v1/push"
```

## Open Issues

- [[synthesis/milestone-1-retrospective#CR-4|CR-4 R1]] — Alloy template src filename mismatch (underscore vs hyphen)
- [[synthesis/milestone-1-retrospective#CR-5|CR-5]] — Alloy dest extension mismatch (.yaml vs .yml)
- [[synthesis/milestone-1-retrospective#CR-10|CR-10 B21]] — Prometheus has no scrape targets for this host
- [[synthesis/milestone-1-retrospective#CR-11|CR-11 B23]] — Node compose missing journald volume mounts

## Notes

> [!info] Template for Future VMs
> Every new VM added to the homelab (arr stack, Immich, Paperless, Pi-hole) should follow this
> exact pattern. Add it to `observability_nodes` group and it gets agents automatically.

> [!tip] cAdvisor Port Conflict
> cAdvisor on nodes is configured but has no host port binding (B7), so Prometheus cannot scrape it.
> Fix: add `ports: ["8080:8080"]` to node compose template.
