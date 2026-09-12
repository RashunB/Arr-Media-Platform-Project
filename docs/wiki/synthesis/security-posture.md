---
type: security
tags: [synthesis, security]
---

# Security Posture

Current security state of the homelab stack. All services are LAN-only (192.168.0.x).

---

## Must Resolve Before External Exposure

These are non-negotiable gates. The reverse proxy (Caddy or Traefik) does not go live until all
four are addressed.

| Finding | Risk |
|---------|------|
| **S1** — Prometheus `--web.enable-admin-api` + `--web.enable-lifecycle` unauthenticated | Any LAN host can trigger snapshots, delete series, or reload config |
| **S4** — Grafana default `admin/admin` credentials unset | First user to reach the UI can claim admin |
| **S5** — Loki port 3100 unauthenticated, bound to `0.0.0.0` | Any LAN host can read all aggregated logs |
| **S13** — No reverse proxy / TLS termination | All services exposed direct; no edge auth, no encryption |

---

## Accepted Risks — LAN-Only Operation

These are known, documented, and acceptable while services remain non-routable.

| Finding | Accepted Because |
|---------|-----------------|
| **S7** — `host_key_checking = false` in `ansible.cfg` | LAN-only, RFC1918 IPs, private repository |
| **S9** — Prometheus scrape endpoints on unauthenticated HTTP | Internal monitoring; no external exposure |
| **S11** — RFC1918 IPs committed to git | Non-routable addresses; private repo; no security boundary crossed |

---

## Fixed This Milestone

| Finding | Fix |
|---------|-----|
| **S14 / CR-8** | PVE credential file `mode: 0644` → `0600` |
| **S2** | `pve-exporter` unnecessary `docker.sock` mount removed |
| **S8** | Proxmox API calls use scoped API token instead of `root@pam`; `validate_certs` addressed |

---

## Pre-Exposure Checklist

Before adding the reverse proxy and making any service reachable outside the LAN:

- [ ] Prometheus admin API disabled or moved behind auth
- [ ] Grafana admin password set via Ansible (not default)
- [ ] Loki protected by reverse proxy auth (basic auth or forward auth)
- [ ] Caddy/Traefik added to control compose with TLS
- [ ] `validate_certs` policy reviewed for PVE API calls
- [ ] Review all service port bindings — close anything not needed externally

---

## Secret Scanning

> [!warning] Open Gap
> No secret scanning is currently configured. The vault password files (`*.vault.txt`) are gitignored but no tooling actively prevents accidental secret commits.

### Pre-commit hook (detect-secrets)

Install in the repo root:

```yaml
# .pre-commit-config.yaml
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ["--baseline", ".secrets.baseline"]
        exclude: "ansible/playbooks/vault/.*\\.yml"
```

Initialize baseline (scans current state so known secrets aren't flagged repeatedly):

```bash
pip install pre-commit detect-secrets
detect-secrets scan > .secrets.baseline
pre-commit install
```

After setup, `git commit` will fail if new secrets are introduced.

### gitleaks (CI gate)

When a GitHub remote is configured, add to `.github/workflows/security.yml`:

```yaml
name: Secret Scan
on: [push, pull_request]
jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

---

## Container Image Hygiene

> [!warning] Open Issue S3
> All compose services currently use `:latest` tags. See [[image-versioning]] for the pinning strategy.

### Image scanning (Trivy)

Scan images for CVEs before deploying a version bump:

```bash
# Scan a specific image version before updating group_vars
docker run --rm aquasec/trivy image prom/prometheus:v2.53.2

# Scan all running containers
docker ps -q | xargs -I{} docker inspect --format='{{.Config.Image}}' {} | \
  sort -u | xargs -I{} docker run --rm aquasec/trivy image {}
```

### Compose resource limits

No services currently have CPU/memory limits set (CR-11). Without limits, a runaway Prometheus or Loki can OOM the host. See [[golden-signals#resource-limits-baseline]] for recommended values.

---

## Ansible Vault Hygiene

- Vault password files (`*.vault.txt`) are listed in `.gitignore` — **never remove these entries**
- PVE credential file must be deployed with `mode: "0600"` (S14 — fixed this milestone)
- Run `git status` before every commit and verify no `*.vault.txt` or decrypted credential files are staged
- All new secrets: encrypt with `ansible-vault encrypt_string` before adding to playbooks or group_vars
