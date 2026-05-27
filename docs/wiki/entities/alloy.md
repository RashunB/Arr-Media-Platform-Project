---
type: service
name: Alloy
port: 12345
host: "[[control]]"
image: grafana/alloy:latest
status: deployed
tags: [service, telemetry, logs, metrics, agent]
---

# Alloy — :12345

Grafana Alloy is the unified telemetry agent. Runs on **all three hosts** (control, pve,
monitoring-1). Responsible for shipping logs to [[loki]] and forwarding metrics.

## Instances

| Host | Journal enabled | Config file |
|------|----------------|-------------|
| [[control]] | Yes (`alloy_journal_enabled: true`) | `/opt/alloy/alloy-config.yml` |
| [[pve]] | Yes (`alloy_journal_enabled: true`) | `/opt/alloy/alloy-config.yml` |
| [[monitoring-1]] | No | `/opt/alloy/alloy-config.yml` |

## Configuration

- **Template (control/pve):** `ansible/playbooks/templates/control/observability/alloy-config.yml.j2`
- **Template (nodes):** `ansible/playbooks/templates/nodes/observability/alloy-config.yml.j2`

## Open Issues

- [[synthesis/milestone-1-retrospective#CR-4|CR-4 R1]] — Node template src uses underscore filename but disk has hyphen
- [[synthesis/milestone-1-retrospective#CR-5|CR-5]] — Node dest uses `.yaml` extension but compose mounts `.yml`
- [[synthesis/milestone-1-retrospective#CR-11|CR-11 B23]] — Node compose missing `{% if alloy_journal_enabled %}` journald volume mounts

## Notes

> [!tip] Why Alloy over Promtail?
> See [[comparisons/alloy-vs-promtail]] for the tradeoff. Short answer: Alloy is the unified
> Grafana agent that replaces Promtail, Grafana Agent, and others — single binary, single config.

> [!warning] Control vs Node Compose Templates
> Control and node Alloy configs are different templates. Control has journald volumes hardcoded.
> Node template should use `{% if alloy_journal_enabled %}` guards for portability.