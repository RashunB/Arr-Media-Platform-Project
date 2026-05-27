---
type: adr
date: 2024-05-01
status: accepted
tags: [adr, architecture, ansible, roles]
---

# ADR-003: Role-based Ansible Architecture

## Context

The initial homelab Ansible implementation used inline tasks directly in playbook files (`observability_control.yml`, `observability_node.yml`). As the number of tasks grew, the playbooks became long, monolithic files that were difficult to test in isolation and hard to reuse across future VMs.

Options: keep flat playbooks, extract into roles, use import_tasks/include_tasks for modular tasks.

## Decision

Migrate to **Ansible roles** (`roles/observability_control/` and `roles/observability_node/`) as the primary unit of configuration.

## Consequences

**Positive:**

- Roles enforce a standard directory structure (`tasks/`, `handlers/`, `defaults/`, `templates/`) that makes behavior predictable and auditable
- Defaults in `defaults/main.yml` serve as self-documenting variable contracts — every variable the role uses is declared there
- Handlers in `handlers/main.yml` are scoped to the role, reducing risk of cross-playbook handler name collisions
- `ansible-lint` gives cleaner output when linting roles vs. flat playbooks
- Future VMs in the fleet (arr stack, Immich, Paperless) get the `observability_node` role applied automatically via group membership — no per-VM playbook changes needed
- Roles are independently testable with Molecule

**Negative:**

- Roles have a steeper initial setup cost vs. adding tasks inline
- The role skeletons exist now but migration from inline tasks is not complete (Phase 4)
- Template paths within roles differ from playbook-relative paths — this caused B3/B4/R1 file-path mismatches during the migration

**Open questions:**

- `observability_pve.yml` currently references non-existent roles (`docker_setup`, `node_observability`) — these need to be created or the playbook needs to use the existing roles
- Molecule testing is a Phase 4+ consideration; not yet set up

---

## Role Contracts

Each role promises: given specific variables (declared in `defaults/main.yml`), it will produce a specific reproducible state. Callers should override via `group_vars` or `host_vars`, not by modifying role internals.

Variable resolution order (highest to lowest precedence):
1. `host_vars/<hostname>/`
2. `group_vars/<group>/`
3. Role `defaults/main.yml`

## Migration Status

| Playbook | Status |
|----------|--------|
| `observability_control.yml` — installs Docker | Using `geerlingguy.docker` role ✅ |
| `observability_control.yml` — deploys stack | Still inline tasks; role skeleton exists |
| `observability_node.yml` — installs Docker | Using `geerlingguy.docker` role ✅ |
| `observability_node.yml` — deploys agents | Still inline tasks; role skeleton exists |
| `observability_pve.yml` | References non-existent roles (B19) |

## Related

- [[ansible-role-contracts]] — concept note on role architecture
- [[variable-hierarchy]] — variable precedence in Ansible
- [[roadmap]] — Phase 4 completes the role migration
