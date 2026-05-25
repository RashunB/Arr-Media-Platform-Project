# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

Homelab Ansible repo deploying an observability stack to bare-metal Debian and Proxmox VE hosts.
Services are LAN-only today; a reverse proxy / tunnel for external access is on the near-term roadmap.

All playbooks live under `ansible/playbooks/`. All `ansible-*` commands must be run from `ansible/` so that `ansible.cfg` is picked up automatically.

## Infrastructure layout

| Host | IP | Role |
|------|----|------|
| `localhost` (control) | 192.168.0.60 | Debian — runs the full observability stack |
| `pve` | 192.168.0.63 | Proxmox VE bare metal — rsyslog forwarder, scraped by Prometheus |
| `monitoring-1` | dynamic (VM on PVE) | Debian VM — node-exporter + Alloy agent |

## Observability stack (all Docker Compose on control)

| Service | Port | Purpose |
|---------|------|---------|
| Prometheus | 9090 | Metrics scraper / TSDB |
| Grafana | 3000 | Dashboards |
| Loki | 3100 | Log aggregation |
| Alloy | 12345 | Telemetry agent (log + metric forwarding) |
| Dozzle | 8080 | Docker log viewer (control); agent on PVE at 7007 |
| node-exporter | 9100 | Host metrics |
| cAdvisor | 8080 | Container metrics |
| smartctl-exporter | 9633 | Disk health |
| pve-exporter | 9221 | Proxmox API metrics |

## Vault setup

Four vault identities are configured in `ansible.cfg`. Password files are gitignored and must be present locally:

```
ansible/playbooks/vault/ghcr.vault.txt
ansible/playbooks/vault/quay.vault.txt
ansible/playbooks/vault/gcr.vault.txt
ansible/playbooks/vault/pve.vault.txt   ← used for pve.yml (PVE API credentials)
```

Encrypted vars live in `ansible/playbooks/vault/pve.yml` (PVE credentials) and the registry `*.yml` files.

## Common commands

All commands run from `ansible/`:

```bash
# Full stack deploy
ansible-playbook playbooks/site.yml --vault-id pve@playbooks/vault/pve.vault.txt

# Control node only
ansible-playbook playbooks/observability_control.yml --vault-id pve@playbooks/vault/pve.vault.txt

# Nodes only
ansible-playbook playbooks/observability_node.yml --vault-id pve@playbooks/vault/pve.vault.txt

# Dry-run (check mode)
ansible-playbook playbooks/site.yml --vault-id pve@playbooks/vault/pve.vault.txt --check --diff

# Lint
ansible-lint playbooks/

# Install / update collections and roles
ansible-galaxy collection install -r requirements.yml -p collections/
ansible-galaxy role install -r requirements.yml

# Encrypt a new variable
ansible-vault encrypt_string --vault-id pve@playbooks/vault/pve.vault.txt 'secret_value' --name 'var_name'
```

SSH key for Ansible: `~/.ssh/ansible_id`. Remote user defaults to `ansible`; PVE uses `root`.

## Architecture

### Inventory structure

Two static inventory files are loaded from `inventory/`:
- `01_baremetal.ini` — defines `[control]` (localhost) and `[proxmox_nodes]` (pve)
- `10_observability.ini` — defines the observability groups and their membership

`10_observability.ini` group hierarchy:
```
baremetal
├── observability_control → control (localhost)
└── observability_pve     → pve

observability_nodes       → monitoring-1  (standalone VM)
```

Group variables are in `inventory/group_vars/` keyed by group name (hyphenated):
- `observability-control` — full variable set for all control-side services
- `observability-nodes` — variables for node agents; `loki_remote_url` points to control IP
- `observability-pve` — minimal flags for PVE host
- `baremetal` — cross-group flags (`alloy_journal_enabled`)

A dynamic Proxmox inventory plugin is configured in `inventory/00_inv.proxmox.yml` but is not yet active; all hosts are currently static.

### Playbook structure

