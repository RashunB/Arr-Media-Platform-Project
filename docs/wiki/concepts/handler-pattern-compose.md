---
type: concept
tags: [concept, ansible, docker, handlers, pattern]
---

# Handler Pattern for Docker Compose Services

The correct way to restart a Docker Compose service in response to a config change.

## The Correct Pattern (Used in Roles)

The `observability_control` role handlers already use this:

```yaml
# roles/observability_control/handlers/main.yml

- name: Restart Prometheus
  community.docker.docker_compose_v2:
    project_src: /opt/docker/observability
    services:
      - prometheus
    state: restarted
```

**Why this works:**
- `docker_compose_v2` uses Compose's own restart logic
- Container stays registered in the Compose project with correct labels/networks
- Idempotent — if already in desired state, no-op

## The Wrong Pattern (Inline Playbook Handlers — CR-9)

`observability_control.yml` still has inline handlers using:

```yaml
# ansible/playbooks/observability_control.yml (line ~117)
handlers:
  - name: Restart prometheus
    community.docker.docker_container:
      name: prometheus
      restart: true
```

**Why this breaks:**
- `docker_container` manages containers as standalone units outside Compose's awareness
- Next `docker compose up` may create a duplicate container or lose network membership
- Restart happens unconditionally on every handler notification (no state check)

## Current State

| Location | Pattern | Status |
|----------|---------|--------|
| `roles/observability_control/handlers/main.yml` | `docker_compose_v2` | Correct |
| `roles/observability_node/handlers/main.yml` | (empty stub) | Needs content in Phase 4 |
| `playbooks/observability_control.yml` handlers | `docker_container` | **CR-9 — fix in Phase 4** |
| `playbooks/observability_node.yml` handlers | `docker_container` | **CR-9 — fix in Phase 4** |

Phase 4 role migration eliminates the inline playbook handlers entirely by moving all logic into
roles where the correct handlers already exist.

## Triggering Handlers

```yaml
- name: Deploy prometheus config
  ansible.builtin.template:
    src: prometheus.yml.j2
    dest: /opt/prometheus/prometheus.yml
  notify: Restart Prometheus    # matches handler name exactly
```

## Related

- [[idempotency]] — correct handler pattern preserves idempotency
- [[synthesis/milestone-1-retrospective]] — CR-9 tracking
