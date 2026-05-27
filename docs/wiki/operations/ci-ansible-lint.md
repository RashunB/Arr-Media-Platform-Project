---
type: operations
tags: [operations, ci, ansible, devops, quality]
---

# CI: Ansible Lint Gate

> [!note] Phase 3 Item
> This CI gate is planned for Phase 3. Currently `ansible-lint` runs manually. This note documents the intended setup so it can be dropped in when a git remote (GitHub) is configured.

## Why

Ansible lint catches common issues before they reach the control host:
- Missing `when` guards on conditional tasks
- `command` module used where a module exists
- YAML formatting inconsistencies
- Role metadata issues

The bugs in this codebase (`B15`, `B18`, `B22`, `B23`) would have been caught by lint rules `no-changed-when`, `var-naming`, and others.

---

## GitHub Actions Workflow

`.github/workflows/ansible-lint.yml`:

```yaml
name: Ansible Lint

on:
  push:
    branches: [main, milestone_*]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: ansible

    steps:
      - uses: actions/checkout@v4

      - name: Install Python
        uses: actions/setup-python@v5
        with:
          python-version: "3.12"
          cache: pip

      - name: Install ansible-lint
        run: pip install ansible-lint

      - name: Install collections
        run: ansible-galaxy collection install -r requirements.yml -p collections/

      - name: Run ansible-lint
        run: ansible-lint playbooks/
```

---

## Local Lint (Already Works)

Run manually from `ansible/`:

```bash
ansible-lint playbooks/
```

To lint a specific playbook:

```bash
ansible-lint playbooks/observability_control.yml
```

To lint with profile (min | basic | moderate | safety | shared | production):

```bash
ansible-lint --profile production playbooks/
```

---

## Key Rules to Enforce

| Rule | What it catches | Relevant bug |
|------|----------------|--------------|
| `no-changed-when` | `command`/`shell` tasks without `changed_when` | General hygiene |
| `var-naming` | Variable names that don't follow convention | B22 |
| `no-free-form` | `command: <args>` free-form usage | General hygiene |
| `fqcn` | Tasks not using fully-qualified collection names | B18 context |
| `yaml` | YAML formatting (line length, trailing spaces) | General hygiene |
| `name` | Tasks missing `name:` field | General hygiene |

---

## `.ansible-lint` Config

Place in `ansible/` alongside `ansible.cfg`:

```yaml
# ansible/.ansible-lint
profile: moderate
warn_list:
  - experimental
skip_list:
  - yaml[line-length]    # long template expressions are unavoidable
exclude_paths:
  - collections/
  - .ansible/
```

---

## Pre-commit Hook (Alternative / Complement)

Run lint automatically before every commit without needing CI:

```yaml
# .pre-commit-config.yaml (repo root)
repos:
  - repo: https://github.com/ansible/ansible-lint
    rev: v24.9.2
    hooks:
      - id: ansible-lint
        args: [ansible/playbooks/]
```

Install:

```bash
pip install pre-commit
pre-commit install
```

---

## Related

- [[roadmap]] — Phase 3 includes CI gate
- [[security-posture]] — `detect-secrets` pre-commit hook (separate concern but same mechanism)
- [[adr-003-ansible-roles]] — why roles simplify linting scope
