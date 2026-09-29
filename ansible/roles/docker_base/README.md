# docker_base

Installs Docker Engine and the Docker Python SDK so that every host can run
Compose projects through `community.docker`. Every workload playbook applies
this role before its own: `observability_control.yml`, `observability_node.yml`,
and `media_platform.yml`.

## What it does

1. Imports `geerlingguy.docker`, passing `docker_base_users` through as
   `docker_users` so those accounts join the `docker` group.
2. Imports `geerlingguy.pip` to install the `docker` Python package that the
   `community.docker` modules require on the managed host.

The role is a thin, validated wrapper: its only interface is the user list,
and the two upstream roles keep their own defaults.

## Requirements

- `geerlingguy.docker` and `geerlingguy.pip`, present under `ansible/roles/`.
- A Debian or Ubuntu host with outbound access to the Docker package
  repository.

## Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `docker_base_users` | list of str | `["ansible"]` | System users added to the docker group. |

## Example

```yaml
- name: Docker hosts
  hosts: observability_node
  become: true
  roles:
    - role: docker_base
      vars:
        docker_base_users: [ansible]
```
