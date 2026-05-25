# Milestone 1 — Ansible Observability Stack: Superpower Plan

> **Branch:** `milestone_1` (base), work in phases off feature branches merged back via PR
> **Goal:** Fully working, idempotent, role-based observability deployment across control host,
> PVE bare metal, and monitoring-1 VM. All metrics → control Prometheus. All logs → control Loki.
> No rsyslog. No hardcoded values. No flat playbooks.

---

## State as of milestone_1 Branch Review

### What's Been Fixed ✅
These were bugs on `main` that are resolved on `milestone_1`:

| # | Fix |
|---|-----|
| 1 | Node alloy `targets = []` bug → `discovery.docker.docker_scrape.targets` |
| 2 | Prometheus template src/dest corrected (`prometheus.yml.j2` → `/opt/prometheus/prometheus.yml`) |
| 3 | Node alloy template src renamed to `.j2` |
| 4 | Node `docker-compose.yml` converted to proper `.j2` template with variables |
| 5 | `requirements.yml` added for `community.docker` and `community.proxmox` collections |
| 6 | group_vars renamed from underscore to hyphen convention |
| 7 | `rsyslog_port` variable replaces hardcoded `514` |
| 8 | `loki_remote_url` used in node alloy — no hardcoded IPs |
| 9 | `/opt/alloy` added to node directory creation loop |
| 10 | `smartctl-exporter` uses `cap_add: SYS_RAWIO` instead of `privileged: true` |
| 11 | `files/` cleaned up — only Grafana dashboard JSONs remain |
| 12 | `baremetal` group added to `10_observability.ini` with control and PVE as children (A1 structurally resolved — functionally blocked by B1) |
| 13 | `CLAUDE.md` created at repo root with architecture, vault setup, run commands, and future vision (Phase 0 complete) |

### Phase 2 Progress (2026-05-24)
Verified by `/code-review --effort high` — 5-agent parallel review. See `code-review-2026-05-24.md`.

| Fix | Status |
|-----|--------|
| B2 — Control compose `copy` → `template` module | ✅ CONFIRMED FIXED |
| B5 — Dozzle env path → `/opt/dozzle/dozzle.env` | ✅ CONFIRMED FIXED |
| B6 — Grafana healthcheck URL → `localhost:3000` | ✅ CONFIRMED FIXED |
| B10 — `docker-compose.yml` renamed to `docker-compose.yml.j2` | ✅ CONFIRMED FIXED |
| B13 — `.gitignore` typo `groups_vars` → `group_vars` | ✅ CONFIRMED FIXED |
| B14 — `loki_remote_url` now uses `hostvars` lookup | ⚠️ PARTIAL — group name still wrong (B1 dependency) |
| A2 — `alloy_journal_enabled` conditional wired into compose + alloy config | ⚠️ PARTIAL |
| A3 — `observability_pve.yml` extracted as separate playbook | ⚠️ WIP — broken (B19, B20) |
| A5 — `observability_control/` and `observability_node/` role skeletons created | ⚠️ WIP — empty stubs |

### Still Broken ❌
These must be fixed before milestone 1 can close.
Verified by `/code-review --effort high` (5-agent parallel review, 2026-05-24 — see `code-review-2026-05-24.md`).

