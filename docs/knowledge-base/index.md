---
title: Homelab Infrastructure Knowledge Base
tags: [moc]
created: 2026-09-17
---

# Homelab Infrastructure Knowledge Base

A component-by-component reference that sits beneath the getting-started
guides: the [root README](../../README.md),
[workspace/README.md](../../workspace/README.md), and
[ansible/README.md](../../ansible/README.md). These pages cover the module
contracts, the task flows inside each role, the keys that flow through SOPS,
and the reasoning behind each design rule, citing repo-relative file paths
throughout.

Suggested order for a full read: provisioning, configuration, secrets,
observability, gpu-passthrough, ci-quality-gates, engineering-decisions. Each
page stands alone as the reference for a single area.

## [Provisioning](provisioning.md)

The Terraform half in depth: the three-stack layering (`modules/proxmox_vm`,
`infrastructure/_base`, `deployments/media/*`), the `proxmox_vm` module's
contract (what it decides internally, such as machine type, BIOS, and EFI
disk, versus what the caller supplies), tag-based template discovery with a
plan-time uniqueness check, list outputs that cover every VM, and the
two-alias provider strategy. Also covers local state and the ephemeral SOPS
reads that keep provider credentials out of it.

## [Configuration](configuration.md)

The Ansible half in depth: how `community.proxmox.proxmox`'s `keyed_groups`
turns a live Proxmox tag into an Ansible group, how `observability_node`
membership follows automatically from the `proxmox_all_qemu` implicit group,
and how `media_platform` membership comes from a static inventory file. Also
covers each first-party role's task order, its `argument_specs.yml`
contract, and the `group_vars` re-export pattern that keeps role variables
collision-free.

## [Secrets](secrets.md)

The SOPS + `age` trust chain: what each file in `secrets/` holds (by key
name, not value), which consumer reads which file, and the `.sops.yaml`
recipient binding. Covers Terraform's two read modes, `ephemeral
"sops_file"` for provider credentials (never in state) and `data
"sops_file"` for the application stack's resource arguments, alongside
Ansible's `community.sops` lookup and vars plugin, and maps each leak path
to the gate that covers it.

## [Observability](observability.md)

The monitoring stack's topology: control vs. node-local services, what each
exporter scrapes, how Prometheus discovers node targets through per-exporter
`file_sd` files that the control role renders from each node's own port
variables, the Loki/Alloy log path, the Dozzle hub-and-agent wiring, and the
exact sequence by which a freshly provisioned host joins monitoring.

## [GPU passthrough](gpu-passthrough.md)

The Intel GPU passthrough mechanism end to end: the Proxmox-side PCI hardware
mapping, the single Terraform variable (`pcie_devices`) that flips machine
type, BIOS, and EFI disk together, per-device `pcie` and `rombar` settings,
and what the `media_platform` Ansible role and the Jellyfin container add on
top of VM-level passthrough for VA-API transcoding (OS drivers, group
membership, and a specific `/dev/dri` device mount).

## [CI and quality gates](ci-quality-gates.md)

Every CI job and every pre-commit hook, matched to what it checks and what
fails it. The `hooks` CI job re-runs pre-commit with the tool-specific hooks
skipped, enforcing hygiene and SOPS checks server-side. TFLint runs the `all`
preset, which requires a description on every Terraform variable and output.

## [Engineering decisions](engineering-decisions.md)

Builds on the root README's "Engineering decisions" section one level deeper
for each rule: the rejected alternative, the reasoning, and the concrete
failure mode in this repo if the rule were broken.
