---
type: concept
tags: [concept, observability, promql, sre, metrics]
---

# Golden Signals

The four golden signals from the Google SRE book: **Latency, Traffic, Errors, Saturation**. PromQL queries below are written against the exporters actually running in this stack.

## Latency

How long requests take. Distinguish fast errors from slow errors.

### Prometheus HTTP (internal)

```promql
# p99 request duration for Prometheus's own HTTP handler
histogram_quantile(0.99,
  sum(rate(prometheus_http_request_duration_seconds_bucket[5m])) by (le, handler)
)
```

### Loki HTTP

```promql
# p99 ingest latency (Alloy push target)
histogram_quantile(0.99,
  sum(rate(loki_request_duration_seconds_bucket{route="/loki/api/v1/push"}[5m])) by (le)
)
```

### Node I/O latency

```promql
# p99 disk read latency (ms) — all block devices on control
histogram_quantile(0.99,
  sum(rate(node_disk_read_time_seconds_bucket{job="node-exporter"}[5m])) by (le, device)
) * 1000
```

---

## Traffic

Volume of work the system is doing.

### Prometheus scrape rate

```promql
# Samples scraped per second across all jobs
sum(rate(prometheus_tsdb_samples_appended_total[5m]))
```

### Loki push rate (log lines/sec)

```promql
sum(rate(loki_distributor_lines_received_total[5m]))
```

### Network throughput — control host

```promql
# Receive Mbps
sum(rate(node_network_receive_bytes_total{job="node-exporter", device!~"lo|docker.*|veth.*"}[5m])) * 8 / 1e6

# Transmit Mbps
sum(rate(node_network_transmit_bytes_total{job="node-exporter", device!~"lo|docker.*|veth.*"}[5m])) * 8 / 1e6
```

### cAdvisor — container network (observability stack)

```promql
sum(rate(container_network_receive_bytes_total{
  container_label_com_docker_compose_project="observability"
}[5m])) by (name) * 8 / 1e6
```

---

## Errors

Rate of requests that fail, explicitly or implicitly.

### Prometheus HTTP 5xx

```promql
sum(rate(prometheus_http_requests_total{code=~"5.."}[5m])) by (handler)
  /
sum(rate(prometheus_http_requests_total[5m])) by (handler)
```

### Prometheus scrape failures

```promql
# Targets currently down (value 1 = up, 0 = down)
sum by (job, instance) (up == 0)
```

### Loki push errors

```promql
sum(rate(loki_request_duration_seconds_count{status_code=~"5..", route="/loki/api/v1/push"}[5m]))
```

### Node disk errors

```promql
sum(rate(node_disk_io_time_weighted_seconds_total{job="node-exporter"}[5m])) by (device)
```

---

## Saturation

How full the most constrained resource is.

### CPU saturation — host

```promql
# Fraction of CPU time NOT idle (1 = fully saturated)
1 - avg(rate(node_cpu_seconds_total{mode="idle", job="node-exporter"}[5m]))
```

### CPU saturation — containers

```promql
# Throttled fraction per container (approaching 1 = CPU limit hit)
sum(rate(container_cpu_cfs_throttled_seconds_total[5m])) by (name)
  /
sum(rate(container_cpu_cfs_periods_total[5m])) by (name)
```

### Memory pressure — host

```promql
# Fraction of physical RAM in use
1 - (
  node_memory_MemAvailable_bytes{job="node-exporter"}
  /
  node_memory_MemTotal_bytes{job="node-exporter"}
)
```

### Memory — per container (working set)

```promql
sum(container_memory_working_set_bytes{
  container_label_com_docker_compose_project="observability",
  name!=""
}) by (name)
```

### Disk fill rate — control

```promql
# Hours until / is full at current write rate (negative = shrinking)
(
  node_filesystem_avail_bytes{job="node-exporter", mountpoint="/"}
  /
  -deriv(node_filesystem_avail_bytes{job="node-exporter", mountpoint="/"}[1h])
) / 3600
```

### Prometheus TSDB utilization

```promql
# WAL segment count — proxy for write volume
prometheus_tsdb_wal_segments_current
```

---

## Resource Limits Baseline

Suggested compose `deploy.resources` limits. Tune after observing actual working set via cAdvisor.

| Service | CPU limit | Memory limit | Memory reservation |
|---------|-----------|--------------|--------------------|
| prometheus | 1.0 | 2Gi | 512Mi |
| grafana | 0.5 | 256Mi | 128Mi |
| loki | 0.5 | 1Gi | 256Mi |
| alloy | 0.5 | 256Mi | 128Mi |
| node-exporter | 0.1 | 64Mi | 32Mi |
| cadvisor | 0.2 | 128Mi | 64Mi |
| smartctl-exporter | 0.05 | 32Mi | 16Mi |
| dozzle | 0.1 | 64Mi | 32Mi |

Add to each service in `docker-compose.yml.j2`:

```yaml
deploy:
  resources:
    limits:
      cpus: "0.5"
      memory: 256M
    reservations:
      memory: 128M
```

> [!warning] Open Issue
> Resource limits are not set on any compose service (CR-11 / Phase 2 gap). A misbehaving Prometheus could OOM the host without them.

---

## Related

- [[homelab-slos]] — SLO targets and error budget math using these signals
- [[telemetry-pipeline]] — how metrics flow from exporters to Prometheus
- [[prometheus]] — scrape configuration and service entity
- [[observability-pillars]] — metrics / logs / traces overview
