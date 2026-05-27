---
type: concept
tags: [concept, ansible, testing, quality]
---

# Molecule Testing

Molecule is the standard framework for testing Ansible roles in isolation. It runs roles against ephemeral containers or VMs, verifies idempotency, and validates the resulting state without requiring real infrastructure.

---

## Why This Matters for This Project

The `roles/observability_control/` and `roles/observability_node/` skeletons are currently empty — tasks live inline in the playbooks. When Phase 4 migrates tasks into roles, Molecule becomes the gate that proves a role is correct before it touches a real host.

---

## How Molecule Works

```
molecule test
  ↓
1. Create    — spin up ephemeral container (Docker driver)
2. Prepare   — install prereqs (Python, etc.)
3. Converge  — run the role under test
4. Idempotency — run again; assert zero changes
5. Verify    — run assertions (Testinfra or Ansible asserts)
6. Cleanup   — destroy container
```

---

## Minimal Setup for a Role

```bash
# From the role directory
cd ansible/roles/observability_control
molecule init scenario

# Run full test cycle
molecule test

# Faster iteration (skip create/cleanup)
molecule converge
molecule verify
```

### `molecule/default/molecule.yml`

```yaml
driver:
  name: docker
platforms:
  - name: instance
    image: geerlingguy/docker-debian12-ansible:latest
    pre_build_image: true
provisioner:
  name: ansible
  playbooks:
    converge: converge.yml
verifier:
  name: ansible
```

### `molecule/default/converge.yml`

```yaml
---
- name: Converge
  hosts: all
  gather_facts: true
  roles:
    - role: observability_control
```

---

## Idempotency Test

Molecule runs the role twice and asserts the second run shows zero changes. This catches tasks that unconditionally write files or restart services. If a task uses `notify` correctly and is guarded by a `changed_when` / `when:` condition, it passes the idempotency check.

A common failure: `template` tasks that render timestamp-containing configs always report `changed`. Fix: strip volatile fields from templates.

---

## Testinfra Verification Example

```python
# molecule/default/tests/test_default.py
import testinfra

def test_docker_running(host):
    service = host.service("docker")
    assert service.is_running
    assert service.is_enabled

def test_compose_file_present(host):
    f = host.file("/opt/docker/observability/docker-compose.yml")
    assert f.exists
    assert f.mode == 0o644
```

---

## Integration with This Stack

- **Phase 4 target**: After roles are populated (`roles/observability_control/`, `roles/observability_node/`), add Molecule scenarios for both
- **CI gate** (future): `molecule test` runs in GitHub Actions on every PR that touches `ansible/roles/`
- **Docker driver**: Uses `geerlingguy/docker-debian12-ansible` image — the same base used by geerlingguy's own role CI

---

## Related

- [[ansible-role-contracts]] — what each role must expose and accept as input
- [[concepts/idempotency]] — the property Molecule's second-run test verifies
- [[sources/geerlingguy-ansible-for-devops]] — ch. 11 covers Molecule patterns
- [[sources/pdf-library]] — "Ansible for DevOps" ch. 7-10 covers role testing
