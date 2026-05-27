---
type: concept
tags: [concept, ansible, core-principle]
---

# Idempotency

An operation is **idempotent** if running it ten times produces the same result as running it once.

In Ansible and Docker Compose terms: the tenth deployment must make zero changes if the state already
matches the desired configuration.

## Why It Matters

Without idempotency, every deploy is a gamble. With it, `--check --diff` becomes a meaningful
preview, and converge runs are safe to automate.

## How Ansible Achieves It

| Pattern | Idempotent | Notes |
|---------|-----------|-------|
| `template` task | Yes | Only writes if file content changes |
| `docker_compose_v2 state: present` | Yes | Starts stack; leaves running stack alone |
| `state: restarted` | No | Restarts every run — only use in handlers |
| `docker_container restart: true` | No | Restarts every run + breaks Compose state |
| `pull_policy: always` | No | Forces image pull on every run |

## The Correct Compose Pattern

```yaml
- name: Start observability stack
  community.docker.docker_compose_v2:
    project_src: /opt/docker/observability
    state: present
    pull: missing
```

Handlers use `state: restarted` with a specific service:

```yaml
- name: Restart prometheus
  community.docker.docker_compose_v2:
    project_src: /opt/docker/observability
    state: restarted
    services: [prometheus]
```

## Verification Sign-Off

A fully idempotent playbook shows zero changes on second run:

```
PLAY RECAP
control : ok=24   changed=0   unreachable=0   failed=0
```

## Related

- [[ansible-role-contracts]]
- [[handler-pattern-compose]]