```
playbooks/
├── site.yml                     ← entry point; imports control + node playbooks
├── observability_control.yml    ← targets observability-control group
├── observability_node.yml       ← targets observability-nodes group
├── observability_pve.yml        ← targets observability-pve group (WIP — B19/B20; not in site.yml)
├── templates/
│   ├── control/observability/   ← Jinja2 templates for control-side services
│   └── nodes/observability/     ← Jinja2 templates for node agents
├── files/
│   └── control/observability/grafana/provisioning/dashboards/  ← static JSON dashboards
└── vault/                       ← encrypted credential files (gitignored)
```

`observability_control.yml` flow:
1. Install Docker + pip (geerlingguy.docker / geerlingguy.pip roles)
2. Create `/opt/{docker/observability,prometheus,grafana,dozzle,loki,alloy}` directories
3. Deploy all service configs via `template` (or `copy` for static files)
4. Start stack via `community.docker.docker_compose_v2` from `/opt/docker/observability/`

`observability_node.yml` targets `observability-nodes`: Docker + Alloy agent + pve-exporter on monitoring VMs.
`observability_pve.yml` targets `observability-pve`: WIP — references non-existent roles; not yet imported by `site.yml` (B19, B20).

### Roles

`roles/observability_control/` and `roles/observability_node/` are **empty skeletons** — scaffolded but awaiting Phase 4 migration from inline playbook tasks.

Downloaded roles (`geerlingguy.docker`, `geerlingguy.pip`) are cached in `.ansible/roles/` (gitignored).

### Installed collections

| Collection | Version | Use |
|------------|---------|-----|
| community.docker | 3.13.10 | `docker_compose_v2`, `docker_container` |
| community.proxmox | 2.0.0 | Dynamic inventory (planned) |
| community.general | 11.4.7 | General utilities |
| ansible.posix | 2.1.0 | POSIX modules |
| fedora.linux_system_roles | 1.122.0 | Installed; not yet used |

Collections are vendored in `collections/ansible_collections/` (gitignored on install, committed here).

## Current state and known issues

The project is on the `milestone_1` branch. See `milestone_1.md` for the full bug inventory, architectural gaps, security findings, and the phased remediation plan. See `code-review-2026-05-24.md` for the latest code review output (7 confirmed findings, 5-agent parallel review).

**Recently fixed (Phase 2):**
- B2 ✅ — Control compose converted from `copy` to `template`
- B5 ✅ — Dozzle env path corrected to `/opt/dozzle/dozzle.env`
- B6 ✅ — Grafana healthcheck URL corrected to `localhost:3000`
- B10 ✅ — `docker-compose.yml` renamed to `docker-compose.yml.j2`
- B13 ✅ — `.gitignore` typo `groups_vars` → `group_vars`

**Current blockers (Phase 2 in progress):**
- **B1** — Group name mismatch: inventory declares `observability_control` (underscore); playbook targets `observability-control` (hyphen); `group_vars/observability-nodes` lookup uses the same wrong hyphen form
- **B3** — Alloy config dest is `/opt/alloy/alloy-config.yml.j2`; compose mounts `alloy-config.yaml` — Alloy will not start
- **B4** — Loki config dest is `/opt/loki/loki-config.yml`; compose mounts `loki-config.yaml` — Loki will not start
- **B18** — `docker_users` passes a bare string UID instead of a list username to `geerlingguy.docker`; use `["{{ ansible_user }}"]`
- **B19** — `observability_pve.yml` references non-existent roles `docker_setup` / `node_observability`
- **B20** — `observability_pve.yml` not imported by `site.yml`; PVE host receives no configuration

## Future homelab vision

Near-term VMs planned on PVE — each will receive Alloy agent + node-exporter pointed at the control stack:
- **arr stack**: Sonarr, Radarr, Prowlarr, qBittorrent
- **utility suite**: Immich, Paperless-ngx, Pi-hole

Before any external exposure of Grafana/Prometheus: add a reverse proxy (Traefik or Caddy) as the TLS termination layer — see security section in `milestone_1.md`.
