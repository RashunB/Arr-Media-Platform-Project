---
type: adr
date: 2024-01-01
status: accepted
tags: [adr, architecture, docker, containers]
---

# ADR-001: Docker Compose over Kubernetes

## Context

The homelab observability stack needs a container orchestrator to run ~8 services (Prometheus, Grafana, Loki, Alloy, node-exporter, cAdvisor, smartctl-exporter, Dozzle) on a single bare-metal Debian host. The operator is a solo practitioner running this on personal hardware.

Options considered: bare Docker commands, Docker Compose, K3s, Kubernetes (full), Nomad.

## Decision

Use **Docker Compose v2** (`community.docker.docker_compose_v2`) managed by Ansible.

## Consequences

**Positive:**

- Single-host deployment matches the infrastructure (one control node, not a cluster)
- Compose files are human-readable and easy to audit — the entire stack is one YAML file
- Ansible's `community.docker.docker_compose_v2` provides idempotent stack management with handler-triggered restarts
- No cluster state to manage; no etcd, no control plane overhead
- Stack recreates in ~30 seconds from a fresh host via Ansible
- Service discovery within the stack uses Docker's internal DNS (service names)

**Negative:**

- No built-in horizontal scaling or rolling updates
- No automatic rescheduling if the host goes down
- Healthcheck-based dependencies are limited compared to Kubernetes readiness probes
- Adding a second control host in the future would require either Swarm or migrating to K3s

**Open questions:**

- If the fleet grows to 5+ hosts running workloads, K3s becomes worth evaluating
- Swarm mode provides multi-host Compose without the Kubernetes learning curve — a middle path if needed

---

## Why Not K3s

K3s would add:
- API server, scheduler, controller-manager overhead on a single host
- Helm chart management instead of Compose YAML
- `kubectl` as the primary operational interface
- Significantly higher cognitive load for a solo homelab operator

The operational complexity cost exceeds the benefit for a single-host, non-production monitoring stack.

## Related

- [[adr-002-alloy]] — telemetry agent choice
- [[roadmap]] — future VM fleet may revisit this decision