| # | Severity | File | Issue |
|---|----------|------|-------|
| B1 | **CONFIRMED** | `inventory/10_observability.ini:1` | Group declared as `[observability_control:children]` (underscore) but playbook targets `hosts: observability-control` (hyphen) and group_vars file is `observability-control` (hyphen). Three-way mismatch — play runs against zero hosts, all vars undefined. |
| B2 | **FIXED ✅** | `playbooks/observability_control.yml:40` | Control `docker-compose.yml` deployed with `ansible.builtin.copy` but file has Jinja2 variables. Fixed: now uses `ansible.builtin.template` with `docker-compose.yml.j2`. |
| B3 | **CONFIRMED** | `playbooks/observability_control.yml:105` | Alloy dest `alloy-config.yml.j2` (`.j2` in dest). Compose mounts `/opt/alloy/alloy-config.yaml`. Two different files — Alloy finds no config and crashes. |
| B4 | **CONFIRMED** | `playbooks/observability_control.yml:96` | Loki dest `/opt/loki/loki-config.yml` (`.yml`). Compose mounts `/opt/loki/loki-config.yaml` (`.yaml`). Extension mismatch — Loki exits with config not found. |
| B5 | **FIXED ✅** | `playbooks/observability_control.yml:87` | Dozzle env deployed to `/opt/dozzle/.env`. Fixed: `dest` now `/opt/dozzle/dozzle.env`, matching compose `env_file`. |
| B6 | **FIXED ✅** | `playbooks/templates/control/observability/docker-compose.yml.j2:106` | Grafana healthcheck rendered to malformed URL. Fixed: healthcheck now uses `http://localhost:3000/api/health`. |
| B7 | **PLAUSIBLE** | `playbooks/templates/nodes/observability/docker-compose.yml.j2` (cadvisor) | cadvisor has no `ports:` on nodes. `prometheus.yml.j2` scrapes `{{ pve_node_ip }}:{{ cadvisor_host_port }}` (192.168.0.248:8080) — nothing listening on host port. PVE cAdvisor scrape permanently fails. |
| B8 | **PLAUSIBLE** | `playbooks/observability_node.yml:27` | `/opt/dozzle/data` removed from node directory creation loop. Node compose still mounts it. Docker auto-creates as root-owned — permission conflicts with container user. |
| B9 | **PLAUSIBLE** | `playbooks/templates/nodes/observability/pve-alloy-forwarder.conf.j2:3` | Hardcoded `hostvars['monitoring-1']['ansible_host']` — if monitoring-1 not in scope when PVE play runs, template render fails with undefined variable. |
| B10 | **FIXED ✅** | `playbooks/templates/control/observability/` | No `.j2` extension on docker-compose file. Fixed: file renamed to `docker-compose.yml.j2`. |
| B11 | — | `playbooks/templates/nodes/observability/docker-compose.yml.j2:78` | `pve-exporter` mounts `/var/run/docker.sock` unnecessarily — grants full Docker daemon access to a container that only needs Proxmox API access. |
| B12 | — | Both alloy templates | `loki.source.syslog` block still present — rsyslog approach not yet replaced with journald. |
| B13 | **FIXED ✅** | `ansible/.gitignore:51` | Typo `**/groups_vars` → `**/group_vars`. Fixed in root `.gitignore`. |
| B14 | **PARTIAL ⚠️** | `inventory/group_vars/observability-nodes:8` | `loki_remote_url` hardcoded IP replaced with `hostvars[groups['observability-control'][0]]['ansible_host']` — but `observability-control` (hyphen) does not exist in inventory (group is `observability_control` with underscore). Lookup returns empty list → index error at runtime. Fully fixed once B1 is resolved. |
| B15 | **NEW** | `playbooks/observability_node.yml:5` | No `when: pve_exporter_enabled` guard on pve-exporter tasks in the nodes play. The `pve_exporter_enabled: true` flag in group_vars is set but not enforced — pve-exporter deploys to every observability-node regardless of the flag. |
| B16 | **NEW** | `collections/ansible_collections/` | `fedora.linux_system_roles` (v1.122.0) is installed under `collections/` but absent from `requirements.yml` and unused in any playbook. Either add to `requirements.yml` with an explicit version or remove. Undeclared dependencies break `ansible-galaxy collection install -r requirements.yml` reproducibility. |
| B17 | **NEW** | `requirements.yml:3` | `community.proxmox` is pinned `>=1.0.0` with no upper bound. v2.0.0 (a major bump) is installed. Pin to `>=1.0.0,<3.0.0` or the installed version to prevent silent breaking changes on next install. |
| B18 | **CONFIRMED** | `playbooks/observability_control.yml:11`, `playbooks/observability_node.yml:12` | `docker_users: "{{ ansible_facts['user_id'] }}"` passes a bare string containing a numeric UID to `geerlingguy.docker`, which expects a list of usernames. `with_items` on a string iterates characters; a UID is not a valid username. Fix: `docker_users: ["{{ ansible_user }}"]`. |
| B19 | **CONFIRMED** | `playbooks/observability_pve.yml:7-8` | `observability_pve.yml` references roles `docker_setup` and `node_observability` — neither exists in `ansible/roles/`. Playbook hard-fails with "role not found" on any invocation. The comment "inline tasks for now" is incorrect; there are no inline tasks. |
| B20 | **CONFIRMED** | `playbooks/site.yml` | `observability_pve.yml` is not imported by `site.yml`. Running the full `site.yml` silently skips all PVE host configuration. |

### Architectural Gaps (not bugs, but blockers for pipeline goal)

