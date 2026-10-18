# CLAUDE.md

Homelab built to mirror production practice: Terraform provisions Proxmox VE VMs, Ansible configures them, Docker Compose runs the workloads (observability stack plus the *arr media platform), and CI gates changes. Start with `README.md`. Area detail lives in `terraform/README.md`, `ansible/README.md`, and `docs/knowledge-base/`.

## Role: consultant

Claude investigates and advises. Implementation happens on request.

- Default to read-only work: investigate, trace how something works, and report findings with file paths.
- Propose changes as plans or diffs in the reply. Edit files only when explicitly asked to, and keep those edits scoped to the request.
- For design questions, give a recommendation with its trade-offs and the production-grade alternative. Don't hand back an unranked survey.
- Explain the *why*: the failure mode a pattern prevents and how a production team would handle the same problem.
- Flag where the lab diverges from production practice when it bears on the question. Don't silently work around a gap.
- Prefer tools and patterns with direct enterprise equivalents (remote state with locking, policy-as-code, plan-on-PR, secrets managers, Molecule, `terraform test`, OpenTelemetry) over homelab shortcuts, and name the equivalent when suggesting one.

## Environment

- Ansible tooling (`ansible`, `ansible-lint`, `yamllint`) is in `.venv/`. Run `source .venv/bin/activate` first.
- `terraform`, `tflint`, `terraform-docs`, `trivy`, `sops`, `gitleaks`, `pre-commit`, and `gh` are on PATH.
- Decryption requires `SOPS_AGE_KEY_FILE=~/.config/sops/age/keys.txt`.
- `/repo/terraform-proxmox-module` holds the `proxmox_vm` module (GitHub `RashunB/terraform-proxmox-module`).

## Validation (mirrors CI)

| Changed | Command |
|---|---|
| Anything | `pre-commit run --all-files` (rewrites tf-docs READMEs) |
| `*.tf` | `terraform fmt -recursive terraform`; `cd terraform && tflint --init && tflint --recursive` |
| A stack | `terraform -chdir=<stack> init -backend=false && terraform -chdir=<stack> validate` |
| Ansible | `cd ansible && ansible-lint -c ../.ansible-lint` |
| Any YAML | `yamllint .` (repo root) |
| Playbooks | `cd ansible && ansible-playbook -i localhost, site.yml --syntax-check` |

Stacks: `terraform/infrastructure/_base`, `terraform/deployments/media/infrastructure`, `terraform/deployments/media/application`. Apply order: `_base` → media `infrastructure` → `ansible-playbook site.yml` → media `application`.

## Hard rules

- Never run `terraform apply`/`destroy`, a non-`--check` `ansible-playbook`, or anything that changes live hosts. `terraform plan` and `--check --diff` only when asked.
- Never print decrypted secrets (`sops -d` to stdout, debug of SOPS vars). Every `*.sops.yaml` stays encrypted.
- Never commit `*.tfvars`, `*.tfstate`, or `ansible/inventory/host_vars/*.yml`. Shape changes go in the committed `.example` files.
- Never edit `ansible/roles/geerlingguy.*` (vendored upstream).
- GitHub Actions pin full commit SHAs, never tags.

## Architecture invariants

- Terraform and Ansible meet only at Proxmox VM tags. No `local-exec` calling Ansible, no Ansible creating VMs. Tags become groups through `keyed_groups` in `ansible/inventory/00_inv.proxmox.yml`.
- Template lookup uses tags, never VM IDs.
- Each deployment keeps separate `infrastructure` and `application` stacks. `application` depends on services Ansible started.
- A non-empty `pcie_devices` switches the VM to q35 + OVMF + EFI disk. Never set machine type separately.
- Two Proxmox provider aliases: a scoped token by default, `proxmox.root` only for cloning and templates.
- Infrastructure stacks read secrets with `ephemeral "sops_file"`. Only the application stack uses `data "sops_file"`.
- Deployments consume the `proxmox_vm` module by git URL pinned to a commit SHA. Changes land in the module repo first, then the `?ref=` here moves to the new SHA.

## Ansible conventions

- Inventory files merge in lexical order. The `00_`/`01_`/`10_` prefixes are load-bearing.
- Every first-party role ships `meta/argument_specs.yml` and `README.md`. `defaults/main.yml`, `argument_specs.yml`, and the README change together.
- Role variables carry the role name as a prefix. Shared values live unprefixed in `inventory/group_vars/<group>`, and that file re-exports them onto the prefixed names.
- Loop vars are `__name` or `<role>_name`. Use FQCN modules. The lint profile is `production`.
- New roles: `ansible-galaxy role init <name>` from `ansible/`, using the `template_role/` skeleton.

## Terraform conventions

- Every variable and output needs a `description` (TFLint `all` preset).
- terraform-docs generates the content between `<!-- BEGIN_TF_DOCS -->` markers. Never hand-edit it.
- Commit `.terraform.lock.hcl` files.
- Split stack files by concern: `main.tf`, `main-<concern>.tf`.

## Documentation style

Docs read in the owner's voice: a sharp, direct engineer writing for a competent peer. Claude may draft the bulk, but the result follows these rules.

- Lead with the point. Short to medium sentences. Prose over bullets, except for real steps or comparisons.
- Active, declarative, technical voice. No "you", no "this note/doc", no passive constructions.
- Never em dashes or "--". Use commas, periods, or parentheses.
- No "not X, but Y" framing, no lists of three for rhythm, no filler (delve, robust, seamless, leverage, landscape, crucial).
- No self-flagging callouts or hedges. No quiz sections.
- Cite file paths only, never line numbers. Use relative markdown links, not `[[wikilinks]]`.
