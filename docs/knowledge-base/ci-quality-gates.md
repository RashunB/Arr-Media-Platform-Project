---
title: CI and Quality Gates
tags: [component/ci, component/quality-gates]
created: 2026-09-17
---

# CI and Quality Gates

> [!warning] The one thing to get right in this note
> **Pre-commit is optional locally. It is not optional in CI.** These are two
> different statements and this repo previously caused confusion by
> conflating them. The `hooks` job in `.github/workflows/ci.yml` re-runs
> `pre-commit run --all-files` server-side, with most hooks skipped via the
> `SKIP` env var, specifically so that the hygiene/SOPS checks are actually
> enforced even if nobody ran `pre-commit install` locally. Everything below
> exists to make that precise.

## Every CI job, matched to what it actually checks

All jobs are defined in `.github/workflows/ci.yml`. There are **7 active
jobs** plus one commented-out job (`pre-commit`, disabled — see below).

| Job | Runs | What would make it fail |
|---|---|---|
| `ansible-lint` | `ansible/ansible-lint@665d9e0...` action, `working_directory: ansible`, `requirements_file: requirements.yml`, `args: '-c ../.ansible-lint'` | Any rule violation under the `production` profile (`.ansible-lint:5`) — the strictest built-in profile — plus the explicitly enabled opt-in rules: `args`, `empty-string-compare`, `no-log-password`, `no-same-owner`, `galaxy-version-incorrect`, `yaml` (`.ansible-lint:60-66`) |
| `yaml-lint` | `yamllint -f github .` against the whole repo, Python 3.12, pinned `yamllint==1.37.1` | Any enabled rule in `.yamllint` — `anchors`, `braces`, `brackets`, `colons`, `commas`, `hyphens`, `indentation`, `key-duplicates`, `document-start`, `new-line-at-end-of-file`, `new-lines`, `trailing-spaces` all `enable`; `comments`/`truthy` are `warning`-level (won't fail the job); `line-length`, `key-ordering`, `octal-values`, `quoted-strings` explicitly `disable` |
| `terraform-static` | `terraform fmt -check -recursive workspace`, then `tflint --init && tflint --recursive --format compact` from `workspace/` | Any file not matching canonical `terraform fmt` output, or any TFLint rule violation (ruleset defined by whatever `.tflint.hcl` config exists, not read for this note) |
| `terraform-validate` | Matrix job over `workspace/infrastructure/_base`, `workspace/deployments/media/infrastructure`, `workspace/deployments/media/application` — for each, `terraform init -backend=false` then `terraform validate` | Any syntax/type error Terraform's own validator catches. `-backend=false` means this job needs **no real state, no Proxmox credentials, no SOPS key** — pure static validation. Note `modules/proxmox_vm` is **not** in this matrix (it has no standalone root config to validate directly — it's exercised transitively whenever a calling stack validates) |
| `trivy` | `aquasecurity/trivy-action`, `scan-type: config`, `scan-ref: workspace`, `trivy-config: trivy.yaml`, `exit-code: 1` | Any IaC misconfiguration Trivy's bundled checks catch across the `terraform`/`dockerfile`/`helm`/`kubernetes` scanners enabled in `trivy.yaml:15-21` — `exit-code: 1` means **any** finding fails the job, not just high-severity ones (no severity filter is set) |
| `gitleaks` | `gitleaks/gitleaks-action`, checkout with `fetch-depth: 0` | Any pattern gitleaks' default+configured rules recognize as a secret, scanned across the **entire git history**, not just the current diff — this is the one job explicitly commented as "not part of pre-commit" (`ci.yml:143`) |
| `actionlint` | `reviewdog/action-actionlint`, `reporter: github-check` | Malformed GitHub Actions workflow syntax, invalid expressions, unpinned/misreferenced actions — explicitly commented "not part of pre-commit" (`ci.yml:157`) |
| `hooks` | `pre-commit run --all-files`, with `SKIP: ansible-lint, yamllint, terraform_fmt, terraform_docs, terraform_tflint, terraform_trivy, terraform_validate` (`ci.yml:169-181`) | Whatever's left after that skip list: `trailing-whitespace`, `end-of-file-fixer`, `check-added-large-files`, `detect-private-key` (from `pre-commit/pre-commit-hooks`), and the `sops` hook (from `squat/pre-commit-sops`) |

## What the `hooks` job is actually for

Once you subtract the `SKIP` list from `.pre-commit-config.yaml`'s full hook
set, what's left is exactly: basic file hygiene
(`trailing-whitespace`, `end-of-file-fixer`, `check-added-large-files`),
`detect-private-key`, and — the one that matters most for [[secrets]] — the
`sops` hook:

```yaml
- repo: https://github.com/squat/pre-commit-sops
  rev: 0.1.0
  hooks:
    - id: sops
      files: '\.sops\.ya?ml$'
      exclude: '(^|/)\.sops\.ya?ml$'
```
(`.pre-commit-config.yaml:46-51`)

