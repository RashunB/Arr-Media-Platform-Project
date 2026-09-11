---
type: service
name: pve-exporter
port: 9221
host: "[[pve]]"
image: prompve/prometheus-pve-exporter:latest
status: deployed
tags: [service, metrics, exporter, proxmox]
---

# pve-exporter — :9221

Proxmox VE API exporter. Queries the PVE REST API to expose VM/container status, resource
usage, cluster health, and storage metrics to Prometheus. **PVE-only** — guarded by
`pve_exporter_enabled: true`.

## Configuration

- **Credentials file:** `/opt/pve-exporter/pve.yml` (vault-encrypted, deployed by Ansible)
- **Template:** `ansible/playbooks/vault/pve.yml`

## Security Notes

> [!danger] Credential File Permissions
> Fixed in Phase 2 (S14 / CR-8): was deployed `mode: 0644` (world-readable).
> Now `mode: 0600` — only the service user can read it.

> [!warning] Guard Required
> The credential copy task must have `when: pve_exporter_enabled | default(false)`.
> Without this guard (B15 / CR-7), PVE credentials are deployed to ALL nodes including
> `monitoring-1` where they serve no purpose. Fixed in Phase 1 remediation.

## Notes

`pve_exporter_enabled: true` is set in `observability_pve` group vars.
`pve_exporter_enabled: false` is set in `observability_nodes` group vars.
Never set in `baremetal` — inherits default.