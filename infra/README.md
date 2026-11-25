# Infra: Mattermost + Dashboard over Tailscale

Run on the Ubuntu box, in this order. Requires Docker + Docker Compose.

## 1. Tailscale (box)
```bash
./tailscale/setup.sh
```
Before running: in the Tailscale admin console → DNS, enable **MagicDNS** and **HTTPS Certificates**.
Note the `https://<box>.<tailnet>.ts.net` name it prints.

## 2. Mattermost (box)
```bash
cd mattermost
cp .env.example .env   # set POSTGRES_PASSWORD, MM_SITEURL (the ts.net name), admin login
docker compose up -d
./setup.sh
```
Creates: team `lifeai`, private channels, and three bots. Bot tokens are written to
`mattermost/tokens/*.out` (gitignored) for OpenClaw later.

| Channel | Bot | Private data allowed |
|---|---|---|
| alerts-local, briefing-local, bills-local, chat-local | local-bot | yes |
| chat-gpt | gpt-bot | **never** |
| chat-claude | claude-bot | **never** |

## 3. Dashboard (box)
```bash
cd dashboard && docker compose up -d
```
Shows sample data until the pipeline writes `site/data.json`.

## 4. Phone
1. Install **Tailscale**, sign in to the same account.
2. Install **Mattermost**, server URL = `https://<box>.<tailnet>.ts.net`.
3. Dashboard: open `https://<box>.<tailnet>.ts.net:8443` and add it to your home screen.

## Notes
- Everything binds to 127.0.0.1; only reachable through `tailscale serve` (tailnet only, not public).
- Image is **Team Edition** on purpose (the unlicensed enterprise image runs as "Entry" with a 10k-message cap).
- If Docker Hub rate-limits pulls, prefix images with `mirror.gcr.io/` (e.g. `mirror.gcr.io/library/postgres:16-alpine`).
- Push notifications use Mattermost's free test push server (no delivery guarantee).
