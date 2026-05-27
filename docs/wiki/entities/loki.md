---
type: service
name: Loki
port: 3100
host: "[[control]]"
image: grafana/loki:latest
status: deployed
tags: [service, logs, observability, log-aggregation]
---

# Loki — :3100

Log aggregation backend. Receives log streams from [[alloy]] agents running on all hosts.
[[grafana]] queries it via the Loki datasource.

## Configuration

- **Config file:** `/opt/loki/loki-config.yml`
- **Template:** `ansible/playbooks/templates/control/observability/loki-config.yml.j2`

## Log Sources

| Source | Agent | Status |
|--------|-------|--------|
| control systemd journal | Alloy on control | Active |
| pve systemd journal | Alloy on pve | Active |
| monitoring-1 app logs | Alloy on monitoring-1 | Active |

## Security Notes

> [!danger] Unauthenticated Port
> Port 3100 is bound to `0.0.0.0` with no authentication. Any host on the LAN can read all
> aggregated logs via the Loki API. **Must be protected before external exposure.**

## Notes

Mount path fixed in Phase 2 (B4): control compose now correctly mounts `loki-config.yml` matching
the path the playbook deploys.