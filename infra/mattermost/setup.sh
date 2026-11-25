#!/usr/bin/env bash
# One-time Mattermost setup: admin user, team, channels, bots.
# Safe to re-run: existing objects are skipped.
set -uo pipefail
cd "$(dirname "$0")"
set -a; source .env; set +a

TEAM=lifeai
mm()  { docker compose exec -T mattermost mmctl --local "$@"; }
# Bot commands are not allowed in local mode; they run as the admin user.
mma() { docker compose exec -T mattermost mmctl "$@"; }

echo "Waiting for Mattermost..."
until mm system status >/dev/null 2>&1; do sleep 3; done

mm user create --username "$MM_ADMIN_USER" --email "$MM_ADMIN_EMAIL" \
  --password "$MM_ADMIN_PASSWORD" --system-admin 2>/dev/null || echo "user exists"
mm team create --name "$TEAM" --display-name "LifeAI" --private 2>/dev/null || echo "team exists"
mm team users add "$TEAM" "$MM_ADMIN_USER" 2>/dev/null || true

# channel  -> bot that is bound to it
# Rule: only *-local channels ever get private data (enforced in OpenClaw config).
declare -A CHANNELS=(
  [alerts-local]=local-bot
  [briefing-local]=local-bot
  [bills-local]=local-bot
  [chat-local]=local-bot
  [chat-gpt]=gpt-bot
  [chat-claude]=claude-bot
)

mma auth login http://localhost:8065 --name lifeai --username "$MM_ADMIN_USER" \
  --password-file /dev/stdin <<<"$MM_ADMIN_PASSWORD" >/dev/null

mkdir -p tokens && chmod 700 tokens
for bot in local-bot gpt-bot claude-bot; do
  if mma bot create "$bot" --display-name "$bot" --with-token > "tokens/$bot.out" 2>&1; then
    echo "created $bot (token saved in infra/mattermost/tokens/$bot.out)"
  else
    echo "$bot exists"; rm -f "tokens/$bot.out"
  fi
  mm team users add "$TEAM" "$bot" 2>/dev/null || true
done
chmod 600 tokens/* 2>/dev/null || true

for ch in "${!CHANNELS[@]}"; do
  mm channel create --team "$TEAM" --name "$ch" --display-name "$ch" --private 2>/dev/null || echo "$ch exists"
  mm channel users add "$TEAM:$ch" "$MM_ADMIN_USER" "${CHANNELS[$ch]}" 2>/dev/null || true
done

mma auth delete lifeai >/dev/null 2>&1 || true
echo "Done. Each bot is a member of its own channels only."
