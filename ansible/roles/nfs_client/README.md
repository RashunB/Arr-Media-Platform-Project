# nfs_client

Mounts remote NFS exports and records them in `fstab`. It pairs with
[`nfs_server`](../nfs_server/README.md). No playbook in the repository
applies it at present.

## What it does

1. `install.yml` installs `nfs-client` and `nfs-common`.
2. `mount.yml` mounts each entry in `nfs_client_mounts` with
   `ansible.posix.mount`.

The default mount options (`hard`, `timeo=600`, `retrans=2`, `_netdev`) make
I/O wait through a server restart instead of failing, and delay the mount
until the network is up at boot.

## Requirements

- Collection `ansible.posix`.
- A reachable NFS server exporting each `src`.

## Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `nfs_client_mounts` | list of dict | **required** | Remote NFS exports to mount on this host. |

Each entry in `nfs_client_mounts` accepts:

| Key | Type | Default | Description |
|---|---|---|---|
| `path` | str | **required** | Absolute local mount point. |
| `src` | str | **required** | Remote export in host:/export form. |
| `fstype` | str | `nfs4` | Mount filesystem type. |
| `options` | str | `rw,hard,timeo=600,retrans=2,_netdev` | Mount options passed to ansible.posix.mount. |
| `state` | str | `absent` | Mount state passed to ansible.posix.mount. |

`state` defaults to `absent` so that a partially filled entry never mounts
anything. Set it to `mounted` to activate a mount.

## Example

```yaml
- name: NFS clients
  hosts: media_platform
  become: true
  roles:
    - role: nfs_client
      vars:
        nfs_client_mounts:
          - path: /mnt/appdata
            src: nfs.example.internal:/exports/appdata
            state: mounted
```
