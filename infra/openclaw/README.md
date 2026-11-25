# OpenClaw ↔ Mattermost (local-bot)

OpenClaw 2026.7.1-2 runs as the user service `openclaw-gateway` (127.0.0.1:18789).
Config lives on the box in `~/.openclaw/openclaw.json` (not in this repo; it holds the
Discord token). This file records what was added for Mattermost so it can be rebuilt.

## What is wired (2026-11-26)

- Plugin: `openclaw plugins install @openclaw/mattermost` → 2026.7.1 (newest compatible;
  2026.11.x needs a newer OpenClaw).
- Bot: **local-bot only**. `gpt-bot` / `claude-bot` are not connected (Phase 7).
- Token: a dedicated `local-bot` token named `openclaw-gateway`, generated with
  `mmctl --local token generate`, stored in `~/.openclaw/secrets/mattermost.env` (0600) as
  `MATTERMOST_BOT_TOKEN`, loaded by the drop-in
  `~/.config/systemd/user/openclaw-gateway.service.d/mattermost.conf`:
  ```ini
  [Service]
  EnvironmentFile=%h/.openclaw/secrets/mattermost.env
  ```
- Talks to Mattermost over loopback (`http://127.0.0.1:8065`), not the tailnet URL.

## Config block (`channels.mattermost`)

```json
{
  "enabled": true,
  "baseUrl": "http://127.0.0.1:8065",
  "network": { "dangerouslyAllowPrivateNetwork": true },
  "dmPolicy": "allowlist", "allowFrom": ["<warwick-chai user id>"],
  "groupPolicy": "allowlist", "groupAllowFrom": ["<warwick-chai user id>"],
  "chatmode": "onmessage",
  "groups": {
    "*":                { "requireMention": true },
    "<chat-local id>":     { "requireMention": false },
    "<alerts-local id>":   { "requireMention": true },
    "<briefing-local id>": { "requireMention": true },
    "<bills-local id>":    { "requireMention": true }
  }
}
```

- Only the user's Mattermost ID can trigger the bot (DMs and channels).
- `chat-local` answers every message; the other `-local` channels are output channels and
  answer only on @mention.
- `allowBots` is not supported by the 2026.7.1 plugin; `groupAllowFrom` already blocks bots.
- IDs: `docker exec lifeai-mattermost-mattermost-1 mmctl --local channel list lifeai --json`
  and `... user list --all`.

## Check

```bash
openclaw channels status --probe
```

## Privacy notes

- All channels currently route to the single `main` agent (Ollama `qwen3:4b`), which also
  serves **Discord**. Before any email/Notion/Dropbox tool is added, split out a dedicated
  `local` agent bound only to Mattermost `-local` channels (rule: private tools only in
  `-local`). Discord must not reach an agent that has private tools.
- Rollback: `~/.openclaw/openclaw.json.pre-mattermost`.
