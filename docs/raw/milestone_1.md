# Ansible Observability Stack — Architecture Guide

> **Branch:** `milestone_1`
> **Goal:** Idempotent, role-based observability stack across a control host, PVE bare metal, and
> a growing fleet of VMs. All metrics to Prometheus on control. All logs to Loki on control.
> Zero playbook edits when a new VM is provisioned.

---

## Design Principles

**Idempotency first.** Every task must produce the same outcome on the tenth run as on the first.
`docker_compose_v2 state: present` and `pull: missing` together achieve this — existing stacks
are left running; configuration changes propagate through handlers, not restarts on every run.

**Role contracts over flat playbooks.** A role is a promise: given certain variables, it produces
a known configuration. New hosts receive the right stack simply by belonging to the right group
and having the right role applied. No per-host if/else in playbooks.

**Variables belong to their scope.** Role `defaults/main.yml` provides safe fallbacks for every
variable the role reads. `group_vars/` provides environment-specific overrides. `host_vars/` is
reserved for genuine per-host exceptions. Playbooks set nothing — they only name roles and hosts.

**Handler pattern for Compose services.** Handlers must use `community.docker.docker_compose_v2`
with `state: restarted` and `services:`. Using `docker_container` with `restart: true` on a
Compose-managed container moves it outside Compose's state tracking — next `compose up` may
create duplicates or lose restart history.

```yaml
# Correct handler pattern for all roles
- name: Restart Prometheus
  community.docker.docker_compose_v2:
    project_src: /opt/docker/observability
    services:
      - prometheus
    state: restarted
```

**Terraform provisions; Ansible configures.** Terraform creates VMs, allocates IPs, and registers
DNS records. Ansible owns everything after first boot: Docker, services, config files, secrets.
No secrets flow through Terraform outputs. The boundary is explicit and maintained.

---

## Infrastructure

| Host | IP | Role |
|------|----|------|
| `control` (localhost) | 192.168.0.60 | Debian — full observability stack |
| `pve` | 192.168.0.248 | Proxmox VE bare metal — node exporters + Alloy |
| `monitoring-1` | dynamic (VM on PVE) | Debian VM — node exporters + Alloy agent |

### Inventory Structure

```
ansible/inventory/
├── 01_baremetal.ini          control (localhost), proxmox_nodes (pve)
├── 10_observability.ini      observability groups + baremetal:children
└── group_vars/
    ├── observability_control  full variable set for control-side services
    ├── observability_nodes    node agent vars; loki_remote_url points to control
    ├── observability_pve      alloy_journal_enabled: true, pve_exporter_enabled: true
    └── baremetal              alloy_journal_enabled: true
```

Group hierarchy in `10_observability.ini`:
```ini
[observability_control:children]
control

[observability_nodes]
monitoring-1

[observability_pve]
pve

[baremetal:children]
control
pve
```

**Convention:** All group names use underscores. All `group_vars/` directory names use underscores.
Playbook `hosts:` lines match exactly. This is enforced — mixing hyphens silently targets zero hosts.

### Variable Hierarchy

```
defaults/main.yml         lowest priority — safe fallbacks required for every var the role reads
group_vars/all            cross-group flags (unused currently)
group_vars/<group>        service vars per host group — primary configuration point
host_vars/<host>          per-host overrides — reserved; empty until fleet grows
playbook vars             highest priority — avoid; use group_vars instead
```

Every variable a role consumes must have a default in `defaults/main.yml`. This makes roles
runnable in Molecule without a real inventory.

---

## Role Architecture

Three custom roles plus two community roles from `geerlingguy`:

```
ansible/roles/
├── geerlingguy.docker           community — Docker Engine installation
├── geerlingguy.pip              community — Python pip packages
├── docker_base/                 NEW — wraps community roles; fixes docker_users in one place
├── observability_control/       populates existing skeleton
└── observability_node/          populates existing skeleton
```

### docker_base

**Purpose:** Installs Docker Engine and the Python docker SDK. Wraps `geerlingguy.docker` and
`geerlingguy.pip` so the `docker_users` list bug (bare string vs list) is fixed in one place
and both application roles consume it correctly.

**Interface:**
```yaml
# defaults/main.yml
docker_base_users:
  - "{{ ansible_user }}"
```

**tasks/main.yml:**
```yaml
- ansible.builtin.import_role:
    name: geerlingguy.docker
  vars:
    docker_users: "{{ docker_base_users }}"

- ansible.builtin.import_role:
    name: geerlingguy.pip
  vars:
    pip_install_packages:
      - name: docker
```

**Consumed by:** `observability_control`, `observability_node`.

