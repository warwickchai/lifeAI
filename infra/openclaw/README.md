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

## Model (CPU, until the 4090)

- `ollama/qwen3:4b-instruct` (Qwen3-4B-Instruct-2507, non-thinking), `num_ctx` 8192.
  `qwen3:4b` (hybrid thinking) "thought out loud" in its replies even with thinking off,
  confused by OpenClaw's long system prompt. Rollback: `~/.openclaw/openclaw.json.pre-instruct`.
- i5-8500 CPU: ~11 tokens/s generation, ~30 tokens/s prompt reading.
- OpenClaw sends ~10k tokens per turn (24.5k before the tool profile), so the 8k default
  context overflowed. Settings (rollback: `openclaw.json.pre-ctx`):
  - `agents.defaults.models["ollama/qwen3:4b-instruct"].params.num_ctx = 32768`
  - `models.providers.ollama.models[]`: `qwen3:4b-instruct`, `contextWindow` 262144,
    `contextTokens` 32768, `params.num_ctx` 32768 (keep `contextTokens` = `num_ctx`)
  - `tools.profile = "messaging"` (smaller tool list; global — affects Discord too)
  - `models.providers.ollama.timeoutSeconds = 900`, `agents.defaults.timeoutSeconds = 1200`
- Measured: first turn of a new session ~2.5–6 min, follow-ups ~20 s (Ollama reuses the
  cached prompt prefix). Revisit all of this once the 4090 is in.

## Check

```bash
openclaw channels status --probe
```

## Privacy notes

- All channels currently route to the single `main` agent (Ollama `qwen3:4b-instruct`), which also
  serves **Discord**. Before any email/Notion/Dropbox tool is added, split out a dedicated
  `local` agent bound only to Mattermost `-local` channels (rule: private tools only in
  `-local`). Discord must not reach an agent that has private tools.
- Rollback: `~/.openclaw/openclaw.json.pre-mattermost`.
