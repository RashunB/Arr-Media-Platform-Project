# Code Review — 2026-05-24

**Branch:** `milestone_1`
**HEAD:** `7addb319e463fe20d86aab39ca3829ec1a19fd9b`
**Scope:** All changes on `milestone_1` vs `main`, plus new untracked files (Phase 2 work)
**Method:** 5-agent parallel review (CLAUDE.md compliance · bug scan · git history · prior comments/bug inventory · code comment compliance), followed by parallel Haiku confidence scoring per issue. Issues below 80/100 confidence filtered out.

**Repo:** https://github.com/RashunB/Homelab-Infra

---

## Findings

Found 7 issues (all scored 100/100 confidence):

---

### 1. `observability_pve.yml` — references non-existent roles; playbook hard-fails on run

The play uses `roles: [docker_setup, node_observability]` but neither exists in `ansible/roles/`
(only `observability_control` and `observability_node` skeletons are present). The inline comment
says "inline tasks for now" but there is no `tasks:` block — only the role references. Any direct
invocation will immediately fail with `role 'docker_setup' was not found`. See also finding #7.

```
ansible/playbooks/observability_pve.yml

roles:
  - role: docker_setup          # Phase 5 item — inline tasks for now
  - role: node_observability
```

*Untracked file — not yet committed.*

---

### 2. B1 still unfixed — `hosts: observability-control` (hyphen) vs inventory `[observability_control:children]` (underscore)

CLAUDE.md explicitly flags this as a known blocker. The play targets a group that does not exist;
it silently runs against zero hosts. All vars are undefined and no tasks execute.

https://github.com/RashunB/Homelab-Infra/blob/7addb319e463fe20d86aab39ca3829ec1a19fd9b/ansible/playbooks/observability_control.yml#L2-L4

---

### 3. Alloy config deployed to wrong filename — Alloy container will not start

`observability_control.yml` line 105 writes `dest: /opt/alloy/alloy-config.yml.j2` (retains the
`.j2` template extension). The Alloy service in `docker-compose.yml.j2` mounts
`/opt/alloy/alloy-config.yaml:/etc/alloy/config.alloy:ro`. The deployed file
(`alloy-config.yml.j2`) is never the mount target; Alloy starts with a missing config.
`observability_node.yml` line 45 correctly uses `alloy-config.yaml`.

https://github.com/RashunB/Homelab-Infra/blob/7addb319e463fe20d86aab39ca3829ec1a19fd9b/ansible/playbooks/observability_control.yml#L102-L109

---

### 4. Loki config extension mismatch `.yml` vs `.yaml` — Loki container will not start

`observability_control.yml` line 96 deploys to `/opt/loki/loki-config.yml`. The Loki service in
`docker-compose.yml.j2` mounts `/opt/loki/loki-config.yaml:/etc/loki/config.yaml`. The `.yml`
file is never found; Loki exits on startup with a missing config error.

https://github.com/RashunB/Homelab-Infra/blob/7addb319e463fe20d86aab39ca3829ec1a19fd9b/ansible/playbooks/observability_control.yml#L93-L100

---

### 5. `control_host_ip` lookup uses wrong group name — all node Loki forwarding breaks

`group_vars/observability-nodes` line 8 resolves the control host IP via
`groups['observability-control'][0]` (hyphen). The inventory declares this group as
`observability_control` (underscore). `groups['observability-control']` is always an empty list;
the `[0]` index raises an `UndefinedError` at runtime, making both `control_host_ip` and
`loki_remote_url` undefined on every node agent.

https://github.com/RashunB/Homelab-Infra/blob/7addb319e463fe20d86aab39ca3829ec1a19fd9b/ansible/inventory/group_vars/observability-nodes#L7-L9

---

### 6. `docker_users` passes a string UID instead of a list username — Docker group membership not set

Both playbooks pass:
```yaml
docker_users: "{{ ansible_facts['user_id'] }}"
```
`ansible_facts['user_id']` is the **numeric UID** (e.g. `"1000"`), not a username.
`geerlingguy.docker` expects a **list of username strings** (`docker_users: []` default, iterated
with `with_items`). Passing a bare string iterates over individual characters; passing a UID
means no valid user is added to the `docker` group. Correct form:
```yaml
docker_users: ["{{ ansible_user }}"]
```

https://github.com/RashunB/Homelab-Infra/blob/7addb319e463fe20d86aab39ca3829ec1a19fd9b/ansible/playbooks/observability_control.yml#L9-L12

https://github.com/RashunB/Homelab-Infra/blob/7addb319e463fe20d86aab39ca3829ec1a19fd9b/ansible/playbooks/observability_node.yml#L10-L13

---

### 7. `observability_pve.yml` not imported by `site.yml` — PVE host receives zero configuration

`site.yml` imports only `observability_control.yml` and `observability_node.yml`. The new
`observability_pve.yml` playbook is never imported. Running
`ansible-playbook playbooks/site.yml` silently skips all PVE configuration. Compounded by
finding #1 — even a direct run of `observability_pve.yml` would fail immediately.

https://github.com/RashunB/Homelab-Infra/blob/7addb319e463fe20d86aab39ca3829ec1a19fd9b/ansible/playbooks/site.yml#L1-L6

---

## Bugs Confirmed Fixed (Phase 2)

The following bugs from `milestone_1.md` were confirmed fixed by the review:

| Bug | Fix Confirmed |
|-----|---------------|
| B2 — Control compose `copy` → `template` | `ansible.builtin.template` with `docker-compose.yml.j2` ✅ |
| B5 — Dozzle env path | `dest: /opt/dozzle/dozzle.env` ✅ |
| B6 — Grafana healthcheck URL | `http://localhost:3000/api/health` ✅ |
| B10 — docker-compose.yml missing `.j2` | File renamed to `docker-compose.yml.j2` ✅ |
| B13 — `.gitignore` typo `groups_vars` | Correct `group_vars` in root `.gitignore` ✅ |

---

## Fix Priority Order

1. **B1** (finding #2) — group name mismatch; blocks everything else
2. **Finding #3** — Alloy dest filename (`.yml.j2` → `.yaml`)
3. **Finding #4** — Loki dest extension (`.yml` → `.yaml`)
4. **Finding #5** — `observability-nodes` group_vars lookup group name (hyphen → underscore)
5. **Finding #6** — `docker_users` type and value
6. **Finding #7** — add `observability_pve.yml` import to `site.yml`
7. **Finding #1** — fix `observability_pve.yml` to use inline tasks or real roles

🤖 Generated with [Claude Code](https://claude.ai/code)
