#!/usr/bin/env bash
# One-shot setup on the Ubuntu box (no GPU needed):
#   Docker, Tailscale, Mattermost (Team Edition), dashboard.
# Run from the repo:  sudo ./infra/bootstrap.sh
# Safe to re-run.
set -euo pipefail
cd "$(dirname "$0")"
[ "$(id -u)" -eq 0 ] || { echo "Run with sudo"; exit 1; }

echo "== 1/5 Docker"
if ! command -v docker >/dev/null; then
  curl -fsSL https://get.docker.com | sh
fi
systemctl enable --now docker
[ -n "${SUDO_USER:-}" ] && usermod -aG docker "$SUDO_USER" || true

echo "== 2/5 Tailscale"
if ! command -v tailscale >/dev/null; then
  curl -fsSL https://tailscale.com/install.sh | sh
fi
tailscale status >/dev/null 2>&1 || tailscale up
TS_NAME=$(tailscale status --json | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))')
echo "Tailnet name: $TS_NAME"
echo "(Needs MagicDNS + HTTPS Certificates enabled in the Tailscale admin console → DNS)"

echo "== 3/5 Pull images (falls back to mirror.gcr.io if Docker Hub rate-limits)"
pull() {
  docker pull -q "$1" >/dev/null 2>&1 && return
  docker pull -q "mirror.gcr.io/$2" && docker tag "mirror.gcr.io/$2" "$1"
}
MM_VERSION=${MM_VERSION:-10.5}
pull postgres:16-alpine library/postgres:16-alpine
pull nginx:1.27-alpine library/nginx:1.27-alpine
pull "mattermost/mattermost-team-edition:$MM_VERSION" "mattermost/mattermost-team-edition:$MM_VERSION"

echo "== 4/5 Mattermost"
cd mattermost
if [ ! -f .env ]; then
  read -rp "Mattermost username for you: " MM_USER
  read -rp "Your email (stays on the box): " MM_EMAIL
  ADMIN_PW=$(openssl rand -base64 18 | tr -d '/+=')Aa1!
  cat > .env <<ENV
POSTGRES_PASSWORD=$(openssl rand -hex 24)
MM_SITEURL=https://$TS_NAME
MM_VERSION=$MM_VERSION
TZ=Australia/Sydney
MM_ADMIN_USER=$MM_USER
MM_ADMIN_EMAIL=$MM_EMAIL
MM_ADMIN_PASSWORD=$ADMIN_PW
ENV
  chmod 600 .env
  echo ">> Your Mattermost password: $ADMIN_PW  (also in infra/mattermost/.env — change it after first login)"
fi
docker compose up -d
./setup.sh
cd ..

echo "== 5/5 Dashboard"
(cd dashboard && docker compose up -d)

tailscale serve --bg --https=443  http://127.0.0.1:8065
tailscale serve --bg --https=8443 http://127.0.0.1:8080

cat <<DONE

Done.
  Mattermost: https://$TS_NAME
  Dashboard:  https://$TS_NAME:8443
Phone: install Tailscale + Mattermost apps, sign in to the same tailnet.
DONE
