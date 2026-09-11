---
type: service
name: Prometheus
port: 9090
host: "[[control]]"
image: prom/prometheus:latest
status: deployed
tags: [service, metrics, observability, tsdb]
---

# Prometheus — :9090

Time-series database and metrics scraper. Central sink for all host and container metrics
across the homelab. Grafana queries it as a datasource.

## Configuration

- **Config file:** `/opt/prometheus/prometheus.yml`
- **Template:** `ansible/playbooks/templates/control/observability/prometheus.yml.j2`
- **Data dir:** `/opt/prometheus/data`

## Scrape Targets (Current)

| Job | Target | Status |
|-----|--------|--------|
| control node-exporter | 192.168.0.60:9100 | Active |
| control cAdvisor | 192.168.0.60:8080 | Active |
| pve node-exporter | 192.168.0.63:9100 | Active |
| pve pve-exporter | 192.168.0.63:9221 | Active |
| monitoring-1 node-exporter | dynamic:9100 | **Missing — B21** |
| monitoring-1 cAdvisor | dynamic:8080 | **Missing — B21 + B7** |

## Open Issues

- [[synthesis/milestone-1-retrospective#CR-10|B21]] — No scrape targets for `monitoring-1`; template doesn't loop over `observability_nodes`

## Useful PromQL Queries

```promql
# All scrape targets currently down
sum by (job, instance) (up == 0)

# Scrape duration p99 per job (ms)
histogram_quantile(0.99,
  sum(rate(prometheus_target_interval_length_seconds_bucket[5m])) by (le, job)
) * 1000

# Time series count per job (cardinality)
sum by (job) (prometheus_tsdb_head_series)

# Total samples stored in TSDB
prometheus_tsdb_head_samples_appended_total

# WAL replay duration on last startup
prometheus_tsdb_reloads_total

# Config reload success (1 = success, 0 = failed)
prometheus_config_last_reload_successful
```

For host/container saturation queries, see [[golden-signals]].

---

## Security Notes

> [!danger] Unauthenticated Admin API
> `--web.enable-admin-api` and `--web.enable-lifecycle` are enabled with no authentication.
> Any LAN host can trigger snapshot creation, series deletion, or config reload.
> **Must be locked down before any external exposure.** See [[synthesis/security-posture]].

## Future

- Replace static scrape targets with `file_sd_configs` so new VMs appear automatically
- Add Alertmanager integration for "instance down" and disk fill alerts