This is the **only** automated check anywhere in the repo — local or CI —
that verifies a `*.sops.yaml` file is actually encrypted. Everything else
(`ansible-lint`, `yamllint`) explicitly **excludes** `*.sops.yaml`/`*.sops.yml`
patterns from its own scope (`.ansible-lint:14-20`, `.yamllint:9-14`), so
they never even parse these files, let alone check their encryption state.

> [!info] Why the redundant hooks/SKIP dance instead of two separate jobs?
> Every other job (`ansible-lint`, `terraform-static`, etc.) already runs
> those specific tools directly, with better-tailored GitHub Actions
> integrations (inline annotations, matrix parallelism). Re-running them a
> second time inside `hooks` would be pure duplication. The `SKIP` list lets
> `hooks` reuse the exact same `.pre-commit-config.yaml` a developer runs
> locally, while only actually executing the handful of checks — hygiene and
> SOPS — that have no dedicated job of their own.

## The disabled `pre-commit` job

Lines 17-54 of `ci.yml` are an entire job, commented out in full, that would
have run the complete `.pre-commit-config.yaml` (including `terraform_docs`,
`terraform_tflint`, `terraform_trivy`, `terraform_validate`, and full
`ansible-lint`/`yamllint`) as one consolidated step. It's disabled — the
in-file comment for the sibling disabled `terraform-docs` job explains why
for that specific hook ("action cannot create file it just fails all the
time" — `ci.yml:124`), and the root README lists **re-enabling this job and
the `terraform-docs` diff check** as an explicit open roadmap item.

**Practical consequence**: right now, `terraform_docs` (which regenerates the
per-stack `README.md` tables between `<!-- BEGIN_TF_DOCS -->` markers) is
enforced **nowhere in CI**. It only runs if you invoke `pre-commit` locally
yourself. A stale generated table in `modules/proxmox_vm/README.md` (or any
other stack README) would not fail a PR.

## Local pre-commit: what running it gets you that CI's `hooks` job doesn't

`pre-commit run --all-files` locally (no `SKIP`) runs **every** hook in
`.pre-commit-config.yaml`:

- `terraform_fmt`, `terraform_tflint`, `terraform_trivy`, `terraform_validate`
  (`-tf-init-args=-lockfile=readonly`, **excluding** `workspace/modules/`
  per `.pre-commit-config.yaml:44-45` — consistent with `terraform-validate`
  CI job's matrix also skipping the module directly)
- `terraform_docs` — regenerates README tables, not checked in CI at all
  right now
- `ansible-lint`, `yamllint` — same tools CI runs, just locally
- the hygiene + `sops` hooks that CI's `hooks` job also runs

So a developer who runs `pre-commit run --all-files` before pushing gets
**strictly more coverage** than CI alone provides today (specifically,
`terraform_docs` drift detection). A developer who skips it entirely still
gets everything except `terraform_docs`, because every other check has an
independent CI job.

> [!tip] The practical rule of thumb
> If you never install pre-commit locally, you are not skipping any check
> that would otherwise block a merge — every enforced check has its own CI
> job. You *are* skipping the fast, local feedback loop, and you're skipping
> `terraform_docs` regeneration, which nothing currently forces you to do at
> all.

## Pinning discipline

`ci.yml`'s in-repo comment states "All third-party actions are pinned to
commit SHAs rather than tags" (root README, "Quality gates" section) — every
`uses:` line in `ci.yml` does reference a full SHA, not a tag like `@v4`.
This is a supply-chain hardening choice: a compromised or force-pushed tag on
a third-party action can't silently change what CI executes; only a new SHA,
requiring an explicit `ci.yml` edit, can.

## Check your understanding

- [ ] Is pre-commit required to be installed locally for a PR to be blocked
      on a hygiene issue? What actually blocks it if you never install
      pre-commit?
- [ ] Which single hook is the only thing in the entire repo — local or CI —
      that verifies a `*.sops.yaml` file is actually encrypted, and why do
      `ansible-lint`/`yamllint` never catch an unencrypted one themselves?
- [ ] Why does the `hooks` CI job set a `SKIP` env var instead of just
      running a smaller, separately curated set of hooks?
- [ ] What does `terraform-validate`'s `-backend=false` buy CI, and why does
      that matter given state is local (see [[provisioning]])?
- [ ] Name one check that only runs if a developer manually runs pre-commit
      locally, with zero CI equivalent today.
- [ ] Why is `workspace/modules/proxmox_vm` excluded from both the
      `terraform_validate` pre-commit hook and the `terraform-validate` CI
      job's matrix?
- [ ] What does `exit-code: 1` on the `trivy` job mean for severity
      filtering — does a low-severity finding fail the build?