| # | Status | Gap |
|---|--------|-----|
| A1 | **PARTIAL** | `baremetal` group now exists in `10_observability.ini` (structurally resolved) but is functionally broken by B1 (group name underscore/hyphen mismatch). Fully resolved when B1 is fixed. |
| A2 | **OPEN** | `alloy_journal_enabled` conditional not implemented — journald mount absent from both composes and alloy configs. Flag is set in group_vars but nothing in the templates reads it. |
| A3 | **OPEN** | `observability-pve` group exists in inventory and group_vars but no playbook targets it — PVE gets the same node stack as a VM (with rsyslog), not the bare-metal treatment |
| A4 | **OPEN** | rsyslog plays still in both playbooks — to be deleted entirely |
| A5 | **OPEN** | Flat playbooks — role conversion not yet done (expected; planned for this milestone) |
| A6 | **NEW** | No `.ansible-lint` config file in `ansible/`. Phase 0 tasks called for adding lint config, but the file was never created. A minimal config committing to `yaml[truthy]`, `name[casing]`, and `fqcn[action-core]` rules should be in `ansible/.ansible-lint`. |
| A7 | **NEW** | Dynamic Proxmox inventory (`inventory/00_inv.proxmox.yml`) is configured and the `community.proxmox` plugin is enabled in `ansible.cfg`, but all hosts remain static. As the VM fleet grows, this becomes the path to zero-touch host onboarding. Document as a planned Phase 4+ migration. |
| A8 | **NEW** | `inventory/host_vars/` is an empty directory. Either remove it (reduces confusion) or add a `README` or `.gitkeep` noting it's reserved for per-host overrides as the fleet grows. |

---

## Implementation Phases

### Phase 0 — Project Foundation (one-time setup)
**Skill:** `/init` — run to create `CLAUDE.md` so every future session has instant project context.

```bash
# From ansible/ directory
ansible-galaxy collection install -r requirements.yml -p collections/
```

**Tasks:**
- [x] Run `/init` to create `CLAUDE.md` documenting stack architecture, inventory layout, role purposes, and run instructions ✅ **DONE** — `CLAUDE.md` created at repo root
- [ ] Add `.ansible-lint` config to `ansible/` (rules: `yaml[truthy]`, `name[casing]`, `fqcn[action-core]`) to enable lint gates (A6)
- [ ] Add a `Makefile` to `ansible/` with common targets (`deploy`, `deploy-control`, `deploy-nodes`, `lint`, `check`) to avoid retyping vault flags on every run
- [ ] Fix `requirements.yml`: pin `community.proxmox` upper bound (`>=1.0.0,<3.0.0`) and add `fedora.linux_system_roles` or remove from collections/ (B16, B17)
- [ ] Confirm `community.docker >= 3.0.0` ✅ (already done)

**Done when:** `CLAUDE.md` exists ✅, `ansible-lint --list-rules` runs without error, collections install cleanly from `requirements.yml` with no undeclared extras.

---

### Phase 1 — Fix Inventory & Group Names
**Skill:** `/code-review` after changes — catch any naming regressions before moving on.

Also fix in this phase: B13 (`.gitignore` typo), A8 (`host_vars/` empty dir).

**Tasks:**

**`ansible/inventory/10_observability.ini`** — replace entirely:
```ini
[observability-control]
control

[observability-nodes]
monitoring-1

[observability-pve]
pve

[baremetal:children]
control
proxmox_nodes
```

**`ansible/inventory/group_vars/`** — rename/create:
- Rename `observability-control` → keep as-is (already hyphen) ✅
- Rename `observability-nodes` → keep as-is (already hyphen) ✅
- Keep `observability-pve` — populate properly in Phase 3
- Create `group_vars/baremetal`:
  ```yaml
  ---
  alloy_journal_enabled: true
  ```

**`ansible/inventory/group_vars/observability-nodes`** — add explicit defaults:
```yaml
alloy_journal_enabled: false
pve_exporter_enabled: false
```

**`ansible/inventory/group_vars/observability-pve`** — replace:
```yaml
---
alloy_journal_enabled: true
pve_exporter_enabled: true
rsyslog_port: 514
```

**`ansible/playbooks/observability_control.yml`** line 3 + 149:
```yaml
hosts: observability-control   # already correct — verify no regression
```

**`ansible/playbooks/observability_node.yml`** line 3:
```yaml
hosts: observability-nodes     # already correct — verify no regression
```

**Verify:**
```bash
cd ansible/
ansible-inventory --list | python3 -m json.tool | grep -E '"control"|"pve"|"monitoring"'
# control should be in: observability-control, baremetal
# pve should be in: observability-pve, proxmox_nodes, baremetal
# monitoring-1 should be in: observability-nodes only
```

**Also in Phase 1:**

Fix `ansible/.gitignore` line 51:
```
# was: **/groups_vars
**/group_vars
```

Remove or add `.gitkeep` to `inventory/host_vars/` (A8):
```bash
# Option A: remove empty dir (preferred until host-specific vars are needed)
git rm -r ansible/inventory/host_vars/
# Option B: keep as documented scaffolding
echo "# Per-host variable overrides — populated as fleet grows" > ansible/inventory/host_vars/README.md
```

**Done when:** All three hosts appear in correct groups, no "no hosts matched" on `--check`, gitignore typo resolved.

---

### Phase 2 — Fix Critical Playbook Bugs (B1–B8)
**Skill:** `/code-review --effort high` after all fixes — verify all paths and module choices.

Fix each item from the bugs table:

