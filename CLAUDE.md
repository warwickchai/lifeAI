# LifeAI — instructions for Claude sessions

Read `SPEC.md` first: it is the agreed requirements and phase plan. Do not re-open
decisions recorded there without the user giving new information.

## Where things run
- This repo is meant to be run on the user's Ubuntu 24 box (RTX 4090, 64GB RAM, always on).
- If you are running ON the box: run commands directly.
- Setup of Docker, Tailscale, Mattermost and the dashboard: `sudo ./infra/bootstrap.sh`
  (see `infra/README.md`). It was tested in a cloud container except for the Tailscale steps.

## Current status
- Phase 0 blocked on the 4090 being installed. Do everything that does not need the GPU.
- OpenClaw: not installed yet.
- Strata (primary model server) + Ollama (cold-standby fallback, same Qwen model).

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
