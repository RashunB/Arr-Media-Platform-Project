---
type: concept
tags: [concept, ansible, variables, configuration]
---

# Variable Hierarchy

Where configuration lives and why the placement matters.

## The Three Layers

```
defaults/main.yml     ← safe fallbacks; every variable the role reads must have a default
group_vars/<group>/   ← primary config point; environment-specific values
host_vars/<host>/     ← per-host exceptions only (empty until fleet grows)
```

Playbooks **set nothing** — they only name roles and hosts.

## Current group_vars Layout

| File | Key Variables |
|------|--------------|
| `group_vars/baremetal/` | `alloy_journal_enabled: true` |
| `group_vars/observability_control/` | Full service config: ports, IPs, URLs |
| `group_vars/observability_nodes/` | `alloy_journal_enabled: false`, `pve_exporter_enabled: false`, `loki_remote_url` |
| `group_vars/observability_pve/` | `alloy_journal_enabled: true`, `pve_exporter_enabled: true` |

## Port Variable Discipline

Every port number must be a variable — never hardcoded in URLs or templates.

```yaml
# WRONG — hardcodes port, creates drift
loki_remote_url: "http://{{ control_host_ip }}:3100/loki/api/v1/push"

# CORRECT — single source of truth
loki_host_port: 3100
loki_remote_url: "http://{{ control_host_ip }}:{{ loki_host_port }}/loki/api/v1/push"
```

This is tracked as open issue B22 in [[synthesis/milestone-1-retrospective]].

## Inventory Group Lookup Pattern

When one group needs to find a variable from another group's host:

```yaml
# In observability_nodes group_vars:
control_host_ip: "{{ hostvars[ groups['observability_control'][0] ]['ansible_host'] }}"
```

> [!warning] Guard Required
> This lookup fails if `observability_control` group is empty. A defensive version:
> `groups.get('observability_control', [{}])[0]` — but Ansible's Jinja doesn't support `.get()`.
> Instead add an `assert` task at play start to catch empty groups early.

## Related

- [[ansible-role-contracts]] — roles consume variables through this hierarchy
