---
type: host
hostname: pve
ip: 192.168.0.63
os: Proxmox VE 8
role: hypervisor
status: active
tags: [host, baremetal, proxmox, observability-pve]
---

# pve — 192.168.0.63

Bare-metal Proxmox VE hypervisor. Hosts all VMs (`monitoring-1` and future fleet). Also runs its
own observability agents so PVE itself is visible in Grafana.

## Services Running

| Service | Port | Purpose |
|---------|------|---------|
| [[alloy\|Alloy]] | — | Telemetry agent → [[loki\|Loki]] + [[prometheus\|Prometheus]] |
| [[dozzle\|Dozzle]] agent | 7007 | Docker log forwarding to control Dozzle |
| [[node-exporter\|node-exporter]] | 9100 | Host metrics |
| [[cadvisor\|cAdvisor]] | 8080 | Container metrics |
| [[smartctl-exporter\|smartctl-exporter]] | 9633 | Disk health |
| [[pve-exporter\|pve-exporter]] | 9221 | Proxmox API metrics (guarded by `pve_exporter_enabled`) |

## Ansible

- **Inventory group:** `observability_pve` (child of `baremetal`)
- **Group vars:** `ansible/inventory/group_vars/observability_pve/`
- **Playbook:** `ansible/playbooks/observability_pve.yml` (WIP — B19, B20, B24 blockers)
- **Remote user:** `root` (Proxmox requirement)

## Key Variables

```yaml
alloy_journal_enabled: true    # from baremetal group
pve_exporter_enabled: true
```

## Open Issues

- [[synthesis/milestone-1-retrospective#CR-1|CR-1 B19]] — observability_pve.yml references non-existent roles
- [[synthesis/milestone-1-retrospective#CR-2|CR-2 B24]] — `hosts: observability-pve` (hyphen) should be underscore
- [[synthesis/milestone-1-retrospective#CR-3|CR-3 B20]] — site.yml missing observability_pve.yml import

## Notes

> [!warning] PVE Remote User
> Proxmox requires `ansible_user: root` — unlike other hosts which use the `ansible` service account.
> This is set in the inventory, not group_vars.

> [!tip] Dynamic Inventory (Future)
> `community.proxmox` dynamic inventory plugin is installed but not yet active. When enabled, VMs
> provisioned on PVE will automatically appear in the inventory without editing INI files.
