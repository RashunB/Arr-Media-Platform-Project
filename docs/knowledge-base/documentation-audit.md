---
title: Documentation Audit
tags: [moc, component/documentation]
created: 2026-09-18
---

# Documentation Audit

> [!info] Scope
> A verification pass over every hand-written document in this repo, run
> against `7096e20`. Part A lists defects **in the documentation**: claims
> that have drifted out of agreement with the code, claims that were wrong
> when written, and places where documentation is absent or boilerplate.
> Part B is the opposite direction: every defect and gap the documentation
> already records, consolidated into one list and re-verified as still
> present in the tree.
>
> This note reports. It fixes nothing. Every row was produced by running the
> command in its citation; any finding the re-run contradicted was dropped
> rather than softened.

Documents audited: [[../../README.md|root README]],
[[../../ansible/README.md|ansible/README.md]],
[[../../workspace/README.md|workspace/README.md]], the seven notes in this
vault, the four terraform-docs stack READMEs, and the seven first-party role
READMEs. Vendored collections, `.venv/`, and `.claude/plugins/` are out of
scope.

---

## Part A: defects in the documentation

### A1. `ci-quality-gates.md` miscounts the CI jobs

The note opens with "There are **7 active jobs** plus one commented-out job
(`pre-commit`, disabled, see below)". Both numbers are wrong, and the note's
own table immediately below lists eight rows.

`.github/workflows/ci.yml` defines **eight** active jobs: `ansible-lint:56`,
`yaml-lint:66`, `terraform-static:78`, `terraform-validate:94`, `trivy:113`,
`gitleaks:144`, `actionlint:158`, `hooks:169`. The root README's "Quality
gates" table and its `8 CI jobs` claim are the correct ones.

There are also **two** commented-out jobs, not one: `pre-commit`
(`ci.yml:17-54`) and `terraform-docs` (`ci.yml:125-141`, with its explanatory
comment at `ci.yml:124`). The note discusses both but counts only the first.

The note's cited span "Lines 17-54" for the `pre-commit` job is accurate and
needs no change.

### A2. `secrets.md` quotes a superseded `.sops.yaml`

