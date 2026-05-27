---
type: runbook
tags: [operations, runbook, docker, observability]
---

# Runbook: Observability Stack

Operational procedures for the Docker Compose observability stack on `control` (192.168.0.60). All `docker compose` commands run from `/opt/docker/observability/`.

---

## Stack-wide Operations

### Restart entire stack

```bash
cd /opt/docker/observability
docker compose restart
```

Wait ~30 seconds, then verify:

```bash
docker compose ps
# All services should show "running (healthy)" or "running"
```

### Pull latest images and recreate (after version bump)

```bash
cd /opt/docker/observability
docker compose pull
docker compose up -d
```

### View live logs for all services

```bash
docker compose logs -f
```

### View logs for one service

```bash
docker compose logs -f prometheus
docker compose logs -f grafana
docker compose logs -f loki
docker compose logs -f alloy
```

### Re-run Ansible to apply config changes

From the control machine's repo root:

```bash
cd /baucumlabs/ansible
ansible-playbook playbooks/observability_control.yml \
  --vault-id pve@playbooks/vault/pve.vault.txt
```

---

## Service-specific Runbooks

### Prometheus down {#prometheus-down}

**Symptoms:** `up{job="prometheus"} == 0` alert fires; Grafana shows "No data" on all panels.

**Step 1 — check container state:**

```bash
docker compose ps prometheus
docker compose logs prometheus --tail=50
```

**Step 2 — common causes:**

| Log pattern | Cause | Fix |
|-------------|-------|-----|
| `opening storage failed` | Data dir permissions | `chown -R 65534:65534 /opt/prometheus/data` |
| `error parsing config` | Bad prometheus.yml | Fix template, re-run playbook |
| `address already in use` | Port 9090 conflict | `ss -tlnp | grep 9090` to find conflicting process |

**Step 3 — restart:**

```bash
docker compose restart prometheus
```

**Step 4 — verify:**

```bash
curl -s http://localhost:9090/-/ready && echo "OK"
# Then check: http://192.168.0.60:9090/targets — all targets should be UP
```

---

### Grafana down {#grafana-down}

**Symptoms:** `up{job="grafana"} == 0`; can't reach `:3000`.

**Step 1:**

```bash
docker compose logs grafana --tail=50
```

**Step 2 — common causes:**

| Log pattern | Cause | Fix |
|-------------|-------|-----|
| `Failed to connect to database` | SQLite locked | Restart container |
| `listen tcp :3000: bind: address already in use` | Port conflict | `ss -tlnp | grep 3000` |
| `permission denied` on `/var/lib/grafana` | Volume ownership | `chown -R 472:472 /opt/grafana` |

**Step 3:**

```bash
docker compose restart grafana
curl -s http://localhost:3000/api/health | grep '"database": "ok"'
```

---

### Loki not receiving logs {#loki-down}

**Symptoms:** Grafana Explore shows no log results; Alloy logs show push errors.

**Step 1 — check Loki:**

```bash
docker compose logs loki --tail=50
curl -s http://localhost:3100/ready
```

**Step 2 — check Alloy is pushing:**

```bash
docker compose logs alloy --tail=50
# Look for: "component started" and no "connection refused" to loki:3100
```

**Step 3 — verify push target:**

Alloy's config must point to `http://loki:3100/loki/api/v1/push` (internal Docker network name). If Alloy is on a node VM, it uses `http://192.168.0.60:3100/loki/api/v1/push`.

**Step 4 — restart Loki, then Alloy:**

```bash
docker compose restart loki
docker compose restart alloy
```

---

### Alloy agent not collecting metrics/logs

**Symptoms:** Some scrape targets disappear from Prometheus; logs stop arriving.

**Step 1:**

```bash
docker compose logs alloy --tail=50
```

**Step 2 — check Alloy UI** (if enabled):

```
http://192.168.0.60:12345
```

This shows component health and pipeline status.

**Step 3 — config reload:**

Alloy supports live reload:

```bash
curl -X POST http://localhost:12345/-/reload
```

**Step 4 — restart if reload fails:**

```bash
docker compose restart alloy
```

---

### Roll back a bad config change

If a config push broke something:

```bash
# See recent ansible runs that changed configs
git -C /baucumlabs log --oneline ansible/playbooks/templates/ | head -10

# Check what changed
git -C /baucumlabs show HEAD:ansible/playbooks/templates/control/observability/prometheus.yml.j2

# Roll back via git
git -C /baucumlabs checkout HEAD~1 -- ansible/playbooks/templates/control/observability/prometheus.yml.j2

# Re-run playbook to deploy reverted config
cd /baucumlabs/ansible
ansible-playbook playbooks/observability_control.yml \
  --vault-id pve@playbooks/vault/pve.vault.txt
```

---

### Disk full on control

**Symptoms:** Prometheus TSDB write errors; Docker containers failing to write logs.

**Step 1 — find what's large:**

```bash
du -sh /opt/prometheus/data
du -sh /opt/loki/data
docker system df
```

**Step 2 — Prometheus retention:**

Prometheus retains 15 days by default. If data dir is growing too fast, set `--storage.tsdb.retention.time=7d` in the compose command.

**Step 3 — Loki retention:**

Loki retention is configured in `loki-config.yml`. Default compactor retention varies by config.

**Step 4 — prune Docker:**

```bash
docker system prune -f
# Remove unused images only
docker image prune -f
```

---

## Health Check Commands

Quick one-liners to verify each service:

```bash
# All at once
curl -sf http://localhost:9090/-/ready && echo "Prometheus OK"
curl -sf http://localhost:3000/api/health && echo "Grafana OK"
curl -sf http://localhost:3100/ready && echo "Loki OK"
curl -sf http://localhost:12345/-/ready && echo "Alloy OK"

# Check Prometheus targets (should show all UP)
curl -s http://localhost:9090/api/v1/targets | python3 -m json.tool | grep '"health"'
```

---

## Related

- [[homelab-slos]] — SLO targets and alerting rules that trigger these runbooks
- [[golden-signals]] — PromQL queries to diagnose the above scenarios
- [[prometheus]] — Prometheus service entity and configuration details
- [[alloy]] — Alloy service entity
