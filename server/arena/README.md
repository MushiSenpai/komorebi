# Komorebi Arena — self-hosted leaderboard backend

A single PocketBase instance behind Caddy serves the opt-in leaderboards
(SPEC §5.7). Only game scores and a chosen handle ever reach it — never
tasks, notes, events, plans, or focus data.

## Deploy (one command)

```bash
./server/arena/deploy.sh
```

Idempotent. It will: install PocketBase v0.39 as a hardened systemd service
(127.0.0.1:8090), create a superuser (credentials saved to
`~/.config/mushishi-infra/pocketbase-arena.credentials`, never committed),
point `arena.theinvalid.me` at the VPS (Cloudflare API, DNS-only so Caddy
can get a Let's Encrypt cert), add the Caddy site, and create the `scores`
collection with its API rules.

Verify: `curl https://arena.theinvalid.me/api/health`

## Data model

One collection, `scores`:

| field | type | notes |
|---|---|---|
| handle | text ≤24 | player display name |
| client_id | text | anonymous per-device id (abuse tracing) |
| mode | text | `survival` or `daily-YYYYMMDD` |
| score | number | tower height in blocks (create rule caps at 500) |
| pieces, duration | number | run stats |
| played_at | date | client-reported |

Rules: anyone can create (capped) and read; update/delete are admin-only.
The app dedupes the leaderboard to each player's best.

## Modes & multiplayer

- **survival** — the all-time board.
- **daily-YYYYMMDD** — the *daily duel*: the app seeds the piece sequence
  from the UTC date, so everyone stacks the same pieces that day. Fair,
  async multiplayer with zero realtime infrastructure.
- Real-time head-to-head racing needs a WebSocket service, state sync, and
  anti-cheat — tracked in SPEC §5.7 future improvements, deliberately not
  faked here.

## Operations

- Logs: `journalctl -u pocketbase -f`
- Admin UI: `https://arena.theinvalid.me/_/` (superuser credentials file)
- Data lives in `/opt/pocketbase/pb_data` — include it in VPS backups.
- Wipe a day's board: delete `mode = 'daily-YYYYMMDD'` rows in the admin UI.