> [!bug] The quoted `path_regex` is the version that was failing
> `secrets.md` reproduces `.sops.yaml` under a "(full file)" label as:
> ```yaml
> creation_rules:
>   - path_regex: '**\.sops\.yaml$'
> ```
> The current file reads:
> ```yaml
> creation_rules:
>   - path_regex: '.*\.sops\.yaml$'
>     age: age1zdcnr28uvud0k57mxeqvs8t07jrk7tz6hpfgauw0twdquwfh4yzshq4j7n
> ```
> The change landed in `97af3b0` ("sops change") and `3790a1f` ("sops was
> failing, no longer fails"), both after this vault was committed in `1276f57`
> / `c7dabcb`. The glob-style `**` the note preserves is not valid Go regexp
> and is the pattern that was breaking encryption. The note therefore
> documents the broken state as current.

### A3. The Dozzle port-mismatch callout overstates its own finding

`observability.md` carries a `[!bug]` stating that the control host's
`DOZZLE_REMOTE_AGENT` entries "point at the wrong port and the control Dozzle
instance cannot reach that node's agent".

The role defaults do diverge, exactly as the note says:

| Source | Value |
|---|---|
| `roles/observability_control/defaults/main.yml:16` | `observability_control_dozzle_host_port: 7070` |
| `roles/observability_node/defaults/main.yml:14` | `observability_node_dozzle_host_port: 7007` |

But both are overridden in the committed inventory, and both resolve to the
same value:

| Source | Value |
|---|---|
| `inventory/group_vars/observability:16` | `dozzle_host_port: 7070` |
| `inventory/group_vars/observability_node:32` | `observability_node_dozzle_host_port: "{{ dozzle_host_port }}"` |
| `inventory/group_vars/observability_control:33` | `observability_control_dozzle_host_port: "{{ dozzle_host_port }}"` |

The callout's own escape clause, "unless a node's
`observability_node_dozzle_host_port` is explicitly overridden to match the
control host's port", is satisfied by the repo as committed. The note does
not say so, and the group_vars re-export it describes approvingly elsewhere
is the thing masking the defect.

This should be reclassified from `[!bug]` to a fragile-default note: the
config is correct today and breaks the moment a host joins
`observability_node` without inheriting `group_vars/observability`.

### A4. The `file_sd` callout's header contradicts its own body

`observability.md`'s header reads "Three of the four `file_sd` templates are
missing a closing quote". The body of the same callout then states
"`smartctl_exporter.yml.j2` has the same missing quote", which makes four.

Verified: **all four** templates in
`roles/observability_control/templates/prometheus/file_sd/` are missing the
closing `"`, and **all four** reference
`observability_node_pve_exporter_host_port` regardless of the exporter they
target.

| Template | Target line |
|---|---|
| `cadvisor.yml.j2` | `:4` |
| `node_exporter.yml.j2` | `:4` |
| `pve_exporter.yml.j2` | `:5` |
| `smartctl_exporter.yml.j2` | `:5` |

The body is correct; the header is not.

### A5. `configuration.md` describes a live YAML key as commented out

The `[!info]` callout states "Lines 14-19 of `00_inv.proxmox.yml` are
commented-out example Jinja-conditional group rules ... They're inert."

Line 14 is `groups:` and is **not** commented. Only lines 15-19 are:

```
14:groups:
15:  # rhce_proxy: "proxmox_name == 'rhce-1'"
...
19:  # rhce: "'rhce' in (proxmox_tags_parsed|list)"
```

The key is live with a null body. "Inert" is the right practical conclusion,
but the description of what is on disk is wrong, and the distinction matters
to anyone deciding whether the block is safe to delete.

Compounding this: the code block directly above the callout is labeled
"(`ansible/inventory/00_inv.proxmox.yml`, full file)" and **omits the
`groups:` block entirely**. The callout references lines that do not appear
in the quotation it annotates.

### A6. `.tflint.hcl` does not exist

`ci-quality-gates.md`'s `terraform-static` row says failures come from "any
TFLint rule violation (ruleset defined by whatever `.tflint.hcl` config
exists, not read for this note)".

No `.tflint.hcl` exists anywhere under `workspace/`. With no configuration
file, `tflint --init` installs no plugins and TFLint runs its core ruleset
only, without the `terraform` ruleset plugin. The job passes on Terraform
that a configured TFLint would reject.

The root README inherits the same overstatement: its quality-gates table
describes `terraform-static` as "`terraform fmt -check -recursive` plus
recursive TFLint", which is literally true and materially misleading about
coverage.

### A7. Several "(full file)" quotations are reconstructions

`index.md:16` states the vault's verification contract: "Every claim cites a
repo-relative file path for verification." Several code blocks labeled "full
file" do not survive that check.

`configuration.md` quotes `site.yml` as:

```yaml
- import_playbook: sops.yml                 # tags: [sops, secrets]
```

The actual file uses `name:` keys and the fully-qualified
`ansible.builtin.import_playbook`:

```yaml
- name: Setup SOPS on control
  ansible.builtin.import_playbook: sops.yml
  tags: [sops, secrets]
```

The same pattern appears in `secrets.md` (A2) and in `configuration.md`'s
`00_inv.proxmox.yml` block (A5). The reconstructions convey the right meaning
and would mislead anyone diffing them against the file. Every "(full file)"
label should be made verbatim or relabeled as an excerpt.

### A8. Every first-party role README is unmodified Galaxy boilerplate

All seven first-party role READMEs are byte-identical, md5
`433d370732878937b5cf7bdbf13b76d6`:

```
ansible/roles/docker_base/README.md
ansible/roles/lvm_storage/README.md
ansible/roles/media_platform/README.md
ansible/roles/observability_control/README.md
ansible/roles/observability_node/README.md
ansible/roles/nfs_server/README.md
ansible/roles/nfs_client/README.md
```

Each still reads "Role Name", "A brief description of the role goes here",
and "License: BSD". All seven are tracked by git.

The root README lists this as a roadmap item. What it does not name is the
cause: `ansible/template_role/README.md.j2` is itself unmodified Galaxy
boilerplate, so the skeleton wired up at `ansible.cfg`'s
`role_skeleton = ./template_role` regenerates the placeholder for every new
role. Writing seven READMEs without changing the skeleton fixes the symptom
for exactly as long as it takes to run `ansible-galaxy role init` again.

The boilerplate's "License: BSD" also contradicts the root README's "Personal
project. No license granted."

### A9. The terraform-docs tables are 60 `n/a` descriptions deep

The generated input tables render `n/a` wherever the source variable has no
`description`:

| Stack README | `n/a` rows |
|---|---|
| `workspace/modules/proxmox_vm/README.md` | 13 |
| `workspace/infrastructure/_base/README.md` | 8 |
| `workspace/deployments/media/infrastructure/README.md` | 23 |
| `workspace/deployments/media/application/README.md` | 16 |

`workspace/modules/proxmox_vm/variables.tf` declares 18 variables and carries
5 descriptions. Because the tables are generated, the fix is in the `.tf`
files, not the READMEs.

All four files also carry **zero prose above `<!-- BEGIN_TF_DOCS -->`**: a
single `#` heading and then the marker. `workspace/README.md` documents that
position as the supported place for hand-written context ("Prose written
above the marker is preserved"), and nothing currently uses it. A caller
reading `proxmox_vm/README.md` gets a variable table and no statement of what
the module does.

### A10. `cloun-init` typo, propagated into generated output

`workspace/modules/proxmox_vm/variables.tf:56`:

```hcl
description = "Path to cloun-init .tpl file. If null, the module default is used."
```

Copied verbatim into `workspace/modules/proxmox_vm/README.md:35` by
terraform-docs. Fixing the README alone would be reverted by the next
`terraform_docs` hook run; the variable is the source.

### A11. Wikilinks do not render outside Obsidian

The vault contains 49 `[[wikilink]]` references. GitHub renders them as
literal bracketed text, so every cross-note link in the knowledge base is
dead for anyone reading the repo in a browser.

Three of them use a hybrid form that renders cleanly in neither target:

```
[[../../README.md|root README]]
[[../../workspace/README.md|workspace/README.md]]
[[../../ansible/README.md|ansible/README.md]]
```

By contrast, every relative markdown link in the three top-level READMEs and
in `index.md` resolves correctly. The decision to make is which renderer the
vault targets; the current state serves Obsidian and abandons GitHub without
saying so anywhere.

### A12. Repository-level documents that do not exist

No `LICENSE`, no `CONTRIBUTING.md`, no root `CLAUDE.md`. The README's
"Personal project. No license granted; see the repository owner." is a
deliberate position rather than an oversight, but it is contradicted in seven
places by A8.

### A13. Clean results worth recording

These were checked and found correct, so that a later pass does not re-derive
them:

- No `TODO`, `TBD`, `FIXME`, or `XXX` marker exists in any in-scope document.
- Every relative markdown link in `README.md`, `ansible/README.md`,
  `workspace/README.md`, and `index.md` resolves to an existing path.
- The root README's counts are accurate: 7 first-party roles, 2 vendored
  roles, 8 CI jobs, 3 Terraform stacks, 5 files in `secrets/`.
- `ci-quality-gates.md`'s `ci.yml:17-54` and `ci.yml:124` line citations are
  correct.
- Em-dash usage is confined to `README.md` (9 occurrences). The vault and the
  two sub-READMEs already use none.

---

## Part B: the backlog the documentation already records

Every item below is a `[!bug]`, `[!warning]`, or roadmap checkbox already
written somewhere in the docs. Each was re-verified as still present at
`7096e20`, with the file and line that would carry the fix.

### Observability

- [X] **B1. All four `file_sd` templates emit invalid YAML.** The target line
      is missing its closing `"`, in
      `roles/observability_control/templates/prometheus/file_sd/`:
      `cadvisor.yml.j2:4`, `node_exporter.yml.j2:4`, `pve_exporter.yml.j2:5`,
      `smartctl_exporter.yml.j2:5`. Documented in `observability.md` (see A4
      for the header/body discrepancy).
- [X] **B2. All four `file_sd` templates use the wrong port variable.** Each
      interpolates `observability_node_pve_exporter_host_port` regardless of
      the exporter it targets, so the cAdvisor, node-exporter, and
      smartctl-exporter target files are built from the PVE exporter's port.
      Same four files and lines as B1.
- [ ] **B3. smartctl-exporter's device list is hardcoded.**
      `roles/observability_node/templates/docker-compose.yml.j2:37-41` mounts
      `/dev/sda` through `/dev/sdd` plus `/dev/nvme0` as literals, derived
      from no fact. A host with different storage needs a template edit.
      Documented in `observability.md`.
- [X] **B4. Orphaned Ansible Vault file inside a role tree.**
      `roles/observability_node/files/prometheus/pve.yml` opens with
      `$ANSIBLE_VAULT;1.2;AES256;pve` and is git-tracked. The role's real
      PVE-exporter config is templated from
      `templates/pve-exporter/pve.yml.j2` by `tasks/pve_exporter.yml:12-13`;
      nothing references the `files/` copy. It sits outside the SOPS pipeline
      and outside the `sops` hook's `\.sops\.ya?ml$` pattern. Documented in
      `secrets.md`.
- [X] **B5. Dozzle default ports diverge.** `observability_control` defaults
      to 7070 (`defaults/main.yml:16`), `observability_node` to 7007
      (`defaults/main.yml:14`). Currently masked by the group_vars re-export;
      see A3.
- [X] **B6. Duplicate Grafana dashboards.**
      `roles/observability_control/files/grafana/provisioning/dashboards/`
      holds both `media-server.json` (135 KB) and `Media Server.json`
      (50 KB). The provisioner loads both. Documented in `observability.md`
      as unresolvable from file contents alone.

### Ansible

- [X] **B7. `media_platform.yml` does not set `force_handlers`.** Both
      `observability_control.yml:5` and `observability_node.yml:5` do. A
      config change queued as a restart handler may not fire if a later task
      in the media play fails. Documented in `configuration.md`.
- [X] **B8. Live `groups:` key with an empty body.**
      `ansible/inventory/00_inv.proxmox.yml:14`, with all five rules
      commented at `:15-19`. Delete or populate. See A5.

### Terraform

- [ ] **B9. `rombar` is derived from `pcie`.**
      `workspace/modules/proxmox_vm/main.tf:82` sets
      `rombar = hostpci.value["pcie"]`. The two are independent Proxmox
      settings, so no device can be passed with `pcie = true` and
      `rombar = false`. Documented in both `provisioning.md` and
      `gpu-passthrough.md`.
- [X] **B10. Module outputs describe only the first VM.**
      `workspace/modules/proxmox_vm/outputs.tf:3,8` both index `vms[0]`, so
      `vm_count > 1` produces VMs that nothing downstream can address through
      the module. Documented in `provisioning.md` as appearing nowhere else
      in the repo.
- [X] **B11. Template lookup has no uniqueness check.**
      `workspace/modules/proxmox_vm/main.tf:19` takes
      `data.proxmox_virtual_environment_vms.templates.vms[0].vm_id`. Two VMs
      matching `["template", os_tag]` means Terraform clones whichever the API
      returns first. Documented in `provisioning.md`.
- [X] **B12. `insecure = true` and hardcoded DNS.** Every Proxmox provider
      block sets `insecure = true`
      (`infrastructure/_base/providers.tf:30,45`,
      `deployments/media/infrastructure/providers.tf:34,49`), and
      `modules/proxmox_vm/main.tf:127-129` hardcodes
      `servers = ["192.168.0.1"]` rather than exposing a variable. Both
      require a source edit, not a tfvars change. Documented in
      `provisioning.md`.

### CI and quality gates

- [ ] **B13. TFLint runs core rules only.** No `.tflint.hcl` exists; see A6.
- [ ] **B14. `terraform_docs` is enforced nowhere in CI.** The
      `terraform-docs` job is commented out at `ci.yml:125-141` because the
      action's output does not match local runs (`ci.yml:124`), and
      `terraform_docs` is in the `hooks` job's `SKIP` list
      (`ci.yml:169-181`). Generated tables can drift silently, which is how
      A9 and A10 persist. Documented in `ci-quality-gates.md` and listed on
      the root README's roadmap.
- [ ] **B15. The consolidated `pre-commit` job is commented out**
      (`ci.yml:17-54`). Listed on the root README's roadmap.

### Named roadmap items

From the root README's "Known gaps and roadmap", all still open:

- [ ] **B16. Terraform state is local.** Per `secrets.md`, decrypted SOPS
      values are written into that state unencrypted; local-and-gitignored is
      the only thing currently keeping them off a shared disk. Migrating to a
      locking backend is the prerequisite for applying from CI.
- [ ] **B17. CI is plan-only.** No `plan` output on pull requests.
- [ ] **B18. No test harness.** No Molecule scenarios for the first-party
      roles, no `terraform test` for `proxmox_vm`.
- [ ] **B19. No TLS.** Services are plain HTTP behind the LAN boundary.
- [ ] **B20. No backup or restore path** for application state or Terraform
      state.
- [ ] **B21. Role READMEs are boilerplate.** See A8 for the skeleton cause
      the roadmap entry omits.

### Questions the documentation leaves open

- [ ] **B22. Is `media_platform` group membership tag-driven or static?**
      `configuration.md` marks this "**unverified**, possibly false" because
      the answer lives in a gitignored `terraform.tfvars`. Resolvable by the
      operator in one command; the answer determines whether the README's "no
      inventory edit needed" claim holds for workload groups or only for
      observability.
- [ ] **B23. Which of the two Grafana dashboard files actually renders?**
      `observability.md` states this is not determinable from file contents.
      Resolvable by looking at the running Grafana instance. See B6.

---

## Sequencing

The two halves have different dependencies.

Part B's cheapest wins are B1, B2, B7, and B8: four small edits in
`ansible/`, none of which depend on anything else. B1 and B2 are the only
items in this audit that make a shipped component silently not work.

Part A splits at B14. A9 and A10 cannot be fixed durably while
`terraform_docs` is unenforced, because the next local hook run regenerates
whatever was hand-edited; fixing the source `.tf` descriptions and then
re-enabling the check is one unit of work, not two. A1 through A7 are edits
to this vault and depend on nothing. A8 requires deciding the skeleton
question before writing seven files. A11 requires picking a target renderer.

## Check your understanding

- [ ] How many jobs does `ci.yml` actually define, how many are commented
      out, and which document states each number correctly?
- [ ] Why does the Dozzle port defect not currently break anything, and what
      single change to a host's group membership would make it break?
- [ ] Which four templates produce invalid YAML, and what would a reader of
      `observability.md` alone conclude about how many are affected?
- [ ] Why can't A9 and A10 be fixed by editing the README files directly?
- [ ] What is the causal relationship between
      `ansible/template_role/README.md.j2` and the seven identical role
      READMEs? What does fixing only the seven leave unfixed?
- [ ] Which two findings in Part B mean a component in this repo does not
      function as documented, as opposed to functioning with a known
      constraint?
