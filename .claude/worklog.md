# Homelab-Platform worklog

Phase: prod prep. Goal: the stack deploys correctly on any host layout, CI gates every change through plan, state and application data survive a host loss, first-party roles carry tests, and the repo reads clean. Work items in order. Each item names its done condition. Record the commit SHA next to each item when it lands.

Deferred work lives in `.claude/backlog.md`. Module work lives in the module's own worklog, `terraform-proxmox-module/.claude/worklog.md`. Item 9 here picks up its release.

## Correctness

### 1. Configarr Radarr template targets an undefined profile

`ansible/roles/media_platform/templates/configarr.yml.j2` includes the `radarr-custom-formats-uhd-bluray-web` template, which scores a `UHD Bluray + WEB` profile. The only Radarr profile defined is `Remux 2160`. `delete_unmanaged_custom_formats` and `delete_unmanaged_quality_profiles` are enabled for Sonarr and Radarr, so the next sync deletes any live profile or format missing from the config.

Drop the include and keep the explicit `custom_formats` block, or define the profile the template targets.

Done when: a Configarr dry run against live Sonarr and Radarr reports no deletions and no scores assigned to undefined profiles.

### 2. argument_specs drift

`observability_control_prometheus_host_port` defaults to 9090 in `ansible/roles/observability_control/defaults/main.yml` and 9100 in `meta/argument_specs.yml`. Defaults with no spec entry: `observability_control_pve_exporter_{name,host_port}` and `observability_node_{cluster_name,grafana_name,grafana_host_port,prometheus_name,prometheus_host_port}`. `observability_node_smartctl_exporter_enabled` has a spec default (`false`) and no entry in `defaults/main.yml`.

Done when: in both roles every default has a spec entry with the same value, every spec default has a matching default, the role READMEs agree, and `ansible-lint -c ../.ansible-lint` passes.

### 3. smartctl-exporter device list is hardcoded

`ansible/roles/observability_node/templates/docker-compose.yml.j2` maps `/dev/sda` through `/dev/sdd` and `/dev/nvme0` as literals. Docker refuses to create the container when a mapped device is missing, so the exporter fails on any host without all five. Add a list variable to `defaults/main.yml`, `meta/argument_specs.yml` and the role README, and render `devices:` from it.

Done when: each node sets its own list in `host_vars`, and `--check --diff` against both nodes shows only that host's devices.

## CI and state

### 4. Enforce terraform-docs in CI, trim tflint args

The `hooks` job in `.github/workflows/ci.yml` lists `terraform_docs` in `SKIP`, so CI never checks the generated tables. Install terraform-docs v0.20.0 in that job (the version in `docs/knowledge-base/ci-quality-gates.md`) and drop it from `SKIP`. In `.pre-commit-config.yaml`, remove the five `--enable-rule` args on `terraform_tflint`. `terraform/.tflint.hcl` already sets `preset = "all"`.

Done when: CI passes on a PR, and a hand edit inside a `BEGIN_TF_DOCS` block fails the `hooks` job.

### 5. Remote state with locking

No stack declares a `backend`, so state is local. The application stack's `data "sops_file"` writes decrypted values into it. Move `_base`, media `infrastructure` and media `application` to a backend with native locking and encryption at rest (S3-compatible with `use_lockfile`, or `pg`). Turn on object versioning so item 7 covers state history.

Done when: `init -migrate-state` succeeds for all three stacks, no `*.tfstate` remains on disk, and a second concurrent `plan` waits on the lock.

### 6. Plan on PR

Depends on 5. Add a CI job that runs `terraform plan` for each changed stack on PRs and posts the output as a comment. GitHub-hosted runners can't reach the Proxmox API on the LAN, so the job needs a self-hosted runner with access to Proxmox and the state backend. The repo is public, so the job must never run for fork PRs: a fork PR would execute arbitrary code on a LAN host.

Done when: a PR touching `terraform/` gets a plan comment per changed stack, and a PR from a fork doesn't trigger the job.

### 7. Backups

