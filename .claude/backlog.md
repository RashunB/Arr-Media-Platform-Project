# Homelab-Platform backlog

Deferred until prod prep in `.claude/worklog.md` is done. An item moves into the worklog, with a done condition, when its phase starts.

## Media platform Grafana dashboard

`ansible/roles/observability_control/files/grafana/provisioning/dashboards/` holds `container.json`, `server.json`, `storage.json` and `thermals.json`. None covers the media platform. Add one for the *arr stack and Jellyfin.

## TLS and safe external access

`proxmox_insecure` defaults to `true` in `terraform/infrastructure/_base/variables.tf` and `terraform/deployments/media/infrastructure/variables.tf`, and every service serves plain HTTP. Add TLS on the LAN (reverse proxy with DNS-01 or internal-CA certificates), then external access through Cloudflare Tunnel or Tailscale with an access layer in front. No port forwards.
