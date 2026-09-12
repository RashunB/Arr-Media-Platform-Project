---
type: service
name: node-exporter
port: 9100
host: "[[control]]"
image: prom/node-exporter:latest
status: deployed
tags: [service, metrics, exporter, host-metrics]
---

# node-exporter — :9100

Prometheus exporter for host-level metrics: CPU, memory, disk I/O, filesystem, network.
Runs on **all three hosts** (control, pve, monitoring-1).

## Instances

| Host | Port | Scraped by Prometheus |
|------|------|-----------------------|
| [[control]] | 9100 | Yes |
| [[pve]] | 9100 | Yes |
| [[monitoring-1]] | 9100 | **No — B21** |

## Notes

> [!warning] monitoring-1 Not Scraped
> `prometheus.yml.j2` has no scrape job for `observability_nodes` group hosts.
> monitoring-1 runs node-exporter but its metrics never reach Prometheus.
> Fix tracked in [[synthesis/milestone-1-retrospective#CR-10|B21]].
