---
type: roadmap
tags: [synthesis, roadmap, planning]
---

# Roadmap

---

## Active — Milestone 1 Phases

### Phase 1: Critical Bug Fixes (8 fixes)
All blockers must be resolved before any other work proceeds.

| Fix | File | Change |
|-----|------|--------|
| CR-1 B19 | `observability_pve.yml` | Replace role references with inline tasks |
| CR-2 B24 | `observability_pve.yml` | `hosts: observability-pve` → `observability_pve` |
| CR-3 B20 | `site.yml` | Add `import_playbook: observability_pve.yml` |
| CR-4 R1 | `observability_node.yml` | Fix Alloy template src filename (hyphen) |
| CR-5 | `observability_node.yml` | Fix Alloy dest extension (.yml) |
| CR-6 B18 | Both playbooks | `docker_users: ["{{ ansible_user }}"]` |
| CR-7 B15 | `observability_node.yml` | Add `when: pve_exporter_enabled \| default(false)` |
| CR-8 S14 | `observability_node.yml` | `mode: "0600"` for credential copy |

### Phase 2: Observability Gaps (5 fixes)

| Fix | File | Change |
|-----|------|--------|
| CR-9 | Playbook `handlers:` blocks | Replace `docker_container restart` with `docker_compose_v2 restarted` |
| CR-10 B21 | `prometheus.yml.j2` | Add scrape loop for `observability_nodes` group |
| CR-11 B23 | nodes `docker-compose.yml.j2` | Add conditional journald volume mounts |
| CR-12 B17 | `requirements.yml` | Add version upper bound for `community.proxmox` |
| CR-13 B22 | `observability_nodes` group_vars | Use `{{ loki_host_port }}` variable in URL |

### Phase 3: Foundation Tooling (3 items)

| Item | Action |
|------|--------|
| `.ansible-lint` | Create in `ansible/` with enforced rules |
| `Makefile` | `lint`, `syntax`, `check`, `deploy` targets in `ansible/` |
| `requirements.yml` | Audit all version constraints |

### Phase 4: Role Population + Template Migration

1. Populate `docker_base` defaults, tasks, meta
2. Populate `observability_control` tasks from flat playbook
3. Populate `observability_node` tasks from flat playbook
4. Migrate templates: `playbooks/templates/control/` → `roles/observability_control/templates/`
5. Migrate templates: `playbooks/templates/nodes/` → `roles/observability_node/templates/`
6. Migrate files: `playbooks/files/control/` → `roles/observability_control/files/`
7. Rewrite playbooks to declaration-only (roles: [...])
8. Phase 4 also merges `observability_pve.yml` away — PVE nodes join via `hosts: observability_nodes:observability_pve`

### Phase 5: Molecule Scenarios (Post-milestone)

- Write `verify.yml` assertions for each role
- Add `.github/workflows/ansible-lint.yml` CI gate

---

## Near-Term (Before External Exposure)

- **Reverse proxy** — Add Caddy or Traefik to control compose; TLS termination layer
- **Auth** — Prometheus + Loki protected behind reverse proxy auth; Grafana strong password set by Ansible
- See [[security-posture]] for the pre-exposure checklist

---

## Medium-Term VM Fleet

Future VMs on PVE — each gets Alloy agent + node-exporter pointed at the control stack.
All join `observability_nodes` group automatically via dynamic inventory.

| Project | Services | Status |
|---------|---------|--------|
| arr stack | Sonarr, Radarr, Prowlarr, qBittorrent | Planned |
| utility suite | Immich, Paperless-ngx, Pi-hole | Planned |

---

## Long-Term

| Item | Notes |
|------|-------|
| Network segmentation | VLANs: management/observability, media, data-eng, utility |
| Prometheus dynamic scrape | `file_sd_configs` so new VMs appear without prometheus.yml edits |
| Alertmanager | Rules: instance down, container restart loop, disk fill prediction |
| Terraform VM provisioning | `bpg/proxmox` provider creates VMs; outputs feed Ansible dynamic inventory |
| Grafana Tempo | Distributed tracing — completes LGTM stack if needed |