**B2 — Alloy dest** (`observability_control.yml:105`) ✅ DONE:
```yaml
dest: /opt/alloy/alloy-config.yaml    # was: /opt/alloy/alloy-config.yml.j2
```

**B3 — Loki dest** (`observability_control.yml:96`):
```yaml
dest: /opt/loki/loki-config.yaml      # was: /opt/loki/loki-config.yml
```

**B4 + B6 — Control compose: copy → template + rename** ✅ DONE:
- Renamed `templates/control/observability/docker-compose.yml` → `docker-compose.yml.j2`
- Changed playbook task from `ansible.builtin.copy` to `ansible.builtin.template`

**B5 — Dozzle env path** ✅ DONE:
```yaml
dest: /opt/dozzle/dozzle.env          # was: /opt/dozzle/.env
```

**B7 — Grafana healthcheck** ✅ DONE (fixed in docker-compose.yml.j2):
```yaml
test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost:3000/api/health || exit 1"]
```

**B8 — PVE exporter docker.sock** (`templates/nodes/observability/docker-compose.yml.j2`):
Remove the `/var/run/docker.sock:/var/run/docker.sock` volume from `prometheus-pve-exporter` service.

**B14 — Fix group name in loki_remote_url lookup** (`inventory/group_vars/observability-nodes:8`):
After B1 is fixed (group renamed to `observability-control`), the existing hostvars lookup will work correctly. Verify the port still references `{{ loki_host_port }}` not a hardcoded value.

**B15 — Add pve_exporter_enabled guard to nodes play** (`observability_node.yml`):
Wrap all pve-exporter tasks with:
```yaml
when: pve_exporter_enabled | default(false)
```

**B18 — Fix docker_users type and value** (both playbooks, line 11/12):
```yaml
docker_users: ["{{ ansible_user }}"]   # was: "{{ ansible_facts['user_id'] }}"
```
`ansible_facts['user_id']` is a numeric UID string, not a username. `geerlingguy.docker` iterates `docker_users` with `with_items` and expects a list of username strings.

**B19 — Fix observability_pve.yml** (`playbooks/observability_pve.yml`):
Replace non-existent role references with inline tasks (same pattern as observability_node.yml) until roles are built in Phase 4:
```yaml
- name: Observability Stack - PVE
  hosts: observability-pve
  become: true
  force_handlers: true
  tasks:
    # inline tasks copied from observability_node.yml play
    # (docker install, dirs, alloy config, compose deploy)
    # filtered by alloy_journal_enabled and pve_exporter_enabled flags
```

**B20 — Add observability_pve.yml to site.yml** (`playbooks/site.yml`):
```yaml
- import_playbook: observability_pve.yml
```

**Done when:** `ansible-playbook --check --diff playbooks/site.yml` completes cleanly across all three host groups; pve-exporter tasks skipped on hosts where `pve_exporter_enabled: false`.

---

### Phase 3 — Replace rsyslog with Journald Alloy
**Skill:** `/security-review` — the journald mount gives Alloy read access to all host logs; confirm the scope is intentional.

This phase resolves A2 (journald conditional not implemented) and A4 (rsyslog removal). The `alloy_journal_enabled` flag in group_vars is set but has had no effect until the template and compose changes below are applied.

This is the architectural shift: remove rsyslog from the stack entirely and move to Alloy containers reading journald directly on bare metal hosts.

**3a — Update Alloy config templates**

`templates/control/observability/alloy/alloy-config.yml.j2` — full rewrite:
```
{% if alloy_journal_enabled | default(false) %}
loki.source.journal "system" {
  path    = "/var/log/journal"
  max_age = "12h"
  labels  = {
    job  = "journal",
    host = "{{ inventory_hostname }}",
  }
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

Apply the same pattern to `templates/nodes/observability/alloy/alloy-config.yml.j2`.

**3b — Add journald volumes to compose templates (conditional)**

In `templates/control/observability/docker-compose.yml.j2`, Alloy service volumes:
```yaml
    volumes:
      - /opt/alloy/alloy-config.yaml:/etc/alloy/config.alloy:ro
      - /var/run/docker.sock:/var/run/docker.sock
{% if alloy_journal_enabled | default(false) %}
      - /var/log/journal:/var/log/journal:ro
      - /run/log/journal:/run/log/journal:ro
      - /etc/machine-id:/etc/machine-id:ro
{% endif %}
```

Apply same block to `templates/nodes/observability/docker-compose.yml.j2`.

Also remove the `514:514/tcp` syslog port mapping from Alloy in both compose templates — no more syslog listener.

**3c — Add `observability-pve` play to `observability_node.yml`**

Replace the current rsyslog play (`hosts: pve`) with a play that uses the new group:
```yaml
- name: Observability Stack - PVE Node
  hosts: observability-pve
  become: true
  force_handlers: true
  roles:
    - role: docker_setup          # Phase 5 item — inline tasks for now
    - role: node_observability    # Phase 5 item — inline tasks for now
