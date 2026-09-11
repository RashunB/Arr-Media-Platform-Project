---
type: comparison
tags: [comparison, ansible, inventory, proxmox]
---

# Static + Dynamic Inventory — How They Work Together

Both inventory sources are active simultaneously. Ansible merges all sources found in `./inventory/`.

## Current Setup

| File | Type | Owns |
|------|------|------|
| `01_baremetal.ini` | Static INI | `control`, `pve` — bare-metal hosts that never change |
| `10_observability.ini` | Static INI | Observability groups and their membership |
| `00_inv.proxmox.yml` | Dynamic plugin | PVE VMs discovered by name via PVE API |

`ansible.cfg` explicitly lists `community.proxmox.proxmox` in `enable_plugins`. The plugin runs
at inventory-refresh time and merges its results with the static INI files.

## Division of Responsibility

- **Static INI** — bare-metal hosts (control, pve). These are fixed and known; no benefit from dynamic discovery.
- **Dynamic plugin** — VM fleet. As VMs are provisioned via Terraform on PVE, they appear automatically in Ansible inventory without INI file edits. Group membership is driven by VM name/tag patterns in the plugin config.

## Why Both at Once

Static INI files for physical hosts + dynamic plugin for VMs is the clean separation:
- Physical hosts don't appear in PVE (they're not VMs), so the plugin can't discover them anyway
- VMs provisioned by Terraform immediately become Ansible targets without manual inventory updates

## Terraform → Ansible Flow

```
Terraform provisions VM on PVE
    ↓ (VM appears in PVE API)
community.proxmox plugin discovers it at next inventory refresh
    ↓
Ansible can target it with observability_node playbook
    ↓
Alloy + exporters deployed automatically by group membership
```

## Related

- [[entities/monitoring-1]] — first VM managed through this pattern
- [[sources/official-docs]] — community.proxmox plugin documentation
- [[synthesis/roadmap]] — dynamic inventory is active; static INI reduction as fleet grows