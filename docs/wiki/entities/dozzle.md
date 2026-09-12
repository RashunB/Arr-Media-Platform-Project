---
type: service
name: Dozzle
port: 8080
host: "[[control]]"
image: amir20/dozzle:latest
status: deployed
tags: [service, logs, docker, log-viewer]
---

# Dozzle — :8080

Real-time Docker container log viewer. Runs in "hub + agent" mode: the main Dozzle instance on
[[control]] connects to agent processes on [[pve]] and [[monitoring-1]] to show logs from all hosts.

## Instances

| Host | Mode | Port |
|------|------|------|
| [[control]] | Hub (main UI) | 8080 |
| [[pve]] | Agent | 7007 |
| [[monitoring-1]] | Agent | 7007 |

## Configuration

- **Env file:** `/opt/dozzle/dozzle.env`
- **Template:** `ansible/playbooks/templates/control/observability/dozzle.env.j2`

## Open Issues

- `dozzle.env.j2` only lists the PVE agent IP; `monitoring-1` agent is invisible to the hub.
  Fix: template the agent list from inventory groups.

## Notes

Env path fixed in Phase 2 (B5): was pointing to wrong directory, now correctly deploys to
`/opt/dozzle/dozzle.env`.
