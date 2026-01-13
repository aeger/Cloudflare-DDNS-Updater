Cloudflare DDNS Updater (Rootless Podman) – Reproducible Setup
0) What this does

Updates these DNS records in your Cloudflare zone to your current public IP:

hello.az-lab.dev

az-lab.dev (root / @)

*.az-lab.dev

Runs in a rootless Podman container on a schedule (loop + sleep).

1) Prereqs (same as Traefik host)
sudo apt update
sudo apt install -y podman uidmap slirp4netns fuse-overlayfs
loginctl enable-linger $USER

2) Directory layout
mkdir -p ~/cf-ddns
cd ~/cf-ddns


Suggested repo layout later:

cf-ddns/
├── Containerfile (or Dockerfile)
├── cf-ddns.sh
├── cf-ddns.env.example
└── README.md

3) Cloudflare API token (DDNS)

Create a token in Cloudflare with:

Zone → DNS → Edit

Zone → Zone → Read (recommended, helps zone lookup)

Scope to zone: az-lab.dev

4) Env file (do NOT commit the real one)

Create: ~/cf-ddns/cf-ddns.env

CF_API_TOKEN=REDACTED
CF_ZONE_NAME=az-lab.dev
CF_RECORD_NAMES=hello.az-lab.dev,az-lab.dev,*.az-lab.dev
PROXIED=true
TTL=120
INTERVAL_SECONDS=300


Lock permissions:

chmod 600 ~/cf-ddns/cf-ddns.env

5) Containerfile / Dockerfile

Use one name consistently. Podman likes Containerfile or Dockerfile. You already got bitten by DockerFile. Humans and capitalization, man.

Create ~/cf-ddns/Containerfile:

FROM alpine:3.20

RUN apk add --no-cache curl jq bash ca-certificates

COPY cf-ddns.sh /usr/local/bin/cf-ddns.sh
RUN chmod +x /usr/local/bin/cf-ddns.sh

ENTRYPOINT ["/usr/local/bin/cf-ddns.sh"]

6) The updater script

Create ~/cf-ddns/cf-ddns.sh:

#!/usr/bin/env bash
set -euo pipefail

# Required env vars
: "${CF_API_TOKEN:?Missing CF_API_TOKEN}"
: "${CF_ZONE_NAME:?Missing CF_ZONE_NAME}"
: "${CF_RECORD_NAMES:?Missing CF_RECORD_NAMES}"

# Optional
PROXIED="${PROXIED:-true}"
TTL="${TTL:-120}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-300}"

api="https://api.cloudflare.com/client/v4"

cf() {
  curl -fsS \
    -H "Authorization: Bearer ${CF_API_TOKEN}" \
    -H "Content-Type: application/json" \
    "$@"
}

get_public_ip() {
  # simple + reliable
  curl -fsS https://api.ipify.org
}

get_zone_id() {
  cf "${api}/zones?name=${CF_ZONE_NAME}&status=active" | jq -r '.result[0].id'
}

ensure_record() {
  local zone_id="$1"
  local name="$2"
  local ip="$3"

  # Lookup existing record (A only)
  local rec
  rec="$(cf "${api}/zones/${zone_id}/dns_records?type=A&name=${name}" | jq -r '.result[0].id // empty')"

  if [[ -z "${rec}" ]]; then
    echo "Creating A record: ${name} -> ${ip}"
    cf -X POST "${api}/zones/${zone_id}/dns_records" \
      --data "{\"type\":\"A\",\"name\":\"${name}\",\"content\":\"${ip}\",\"ttl\":${TTL},\"proxied\":${PROXIED}}" \
      >/dev/null
  else
    # Update only if changed
    local cur
    cur="$(cf "${api}/zones/${zone_id}/dns_records/${rec}" | jq -r '.result.content')"
    if [[ "${cur}" != "${ip}" ]]; then
      echo "Updating A record: ${name} ${cur} -> ${ip}"
      cf -X PUT "${api}/zones/${zone_id}/dns_records/${rec}" \
        --data "{\"type\":\"A\",\"name\":\"${name}\",\"content\":\"${ip}\",\"ttl\":${TTL},\"proxied\":${PROXIED}}" \
        >/dev/null
    else
      echo "No change: ${name} -> ${ip}"
    fi
  fi
}

main() {
  local zone_id
  zone_id="$(get_zone_id)"
  if [[ -z "${zone_id}" || "${zone_id}" == "null" ]]; then
    echo "ERROR: Could not find zone id for ${CF_ZONE_NAME}"
    exit 1
  fi

  echo "Cloudflare DDNS starting for zone ${CF_ZONE_NAME} (${zone_id})"
  echo "Records: ${CF_RECORD_NAMES}"
  echo "Interval: ${INTERVAL_SECONDS}s  TTL: ${TTL}  Proxied: ${PROXIED}"

  while true; do
    ip="$(get_public_ip)"
    echo "Public IP: ${ip}"

    IFS=',' read -ra names <<< "${CF_RECORD_NAMES}"
    for n in "${names[@]}"; do
      n="$(echo "$n" | xargs)"  # trim
      [[ -z "${n}" ]] && continue
      ensure_record "${zone_id}" "${n}" "${ip}"
    done

    sleep "${INTERVAL_SECONDS}"
  done
}

main "$@"


Make executable:

chmod +x ~/cf-ddns/cf-ddns.sh

7) Build and run (rootless)

Build:

cd ~/cf-ddns
podman build -t cf-ddns:latest -f Containerfile .


Run:

podman rm -f cf-ddns 2>/dev/null || true
podman run -d \
  --name cf-ddns \
  --restart=unless-stopped \
  --env-file "$HOME/cf-ddns/cf-ddns.env" \
  cf-ddns:latest


Check logs:

podman logs -f cf-ddns

8) Auto-start on reboot (headless)

You already did the correct model:

--restart=unless-stopped

loginctl enable-linger $USER

Verify by rebooting:

sudo reboot
# after reboot
podman ps
podman logs cf-ddns | tail -n 50


If it doesn’t come up, 99% of the time lingering wasn’t enabled for the user that owns the container.

9) Optional: make it more “infra-grade”
A) Separate image tag
podman build -t localhost/cf-ddns:$(date +%F) -f Containerfile .

B) Pin the public IP endpoint

If you hate depending on one service, add a fallback:

ipify, ifconfig.me, Cloudflare trace, etc.

C) Don’t proxy wildcard

Cloudflare can proxy wildcard records, but you might not want everything under *.az-lab.dev proxied. You can split records and set proxied per record if needed.

GitHub repo?

Same answer as Traefik: yes, and preferably private.

Include:

Containerfile

cf-ddns.sh

cf-ddns.env.example

README.md

Exclude:

real cf-ddns.env (token)

anything with your real secrets

Add a .gitignore:

cf-ddns.env
*.env
secrets/