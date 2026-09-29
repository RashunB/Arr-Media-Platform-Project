# nfs_server

Exports local directories over NFS. The role creates each export directory
with the requested ownership and mode, renders `/etc/exports`, and keeps
`nfs-server` enabled and running. No playbook in the repository applies it
at present; it is a building block for shared storage between hosts.

## What it does

1. `install.yml` installs `nfs-kernel-server` and `nfs-common`.
2. `exports.yml` creates the `/exports` parent, creates each export directory,
   and renders `/etc/exports` from `templates/exports.j2`. A change notifies
   the `Reload NFS Exports` handler (`exportfs -ra`), so existing clients stay
   mounted.
3. `service.yml` enables and starts `nfs-server`.

## Requirements

- A Debian or Ubuntu host.
- Client specifications in `clients` narrow enough for the network. The
  default options include `no_root_squash`, which suits container volumes
  and trusts client root.

## Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `nfs_server_exports` | list of dict | **required** | Directories exported by the NFS server. |

Each entry in `nfs_server_exports` accepts:

| Key | Type | Default | Description |
|---|---|---|---|
| `path` | str | **required** | Absolute path of the exported directory. |
| `clients` | str | **required** | Client specification allowed to mount the export. |
| `options` | str | `rw,sync,no_subtree_check,no_root_squash` | NFS export options. |
| `owner` | str | `root` | Owner of the exported directory. |
| `group` | str | `root` | Group of the exported directory. |
| `mode` | str | `0770` | Permission mode of the exported directory. |

## Example

```yaml
- name: NFS server
  hosts: control
  become: true
  roles:
    - role: nfs_server
      vars:
        nfs_server_exports:
          - path: /exports/appdata
            clients: 192.0.2.0/24
```
