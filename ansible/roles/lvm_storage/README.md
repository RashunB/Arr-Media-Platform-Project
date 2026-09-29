# lvm_storage

Builds LVM storage from a declarative list: volume groups, logical volumes,
filesystems, and mounts. `media_platform.yml` applies it to give the media
host a dedicated volume at `/opt/media_platform` before the application
stack starts.

## What it does

Each task file loops over `lvm_storage_logical_volumes`, in this order:

1. `install.yml` installs `lvm2`.
2. `volumes.yml` creates each volume group from its `pvs`
   (`community.general.lvg`), then each logical volume
   (`community.general.lvol`).
3. `filesystem.yml` creates the filesystem on `/dev/<vg>/<lv>`.
4. `mount.yml` mounts it and writes the `fstab` entry
   (`ansible.posix.mount`).

Each stage reads its own `*_state` key from the entry (`vg_state`,
`lv_state`, `fs_state`, `mount_state`).

## Requirements

- Collections `community.general` and `ansible.posix`.
- Physical devices attached to the host. Stable `/dev/disk/by-id/` paths are
  preferred over `/dev/sdX`, which can reorder across reboots.

## Variables

| Variable | Type | Default | Description |
|---|---|---|---|
| `lvm_storage_logical_volumes` | list of dict | **required** | Logical volumes to provision, format, and mount. |

Each entry in `lvm_storage_logical_volumes` accepts:

| Key | Type | Default | Description |
|---|---|---|---|
| `vg` | str | **required** | Volume group name. |
| `lv` | str | **required** | Logical volume name. |
| `pvs` | list of str | **required** | Physical volume device paths backing the volume group. |
| `mountpoint` | str | **required** | Absolute path where the volume is mounted. |
| `size` | str | `100%VG` | Logical volume size in lvol size syntax. |
| `fstype` | str | `ext4` | Filesystem type created on the volume. |
| `mount_state` | str | `mounted` | Mount state passed to ansible.posix.mount. |
| `fs_state` | str | `present` | Filesystem creation state. |
| `lv_state` | str | `present` | Logical volume state. |
| `vg_state` | str | `present` | Volume group state. |

## Example

This is the media host's configuration in
`ansible/inventory/group_vars/media_platform`:

```yaml
lvm_storage_logical_volumes:
  - vg: vg.media
    lv: lv.media
    pvs:
      - /dev/disk/by-id/scsi-SQEMU_QEMU_HARDDISK_vgmedia-d0
      - /dev/disk/by-id/scsi-SQEMU_QEMU_HARDDISK_vgmedia-d1
    size: 100%VG
    fstype: ext4
    mountpoint: /opt/media_platform
```

The `by-id` names derive from the `serial` that each entry in the Terraform
media stack's `additional_disks` input sets, which ties the two tools together
without either one depending on device letters.