```

For now (pre-role), the PVE play can use the same inline task structure as the nodes play but targeting `observability-pve`. The key difference is that `alloy_journal_enabled: true` and `pve_exporter_enabled: true` in `group_vars/observability-pve` will drive the conditional blocks.

**3d — Delete rsyslog artifacts**
- Delete `playbooks/templates/control/observability/pve-alloy-forwarder.conf.j2`
- Delete `playbooks/templates/nodes/observability/pve-alloy-forwarder.conf.j2`
- Delete `playbooks/templates/rsyslog-heartbeat.conf.j2`
- Remove the rsyslog play from `observability_control.yml` (lines 148–177)
- Remove the rsyslog play from `observability_node.yml` (lines 77–105)

**Done when:** No rsyslog references in any playbook or template; `--check` against PVE shows journald volumes being added; `--check` against monitoring-1 shows no journal volumes.

---

### Phase 4 — Role Conversion
**Skill:** `/code-review` after scaffolding; `/fewer-permission-prompts` to add ansible-lint and syntax-check commands to allowed list.

Convert flat playbooks into reusable roles. This is what enables the pipeline vision — new VMs get `docker_setup` + `node_observability` automatically.

**Target role structure:**
```
ansible/roles/
├── geerlingguy.docker          (keep — community role)
├── geerlingguy.pip             (keep — community role)
├── docker_setup/               NEW
│   ├── defaults/main.yml
│   ├── tasks/main.yml
│   └── meta/main.yml
├── observability_control/      NEW
│   ├── defaults/main.yml       (all vars from group_vars/observability-control as documented fallbacks)
│   ├── tasks/
│   │   ├── main.yml
│   │   ├── directories.yml
│   │   ├── prometheus.yml
│   │   ├── loki.yml
│   │   ├── alloy.yml
│   │   ├── grafana.yml
│   │   ├── dozzle.yml
│   │   └── compose.yml
│   ├── handlers/main.yml
│   ├── templates/              (move from playbooks/templates/control/)
│   └── files/                  (grafana dashboard JSONs)
└── node_observability/         NEW
    ├── defaults/main.yml       (alloy_journal_enabled: false, pve_exporter_enabled: false)
    ├── tasks/
    │   ├── main.yml
    │   ├── directories.yml
    │   ├── alloy.yml
    │   └── compose.yml
    ├── handlers/main.yml
    └── templates/              (move from playbooks/templates/nodes/)
```

**`roles/docker_setup/tasks/main.yml`:**
```yaml
---
- ansible.builtin.import_role:
    name: geerlingguy.docker
  vars:
    docker_users: "{{ docker_service_user | default('ansible') }}"

- ansible.builtin.import_role:
    name: geerlingguy.pip
  vars:
    pip_install_packages:
      - name: docker
```

**`roles/node_observability/defaults/main.yml`:**
```yaml
---
alloy_journal_enabled: false
pve_exporter_enabled: false
cluster_name: homelab
control_host_ip: "192.168.0.60"
```

**New `playbooks/observability_control.yml`:**
```yaml
---
- name: Observability Stack - Control Host
  hosts: observability-control
  become: true
  force_handlers: true
  roles:
    - role: docker_setup
    - role: observability_control
```

**New `playbooks/observability_node.yml`:**
```yaml
---
- name: Observability Stack - Nodes and Bare Metal
  hosts: observability-nodes:observability-pve
  become: true
  force_handlers: true
  roles:
    - role: docker_setup
    - role: node_observability
```

**Done when:** `ansible-playbook --syntax-check playbooks/site.yml` passes; all three hosts reachable under `--check`; tasks split cleanly with tags; `ansible-lint playbooks/` returns zero violations.

---

### Phase 5 — File Cleanup
Delete all retired paths after roles are wired in.

```bash
rm -rf ansible/playbooks/templates/
# Grafana dashboards are now in roles/observability_control/files/
# All templates are now in roles/*/templates/

