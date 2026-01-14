#!/usr/bin/env bash
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "[*] Creating directories..."
mkdir -p "${HOME}/.config/systemd/user"
mkdir -p "${HOME}/cf-ddns"

echo "[*] Copying unit..."
cp -v "${HERE}/systemd/cf-ddns.service" "${HOME}/.config/systemd/user/cf-ddns.service"

echo "[*] Enabling linger (sudo once)..."
sudo loginctl enable-linger "${USER}"

echo "[*] Reloading and enabling cf-ddns..."
systemctl --user daemon-reload
systemctl --user enable --now cf-ddns.service

echo
systemctl --user --no-pager status cf-ddns.service || true
