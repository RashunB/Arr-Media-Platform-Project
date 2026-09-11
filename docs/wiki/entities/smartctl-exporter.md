---
type: service
name: smartctl-exporter
port: 9633
host: "[[control]]"
image: prometheuscommunity/smartctl-exporter:latest
status: deployed
tags: [service, metrics, exporter, disk-health]
---

# smartctl-exporter — :9633

Exposes S.M.A.R.T. disk health metrics from `smartctl`. Useful for early warning of disk
failure on bare-metal hosts. Runs on all three hosts.

## Instances

| Host | Port | Scraped by Prometheus |
|------|------|-----------------------|
| [[control]] | 9633 | Yes |
| [[pve]] | 9633 | Yes |
| [[monitoring-1]] | 9633 | **No — B21** |

## Notes

> [!tip] Why This Matters
> Bare-metal drives fail without warning in consumer hardware. smartctl-exporter feeding Grafana
> gives visibility into reallocated sectors, temperature, and pending sector count before a drive
> actually fails. Especially important for PVE which hosts all VMs.