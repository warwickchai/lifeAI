#!/usr/bin/env bash
# Install Tailscale on the Ubuntu box and expose services to your tailnet only.
#   https://<box>.ts.net        -> Mattermost (127.0.0.1:8065)
#   https://<box>.ts.net:8443   -> Dashboard  (127.0.0.1:8081)
# Nothing is exposed to the public internet (this is `serve`, not `funnel`).
set -euo pipefail
if ! command -v tailscale >/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
sudo tailscale up
sudo tailscale funnel reset   # tailnet only, never public
# HTTPS certs require "MagicDNS" and "HTTPS Certificates" enabled in the
# Tailscale admin console (DNS page).
sudo tailscale serve --bg --https=443  http://127.0.0.1:8065
sudo tailscale serve --bg --https=8443 http://127.0.0.1:8081
tailscale serve status
echo "Use the https://...ts.net name above as MM_SITEURL in infra/mattermost/.env"
