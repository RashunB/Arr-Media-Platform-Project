---
type: retrospective
milestone: 1
tags: [synthesis, milestone-1, retrospective]
---

# Milestone 1 Retrospective

Branch: `milestone_1`

---

## Bug Inventory

### Phase 1 — Blockers

| ID | File | Description | Status |
|----|------|-------------|--------|
| CR-1 / B19 | `observability_pve.yml` | References non-existent roles `docker_setup` / `node_observability` | Open |
| CR-2 / B24 | `observability_pve.yml` | `hosts: observability-pve` (hyphen) — group is `observability_pve` | Open |
| CR-3 / B20 | `site.yml` | Missing `import_playbook: observability_pve.yml` | Open |
| CR-4 / R1 | `observability_node.yml:45` | Template src underscore vs hyphen filename mismatch | Open |
| CR-5 | `observability_node.yml:46` | Alloy dest `.yaml` vs compose mount `.yml` | Open |
| CR-6 / B18 | Both playbooks | `docker_users` passed as UID string instead of username list | Open |
| CR-7 / B15 | `observability_node.yml` | No `when: pve_exporter_enabled` guard on credential copy | Open |
| CR-8 / S14 | `observability_node.yml` | PVE credential file `mode: 0644` | Open |

### Phase 2 — High Priority Gaps

| ID | File | Description | Status |
|----|------|-------------|--------|
| CR-9 | Both playbook handler blocks | Inline handlers use `docker_container restart: true` | Open |
| CR-10 / B21 | `prometheus.yml.j2` | No scrape targets for `observability_nodes` | Open |
| CR-11 / B23 | nodes `docker-compose.yml.j2` | No conditional journald volume mounts | Open |
| CR-12 / B17 | `requirements.yml` | `community.proxmox` no version upper bound | Open |
| CR-13 / B22 | `observability_nodes` group_vars | `loki_remote_url` hardcodes port `3100` | Open |

### Phase 3 — Medium / Low Priority

| ID | File | Description | Status |
|----|------|-------------|--------|
| CR-14 | `observability_nodes` group_vars | No empty-group guard on `groups['observability_control'][0]` — raises `UndefinedError` if group is empty | Open |
| CR-15 | `roles/observability_control/`, `roles/observability_node/` | Role task stubs reference templates not yet migrated to role `templates/` dirs | Open |
| B7 | nodes `docker-compose.yml.j2` | cAdvisor has no `ports:` binding — container runs but Prometheus cannot scrape port 8080 | Open |
| B11 / S2 | nodes `docker-compose.yml.j2` | pve-exporter mounts `/var/run/docker.sock` unnecessarily — remove volume | Open |
| S3 | All compose templates | All images use `:latest` + `pull_policy: always`; no pinned versions | Open |
| S4 | `observability_control.yml` / group_vars | Grafana starts with default `admin/admin` credentials; not overridden by Ansible | Open |
| A9 | nodes `docker-compose.yml.j2` | Dozzle env only references PVE agent; monitoring-1 Dozzle agent invisible to control Dozzle | Open |

### Fixed

| Bug | Fix |
|-----|-----|
| B1 | `hosts:` lines and `group_vars/` names renamed to underscores |
| B2 | Control compose: `copy` → `template` with `.j2` source |
| B3 | Control compose: Alloy config mount path corrected |
| B4 | Control compose: Loki config mount path corrected |
| B5 | Dozzle env path corrected |
| B6 | Grafana healthcheck URL corrected |
| B8 | `/opt/dozzle/data` added to node directory creation loop |
| B10 | `docker-compose.yml` renamed to `.j2` |
| B13 | `.gitignore` typo `groups_vars` → `group_vars` |
| B14 | (confirmed fixed per pass 4 review — see [[sources/code-review-2026-05-24]]) |

---

## IP Discrepancy Note

> [!warning] PVE IP Conflict
> `docs/raw/milestone_1.md` (pass 4, 2026-05-25) lists PVE at `192.168.0.248`.
> `CLAUDE.md`, inventory files, and the wiki use `192.168.0.63`.
> The inventory is authoritative — confirm the correct IP before the next playbook run.

---

## Verification Checklist

- [ ] `ansible-playbook --syntax-check playbooks/site.yml` passes
- [ ] `--check --diff` runs across all three hosts without hard errors
- [ ] Grafana at `http://192.168.0.60:3000` — Prometheus + Loki datasources green
- [ ] Prometheus targets — control, pve, and monitoring-1 exporters all UP
- [ ] Loki — streams present from all three hosts
- [ ] Second run: zero changes reported
- [ ] PVE credentials absent from monitoring-1 filesystem
- [ ] Alloy on pve/control have journald volumes; monitoring-1 does not

---

## Takeaways

<!-- Your perspective on what this milestone revealed — what surprised you, what you'd do differently, what patterns you want to carry forward. -->
