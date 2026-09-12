---
type: service
name: Grafana
port: 3000
host: "[[control]]"
image: grafana/grafana:latest
status: deployed
tags: [service, dashboards, observability, visualization]
---

# Grafana — :3000

Dashboard and visualization layer. Consumes metrics from [[prometheus]] and logs from [[loki]].
The human-facing window into the entire observability stack.

## Configuration

- **Config dir:** `/opt/grafana/`
- **Provisioning:** `ansible/playbooks/files/control/observability/grafana/provisioning/`
- **Dashboards:** JSON files in `provisioning/dashboards/` (static, not templated)

## Datasources

| Datasource | URL | Type |
|-----------|-----|------|
| Prometheus | `http://prometheus:9090` | Metrics |
| Loki | `http://loki:3100` | Logs |

## Security Notes

> [!danger] Default Credentials
> Grafana starts with `admin` / `admin` if no password override is configured.
> **Set a strong password before any external exposure.**
> See [[synthesis/security-posture]] for the full pre-exposure checklist.

## Dashboards

Provisioned dashboards live in `files/control/observability/grafana/provisioning/dashboards/`.
Static JSON — no Jinja2 templating. Update the JSON file to change dashboard content.

## Notes

Healthcheck fixed in Phase 2 (B6): was pointing to wrong URL, now correctly checks
`http://localhost:3000/api/health`.
