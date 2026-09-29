---
title: CI and Quality Gates
tags: [component/ci, component/quality-gates]
created: 2026-09-17
---

# CI and Quality Gates

> [!info] Local vs. CI
> Pre-commit runs locally on demand. In CI, the `hooks` job in
> `.github/workflows/ci.yml` runs `pre-commit run --all-files` server-side
> with most hooks skipped through the `SKIP` env var, which enforces the
> hygiene and SOPS checks on every push regardless of local setup.

## Every CI job and what fails it

`.github/workflows/ci.yml` defines **8 jobs**. Every push to `main` and every
pull request runs all of them.

| Job | Runs | Fails on |
|---|---|---|
| `ansible-lint` | `ansible/ansible-lint` action, `working_directory: ansible`, `requirements_file: requirements.yml`, `args: '-c ../.ansible-lint'` | Any rule violation under the `production` profile (the strictest built-in profile), plus the opt-in rules in `.ansible-lint`'s `enable_list`: `args`, `empty-string-compare`, `no-log-password`, `no-same-owner`, `galaxy-version-incorrect`, `yaml` |
| `yaml-lint` | `yamllint -f github .` across the whole repo, Python 3.12, `yamllint==1.37.1` | Any enabled rule in `.yamllint`: `anchors`, `braces`, `brackets`, `colons`, `commas`, `document-start`, `empty-lines`, `hyphens`, `indentation`, `key-duplicates`, `new-line-at-end-of-file`, `new-lines`, `trailing-spaces`. `comments` and `truthy` run at `warning` level and do not fail the job; `line-length`, `key-ordering`, `octal-values`, and `quoted-strings` are off |
| `terraform-static` | `terraform fmt -check -recursive workspace`, then `tflint --init && tflint --recursive --format compact` from `workspace/` | Any file that differs from canonical `terraform fmt` output, or any TFLint violation. `workspace/.tflint.hcl` enables the bundled `terraform` ruleset with `preset = "all"`, which includes `terraform_documented_variables`, `terraform_documented_outputs`, `terraform_naming_convention`, and `terraform_standard_module_structure` on top of the recommended rules |
| `terraform-validate` | Matrix over `workspace/infrastructure/_base`, `workspace/deployments/media/infrastructure`, and `workspace/deployments/media/application`; each runs `terraform init -backend=false` then `terraform validate` | Any syntax or type error Terraform's validator catches. `-backend=false` means the job needs **no real state, no Proxmox credentials, and no SOPS key**. `modules/proxmox_vm` has no standalone root config, so the stacks that call it exercise it transitively |
| `trivy` | `aquasecurity/trivy-action`, `scan-type: config`, `scan-ref: workspace`, `trivy-config: trivy.yaml`, `exit-code: 1` | Any IaC misconfiguration Trivy's bundled checks catch across the scanners enabled in `trivy.yaml` (`dockerfile`, `helm`, `kubernetes`, `terraform`, and the Terraform plan formats). With `exit-code: 1` and no severity filter, **any** finding fails the job |
| `gitleaks` | `gitleaks/gitleaks-action`, checkout with `fetch-depth: 0` | Any pattern gitleaks recognizes as a secret, scanned across the **entire git history**, not only the current diff |
| `actionlint` | `reviewdog/action-actionlint`, `reporter: github-check` | Malformed GitHub Actions workflow syntax, invalid expressions, misreferenced actions |
| `hooks` | `pre-commit run --all-files` with `SKIP: ansible-lint, yamllint, terraform_fmt, terraform_docs, terraform_tflint, terraform_trivy, terraform_validate` | The hooks left after the skip list: `trailing-whitespace`, `end-of-file-fixer`, `check-added-large-files`, `detect-private-key` (from `pre-commit/pre-commit-hooks`), and `sops` (from `squat/pre-commit-sops`) |

## What the `hooks` job covers

Subtracting the `SKIP` list from `.pre-commit-config.yaml`'s full hook set
leaves basic file hygiene (`trailing-whitespace`, `end-of-file-fixer`,
`check-added-large-files`), `detect-private-key`, and the `sops` hook, the
one that matters most for [Secrets](secrets.md):

