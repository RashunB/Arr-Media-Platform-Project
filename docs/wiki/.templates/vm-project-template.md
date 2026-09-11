---
type: project
status: planned     # planned | provisioning | active
host_target: pve
tags: [project, vm, planned]
---

# {{Project Name}}

## Services

| Service | Port | Image |
|---------|------|-------|

## Observability

- **Ansible group:** `observability_nodes`
- **Alloy:** journal enabled?
- **Exporters:** node-exporter, cAdvisor, smartctl-exporter

## Ansible Integration

- Playbook: `observability_node.yml` (automatic via group)
- Any additional role/playbook:

## VM Specs (on PVE)

| | |
|-|-|
| vCPU | |
| RAM | |
| Disk | |
| IP | |

## Notes