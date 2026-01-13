#!/usr/bin/env bash
set -euo pipefail

: "${CF_API_TOKEN:?set CF_API_TOKEN}"
: "${CF_ZONE_NAME:?set CF_ZONE_NAME}"
: "${CF_RECORD_NAMES:?set CF_RECORD_NAMES (comma-separated)}"

CF_API="https://api.cloudflare.com/client/v4"
AUTH=(-H "Authorization: Bearer ${CF_API_TOKEN}" -H "Content-Type: application/json")

INTERVAL_SECONDS="${INTERVAL_SECONDS:-300}"
TTL="${TTL:-120}"
PROXIED="${PROXIED:-true}"

# Get public IPv4 (try a couple sources)
get_public_ip() {
  local ip
  ip="$(curl -fsS https://ipv4.icanhazip.com 2>/dev/null | tr -d '\n' || true)"
  if [[ -z "${ip}" ]]; then
    ip="$(curl -fsS https://api.ipify.org 2>/dev/null | tr -d '\n' || true)"
  fi
  [[ "${ip}" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  echo "${ip}"
}

get_zone_id() {
  curl -fsS "${CF_API}/zones?name=${CF_ZONE_NAME}&status=active" "${AUTH[@]}" \
    | jq -r '.result[0].id // empty'
}

# Fetch record (returns JSON object or empty)
get_record() {
  local zone_id="$1" name="$2"
  curl -fsS "${CF_API}/zones/${zone_id}/dns_records?type=A&name=${name}" "${AUTH[@]}" \
    | jq -c '.result[0] // empty'
}

create_record() {
  local zone_id="$1" name="$2" ip="$3"
  local resp
  resp="$(curl -fsS -X POST "${CF_API}/zones/${zone_id}/dns_records" "${AUTH[@]}" \
    --data "{
      \"type\":\"A\",
      \"name\":\"${name}\",
      \"content\":\"${ip}\",
      \"ttl\":${TTL},
      \"proxied\":${PROXIED}
    }" || true)"

  if [[ -z "${resp}" ]] || [[ "$(echo "$resp" | jq -r '.success')" != "true" ]]; then
    echo "ERROR creating ${name}: ${resp}" >&2
    return 1
  fi
}

update_record() {
  local zone_id="$1" record_id="$2" name="$3" ip="$4"
  local resp
  resp="$(curl -fsS -X PUT "${CF_API}/zones/${zone_id}/dns_records/${record_id}" "${AUTH[@]}" \
    --data "{
      \"type\":\"A\",
      \"name\":\"${name}\",
      \"content\":\"${ip}\",
      \"ttl\":${TTL},
      \"proxied\":${PROXIED}
    }" || true)"

  if [[ -z "${resp}" ]] || [[ "$(echo "$resp" | jq -r '.success')" != "true" ]]; then
    echo "ERROR updating ${name}: ${resp}" >&2
    return 1
  fi
}

# Normalize record list (comma-separated -> lines)
IFS=',' read -r -a RECORDS <<< "${CF_RECORD_NAMES}"

ZONE_ID="$(get_zone_id)"
if [[ -z "${ZONE_ID}" ]]; then
  echo "ERROR: Could not find active zone: ${CF_ZONE_NAME}" >&2
  exit 1
fi

echo "Cloudflare DDNS starting for zone ${CF_ZONE_NAME} (${ZONE_ID})"
echo "Records: ${CF_RECORD_NAMES}"
echo "Interval: ${INTERVAL_SECONDS}s  TTL: ${TTL}  Proxied: ${PROXIED}"

last_ip=""

while true; do
  ip="$(get_public_ip || true)"
  if [[ -z "${ip}" ]]; then
    echo "WARN: Could not determine public IPv4. Retrying in ${INTERVAL_SECONDS}s." >&2
    sleep "${INTERVAL_SECONDS}"
    continue
  fi

  if [[ "${ip}" != "${last_ip}" ]]; then
    echo "Public IP: ${ip}"
    last_ip="${ip}"
  fi

  for name in "${RECORDS[@]}"; do
    name="$(echo "${name}" | xargs)" # trim whitespace
    [[ -z "${name}" ]] && continue

    rec="$(get_record "${ZONE_ID}" "${name}" || true)"

    if [[ -z "${rec}" ]]; then
      echo "Creating A record: ${name} -> ${ip}"
      create_record "${ZONE_ID}" "${name}" "${ip}"
      continue
    fi

    rec_id="$(echo "${rec}" | jq -r '.id')"
    rec_ip="$(echo "${rec}" | jq -r '.content')"
    rec_proxied="$(echo "${rec}" | jq -r '.proxied')"

    if [[ "${rec_ip}" == "${ip}" && "${rec_proxied}" == "${PROXIED}" ]]; then
      # already correct
      continue
    fi

    echo "Updating A record: ${name} ${rec_ip} -> ${ip} (proxied: ${rec_proxied} -> ${PROXIED})"
    update_record "${ZONE_ID}" "${rec_id}" "${name}" "${ip}"
  done

  sleep "${INTERVAL_SECONDS}"
done
