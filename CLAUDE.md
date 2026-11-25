# LifeAI — instructions for Claude sessions

Read `SPEC.md` first: it is the agreed requirements and phase plan. Do not re-open
decisions recorded there without the user giving new information.

## Where things run
- This repo is meant to be run on the user's Ubuntu 26.04 box (host `ubuntu-24-2026`, LAN 192.168.0.242) (RTX 4090, 64GB RAM, always on).
- If you are running ON the box: run commands directly.
- Setup of Docker, Tailscale, Mattermost and the dashboard: `sudo ./infra/bootstrap.sh`
  (see `infra/README.md`). It was tested in a cloud container except for the Tailscale steps.

## Current status
- Phase 0 blocked on the 4090 being installed. Do everything that does not need the GPU.
- Phase 1 infra is up (2026-11-26): Docker, Mattermost Team Edition (team `lifeai`,
  6 private channels, 3 bots), dashboard on 127.0.0.1:8081. Both via `tailscale serve`
  (tailnet only, Funnel reset off): Mattermost `https://ubuntu-24-2026.tail36344c.ts.net`,
  dashboard `:8443`. Bot tokens in `infra/mattermost/tokens/` (root-owned, on the box only).
- OpenClaw 2026.7.1-2 is already installed (user npm global) and running as the user
  service `openclaw-gateway` on 127.0.0.1:18789. Not yet wired to Mattermost.
- Ollama installed (`qwen3.8:27b`, `qwen3:4b`). Strata not installed (needs the GPU).
- Open WebUI already uses 0.0.0.0:8080 — that is why the dashboard is on 8081.
- btop runs on tty3 (`btop-console.service`, user `btopview`): Ctrl+Alt+F3 at the box.
- Known deviations from the 127.0.0.1 rule: Open WebUI (8080), Ollama (11434) and the
  ubuntu-mcp server (8765) listen on all interfaces. Not yet fixed.

## Access from the user's Mac
- `.mcp.json` registers the box's `ubuntu` MCP server (runs as unprivileged `ubuntu-mcp`,
  no sudo). SSH as `warwick-chai` works with keys; sudo needs the user's password, so
  root steps run in a terminal tab the user types into.

## Hard rules (privacy)
- Private data (email, Notion, Dropbox) is processed by the LOCAL model only.
- Only channels ending in `-local` may be given email/Notion/Dropbox tools.
  `-gpt` and `-claude` agents must never have them. Enforce in config, not prompts.
- One bot per agent; each bot is only a member of its own channels.
- Mattermost must stay **Team Edition** (not the enterprise image / "Entry", 10k-message cap).
- Services bind to 127.0.0.1 and are exposed only via `tailscale serve` (never `funnel`)
  until the public web server phase is designed.
- Email: read + mark-as-read only. Never follow unsubscribe/account/footer links.
- Notion: one tasks page; create/update allowed, delete/archive blocked in code, log all writes.
- Secrets live in `.env` files and `infra/mattermost/tokens/` — never commit them.

## Pending user decisions
- WhatsApp alerts: (a) OpenClaw native WhatsApp on a second number [recommended],
  (b) CallMeBot now, (c) Mattermost only.
- Public web server for the dashboard (later phase).

## Style
- The user wants short answers, uncomfortable points first, confidence tags
  (certain / estimate / guess) on claims, and pushback when they are wrong.
