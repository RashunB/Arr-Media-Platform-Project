---
title: Homelab Infrastructure Knowledge Base
tags: [moc]
created: 2026-09-17
---

# Homelab Infrastructure Knowledge Base

This is a reference vault, not a getting-started guide. The getting-started
guides already exist: [[../../README.md|root README]],
[[../../workspace/README.md|workspace/README.md]], and
[[../../ansible/README.md|ansible/README.md]]. This vault does not repeat
their content. What follows is the deeper, component-by-component reference:
the actual module contracts, the actual task flows inside each role, the
actual keys that flow through SOPS, and the incomplete or inconsistent areas
that don't appear in a README. Every claim cites a repo-relative file path
for verification.

Read in this order when re-orienting from scratch: provisioning →
configuration → secrets → observability → gpu-passthrough → ci-quality-gates
→ engineering-decisions. Each note stands alone as a reference for a single
area.

## [[provisioning]]

The Terraform half in depth. Covers the three-stack layering
(`modules/proxmox_vm` → `infrastructure/_base` → `deployments/media/*`), the
`proxmox_vm` module's input/output contract (what it decides internally,
such as machine type, BIOS, and EFI disk, versus what the caller must
supply), how templates are discovered by tag instead of hardcoded VM ID, and
a module limitation not documented elsewhere: the module's outputs only
expose the *first* VM it creates, even when `vm_count > 1`. Also covers why
state is local today and what that constraint blocks.

## [[configuration]]

The Ansible half in depth. Covers how `community.proxmox.proxmox`'s
`keyed_groups` turns a live Proxmox tag into an Ansible group with zero
inventory editing, and where that automation stops: `observability_node`
membership is fully automatic (via the `proxmox_all_qemu` implicit group),
while `media_platform` membership is a static, hand-edited host list today,
not tag driven. Also covers each first-party role's task order, its
`argument_specs.yml` contract, and the `group_vars` re-export pattern that
keeps role variables collision-free.

## [[secrets]]

The full SOPS + `age` trust chain: what each `secrets/*.sops.yaml` file holds
(by key name, not value), which consumer reads which file (Terraform's
`sops_file` data source vs. Ansible's `community.sops` lookup and vars
plugin), and the `.sops.yaml` recipient binding that makes decryption
possible. Covers the gap analysis: which pre-commit hook and which CI job
catch a leaked plaintext secret, and which ones do not, including an
orphaned Ansible Vault file sitting inside a role directory that neither the
`sops` hook nor `yamllint`/`ansible-lint` inspect.

## [[observability]]

The monitoring stack's topology: control vs. node-local services, what each
exporter scrapes, and how Prometheus discovers node targets (a file that
Ansible renders once per control-role run, not a live discovery mechanism),
the Loki/Alloy log path, and precisely how and whether a freshly provisioned
host joins monitoring automatically. Includes template defects found by
reading the Jinja source directly: a malformed YAML target line repeated
across three `file_sd` templates, and a Dozzle remote-agent port mismatch
between the control and node roles.

## [[gpu-passthrough]]

The Intel GPU passthrough mechanism end to end, from the Proxmox-side PCI
hardware mapping, through the single Terraform variable (`pcie_devices`)
that flips machine type/BIOS/EFI disk together, down to what the
`media_platform` Ansible role and the Jellyfin container need on top of the
VM-level passthrough for VA-API transcoding to work (passing the PCI device
through is not sufficient: OS driver installation, group membership, and a
specific `/dev/dri` device mount are also required).

## [[ci-quality-gates]]

Every CI job and every pre-commit hook, matched to what it checks and what
would make it fail. **Pre-commit is optional locally**; the *only* thing
that enforces the hygiene/SOPS hooks is the `hooks` job in CI, which re-runs
pre-commit itself with everything else skipped. The commented-out
`pre-commit` job in `ci.yml` is not a gate at present.

## [[engineering-decisions]]

Builds on the root README's "Engineering decisions" section but goes one
level deeper for each rule: what the rejected alternative was, and what
concretely breaks if the rule is violated. Not just the rationale, but the
concrete failure mode in this repo if the rule were ignored.

---

> [!tip] How to use this vault
> Each note ends with a "Check your understanding" checklist. Closing the
> note and answering the checklist from memory verifies recall of the
> material.
