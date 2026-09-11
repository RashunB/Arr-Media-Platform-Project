---
type: source
tags: [source, reference, books, pdf]
---

# PDF Reference Library

Local PDFs in `docs/resources/`. These are the primary technical references for homelab architecture decisions.

---

## Available Books

| Title | Relevance |
|-------|-----------|
| **Ansible for DevOps** — Jeff Geerling | Primary Ansible reference; geerlingguy role patterns, playbook structure |
| **Ansible for Kubernetes** — Jeff Geerling | Kubernetes automation patterns (future fleet) |
| **Ansible Up and Running, 3rd ed.** — Bas Meijer et al. | Inventory design, role contracts, variable hierarchy |
| **Designing Data-Intensive Applications** — Kleppmann | Architecture decision-making; reliability, consistency trade-offs |
| **Docker Up and Running, 3rd ed.** — Karl Matthias et al. | Compose patterns, container networking, resource limits |
| **Kubernetes Up and Running, 3rd ed.** — Burns et al. | Future homelab expansion reference |
| **Prometheus Up and Running** — Brian Brazil | SLI/SLO design, PromQL queries, alerting rules; directly applies to [[entities/prometheus]] |
| **Terraform Up and Running, 3rd ed.** — Brikman | IaC patterns; applicable if Proxmox provisioning moves to Terraform |
| **The DevOps Handbook, 2nd ed.** — Kim et al. | Observability philosophy, deployment practices, flow/feedback/learning |

---

## Most Immediately Applicable

1. **Ansible Up and Running** — inventory design decisions (static vs dynamic inventory, group_vars hierarchy)
2. **Prometheus Up and Running** — PromQL for [[concepts/golden-signals]], alert design when SLOs are defined
3. **Docker Up and Running** — Compose resource limits (open gap S3/CR-11), container networking patterns
4. **The DevOps Handbook** — observability pillar philosophy behind [[concepts/observability-pillars]]

---

## Reading Path for Milestone 2

- [ ] Ansible for DevOps ch. 7-10 — roles, testing with Molecule, Galaxy
- [ ] Prometheus Up and Running ch. 5-7 — labeling, alerting, Alertmanager
- [ ] Docker Up and Running ch. 8 — resource constraints (closes S3 resource limits gap)