### observability_control

**Purpose:** Deploys the full observability stack on the control host: Prometheus, Loki, Grafana,
Alloy, Dozzle, node-exporter, cAdvisor, and smartctl-exporter. All services run in a single
Docker Compose project at `/opt/docker/observability/`.

**Task layout:**
```
tasks/
├── main.yml          include_tasks for each sub-file in order
├── directories.yml   all /opt/* dirs; idempotent with state: directory
├── prometheus.yml    prometheus.yml.j2 → /opt/prometheus/prometheus.yml
├── loki.yml          loki-config.yml.j2 → /opt/loki/loki-config.yml
├── alloy.yml         alloy-config.yml.j2 → /opt/alloy/alloy-config.yml
├── grafana.yml       datasource templates + dashboard JSON files
├── dozzle.yml        dozzle.env.j2 → /opt/dozzle/dozzle.env
└── compose.yml       docker_compose_v2 state: present
```

**Key variables** (all must have defaults):
```yaml
control_host_ip: "192.168.0.60"
prometheus_host_port: 9090
loki_host_port: 3100
grafana_host_port: 3000
alloy_host_port: 12345
alloy_con_port: 12345
dozzle_host_port: 8080
dozzle_agent_pve_ip: "{{ pve_node_ip }}"
alloy_journal_enabled: false   # override true in baremetal group_vars
cluster_name: homelab
```

**Templates** (live in `roles/observability_control/templates/` after migration):
```
docker-compose.yml.j2
prometheus/prometheus.yml.j2
loki/loki-config.yml.j2
alloy/alloy-config.yml.j2       (shared with observability_node)
grafana/provisioning/datasources/prometheus.yml.j2
grafana/provisioning/datasources/loki.yml.j2
dozzle/dozzle.env.j2
```

**Files** (live in `roles/observability_control/files/`):
```
grafana/provisioning/dashboards/*.json
```

### observability_node

**Purpose:** Deploys the node agent stack on VMs and bare metal: node-exporter, cAdvisor,
smartctl-exporter, pve-exporter (guarded by flag), Dozzle agent, and Alloy. All services run
in a Compose project at `/opt/docker/` on each node.

**Task layout:**
```
tasks/
├── main.yml          include_tasks in order
├── directories.yml   /opt/pve-exporter, /opt/docker, /opt/alloy, /opt/dozzle/data
├── alloy.yml         alloy-config.yml.j2 → /opt/alloy/alloy-config.yml
├── pve_exporter.yml  pve.yml copy; guarded by pve_exporter_enabled
└── compose.yml       docker_compose_v2 state: present
```

**Key variables** (all must have defaults):
```yaml
alloy_journal_enabled: false
pve_exporter_enabled: false
control_host_ip: ""         # set via hostvars lookup in group_vars
loki_host_port: 3100
loki_remote_url: "http://{{ control_host_ip }}:{{ loki_host_port }}/loki/api/v1/push"
rsyslog_port: 514
cluster_name: homelab
```

**Conditional task guards:**
```yaml
# pve_exporter.yml — credentials only go where they're needed
- name: Copy pve-exporter config
  ansible.builtin.copy:
    src: vault/pve.yml
    dest: /opt/pve-exporter/pve.yml
    mode: "0600"
  when: pve_exporter_enabled | default(false)
```

---

## Playbook Structure (target state)

After role migration, playbooks are declaration-only:

```yaml
# observability_control.yml
---
- name: Observability Stack - Control Host
  hosts: observability_control
  become: true
  force_handlers: true
  roles:
    - role: docker_base
    - role: observability_control

# observability_node.yml
---
- name: Observability Stack - Nodes and Bare Metal
  hosts: observability_nodes:observability_pve
  become: true
  force_handlers: true
  roles:
    - role: docker_base
    - role: observability_node

# site.yml
---
- ansible.builtin.import_playbook: observability_control.yml
- ansible.builtin.import_playbook: observability_node.yml
```

PVE is included in the nodes play via `observability_nodes:observability_pve`. The
`alloy_journal_enabled: true` and `pve_exporter_enabled: true` in `observability_pve` group_vars
drive the conditional task blocks — PVE gets journald mounts and pve-exporter; VMs do not.

---

## Template: Alloy Config

One shared template drives all hosts. The `alloy_journal_enabled` flag controls whether
journald sources are rendered:

