#!/usr/bin/env bash
set -euo pipefail

echo "== cf-ddns container status =="
podman ps --filter "name=cf-ddns" || true

echo "== recent logs (tail 200) =="
podman logs --tail 200 cf-ddns || true
