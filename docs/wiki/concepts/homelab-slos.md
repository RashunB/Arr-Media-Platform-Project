---
type: concept
tags: [concept, sre, slo, observability, alerting]
---

# Homelab SLOs

Service Level Objectives for the observability stack. These are homelab targets — no on-call pager, no external customers — but having explicit targets surfaces when things are meaningfully broken vs. expected degradation.

## SLO Targets

| Service | SLI | Target | Allowed downtime / month |
|---------|-----|--------|--------------------------|
| Prometheus | HTTP `up == 1` | 99.5% | 3h 39m |
| Grafana | HTTP 200 on `/api/health` | 99.0% | 7h 18m |
| Loki | Push endpoint 2xx rate | 99.0% | 7h 18m |
| Alloy (control) | Process `up == 1` | 99.5% | 3h 39m |
| node-exporter (all hosts) | `up == 1` per host | 99.0% | 7h 18m |

**Error budget math** (30-day window, request-based):

```
Allowed error rate = 1 - SLO
Prometheus at 99.5%: 0.5% of scrape attempts may fail
  → at ~10k scrapes/day: 50 failed scrapes/day allowed
  → monthly budget: ~1,500 failed scrapes
```

---

## Alerting Rules

Multiwindow burn-rate alerts catch both fast burns (large outage) and slow burns (sustained degradation).

### Prometheus availability — fast burn

```yaml
groups:
  - name: homelab_slo
    rules:
      # 2% of monthly Prometheus budget burned in 1h → critical
      - alert: PrometheusFastBurn
        expr: |
          (
            sum(rate(up{job="prometheus"}[1h])) < 0.986
          )
          and
          (
            sum(rate(up{job="prometheus"}[5m])) < 0.986
          )
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Prometheus scraping is failing fast"
          runbook: "wiki/operations/runbook-stack.md#prometheus-down"

      # Slow burn: sustained degradation over 6h
      - alert: PrometheusSlowBurn
        expr: |
          sum(rate(up{job="prometheus"}[6h])) < 0.995
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "Prometheus availability below SLO (slow burn)"
```

### Grafana availability

```yaml
      - alert: GrafanaDown
        expr: up{job="grafana"} == 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Grafana is unreachable"
          runbook: "wiki/operations/runbook-stack.md#grafana-down"
```

### Loki push errors

```yaml
      - alert: LokiPushErrors
        expr: |
          sum(rate(loki_request_duration_seconds_count{
            status_code=~"5..",
            route="/loki/api/v1/push"
          }[5m]))
          /
          sum(rate(loki_request_duration_seconds_count{
            route="/loki/api/v1/push"
          }[5m]))
          > 0.01
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Loki push error rate >1%"
```

### Disk fill rate

```yaml
      # Alert when / has <20% free
      - alert: DiskFillingUp
        expr: |
          node_filesystem_avail_bytes{job="node-exporter", mountpoint="/"} 
          / 
          node_filesystem_size_bytes{job="node-exporter", mountpoint="/"}
          < 0.20
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Root filesystem below 20% free on {{ $labels.instance }}"
```

### CPU throttling — containers

```yaml
      - alert: ContainerCPUThrottled
        expr: |
          sum(rate(container_cpu_cfs_throttled_seconds_total[5m])) by (name)
          /
          sum(rate(container_cpu_cfs_periods_total[5m])) by (name)
          > 0.25
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} CPU throttled >25%"
```

---

## Error Budget Policy

Since this is a homelab with no SLA commitments, the policy is intentionally lightweight:

| Budget remaining | Action |
|-----------------|--------|
| > 50% | Normal operation; any change is fine |
| 25–50% | Review what's consuming budget before big changes |
| < 25% | Prioritize stability; avoid non-critical restarts |
| Exhausted | Root-cause and fix before touching stack again |

---

## Where to Put Alert Rules

Alert rules belong in a file mounted into Prometheus. Add to `templates/control/observability/prometheus/rules/homelab.yml.j2` and mount via the Prometheus compose service:

```yaml
volumes:
  - /opt/prometheus/rules:/etc/prometheus/rules:ro
```

Then add to `prometheus.yml.j2`:

```yaml
rule_files:
  - /etc/prometheus/rules/*.yml
```

> [!note] Not Yet Implemented
> Alert rules are not currently deployed. This is a Phase 3 task. Grafana alerting can be used as a stopgap via the UI until Prometheus alertmanager is wired in.

---

## Related

- [[golden-signals]] — PromQL queries these rules are built from
- [[prometheus]] — scrape config and service entity
- [[runbook-stack]] — what to do when alerts fire
