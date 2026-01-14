# Cloudflare-DDNS-Updater: commit-ready additions

This update bundle is designed to be dropped into your existing `aeger/Cloudflare-DDNS-Updater` repo.

## Files included
- `docs/host-rename-note.md`
- `scripts/healthcheck-ddns.sh`

## What to do
1) Copy these files into your repo.
2) Make `scripts/healthcheck-ddns.sh` executable:
   ```bash
   chmod +x scripts/healthcheck-ddns.sh
   ```
3) Commit:
   ```bash
   git add docs/host-rename-note.md scripts/healthcheck-ddns.sh
   git commit -m "docs: add svc-podman-01 rename note and ddns healthcheck"
   ```

This doesn’t assume any specific record name or zone; it just documents the rename and provides a quick log/health script.
