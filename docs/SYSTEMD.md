# systemd (user) service for Cloudflare DDNS Updater (rootless Podman)

This adds a reproducible systemd **user** unit for the `cf-ddns` container on rootless Podman.

## Files you must provide on the host
- `~/cf-ddns/cf-ddns.env` (token, zone, records, interval, etc.)

## Image
This unit references your current workflow image: `localhost/cf-ddns:latest`.
- If you later publish to GHCR/Docker Hub, change the image in `systemd/cf-ddns.service`.

## Install
```bash
make install
```

## Verify
```bash
make status
make ps
make logs
```

## Why “linger”
The install enables `loginctl enable-linger $USER` so the user service starts at boot even when nobody logs in.