```
{% if alloy_journal_enabled %}
loki.source.journal "system" {
    path    = "/var/log/journal"
    max_age = "12h"
    labels  = { job = "journal", source = "{{ inventory_hostname }}" }
    forward_to = [loki.write.default.receiver]
}
{% endif %}

discovery.docker "docker_scrape" {
  host             = "unix:///var/run/docker.sock"
  refresh_interval = "5s"
}

discovery.relabel "docker_scrape" {
  targets = discovery.docker.docker_scrape.targets
  rule {
    source_labels = ["__meta_docker_container_name"]
    regex         = "/(.*)"
    target_label  = "container"
  }
}

loki.source.docker "docker_scrape" {
  host             = "unix:///var/run/docker.sock"
  targets          = discovery.relabel.docker_scrape.output
  forward_to       = [loki.write.default.receiver]
  relabel_rules    = discovery.relabel.docker_scrape.rules
  refresh_interval = "5s"
}

loki.write "default" {
  endpoint {
    url = "{{ loki_remote_url }}"
  }
  external_labels = {}
}
```

The Docker Compose template for each host's Alloy service must mount the journal paths
conditionally:

```yaml
volumes:
  - /opt/alloy/alloy-config.yml:/etc/alloy/config.alloy:ro
  - /var/run/docker.sock:/var/run/docker.sock
{% if alloy_journal_enabled %}
  - /var/log/journal:/var/log/journal:ro
  - /run/log/journal:/run/log/journal:ro
  - /etc/machine-id:/etc/machine-id:ro
{% endif %}
```

---

## Terraform ↔ Ansible Boundary

```
Terraform owns:
  - PVE VM lifecycle (create/resize/destroy) via bpg/proxmox provider
  - Static IP allocation via cloud-init network config
  - DNS records (PiHole or router) via provider
  - Storage pool and disk allocation
  - Output: control_ip, pve_ip, node_ips (list)

Ansible owns:
  - All OS configuration after first boot
  - Docker installation and service deployment
  - Config files, secrets, and cert management
  - Idempotent re-runs for drift correction

Handoff (homelab approach):
  - Terraform writes outputs to a local JSON file via local_exec
  - Static inventory is updated from that JSON (or community.proxmox dynamic inventory)
  - No secrets flow through Terraform outputs; ansible-vault handles secrets
  - Future: community.proxmox dynamic inventory plugin replaces static INI files
```

Secrets stay in ansible-vault. Terraform is not a secrets manager. PVE API credentials, registry
credentials, and Grafana passwords live in `playbooks/vault/*.yml` encrypted at rest.

---

## Molecule Testing

Scaffold directories exist in each custom role:
```
roles/<role>/molecule/default/
├── molecule.yml     Docker driver; debian12 image
├── converge.yml     applies the role
└── verify.yml       assertions (Phase 5 — empty stubs now)
```

Molecule configuration (all three roles):
```yaml
# molecule/default/molecule.yml
---
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: instance
    image: geerlingguy/docker-debian12-ansible:latest
    pre_build_image: true
provisioner:
  name: ansible
verifier:
  name: ansible
```

Run syntax check locally: `cd roles/docker_base && molecule syntax`

Scenarios with real assertions are deferred to Phase 5 after roles are stable.

---

## Implementation Phases

### Phase 1 — Critical Bug Fixes (unblocks clean runs)

All five blockers must be fixed before any other work. None require role migration.

| Fix | File | Change |
|-----|------|--------|
| CR-1 B19 | `observability_pve.yml:6-8` | Replace non-existent roles with inline tasks mirroring node playbook |
| CR-2 B24 | `observability_pve.yml:3` | `hosts: observability-pve` → `hosts: observability_pve` |
| CR-3 B20 | `site.yml` | Add `import_playbook: observability_pve.yml` |
| CR-4 R1 | `observability_node.yml:45` | `alloy_config.yml.j2` → `alloy-config.yml.j2` |
| CR-5 | `observability_node.yml:46` | `alloy-config.yaml` → `alloy-config.yml` |
| CR-6 B18 | Both playbooks line 11/12 | `docker_users: ["{{ ansible_user }}"]` (list) |
| CR-7 B15 | `observability_node.yml:34-41` | Add `when: pve_exporter_enabled \| default(false)` |
| CR-8 S14 | `observability_node.yml:39` | `mode: "0644"` → `mode: "0600"` |

**Verify:** `ansible-playbook --syntax-check playbooks/site.yml` passes; `--check --diff` runs
against all three hosts without hard errors.

### Phase 2 — Observability Gaps (fix what runs but produces wrong output)

