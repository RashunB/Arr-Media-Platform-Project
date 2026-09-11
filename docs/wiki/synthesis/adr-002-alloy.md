---
type: adr
date: 2024-01-01
status: accepted
tags: [adr, architecture, alloy, telemetry, grafana]
---

# ADR-002: Alloy as Unified Telemetry Agent

## Context

The stack needs a telemetry agent running on each host to:
1. Ship logs to Loki
2. Expose or forward metrics for Prometheus to scrape
3. Optionally collect systemd journal logs

Options considered: Promtail (Grafana), Fluent Bit, Vector, Telegraf, Alloy (Grafana).

## Decision

Use **Grafana Alloy** as the single telemetry agent on all hosts (control node and observability nodes).

## Consequences

**Positive:**

- Single agent replaces Promtail (log shipping) and potentially eliminates some standalone exporters via Alloy's metric collection components
- Alloy is the official successor to Promtail; Promtail is EOL / maintenance-only
- Alloy's River config language is more expressive than Promtail's static YAML
- Native support for OpenTelemetry traces — enables traces pillar without swapping agents when needed
- Grafana Labs maintains both Alloy and Loki — push format compatibility is guaranteed
- Single binary, single container to manage per host

**Negative:**

- Alloy is newer than Promtail; less community documentation for edge cases
- River config syntax has a learning curve vs. Promtail's more straightforward YAML
- More powerful = more ways to misconfigure; operational surface is larger

**Open questions:**

- Alloy can scrape metrics via its Prometheus-compatible components — evaluate whether it can replace standalone node-exporter on future VM nodes (reduces per-VM container count)
- Alloy trace collection (OTLP receiver) not yet configured; this is the natural path to adding traces

---

## Why Not Promtail

Promtail is in maintenance mode as of Grafana Labs' public statements. New features (OTEL support, improved pipeline components) are being built in Alloy only. Starting new deployments on Promtail would require a future migration.

## Why Not Vector

Vector is excellent but vendor-neutral — not optimized for the Loki push format the way Alloy is. Would introduce a dependency without the Grafana ecosystem alignment benefit.

## Related

- [[alloy]] — Alloy service entity and current config details
- [[telemetry-pipeline]] — how Alloy fits in the overall pipeline
- [[adr-001-docker-compose]] — container orchestration decision
