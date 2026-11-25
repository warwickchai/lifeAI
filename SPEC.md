# LifeAI — Requirements & Phase Plan

Private, self-hosted personal assistant built on OpenClaw. Private data is processed by a
local LLM only. Frontier models (ChatGPT, Claude) are used only in explicitly labelled
channels and never get access to private data.

## 1. Goals

1. A **morning dashboard**, ready by 07:00, showing:
   - **Today** — split into **Urgent** and **Info**
   - **7-day chronological timeline** — meetings, events, bills, important items
   - Overnight email worth reading
   - **Bills** due, with paid/unpaid status
   - **Focus list** from Notion tasks
   - **Read-later** links extracted from newsletters
2. A **self-hosted chat interface** with per-channel model and data-access rules.
3. Continuous incremental updates during the day; push alerts for urgent items.

## 2. Infrastructure

| Item | Decision |
|---|---|
| Host | Ubuntu 24, RTX 4090 (24GB VRAM), 64GB RAM, always on |
| Primary model server | Strata (OpenAI-compatible API), Qwen3.6-35B-A3B / Qwen3.8-Flash-Next |
| Fallback model server | Ollama, same Qwen model, cold standby (loads only if Strata is down) |
| Failover | Manual URL swap in config at first; scripted health check only if Strata proves flaky |
| Agent gateway | OpenClaw (not yet installed) |
| Chat | Mattermost **Team Edition** (NOT Entry — Entry has a 10k message cap) |
| Remote access | Tailscale only for now; a **public web server** for the dashboard is a later phase |
| State store | SQLite (local). No ClickHouse. |
| Config/code | This repo. Secrets in local `.env` only, never committed. |

**Open:** confirm the 4090 is physically installed and visible to Strata (`nvidia-smi`).

## 3. Privacy model (hard rules)

1. Private data (email, Notion, Dropbox) is processed **only by the local model**.
2. Channel naming: every channel ends in `-local`, `-gpt` or `-claude`.
3. **Only `-local` channels may be given email, Notion or Dropbox tools.** Setup must refuse
   to bind these tools to `-gpt` / `-claude` agents. Enforced in OpenClaw agent config,
   not by prompt.
4. One Mattermost bot per agent; each bot is a member of its own channels only.
5. Frontier agents see only what the user types. A local pre-send check warns when a
   message to a frontier channel looks like private data (account numbers, emails, etc.).
6. Frontier access:
   - ChatGPT — OpenClaw OpenAI Codex sign-in (subscription). Verify on installed version.
   - Claude — Anthropic API key with a spend cap (start US$20/month).
   - No web-UI scraping.
7. Ingest agent treats email as untrusted (prompt injection): read-only on mail except
   mark-as-read; no outbound channel to frontier models.

## 4. Email & calendar

- 4–5 personal accounts across Gmail and Office 365. All approved for local processing.
- 40–50 emails/day.
- **Backfill:** 12 months, newest first, sender/subject pre-filter before the LLM,
  run overnight only.
- Gmail OAuth app must be published to **Production** (Testing-mode tokens expire after 7 days).
- O365 via Microsoft Graph (personal accounts).
- Calendars: 4–5 across Gmail and O365. **Duplicate meetings merged.**

### Newsletters → read-later

- The user flags a newsletter (in email or on the dashboard); sender is remembered after the first flag.
- Links extracted, email **marked as read** (not archived, not deleted).
- **Never follow** unsubscribe, account, preference or footer links.
- Resolve tracking redirects only for links that are kept.
- Ranking learned from the user's clicks (logged locally). No seed topics: links are shown
  unranked, in original order, until enough click history exists (~30–50 clicks).
- Paywalled sources (e.g. AFR) need the user's own login to open.

## 5. Bills

- Source: email only (body and PDF attachments; local text extraction/OCR).
- Billers and direct-debit status learned from email over time; ask once if unclear, then remember.
- Payment evidence: email receipts/confirmations only (no bank data). User will make sure
  each payment produces a confirmation email.
- States:

| State | Meaning | Today section |
|---|---|---|
| Overdue | Past due, no receipt | Urgent (persists) |
| Due, unpaid | Due today, no receipt | Urgent |
| Unknown | "Bill ready, log in" notice with no amount/date | Urgent ("check portal") |
| Likely paid — verify | Ambiguous receipt match | Urgent |
| Paid | Receipt matched (biller + amount + date), linked | Info |
| Auto-pay | Direct debit biller | Info |

- User can manually mark paid from the dashboard.
- All bills in the next 7 days appear on the timeline.

## 6. Tasks (Notion)

- Single Notion page/database shared with the integration. Properties: due date, priority, status.
- Write allowed: **create**, **update status / due date**.
- **Blocked in code:** delete or archive.
- Agent-created tasks tagged `source: agent`. All writes logged locally for undo.

## 7. Dashboard

- Served locally from the Ubuntu box; reachable on phone via Tailscale.
- Full rebuild finished by **06:30**; incremental updates on new mail/calendar/task changes.
- Push alerts via Mattermost DM from the private bot.
- Notification detail is **on**, limited to biller/item + status (no amounts, no account numbers).

## 8. Out of scope for v1

- Dropbox (later phase, as a data source for private Q&A).
- Bank data / Redbark.
- Notion content beyond the tasks page.

## 9. Phases

| Phase | Deliverable | Exit criteria |
|---|---|---|
| 0 | 4090 working; Strata serving Qwen; Ollama fallback; OpenClaw installed and pointed at Strata | Tool-calling test passes against Strata |
| 1 | Mattermost Team Edition + Tailscale; private bot in `-local` channels | Chat with local model from phone |
| 2 | Email + calendar ingest (read-only + mark-read), SQLite store, backfill | 12-month backfill completes; duplicates merged |
| 3 | Morning dashboard: Today (urgent/info), 7-day timeline, overnight email, focus list | Dashboard ready by 06:30 for 7 consecutive days |
| 4 | Bills: extraction, states, receipt matching, alerts | No missed due bills over 1 billing cycle |
| 5 | Newsletter flagging, link extraction, read-later, click learning | Flag → links appear → email marked read |
| 6 | Notion write (create/update, no delete, change log) | Agent-created tasks visible and undoable |
| 7 | Frontier channels (`-gpt` via Codex sign-in, `-claude` via API), pre-send check | Frontier agents provably have no private tools |
| 8 | Dropbox as a private data source | — |

## 10. Open items

- [ ] Design the public web server for the dashboard (auth, what data is exposed, hosting).

- [ ] Confirm the 4090 is installed and visible (`nvidia-smi`).
- [ ] Confirm which Strata project is in use (believed to be Niko1221/Strata) and that it supports tool calling.
- [ ] Verify OpenClaw supports the OpenAI Codex sign-in on the installed version.