| Fix | File | Change |
|-----|------|--------|
| CR-10 B21 | `prometheus.yml.j2` | Add scrape jobs for monitoring-1 (loop over `groups['observability_nodes']`) |
| CR-11 B23 | `nodes/docker-compose.yml.j2` | Add `{% if alloy_journal_enabled %}` journald volume block to Alloy service |
| CR-13 B22 | `observability_nodes` group_vars | Add `loki_host_port: 3100`; use `{{ loki_host_port }}` in `loki_remote_url` |
| CR-9 | Both playbook handlers + role handlers | Rewrite to `docker_compose_v2 state: restarted` with `services:` |
| B17 | `requirements.yml:6` | Add upper bound: `community.proxmox: ">=1.0.0,<3.0.0"` |

Prometheus scrape config for monitoring-1 should loop over `groups['observability_nodes']`
so adding new VMs to the group is sufficient — no prometheus.yml edits:
```yaml
{% for host in groups['observability_nodes'] %}
- job_name: "{{ host }} Node-Exporter"
  static_configs:
    - targets: ["{{ hostvars[host]['ansible_host'] }}:{{ node_exporter_host_port }}"]
{% endfor %}
```

**Verify:** `--check --diff` shows prometheus.yml rendered with monitoring-1 jobs; node compose
shows journald volumes when `alloy_journal_enabled: true`.

### Phase 3 — Foundation Tooling

| Item | Action |
|------|--------|
| `.ansible-lint` | Create in `ansible/` with `yaml[truthy]`, `name[casing]`, `fqcn[action-core]` |
| `Makefile` | Create in `ansible/` with `lint`, `syntax`, `check`, `deploy`, `deploy-control`, `deploy-nodes` targets |
| `requirements.yml` | Add `fedora.linux_system_roles` or remove the installed collection from `collections/` |

**Verify:** `ansible-lint playbooks/site.yml` runs clean; `make lint` works from `ansible/`.

### Phase 4 — Role Population + Template Migration

This is the milestone's primary architectural work.

1. Create `docker_base` role with defaults, tasks wrapping community roles, meta.
2. Populate `observability_control` task stubs with tasks migrated from the flat playbook.
3. Populate `observability_node` task stubs with tasks migrated from the flat playbook.
4. Move `playbooks/templates/control/` into `roles/observability_control/templates/`.
5. Move `playbooks/templates/nodes/` into `roles/observability_node/templates/`.
6. Move `playbooks/files/control/` into `roles/observability_control/files/`.
7. Fix all role handlers to use `docker_compose_v2` pattern.
8. Rewrite playbooks to declaration-only (roles: [docker_base, observability_control]).
9. Add Molecule scaffold directories to all three custom roles.

**Verify:** `ansible-playbook --syntax-check playbooks/site.yml`; `ansible-lint playbooks/`;
`molecule syntax` in each role directory; second `--check` run shows zero changes.

### Phase 5 — Molecule Scenarios (post-milestone)

Write `verify.yml` assertions for each role. Add `.github/workflows/ansible-lint.yml`.
Create mock inventory for CI runs (no real hosts required).

---

## Current Open Items (pass 4, 2026-05-25)

