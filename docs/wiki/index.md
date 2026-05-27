---
type: nexus
updated: 2026-05-26
tags: [index, homelab, meta]
---

# Baucumlabs Homelab — Nexus

> [!info] What This Is
> A LAN-based homelab running a Docker Compose observability stack (Prometheus · Grafana · Loki · Alloy)
> deployed idempotently via Ansible across bare-metal Debian and Proxmox VE hosts.
> Goal: zero playbook edits when new VMs are provisioned — all configuration flows through roles and group_vars.

## Quick Facts

| | |
|--|--|
| **Control host** | `control` — 192.168.0.60 (Debian) |
| **Hypervisor** | `pve` — 192.168.0.63 (Proxmox VE) |
| **First VM node** | `monitoring-1` — dynamic IP (Debian VM on PVE) |
| **Observability services** | 9 (Prometheus, Grafana, Loki, Alloy, Dozzle, node-exporter, cAdvisor, smartctl-exporter, pve-exporter) |
| **Automation** | Ansible — `ansible/` directory, `milestone_1` branch |
| **Current milestone** | Milestone 1 — bug remediation, role scaffolding |

---

## Network Topology

```mermaid
graph TB
    subgraph LAN["LAN — 192.168.0.0/24"]
        control["control\n192.168.0.60\nDebian 12"]
        pve["pve\n192.168.0.63\nProxmox VE"]
        subgraph VMs["VMs on PVE"]
            m1["monitoring-1\ndynamic IP\nDebian VM"]
        end
    end

    m1 -- "Alloy → Loki :3100\nmetrics → Prometheus :9090" --> control
    pve -- "Alloy → Loki :3100\nmetrics → Prometheus :9090\npve-exporter :9221" --> control
```

---

## Telemetry Pipeline

```mermaid
flowchart LR
    subgraph control["control (192.168.0.60)"]
        prom["Prometheus\n:9090"]
        graf["Grafana\n:3000"]
        loki["Loki\n:3100"]
        alloy_c["Alloy\n:12345"]
    end

    subgraph pve_box["pve (192.168.0.63)"]
        alloy_p["Alloy"]
        ne_p["node-exporter\n:9100"]
        ca_p["cAdvisor\n:8080"]
        pe["pve-exporter\n:9221"]
        sc_p["smartctl\n:9633"]
    end

    subgraph m1_box["monitoring-1"]
        alloy_m["Alloy"]
        ne_m["node-exporter\n:9100"]
        ca_m["cAdvisor\n:8080"]
        sc_m["smartctl\n:9633"]
    end

    alloy_p -- logs --> loki
    alloy_m -- logs --> loki
    alloy_c -- logs --> loki

    prom -- scrape --> ne_p & ca_p & pe & sc_p
    prom -- scrape --> ne_m & ca_m & sc_m
    prom -- scrape --> alloy_c

    loki --> graf
    prom --> graf
```

---

## Ansible Inventory Hierarchy

```mermaid
graph TD
    baremetal["baremetal\nalloy_journal_enabled: true"]
    oc["observability_control"]
    op["observability_pve"]
    on["observability_nodes"]
    ctrl["control\n192.168.0.60"]
    pve_h["pve\n192.168.0.63"]
    m1_h["monitoring-1"]

    baremetal --> oc --> ctrl
    baremetal --> op --> pve_h
    on --> m1_h
```

---

## Host Inventory

![[network-inventory.base]]

---

## Service Map

![[services.base]]

---

## Navigation

### Infrastructure
- [[entities/control|control]] — Debian control host, full stack
- [[entities/pve|pve]] — Proxmox VE hypervisor
- [[entities/monitoring-1|monitoring-1]] — first VM node

### Services
- [[entities/prometheus|Prometheus]] · [[entities/grafana|Grafana]] · [[entities/loki|Loki]] · [[entities/alloy|Alloy]]
- [[entities/dozzle|Dozzle]] · [[entities/node-exporter|node-exporter]] · [[entities/cadvisor|cAdvisor]]
- [[entities/smartctl-exporter|smartctl-exporter]] · [[entities/pve-exporter|pve-exporter]]

### Architecture & Concepts
- [[concepts/idempotency|Idempotency]] · [[concepts/ansible-role-contracts|Role Contracts]]
- [[concepts/variable-hierarchy|Variable Hierarchy]] · [[concepts/telemetry-pipeline|Telemetry Pipeline]]
- [[concepts/handler-pattern-compose|Compose Handler Pattern]] · [[concepts/observability-pillars|Observability Pillars]]

### Retrospectives & Analysis
- [[synthesis/milestone-1-retrospective|Milestone 1 Retrospective]]
- [[synthesis/lessons-learned|Lessons Learned]]
- [[synthesis/security-posture|Security Posture]]
- [[synthesis/roadmap|Roadmap]]

### Resources
- [[sources/geerlingguy-ansible-for-devops|Ansible for DevOps]]
- [[sources/community-roles|Community Roles]]
- [[sources/official-docs|Official Docs]]
- [[comparisons/caddy-vs-traefik|Caddy vs Traefik]]
- [[comparisons/static-vs-dynamic-inventory|Static vs Dynamic Inventory]]

---

## Common Commands

```bash
# All commands run from ansible/

# Full stack deploy
ansible-playbook playbooks/site.yml --vault-id pve@playbooks/vault/pve.vault.txt

# Control node only
ansible-playbook playbooks/observability_control.yml --vault-id pve@playbooks/vault/pve.vault.txt

# Dry-run (check mode)
ansible-playbook playbooks/site.yml --vault-id pve@playbooks/vault/pve.vault.txt --check --diff

# Lint
ansible-lint playbooks/

# Encrypt a new variable
ansible-vault encrypt_string --vault-id pve@playbooks/vault/pve.vault.txt 'secret_value' --name 'var_name'

# Inventory shape check
ansible-inventory --list | python3 -m json.tool | head -60
```