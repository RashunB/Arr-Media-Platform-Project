---
type: comparison
tags: [comparison, reverse-proxy, networking, future]
---

# Caddy vs Traefik — Reverse Proxy Decision

A reverse proxy is required before any external exposure of Grafana, Prometheus, or Loki.
This note captures the tradeoffs as of the homelab's current phase.

## Side-by-Side

| Feature | Caddy | Traefik |
|---------|-------|---------|
| TLS (Let's Encrypt) | Automatic, zero config | Requires certResolver config |
| Config format | Simple Caddyfile or JSON | YAML/TOML with provider discovery |
| Docker integration | Manual in Caddyfile | Native label-based autodiscovery |
| Dashboard | None (by design) | Built-in web UI |
| Homelab complexity | Low | Medium |
| Learning curve | Low | Medium-high |
| Authentication | Forward auth or basic auth modules | Middleware system |
| HTTP/3 | Yes | Yes |

## Recommendation for This Stack

**Caddy** for homelab scale. Reasons:
- Single Caddyfile to manage all services on control host
- Automatic TLS handling is simpler when managing DNS manually
- No need for label-based autodiscovery with a small, fixed service set
- Community is large and homelab documentation is plentiful

Traefik makes more sense if: the service count grows to 10+ and per-service label-based routing
would save significant maintenance, or if Kubernetes is introduced.

## Implementation Path

When adding Caddy to the control compose stack:

```yaml
# In docker-compose.yml.j2 (control)
caddy:
  image: caddy:latest
  ports:
    - "80:80"
    - "443:443"
  volumes:
    - /opt/caddy/Caddyfile:/etc/caddy/Caddyfile:ro
    - caddy_data:/data
    - caddy_config:/config
```

Sample Caddyfile for Grafana:

```
grafana.homelab.local {
  reverse_proxy grafana:3000
  basicauth {
    user $2a$14$<bcrypt-hash>
  }
}
```

## Status

Not yet implemented. Tracked as near-term roadmap item in [[synthesis/roadmap]].