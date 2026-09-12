---
type: concept
tags: [concept, observability, theory]
---

# Observability Pillars

The three signals that together give full visibility into a running system.

## The Three Pillars

| Pillar | Tool | What it tells you |
|--------|------|-------------------|
| **Metrics** | [[entities/prometheus\|Prometheus]] + [[entities/grafana\|Grafana]] | System is healthy/degraded — quantitative trends |
| **Logs** | [[entities/alloy\|Alloy]] + [[entities/loki\|Loki]] + [[entities/grafana\|Grafana]] | What happened and when — event records |
| **Traces** | Not yet implemented | Why it happened — request path through services |

## Current Stack Coverage

```
Metrics  ████████████████████  Full (with B21 gap for monitoring-1)
Logs     ██████████████░░░░░░  Partial (journal + Docker logs, B23 gap)
Traces   ░░░░░░░░░░░░░░░░░░░░  Not implemented
```

## Metrics in This Stack

- **node-exporter** → CPU, memory, disk, network per host
- **cAdvisor** → per-container resource usage
- **smartctl-exporter** → drive S.M.A.R.T. health
- **pve-exporter** → VM/container status, storage, cluster health
- **Alloy** → agent health and pipeline metrics

## Logs in This Stack

- **systemd journal** → OS-level events (kernel, services, systemd units)
- **Docker log driver** → container stdout/stderr
- Alloy ships both to Loki with host/job/container labels for filtering in Grafana

## Future: Traces

For the homelab scale, distributed tracing is overkill today. Would become relevant if:
- Self-hosted web apps with multiple service dependencies are added
- Performance debugging requires cross-service request traces

Grafana Tempo would be the natural addition (completes the Grafana LGTM stack: Loki + Grafana + Tempo + Mimir).

## Related

- [[telemetry-pipeline]] — how signals flow to dashboards
