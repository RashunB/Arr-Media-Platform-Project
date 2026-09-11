---
type: concept
tags: [concept, devops, security, docker, containers]
---

# Image Versioning Strategy

> [!warning] Open Issue S3
> The current `docker-compose.yml.j2` uses `:latest` tags for all services. This is a known security and reproducibility gap. Phase 3 remediation: pin all images to semver digests.

## The Problem with `:latest`

- **Non-reproducible**: `docker pull prometheus:latest` today ≠ `docker pull prometheus:latest` in 3 months.
- **Silent breaking changes**: A major-version bump in Grafana or Loki can break dashboards or push format on the next `docker compose pull`.
- **No audit trail**: `git log` cannot tell you what version of Prometheus was running on a given date.

---

## Pinning Strategy

### Semver tag pinning (minimum viable)

Pin to the minor version. Accept patch updates but control minor/major manually.

```yaml
# In docker-compose.yml.j2 (via group_vars variable)
services:
  prometheus:
    image: prom/prometheus:{{ prometheus_version }}
  grafana:
    image: grafana/grafana:{{ grafana_version }}
  loki:
    image: grafana/loki:{{ loki_version }}
  alloy:
    image: grafana/alloy:{{ alloy_version }}
```

In `group_vars/observability_control/vars.yml`:

```yaml
prometheus_version: "v2.53.2"
grafana_version: "11.3.0"
loki_version: "3.2.1"
alloy_version: "v1.4.2"
node_exporter_version: "v1.8.2"
cadvisor_version: "v0.49.1"
smartctl_exporter_version: "v0.12.0"
dozzle_version: "v8.8.3"
pve_exporter_version: "v3.3.0"
```

### Digest pinning (hardened)

For production or security-sensitive contexts, pin to the image digest. This is immutable — the image can never change under you.

```yaml
image: prom/prometheus@sha256:b7c8e...
```

For a homelab stack, **semver pinning is the right tradeoff** — easier to read, easier to bump intentionally, still reproducible.

---

## Update Workflow

Manual bump cadence (homelab, no CI/CD):

1. Check upstream release pages for each service
2. Test in `--check` mode: `ansible-playbook playbooks/observability_control.yml --check`
3. Update version variable in group_vars
4. Run playbook — Compose will pull new image and recreate container
5. Verify health: check Grafana dashboards for 5 minutes post-deploy
6. Commit version bump with message: `chore: bump prometheus v2.53.1 → v2.53.2`

---

## Automated Updates (Future)

Once a git remote is set up, Renovate Bot can automate version PRs.

`.renovaterc.json`:

```json
{
  "$schema": "https://docs.renovateapp.com/renovate-schema.json",
  "extends": ["config:base"],
  "ansible": {
    "enabled": true
  },
  "packageRules": [
    {
      "matchPackageNames": ["prom/prometheus", "grafana/grafana", "grafana/loki", "grafana/alloy"],
      "groupName": "observability stack",
      "automerge": false
    }
  ]
}
```

This opens PRs for version bumps but requires manual merge — appropriate for a homelab stack where you want to vet changes.

---

## Image Pull Policy

In the current compose template, images are pulled as `pull_policy: missing` (Ansible default). This means:

- New deploys pull the image if not cached locally
- Re-runs do NOT pull if image is already present
- To force a pull after bumping a version variable: `docker compose pull` before running the playbook, or add `pull_policy: always` to the Ansible task temporarily

---

## Related

- [[adr-001-docker-compose]] — why Docker Compose over Kubernetes
- [[security-posture]] — S3 is one of the must-fix items before external exposure
- [[roadmap]] — Phase 3 includes image pinning
