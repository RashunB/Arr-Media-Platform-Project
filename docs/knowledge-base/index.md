---
title: Homelab Infrastructure Knowledge Base
tags: [moc]
created: 2026-09-17
---

# Homelab Infrastructure Knowledge Base

This is a study vault, not a getting-started guide. The getting-started guides
already exist — [[../../README.md|root README]],
[[../../workspace/README.md|workspace/README.md]], and
[[../../ansible/README.md|ansible/README.md]] — and this vault does not repeat
their content. What follows is the deeper, component-by-component reference:
the actual module contracts, the actual task flows inside each role, the
actual keys that flow through SOPS, and — as importantly — the footguns and
half-finished corners that don't make it into a README. Every claim here cites
a repo-relative file path so you can go check it yourself.

Read in this order if you're re-orienting from scratch: provisioning →
configuration → secrets → observability → gpu-passthrough → ci-quality-gates →
engineering-decisions. Each note stands alone if you already know the area and
just need to jog your memory on one piece.

## [[provisioning]]

The Terraform half in depth. Covers the three-stack layering
(`modules/proxmox_vm` → `infrastructure/_base` → `deployments/media/*`), the
`proxmox_vm` module's real input/output contract (what it decides for you —
machine type, BIOS, EFI disk — versus what you must supply), how templates
are discovered by tag instead of hardcoded VM ID, and a close reading of a
module limitation that isn't documented anywhere else: the module's outputs
only ever expose the *first* VM it creates, even when `vm_count > 1`. Also
covers why state is local today and what that blocks.

## [[configuration]]

The Ansible half in depth. Walks through exactly how
`community.proxmox.proxmox`'s `keyed_groups` turns a live Proxmox tag into an
Ansible group with zero inventory editing, and — this is the subtle part —
where that automation actually stops: `observability_node` membership really
is fully automatic (via the `proxmox_all_qemu` implicit group), but
`media_platform` membership is a static, hand-edited host list today, not tag
driven. Also covers each first-party role's actual task order, its
`argument_specs.yml` contract, and the `group_vars` re-export pattern that
keeps role variables collision-free.

## [[secrets]]

The full SOPS + `age` trust chain: what each `secrets/*.sops.yaml` file holds
(by key name, not value), which consumer reads which file (Terraform's
`sops_file` data source vs. Ansible's `community.sops` lookup and vars
plugin), and the `.sops.yaml` recipient binding that makes decryption
possible at all. The important part is the gap analysis: which pre-commit
hook and which CI job would actually catch a leaked plaintext secret, and
which ones are blind to it — including a genuinely orphaned Ansible Vault
file sitting inside a role directory that neither the `sops` hook nor
`yamllint`/`ansible-lint` ever look at.

## [[observability]]

The monitoring stack's actual topology: control vs. node-local services, what
each exporter scrapes and how Prometheus discovers node targets (spoiler:
it's a file that Ansible renders once per control-role run, not a live
discovery mechanism), the Loki/Alloy log path, and precisely how — or
whether — a freshly provisioned host joins monitoring automatically. Includes
several concrete template bugs found by reading the Jinja source directly:
a malformed YAML target line repeated across three `file_sd` templates, and a
Dozzle remote-agent port mismatch between the control and node roles.

## [[gpu-passthrough]]

The Intel GPU passthrough mechanism end to end, from the Proxmox-side PCI
hardware mapping, through the single Terraform variable
(`pcie_devices`) that flips machine type/BIOS/EFI disk together, down to what
the `media_platform` Ansible role and the Jellyfin container actually need on
top of the VM-level passthrough for VA-API transcoding to work at all (it is
not enough to pass the PCI device through — there's OS driver installation,
group membership, and a specific `/dev/dri` device mount still required).

## [[ci-quality-gates]]

Every CI job and every pre-commit hook, matched precisely to what it checks
and what would make it fail — including the one point of confusion this repo
had before: **pre-commit is optional locally**, and the *only* thing that
actually enforces the hygiene/SOPS hooks is the `hooks` job in CI, which
re-runs pre-commit itself with everything else skipped. The commented-out
`pre-commit` job in `ci.yml` is not a gate at all right now.

## [[engineering-decisions]]

Builds on the root README's "Engineering decisions" section but goes one
level deeper for each rule: what the rejected alternative was, and what
concretely breaks if the rule is violated — not just "why," but "what would
actually go wrong in this repo, today, if you ignored this."

---

> [!tip] How to use this vault
> Each note ends with a "Check your understanding" checklist. Don't just read
> the note — close it and try to answer the checklist from memory. That's the
> actual test of whether the knowledge has come back or not.