Nothing backs up application state. Cover `media_platform_config_dir` (*arr, Jellyfin and Configarr config), `{{ observability_control_root_dir }}/grafana/data` on the control host, and the state bucket from item 5. Copies land off-host on a schedule.

Done when: a scheduled run completes, and restoring one *arr config onto a fresh VM brings the service back with its settings intact.

## Tests

### 8. Molecule for first-party roles

`docker_base`, `lvm_storage`, `media_platform`, `nfs_client`, `nfs_server`, `observability_control` and `observability_node` have no tests. Add a Molecule scenario per role: converge, idempotence, and `verify` assertions on what the role guarantees (containers running, files rendered, ports listening). `lvm_storage` and `nfs_server` need block devices and kernel NFS, which the Docker driver can't provide, so those two get a delegated VM scenario. Add a CI job that runs the container scenarios.

Done when: `molecule test` passes for every role locally, and CI runs the container-driver scenarios on every PR that touches `ansible/roles/`.

## Module

### 9. Consume terraform-proxmox-module v2.0.0

The module worklog covers the fixes, `terraform test`, examples, CI, README and the `v2.0.0` release. Once that tag exists, move `?ref=` in `terraform/deployments/media/infrastructure/main.tf` to the tag's commit SHA.

Done when: `terraform -chdir=terraform/deployments/media/infrastructure init -backend=false && terraform -chdir=terraform/deployments/media/infrastructure validate` passes, and `pre-commit run --all-files` is clean.

## Cleanup and presentability

### 10. Unvendor geerlingguy.docker and geerlingguy.pip

`ansible/roles/geerlingguy.docker` (8.0.0) and `ansible/roles/geerlingguy.pip` (3.1.2) are committed copies. This reverses the decision recorded under "Vendored" in `ansible/README.md`. Pinned versions in `requirements.yml` keep the exact-version record, and Galaxy becomes an install-time dependency.

Add both to a `roles:` section in `ansible/requirements.yml` at those versions. Install to a gitignored `ansible/galaxy_roles/`, set `roles_path = ./galaxy_roles:./roles` in `ansible/ansible.cfg`, and drop the geerlingguy entries from `.ansible-lint` and `.yamllint`. Rewrite the Vendored section of `ansible/README.md`, the "2 vendored" line in `README.md`, and the vendored-role rule in `CLAUDE.md`.

Done when: a clean clone runs `ansible-galaxy install -r requirements.yml` from `ansible/`, `ansible-playbook -i localhost, site.yml --syntax-check` passes, and no `geerlingguy.*` remains under `ansible/roles/`.

### 11. Role licence metadata

`license: BSD` in the seven first-party `ansible/roles/*/meta/main.yml` files and `ansible/template_role/meta/main.yml.j2` contradicts "No license granted" in `README.md`. Make the field match the README.

Done when: `license: BSD` appears only under the geerlingguy roles (or nowhere, after item 10), and `ansible-lint -c ../.ansible-lint` passes.

### 12. Stack README prose

`terraform/infrastructure/_base/README.md`, `terraform/deployments/media/infrastructure/README.md` and `terraform/deployments/media/application/README.md` carry only a title above `<!-- BEGIN_TF_DOCS -->`. Add a short paragraph to each: what the stack owns, what it reads from upstream stacks or Ansible, and where it sits in the apply order.

Done when: each README has prose above the marker in the `CLAUDE.md` documentation style, and `pre-commit run --all-files` leaves it untouched.

### 13. Branches and merge policy

Local branches already merged into `main`: `ci_cd`, `develop`, `documentatin`, `documentation`, `list`, `media_platform`, `milestone_1`, `secrets_cleanup`, `test`. Delete them. `gitleaks` exists on the remote too and isn't merged into `main` (last commit 2026-10-02): merge it or delete both copies. One stash remains (`WIP on main: 6ca7374 Audit (#24)`): apply or drop it. Then set the GitHub repo to allow squash merges only.

Done when: `git branch -a` lists only `main` and active work, `git stash list` is empty, and the repo settings allow squash merges only.
