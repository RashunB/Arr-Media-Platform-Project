---
type: source
name: Community Roles and Collections
author: Various
tags: [source, ansible, roles, collections]
---

# Community Roles and Collections

External dependencies used in this project.

## Ansible Galaxy Roles

| Role | Author | Purpose | Version Policy |
|------|--------|---------|----------------|
| `geerlingguy.docker` | Jeff Geerling | Docker Engine install | No upper bound set |
| `geerlingguy.pip` | Jeff Geerling | Python pip packages | No upper bound set |

## Ansible Collections

| Collection | Version | Use |
|------------|---------|-----|
| `community.docker` | 3.13.10 | `docker_compose_v2`, `docker_container` |
| `community.proxmox` | 2.0.0 | Dynamic inventory (planned, not active) |
| `community.general` | 11.4.7 | General utilities |
| `ansible.posix` | 2.1.0 | POSIX modules |
| `fedora.linux_system_roles` | 1.122.0 | Installed; not yet used |

Collections are vendored in `collections/ansible_collections/` (gitignored on install, committed here).

## Version Pinning Status

> [!warning] B17 — No Upper Bounds
> `requirements.yml` has `community.proxmox:` with no version constraint. Should be
> `">=1.0.0,<3.0.0"` to prevent silent breaking changes on `ansible-galaxy install`.
> See [[synthesis/milestone-1-retrospective]].

## Updating

```bash
# From ansible/ directory
ansible-galaxy collection install -r requirements.yml -p collections/
ansible-galaxy role install -r requirements.yml
```