# Verify no dangling references
grep -r "playbooks/templates\|playbooks/files" ansible/playbooks/
```

**Done when:** Only role-internal template and file directories remain. No references to `playbooks/templates/` or `playbooks/files/` anywhere.

---

### Phase 6 — Smoke Test & Milestone 1 Verification
**Skills:** `/verify` — run after live deployment to confirm functional state; `/security-review` — final pass on the complete diff before tagging.

**Pre-flight:**
```bash
cd ansible/
ansible-lint playbooks/site.yml
ansible-playbook --syntax-check playbooks/site.yml
ansible-inventory --list | jq 'keys'
```

**Deployment order** (control must be up first — nodes push to it):
```bash
ansible-playbook playbooks/observability_control.yml
ansible-playbook playbooks/observability_node.yml
```

**Functional checklist:**
- [ ] Grafana at `http://192.168.0.60:3000` — Prometheus and Loki datasources both green
- [ ] Prometheus targets page — all exporters UP: control (node, cadvisor, smartctl), PVE (node, cadvisor, smartctl, pve-exporter), monitoring-1 (node, cadvisor, smartctl)
- [ ] Loki — streams present: `{job="journal", host="localhost"}` (control), `{job="journal", host="pve"}` (PVE), `{job="docker_logs"}` from all three
- [ ] `docker ps` on control — full stack running (prometheus, loki, grafana, alloy, node-exporter, cadvisor, smartctl, dozzle)
- [ ] `docker ps` on pve — node stack + pve-exporter running (no loki, no grafana)
- [ ] `docker ps` on monitoring-1 — node stack running (no pve-exporter)
- [ ] No rsyslog service running on any host
- [ ] Re-run is idempotent — second `ansible-playbook` run shows zero changes

**Milestone 1 closed when all checklist items pass.**

---

## Post-Milestone 1: Next Phase Roadmap

### Prometheus Dynamic Scrape (Priority 1)
Current static scrape configs in `prometheus.yml.j2` won't scale as VMs are added. Replace with `file_sd_configs`:

```yaml
# prometheus.yml.j2
- job_name: node_exporters
  file_sd_configs:
    - files: ['/etc/prometheus/targets/node_exporter/*.json']
      refresh_interval: 30s
```

The `observability_control` role generates per-host target JSON files from Ansible inventory:
```yaml
- name: Generate Prometheus targets
  ansible.builtin.template:
    src: targets/node_exporter.json.j2
    dest: /opt/prometheus/targets/node_exporter/{{ item }}.json
  loop: "{{ groups['observability-nodes'] + groups['observability-pve'] }}"
  delegate_to: "{{ groups['observability-control'][0] }}"
  notify: Reload Prometheus
```

New VMs added via Terraform + tagged correctly → Ansible re-run regenerates target files → Prometheus picks them up within `refresh_interval`. Zero manual prometheus.yml edits.

### Alerting Foundation (Priority 2)
Add Alertmanager to control stack compose. Add a `rules/` directory to `observability_control` role. Start with:
- Instance down alert (any exporter missing for > 2 minutes)
- Container restart loop (restart count > 5 in 10 minutes)
- Disk fill prediction (> 80% used, filling within 24h)

### CI/CD Pipeline Basics (Priority 3)
`.github/workflows/ansible-lint.yml` — runs on every PR touching `ansible/`:
```yaml
- run: ansible-lint playbooks/site.yml
- run: ansible-playbook --syntax-check --check playbooks/site.yml
  env:
    ANSIBLE_INVENTORY: tests/mock_inventory.ini
```

Requires a mock inventory for CI (no real hosts). The `/session-start-hook` skill can scaffold the setup script for web sessions.

### Terraform State Backend (Priority 4)
Add S3-compatible backend to each `workspace/` deployment. Options:
- MinIO container on control host (the `observability_control` role can manage it)
- Cloudflare R2 (free tier, no egress)

Backend block in each deployment `main.tf`:
```hcl
terraform {
  backend "s3" {
    bucket = "tfstate"
    key    = "deployments/monitoring/terraform.tfstate"
    # endpoint, access_key, secret_key via env vars
  }
}
```

### Dozzle Dynamic Agent List (Priority 5)
Update `dozzle.env.j2` to build the `DOZZLE_REMOTE_AGENT` value from inventory rather than a hardcoded IP:
```jinja2
DOZZLE_REMOTE_AGENT={% for host in groups['observability-nodes'] + groups['observability-pve'] %}{{ hostvars[host]['ansible_host'] }}:{{ dozzle_agent_port }}|{{ host }}{% if not loop.last %},{% endif %}{% endfor %}
```

### Network Segmentation (Future)
As more stacks are added (media, data-eng, utility), introduce VLANs via Terraform:
- `vmbr1` — management/observability (current `vmbr0` range)
- `vmbr2` — media stack (isolated, no internet except Jellyfin/Plex ports)
- `vmbr3` — data engineering (airflow, internal only)
- `vmbr4` — utility services (pihole on this VLAN as DNS for all others)

Each stack's Terraform deployment module gains a `network_bridge` variable. PiHole on the utility VLAN becomes the DNS server injected into all VM cloud-init configs.

---

## Skill Reference Card