```yaml
  - repo: https://github.com/squat/pre-commit-sops
    rev: 0.1.0
    hooks:
      - id: sops
        files: '\.sops\.ya?ml$'
        exclude: '(^|/)\.sops\.ya?ml$'
```
(`.pre-commit-config.yaml`, excerpt)

The `sops` hook is the check that verifies a `*.sops.yaml` file is actually
encrypted. `ansible-lint` and `yamllint` **exclude** `*.sops.yaml` and
`*.sops.yml` from their scope (`.ansible-lint`, `.yamllint`), so they never
parse ciphertext.

> [!info] Why `hooks` uses SKIP instead of a curated hook list
> Every other job (`ansible-lint`, `terraform-static`, and the rest) already
> runs its tool directly, with tailored GitHub Actions integration (inline
> annotations, matrix parallelism). The `SKIP` list lets `hooks` reuse the
> exact `.pre-commit-config.yaml` that runs locally while executing only the
> checks with no dedicated job of their own: hygiene and SOPS.

## `terraform_docs`

`terraform_docs` regenerates each stack's `README.md` tables between the
`<!-- BEGIN_TF_DOCS -->` markers from `workspace/.terraform-docs.yaml`. It
runs through local pre-commit, and the `hooks` job skips it, so CI does not
diff generated tables. The `terraform-static` job covers the input side: the
`all` TFLint preset requires a `description` on every variable and output,
and those descriptions are what `terraform_docs` renders.

## Local pre-commit

`pre-commit run --all-files` locally (no `SKIP`) runs **every** hook in
`.pre-commit-config.yaml`:

- `terraform_fmt`, `terraform_tflint`, `terraform_trivy`, and
  `terraform_validate` (`--tf-init-args=-lockfile=readonly`, excluding
  `workspace/modules/`, consistent with the `terraform-validate` job's
  matrix). The `terraform_tflint` hook also passes `--enable-rule` for the
  documentation, naming, structure, and module-shallow-clone rules.
- `terraform_docs`, which regenerates the README tables.
- `ansible-lint` and `yamllint`, the same tools CI runs.
- The hygiene and `sops` hooks that CI's `hooks` job also runs.

A local run therefore adds `terraform_docs` regeneration to everything CI
enforces. Every other check has an independent CI job.

> [!tip] Rule of thumb
> Every check that blocks a merge has its own CI job. Local pre-commit adds
> fast feedback before push and keeps the generated README tables current.

## Local tooling

The Terraform-side hooks call binaries that `pre-commit` does not install.
The versions below match the ones that generated the committed README tables
and that the hooks were last run with:

```bash
# trivy v0.74.0
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh \
  | sudo sh -s -- -b /usr/local/bin v0.74.0

# terraform-docs v0.20.0
curl -sSLo /tmp/terraform-docs.tar.gz \
  "https://github.com/terraform-docs/terraform-docs/releases/download/v0.20.0/terraform-docs-v0.20.0-$(uname)-amd64.tar.gz"
tar -xzf /tmp/terraform-docs.tar.gz -C /tmp terraform-docs
sudo install /tmp/terraform-docs /usr/local/bin/terraform-docs

# tflint v0.64.0, verified against its signed checksums
curl -sSLO https://github.com/terraform-linters/tflint/releases/download/v0.64.0/tflint_linux_amd64.zip
curl -sSLO https://github.com/terraform-linters/tflint/releases/download/v0.64.0/checksums.txt
gh attestation verify checksums.txt -R terraform-linters/tflint
sha256sum --ignore-missing -c checksums.txt
unzip tflint_linux_amd64.zip && sudo install tflint /usr/local/bin/
```

A different `terraform-docs` version can reorder or reformat the generated
tables, which shows up as a diff on the next hook run.

## Pinning

Every `uses:` line in `ci.yml` references a full commit SHA rather than a tag
like `@v4`. A compromised or force-pushed tag on a third-party action cannot
change what CI executes; only a new SHA, through an explicit `ci.yml` edit,
can. Tool versions inside jobs carry exact pins too (`yamllint==1.37.1`,
`pre-commit==4.6.2`).
