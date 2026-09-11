---
type: concept
tags: [concept, ansible, architecture, roles]
---

# Ansible Role Contracts

A role is a **promise**: given a defined set of variables, it produces a known, reproducible
configuration — regardless of which playbook calls it or which host it runs on.

## The Contract

```
Role inputs:  defaults/main.yml  (safe fallbacks for every variable)
              group_vars/<group>  (environment-specific overrides)
              host_vars/<host>    (per-host exceptions, rare)

Role outputs: Configured system state
              Running services
              Deployed config files

Playbooks:    Name roles + hosts only — set nothing themselves
```

## Why Not Flat Playbooks?

Flat playbooks that set variables inline create tight coupling:
- Variables are buried in playbook logic, not visible to future callers
- Can't reuse the logic for a different host or environment
- No `defaults/` to document what variables the logic depends on

## Current State (Milestone 1)

The homelab uses flat inline playbooks. Roles exist as skeletons, migration is Phase 4.

| Role | Status |
|------|--------|
| `docker_base` | Skeleton — wraps geerlingguy.docker + geerlingguy.pip with correct types |
| `observability_control` | Skeleton — task files exist, no content yet |
| `observability_node` | Skeleton — task files exist, no content yet |

## Target State (Post Phase 4)

```yaml
# observability_control.yml — declaration only
- name: Observability Stack - Control Host
  hosts: observability_control
  become: true
  force_handlers: true
  roles:
    - role: docker_base
    - role: observability_control
```

## Variable Precedence (Ansible order, low → high)

1. `role/defaults/main.yml` — widest scope, lowest priority
2. `inventory/group_vars/<group>/` — group-level overrides
3. `inventory/host_vars/<host>/` — host-level exceptions
4. Playbook `vars:` block — never used in target architecture

## Related

- [[variable-hierarchy]] — where each variable type belongs
- [[idempotency]] — roles enforce idempotency through module choices
