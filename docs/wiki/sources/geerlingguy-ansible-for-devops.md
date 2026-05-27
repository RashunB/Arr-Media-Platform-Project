---
type: source
name: Ansible for DevOps
author: Jeff Geerling
year: 2023
url: https://www.ansiblefordevops.com
tags: [source, ansible, book]
---

# Ansible for DevOps — Jeff Geerling

The primary reference for Ansible best practices used in this project. Jeff Geerling's
community roles (`geerlingguy.docker`, `geerlingguy.pip`) are direct dependencies.

## Key Concepts Applied

| Concept | How it appears in this project |
|---------|-------------------------------|
| Role structure | `defaults/`, `tasks/`, `handlers/`, `templates/` layout |
| Variable precedence | `group_vars/` overriding `defaults/main.yml` |
| Idempotent tasks | `state: present` + handlers for restarts |
| Vault for secrets | `ansible-vault encrypt_string` for PVE credentials |

## Community Roles Used

- `geerlingguy.docker` — Docker Engine installation; expects `docker_users: []` list
- `geerlingguy.pip` — Python package installation (Docker SDK)

Both are cached in `ansible/.ansible/roles/` (gitignored) and listed in `requirements.yml`.

## Notes

> [!tip] docker_users Bug Source
> The `docker_users` list-vs-string bug (CR-6 / B18) came from misreading `ansible_facts['user_id']`
> as a username when it's actually a numeric UID. geerlingguy.docker's README clearly specifies
> a list of username strings.