| Phase | Skill/Tool | When to Use |
|-------|-----------|-------------|
| 0 | `/init` | Once — creates `CLAUDE.md` for persistent project context |
| 1, 2, 4 | `/code-review` | After each phase — catch regressions and path errors |
| 3, 6 | `/security-review` | After rsyslog removal and before milestone sign-off |
| 6 | `/verify` | After live deployment — confirms functional stack |
| Any | `/fewer-permission-prompts` | After initial session — reduce friction for repeated commands |
| Future CI | `session-start-hook` | Set up web session startup script for collection install |

---

## Bug Reference (Quick Fix Lookup)

| Bug | File | Line | Fix | Status |
|-----|------|------|-----|--------|
| B1 | `inventory/10_observability.ini` | 1 | `[observability_control:children]` → `[observability-control]`; fix all hostvars lookups to match | OPEN |
| B2 | `playbooks/observability_control.yml` | 40 | `copy:` → `template:`, add `.j2` to src | ✅ FIXED |
| B3 | `playbooks/observability_control.yml` | 105 | dest: `alloy-config.yaml` (drop `.j2` suffix) | OPEN |
| B4 | `playbooks/observability_control.yml` | 96 | dest: `loki-config.yaml` (`.yml` → `.yaml`) | OPEN |
| B5 | `playbooks/observability_control.yml` | 88 | dest: `dozzle.env` (not `.env`) | ✅ FIXED |
| B6 | `templates/control/.../docker-compose.yml.j2` | 106 | healthcheck URL: `localhost:3000` | ✅ FIXED |
| B7 | `templates/nodes/.../docker-compose.yml.j2` | cadvisor | Add `ports:` mapping for cadvisor | OPEN |
| B8 | `playbooks/observability_node.yml` | dirs loop | Add `/opt/dozzle/data` to directory creation loop | OPEN |
| B9 | `templates/nodes/.../pve-alloy-forwarder.conf.j2` | 3 | Delete file entirely (rsyslog removed in Phase 3) | OPEN |
| B10 | `templates/control/.../docker-compose.yml` | — | Rename to `.j2` | ✅ FIXED |
| B11 | `templates/nodes/.../docker-compose.yml.j2` | 78 | Remove docker.sock from pve-exporter volumes | OPEN |
| B12 | Both alloy templates | 1–11 | Remove `loki.source.syslog`; add `loki.source.journal` conditional (Phase 3) | OPEN |
| B13 | `.gitignore` | 51 | `**/groups_vars` → `**/group_vars` | ✅ FIXED |
| B14 | `inventory/group_vars/observability-nodes` | 8 | hostvars lookup now present — fix group name to `observability_control` (underscore) when B1 is resolved | PARTIAL |
| B15 | `playbooks/observability_node.yml` | pve-exporter tasks | Add `when: pve_exporter_enabled \| default(false)` guard | OPEN |
| B16 | `requirements.yml` | — | Add `fedora.linux_system_roles` or remove from `collections/` | OPEN |
| B17 | `requirements.yml` | 6 | `community.proxmox: >=1.0.0` → add upper bound `<3.0.0` | OPEN |
| B18 | `playbooks/observability_control.yml`, `observability_node.yml` | 11/12 | `docker_users: ["{{ ansible_user }}"]` (list of username, not string UID) | OPEN |
| B19 | `playbooks/observability_pve.yml` | 7–8 | Replace role references with inline tasks (roles don't exist yet) | OPEN |
| B20 | `playbooks/site.yml` | — | Add `import_playbook: observability_pve.yml` | OPEN |

---

## Security Review Findings

Run by `/security-review` against the `milestone_1` branch diff. Ranked by severity.
Address HIGH findings before closing milestone 1; MEDIUM findings are acceptable for homelab but should be tracked.

> **Context:** All services are currently LAN-only (192.168.0.x, no internet exposure). A reverse proxy
> for external access is on the near-term roadmap. All HIGH findings must be resolved before any external
> exposure. MEDIUM findings with "Pre-exposure action required" should be tracked as a pre-exposure checklist.

### HIGH

| # | File | Finding | Fix |
|---|------|---------|-----|
| S1 | `templates/control/observability/docker-compose.yml` | Prometheus `--web.enable-admin-api` and `--web.enable-lifecycle` flags expose unauthenticated admin and reload endpoints to any host on the LAN. Admin API allows TSDB deletion; lifecycle allows hot reload and shutdown. | Remove both flags or bind Prometheus to `127.0.0.1` and proxy through Alloy or nginx with auth. At minimum, do not expose port 9090 beyond `127.0.0.1` if the control host is reachable from untrusted LAN segments. |
| S2 | `templates/nodes/observability/docker-compose.yml.j2` | `prometheus-pve-exporter` mounts `/var/run/docker.sock` — grants full Docker daemon access (equivalent to root on the host) to a container that only needs Proxmox API HTTP access. Covered as B11 in bug table. | Remove the docker.sock volume. The pve-exporter binary only calls the Proxmox API; it has no code path that uses Docker. |
| S3 | Both compose templates | All container images pinned to `:latest` with `pull_policy: always`. Any upstream image push replaces running containers on next deploy with no review. | Pin to digest (`image: prom/prometheus@sha256:...`) or at minimum to a semver tag (`prom/prometheus:v2.51.2`). Use Renovate or Dependabot to automate pin updates. |

### MEDIUM

| # | File | Finding | Fix |
|---|------|---------|-----|
| S4 | `templates/control/observability/docker-compose.yml` | Grafana starts with default `admin`/`admin` credentials. No `GF_SECURITY_ADMIN_PASSWORD` set in compose or env. First person on the LAN to hit port 3000 can take over. | Set `GF_SECURITY_ADMIN_PASSWORD` via Ansible vault: `"{{ grafana_admin_password \| default(lookup('ansible.builtin.password', '/dev/null length=24')) }}"` — store the generated value in vault. |
| S5 | `templates/control/observability/docker-compose.yml` | Loki HTTP API on port `3100` is fully unauthenticated (`auth_enabled: false` in loki-config). Any process on the LAN can push arbitrary log entries or query all stored logs. | For homelab, bind to `127.0.0.1:3100` and let Alloy forward via loopback. If cross-host push is needed, put nginx + basic auth in front and remove the direct port mapping. |
| S6 | Both compose templates | Alloy UI port `12345` and syslog port `514` bind to `0.0.0.0`. The Alloy UI exposes pipeline graphs and component state to anyone on the LAN; the syslog port accepts unauthenticated log injection. | After Phase 3 removes rsyslog: delete the `514:514` mapping entirely. Alloy UI: bind to `127.0.0.1:12345` or restrict with firewall rules. |
| S7 | `ansible/ansible.cfg:5` | `host_key_checking = false` disables SSH host key verification for all Ansible connections. Leaves all managed hosts open to MITM on first-connect if an attacker can intercept the management network. | Acceptable for closed homelab LAN. Document in `CLAUDE.md` as a known accepted risk. When management VLAN is added (post-milestone roadmap), re-enable and seed known_hosts from Terraform outputs. |
| S8 | `ansible/playbooks/pve_management.yml` | Proxmox API calls use `validate_certs: false` with `root@pam` password authentication. Root credentials + no cert validation means a MITM on the management network gets Proxmox admin. | Use an API token scoped to only what Ansible needs (VM operations, no user management) via `user@pve!token_id`. Store token in vault. Re-enable cert validation once Proxmox has a real cert (Let's Encrypt via ACME or internal CA). |
| S9 | `templates/control/observability/prometheus.yml.j2` | All scrape endpoints use plaintext HTTP with no bearer token or basic auth. Any host on the LAN can query all metrics, enumerate container names, and watch resource usage. | For homelab: acceptable if on trusted VLAN. For hardening: add `bearer_token` to scrape configs and configure exporters to require it. Track as post-milestone work alongside Prometheus RBAC. |
| S13 | **NEW** `playbooks/observability_control.yml` | No reverse proxy in the current stack. Grafana (3000), Prometheus (9090), Loki (3100), and Alloy UI (12345) are served directly on HTTP with no TLS termination layer. Adding a reverse proxy (Traefik or Caddy) must be the **first action** before any external exposure — not an afterthought. | Add Traefik or Caddy to the control compose stack. Caddy is simpler for homelab (automatic HTTPS via ACME). Traefik integrates better with Docker labels for dynamic routing as the VM fleet grows. Either blocks external access to all backend ports. Track as post-milestone Priority 0 before the Terraform/networking work. |

### LOW

| # | File | Finding | Fix |
|---|------|---------|-----|
| S10 | `ansible/requirements.yml` | `community.proxmox` collection has no upper version bound (`>=1.0.0` only). A breaking major release auto-installs and silently changes module behaviour or parameter names. | Change to `>=1.0.0,<2.0.0`. Bump the upper bound intentionally after testing, not automatically. |
| S11 | `ansible/inventory/group_vars/observability-nodes` | Internal IP `192.168.0.248` is committed to git history and will remain there even if the file is later changed. Not a secret, but leaks topology information from any public fork or repo exposure. | Low risk for a private homelab repo. If repo goes public: `git filter-repo --path-glob '*/group_vars/*' --invert-paths` or BFG to rewrite history. Document the IP range is RFC1918 and non-routable. |
| S12 | `templates/control/observability/docker-compose.yml` | Grafana healthcheck renders to `http://{{ grafana_host_port }}:3000/api/health` → `http://3000:3000/api/health` (port number used as hostname). Covered as B6 in bug table. Security impact: Docker marks Grafana permanently unhealthy, which can trigger automated restarts in production setups. | Fix already tracked in bug table: change to `http://localhost:3000/api/health`. |