| ID | Severity | Status | Summary |
|----|----------|--------|---------|
| CR-1 / B19 | BLOCKER | OPEN | `observability_pve.yml` references non-existent roles |
| CR-2 / B24 | BLOCKER | OPEN | `observability_pve.yml` hosts: hyphen vs underscore |
| CR-3 / B20 | BLOCKER | OPEN | `site.yml` missing `observability_pve.yml` import |
| CR-4 / R1 | BLOCKER | OPEN | Node alloy template src: underscore filename (disk has hyphen) |
| CR-5 | BLOCKER | OPEN | Node alloy dest: `.yaml` extension (compose mounts `.yml`) |
| CR-6 / B18 | HIGH | OPEN | `docker_users` bare string not list |
| CR-7 / B15 | HIGH | OPEN | No `pve_exporter_enabled` guard on credential copy task |
| CR-8 / S14 | HIGH | OPEN | PVE credentials deployed `mode: 0644` (world-readable) |
| CR-9 | HIGH | OPEN | Handlers use `docker_container restart:true` on Compose containers |
| CR-10 / B21 | HIGH | OPEN | Prometheus has no scrape targets for monitoring-1 |
| CR-11 / B23 | HIGH | OPEN | Node compose Alloy service missing journald volume mounts |
| CR-12 / B17 | MEDIUM | OPEN | `community.proxmox` version has no upper bound |
| CR-13 / B22 | MEDIUM | OPEN | `loki_remote_url` hardcodes port 3100 in nodes group_vars |
| CR-14 | MEDIUM | OPEN | No empty-group guard on `groups['observability_control'][0]` |
| CR-15 | MEDIUM | OPEN | Role task stubs reference templates not yet in role templates/ dirs |
| B7 | LOW | OPEN | Node cadvisor has no host port mapping (can't be scraped by Prometheus) |
| B11 | LOW | OPEN | pve-exporter mounts docker.sock unnecessarily |
| S3 | LOW | OPEN | All images pinned to `:latest` with `pull_policy: always` |
| S4 | LOW | OPEN | Grafana starts with default admin/admin credentials |
| A9 | LOW | OPEN | Dozzle env only points to PVE agent; monitoring-1 agent invisible |

Previously confirmed fixed: B1, B2, B3, B4, B5, B6, B8, B10, B13, B14.

---

## Security Posture

All services are LAN-only today (192.168.0.x). A reverse proxy is required before any external
exposure — this is non-negotiable. The findings below are ranked by urgency.

**Resolve before external exposure:**
- S1 — Prometheus `--web.enable-admin-api` and `--web.enable-lifecycle` are unauthenticated
- S4 — Grafana default admin/admin credentials
- S5 — Loki port 3100 unauthenticated and bound to 0.0.0.0
- S13 — No reverse proxy/TLS termination layer; add Traefik or Caddy to control compose first

**Accepted for LAN-only operation, document as known:**
- S7 — `host_key_checking = false` in `ansible.cfg`
- S9 — Prometheus scrape endpoints unauthenticated HTTP
- S11 — RFC1918 IPs committed to git (non-routable, private repo)

**Fix in current milestone:**
- S14 / CR-8 — PVE credentials `mode: 0644` → `mode: 0600`
- S2 / B11 — pve-exporter mounts docker.sock (remove the volume)
- S8 — Proxmox API calls use root@pam + validate_certs: false (use scoped API token)

---

## Roadmap

### Prometheus Dynamic Scrape
Replace static targets in `prometheus.yml.j2` with `file_sd_configs`. The
`observability_control` role generates per-host target JSON files from Ansible inventory. New
VMs appear in Prometheus within `refresh_interval` after an Ansible re-run — zero
`prometheus.yml` edits required.

### Alerting
Add Alertmanager to the control compose stack. Add a `rules/` directory to `observability_control`
role. Start with: instance down (exporter missing > 2m), container restart loop, disk fill
prediction (>80%, fills within 24h).

### Reverse Proxy
Add Caddy or Traefik to control compose before any external access. Caddy is simpler for homelab
(automatic HTTPS via ACME). Traefik scales better with Docker labels as the VM fleet grows.
All backend ports stop binding to 0.0.0.0 once a proxy is in place.

### Terraform VM Provisioning
`bpg/proxmox` provider creates PVE VMs. Outputs (IPs, hostnames) feed Ansible inventory. Static
inventory initially updated via `local_exec`; long-term replaced by `community.proxmox` dynamic
inventory plugin. No secrets in Terraform outputs. Near-term VMs: arr stack, utility suite
(Immich, Paperless-ngx, Pi-hole).

### CI Foundation
`.github/workflows/ansible-lint.yml` runs `ansible-lint` and `--syntax-check` on every PR
touching `ansible/`. Requires mock inventory for CI (no real hosts). Enables lint gates before
role work is merged.

### Network Segmentation
As stacks grow, introduce VLANs via Terraform: management/observability, media, data-eng, utility.
Pi-hole on the utility VLAN becomes DNS for all others. Each stack Terraform module gains a
`network_bridge` variable.

---

## Verification Checklist (milestone 1 complete when all pass)

```bash
cd ansible/

# Syntax and lint
ansible-lint playbooks/site.yml
ansible-playbook --syntax-check playbooks/site.yml

# Dry-run across all hosts
ansible-playbook playbooks/site.yml --vault-id pve@playbooks/vault/pve.vault.txt --check --diff

# Inventory shape
ansible-inventory --list | jq 'keys'
# Expected: observability_control → control
#           observability_nodes → monitoring-1
#           observability_pve → pve
#           baremetal → control, pve

# Molecule (each custom role)
cd roles/docker_base && molecule syntax
cd roles/observability_control && molecule syntax
cd roles/observability_node && molecule syntax
```

Functional sign-off:
- [ ] Grafana at `http://192.168.0.60:3000` — Prometheus + Loki datasources green
- [ ] Prometheus targets — control, pve, AND monitoring-1 exporters all UP
- [ ] Loki — streams present from all three hosts
- [ ] `docker ps` on each host shows expected services only (no extras, no missing)
- [ ] Second run is fully idempotent — zero changes reported
- [ ] PVE credentials not present on monitoring-1 (`/opt/pve-exporter/` absent)
- [ ] Alloy on PVE and control have journald volumes; Alloy on monitoring-1 does not
