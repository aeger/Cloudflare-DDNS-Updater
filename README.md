# Cloudflare DDNS Updater (Rootless Podman)

A tiny container that keeps Cloudflare DNS records pointed at your **current public IP**.

Designed for **rootless Podman** on a headless server. It updates multiple DNS records (for example: `hello`, zone apex `@`, and `*`) on a configurable interval.

---

## What it updates

Given a zone (example: `az-lab.dev`) and a list of record names, this container ensures **A records** exist and match your current public IPv4:

- `hello.az-lab.dev`
- `az-lab.dev` (zone apex / `@`)
- `*.az-lab.dev`

> Note: This project updates **A records only**. IPv6 (AAAA) support would be a straightforward extension if needed.

---

## Requirements

Ubuntu 24.04+ (or similar) with rootless Podman:

```bash
sudo apt update
sudo apt install -y podman uidmap slirp4netns fuse-overlayfs jq curl bash
loginctl enable-linger "$USER"
```

That last command allows rootless containers to start on boot, even on headless systems.

---

## Cloudflare API token

Create a Cloudflare API token with **minimum required permissions**:

**Permissions**
- Zone → DNS → Edit
- Zone → Zone → Read (recommended, simplifies zone lookup)

Scope the token to your specific zone (for example: `az-lab.dev`).

---

## Installation

### 1. Clone the repo

```bash
git clone https://github.com/aeger/Cloudflare-DDNS-Updater.git
cd Cloudflare-DDNS-Updater
```

### 2. Create your environment file

```bash
cp cf-ddns.env.example cf-ddns.env
chmod 600 cf-ddns.env
```

Edit `cf-ddns.env`:

```env
CF_API_TOKEN=REDACTED
CF_ZONE_NAME=az-lab.dev
CF_RECORD_NAMES=hello.az-lab.dev,az-lab.dev,*.az-lab.dev
PROXIED=true
TTL=120
INTERVAL_SECONDS=300
```

---

## Build and run (rootless Podman)

### Build the image

```bash
podman build -t localhost/cf-ddns:latest -f Containerfile .
```

### Run the container

```bash
podman rm -f cf-ddns 2>/dev/null || true

podman run -d   --name cf-ddns   --restart=unless-stopped   --env-file "$PWD/cf-ddns.env"   localhost/cf-ddns:latest
```

### View logs

```bash
podman logs -f cf-ddns
```

You should see the public IP detected and DNS records created or updated.

---

## Autostart on boot

If you enabled lingering and used `--restart=unless-stopped`, the container will automatically restart after a reboot.

Verify:

```bash
sudo reboot
# after reboot
podman ps
podman logs cf-ddns | tail -n 50
```

### Optional: systemd user service

For tighter systemd integration:

```bash
podman generate systemd --new --name cf-ddns --files --user
mkdir -p ~/.config/systemd/user
mv container-cf-ddns.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now container-cf-ddns.service
```

---

## Security notes

- **Never commit** `cf-ddns.env` (it contains your API token).
- Scope API tokens to a single zone.
- Proxying wildcard records (`*.example.com`) means *everything* under that zone is proxied through Cloudflare.

---

## Troubleshooting

### Zone not found
- Token missing Zone:Read permission
- `CF_ZONE_NAME` does not exactly match the Cloudflare zone

### Container does not restart after reboot
- `loginctl enable-linger` not enabled for the container owner

### IP never updates
- Verify your WAN IP manually:
```bash
curl -s https://api.ipify.org && echo
```

---

## License

MIT (see LICENSE file)
