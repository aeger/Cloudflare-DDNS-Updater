# Cloudflare DDNS Updater (Rootless Podman)

A tiny container that keeps Cloudflare DNS records pointed at your **current public IP**.

It’s designed for a **rootless Podman** host (like your `svc-docker-01` lab VM), and it updates multiple records (ex: `hello`, root `@`, and `*`) on a loop.

Repo: `aeger/Cloudflare-DDNS-Updater` citeturn2view0

---

## What it updates

Given a zone (example: `az-lab.dev`) and a list of record names, it will ensure **A records** exist and match your current public IPv4:

- `hello.az-lab.dev`
- `az-lab.dev` (zone apex / `@`)
- `*.az-lab.dev` citeturn2view0

> Note: this repo updates **A records**. If you want IPv6 too, you’ll need AAAA support (easy add later).

---

## Requirements

On Ubuntu (24.04+ recommended):

```bash
sudo apt update
sudo apt install -y podman uidmap slirp4netns fuse-overlayfs jq curl bash
loginctl enable-linger "$USER"
```

That last line is the “make rootless stuff start after reboots” switch humans forget and then blame computers for. citeturn2view0

---

## Cloudflare API token

Create a Cloudflare API token scoped to **only what you need**:

**Permissions (minimum):**
- Zone → DNS → Edit
- Zone → Zone → Read (recommended; helps zone lookup)

Scope it to your zone (example: `az-lab.dev`). citeturn2view0

---

## Install

### 1) Clone

```bash
git clone https://github.com/aeger/Cloudflare-DDNS-Updater.git
cd Cloudflare-DDNS-Updater
```

### 2) Create your env file

Copy the example:

```bash
cp cf-ddns.env.example cf-ddns.env
chmod 600 cf-ddns.env
```

Edit `cf-ddns.env` and set:

- `CF_API_TOKEN` (your token)
- `CF_ZONE_NAME` (example: `az-lab.dev`)
- `CF_RECORD_NAMES` (comma-separated list)
- Optional knobs: `PROXIED`, `TTL`, `INTERVAL_SECONDS`

Example:

```env
CF_API_TOKEN=REDACTED
CF_ZONE_NAME=az-lab.dev
CF_RECORD_NAMES=hello.az-lab.dev,az-lab.dev,*.az-lab.dev
PROXIED=true
TTL=120
INTERVAL_SECONDS=300
```

---

## Build & run (rootless Podman)

### Build

This repo uses a `Containerfile` (Podman-friendly).

```bash
podman build -t localhost/cf-ddns:latest -f Containerfile .
```

### Run

```bash
podman rm -f cf-ddns 2>/dev/null || true

podman run -d \
  --name cf-ddns \
  --restart=unless-stopped \
  --env-file "$PWD/cf-ddns.env" \
  localhost/cf-ddns:latest
```

### Watch logs

```bash
podman logs -f cf-ddns
```

You should see it discover your zone ID, your public IP, and then create/update records. citeturn2view0

---

## Verify in Cloudflare

Quick sanity check using the Cloudflare API (optional):

```bash
# list DNS records for the zone (example, tweak if you want filtering)
curl -sS -H "Authorization: Bearer $CF_API_TOKEN" \
  "https://api.cloudflare.com/client/v4/zones?name=$CF_ZONE_NAME&status=active" | jq
```

Or just check in the Cloudflare dashboard: you should see A records for each name pointing at your WAN IP. citeturn2view0

---

## Autostart on boot (rootless)

If you already ran:

```bash
loginctl enable-linger "$USER"
```

…and you used `--restart=unless-stopped`, Podman will bring the container back after reboot. citeturn2view0

To verify:

```bash
sudo reboot
# after reboot
podman ps
podman logs cf-ddns | tail -n 50
```

### Want “real” systemd management? (optional)

If you prefer systemd user services, you can generate one:

```bash
podman generate systemd --new --name cf-ddns --files --user
mkdir -p ~/.config/systemd/user
mv container-cf-ddns.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now container-cf-ddns.service
```

(Still keep lingering enabled if the box is headless.)

---

## Security notes

- **Do not commit** `cf-ddns.env` (contains your token).
- Keep the token scoped to a single zone.
- If you enable Cloudflare proxying (`PROXIED=true`) on a wildcard, you’re proxying *everything* under `*.yourdomain`. That might be exactly what you want, or it might be a surprise later. citeturn2view0

---

## Troubleshooting

### “Zone could not be found”
- Token missing Zone:Read, or zone name mismatch.
- Make sure `CF_ZONE_NAME` is exactly the zone in Cloudflare. citeturn2view0

### Container runs but doesn’t restart after reboot
- Most common cause: lingering not enabled for the user that owns the container. citeturn2view0

### Nothing changes even though your ISP IP changed
- Check `INTERVAL_SECONDS`
- Make sure your “public IP” endpoint is reachable
- Confirm your WAN IP via a separate check:

```bash
curl -sS https://api.ipify.org && echo
```

(The script in this repo uses ipify by default.) citeturn2view0

---

## Repo hygiene checklist

Already good:
- `Containerfile`
- `cf-ddns.sh`
- `cf-ddns.env.example`
- `.gitignore` present citeturn2view0

Suggested tweaks:
- Add a short `CHANGELOG.md` (even if it’s just dates + bullets).
- Add a `LICENSE` file (unless you want “all rights reserved by default” energy).
- Consider a GitHub Action for shellcheck (optional but nice).

---

## Why this exists

Because home internet connections are fickle, and humans prefer blaming routers instead of accepting the concept of “dynamic.”

