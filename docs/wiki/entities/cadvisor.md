---
type: service
name: cAdvisor
port: 8080
host: "[[control]]"
image: gcr.io/cadvisor/cadvisor:latest
status: deployed
tags: [service, metrics, exporter, container-metrics]
---

# cAdvisor — :8080

Google's Container Advisor. Exposes per-container resource metrics (CPU, memory, network, disk)
for Prometheus to scrape. Runs on all hosts.

## Instances

| Host | Port | Host Port Bound | Scraped |
|------|------|----------------|---------|
| [[control]] | 8080 | Yes | Yes |
| [[pve]] | 8080 | Yes | Yes |
| [[monitoring-1]] | 8080 | **No — B7** | **No — B21** |

## Open Issues

- **B7** — `monitoring-1` node compose has no `ports:` mapping for cAdvisor; Prometheus can't reach it
- **B21** — Even if port were bound, Prometheus template has no scrape job for `observability_nodes`

## Notes

> [!warning] Port Conflict with Dozzle
> Both cAdvisor and Dozzle request port 8080. On the control host these are separate compose services
> so they differentiate by service name, but the host port 8080 can only be bound by one process.
> Verify compose port mappings don't collide.