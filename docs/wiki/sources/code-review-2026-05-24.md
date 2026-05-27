---
type: source
tags: [source, code-review, milestone-1, audit]
---

# Code Review — 2026-05-24

**Raw file:** `docs/raw/code-review-2026-05-24.md`  
**Branch:** `milestone_1` @ `7addb319`  
**Method:** 5-agent parallel review + Haiku confidence scoring (≥ 80/100 included)

---

## Summary

7 findings confirmed at 100/100 confidence. Maps to [[synthesis/milestone-1-retrospective]] bug inventory. Bugs confirmed fixed by this review: B2, B5, B6, B10, B13.

---

## Key Findings

| Finding | Bug ID | File | Impact |
|---------|--------|------|--------|
| 1 — roles `docker_setup`/`node_observability` missing | CR-1 / B19 | `observability_pve.yml` | Hard fail on any run |
| 2 — `hosts: observability-control` hyphen | B1 | `observability_control.yml:2` | Silently targets zero hosts |
| 3 — Alloy dest retains `.j2` extension | CR-4 / R1 | `observability_control.yml:105` | Alloy starts with no config |
| 4 — Loki dest `.yml` vs mount `.yaml` | — | `observability_control.yml:96` | Loki exits on startup |
| 5 — `groups['observability-control']` hyphen lookup | B1 variant | `group_vars/observability-nodes:8` | `loki_remote_url` undefined on all nodes |
| 6 — `docker_users` is string UID not username list | CR-6 / B18 | Both playbooks | Docker group never set |
| 7 — `observability_pve.yml` not imported by `site.yml` | CR-3 / B20 | `site.yml` | PVE host receives zero config |

---

## Fix Priority Order

1. B1 — group name mismatch (hyphen → underscore); blocks everything else
2. Finding #3 — Alloy control dest (`.yml.j2` → `.yaml`)
3. Finding #4 — Loki dest (`.yml` → `.yaml`)
4. Finding #5 — `observability-nodes` group_vars lookup (hyphen → underscore)
5. CR-6 / B18 — `docker_users` type and value
6. CR-3 / B20 — add `observability_pve.yml` import to `site.yml`
7. CR-1 / B19 — fix `observability_pve.yml` inline tasks or real roles

---

## Relation to Milestone Bug Inventory

- Finding #3 maps to **CR-4 / R1** in the retrospective (node playbook) — but also surfaces a separate control-side Alloy dest bug not previously catalogued
- Finding #4 surfaces a Loki extension mismatch that is related but distinct from CR-5
- Finding #5 is the root cause behind B22 (`loki_remote_url` undefined)

See [[synthesis/milestone-1-retrospective]] for the full CR-series inventory.
