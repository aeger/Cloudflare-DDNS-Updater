# Host rename note: svc-docker-01 → svc-podman-01

The homelab VM previously known as `svc-docker-01` has been renamed to `svc-podman-01` (2026-01-13).

This DDNS updater container should be unaffected by the hostname change **unless** you:
- reference the old hostname in documentation, scripts, inventories, or monitoring labels
- tie the updater configuration to a host-specific name (uncommon)

## Quick check
```bash
podman ps
podman logs --tail 200 cf-ddns
```
