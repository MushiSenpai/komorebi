# Komorebi — Personal Productivity Suite

> 木漏れ日 — *sunlight filtering through leaves.*
> A calm, Ghibli-inspired, local-first productivity app: todos, kanban, calendar,
> notes, pomodoro, and a physics tower game for breaks.

**Status:** Specification v1.0 (2026-06-10) — approved decisions from discovery Q&A.
**Owner:** Mushi

---

## 1. Vision

One beautiful app where planning (tasks, boards, calendar), thinking (notes), and
focusing (pomodoro) share a single data model — so a task can live on a board,
appear on the calendar, accumulate focus time, and be referenced from a note.
Breaks are real breaks: a built-in physics block-stacking game (Tricky Towers-style).

Design language: hand-crafted Studio Ghibli warmth, not stock Material widgets.

**Guiding principles**

1. **Local-first, sovereign.** All data lives on the device. No accounts, no cloud,
   no telemetry. Sync to a self-hosted server is a planned future layer, not a rewrite.
2. **Deeply integrated.** One schema, many views. The todo list and kanban board are
   two lenses on the same tasks.
3. **Every feature ships with a roadmap.** Each module below has a "Future
   improvements" section. Iterations pick from these lists — nothing is a dead end.
4. **Calm over gamified.** Gentle motion, paper textures, no guilt mechanics.

---

## 2. Platform & Tech Stack

| Concern | Choice | Rationale |
|---|---|---|
| Framework | **Flutter** (stable channel) | One codebase for Linux/Windows/macOS desktop + Android + iOS; renders its own pixels, ideal for a custom Ghibli art style. |
| Language | Dart | Comes with Flutter. |
| State management | **Riverpod** | Compile-safe, testable, scales to a multi-module app. |
| Navigation | go_router | Declarative, deep-linkable module routes. |
| Database | **SQLite via Drift** | Typed local DB, reactive queries (streams power live UI), single file per device, easy backup. |
| Markdown editing | flutter_markdown (render) + custom editor layer for `[[wiki-links]]` | |
| Drag & drop | Flutter native + `reorderables` for kanban columns/cards | |
| Calendar UI | `table_calendar` as the base, custom-skinned | |
| Notifications | `flutter_local_notifications` (desktop + mobile) | Reminders & pomodoro phase changes, fully local. |
| Game | **Flame engine + Forge2D** (Box2D physics) | Proper rigid-body physics for tower toppling. |
| Recurrence | `rrule` package (RFC 5545 rules) | Same standard as iCal → future calendar sync stays compatible. |

**Targets for v1:** Linux desktop + Android (Mushi's daily devices). macOS/iOS/Windows
builds are unblocked by the stack but verified later.

### Data ownership & sync-readiness

- One SQLite database file per device, in the platform app-data directory.
- Every row carries: `id` (UUIDv7), `created_at`, `updated_at` (UTC), `deleted_at`
  (soft delete). These are the prerequisites for conflict-aware sync later.
- Export/import: full JSON export + notes-as-markdown export from day one, so data is
  never trapped.

**Future improvements (data layer)**
- [ ] Self-hosted sync server (Docker service on the Mushishi stack): per-table
      last-write-wins on `updated_at` first; upgrade to CRDT/op-log if conflicts hurt.
- [ ] End-to-end encrypted backup snapshots.
- [ ] Multi-device presence (same data on desktop + phone, near-real-time).
- [ ] Optional notes-on-disk mode (markdown files instead of DB rows) for
      Obsidian-style interop.

---

## 3. Design System — "Ghibli, both moods"

Two full themes, switchable + follow-system:

| | **Meadow (light)** | **Twilight (dark)** |
|---|---|---|
| Inspiration | *My Neighbor Totoro* — daytime meadow | *Spirited Away* — evening bathhouse |
| Base | Cream paper `#F6F1E1`, soft greens `#7C9A6D`, warm brown ink `#4A3F35` | Deep indigo `#1B2238`, lantern gold `#E8A84C`, vermilion accents `#C3514E` |
| Texture | Subtle washi-paper grain background | Subtle night-sky grain, faint lantern glow on accents |

- **Typography:** a rounded humanist sans for UI; a slightly calligraphic serif for
  headings. All text themed via tokens, no hardcoded colors.
- **Shapes & motion:** generous corner radii, "settle" animations (ease-out-back),
  nothing snaps — things *land*.
- **Illustrated accents:** small hand-drawn SVG sprites — leaves, acorns, kodama-like
  spirits, paper lanterns (dark mode). Empty states get a tiny scene, not gray text.
- **Sound (off by default):** soft paper/wood UI ticks; gentle chime on pomodoro end.

**Future improvements (design)**
- [ ] Seasonal accents (sakura petals in spring, snow in winter) tied to system date.
- [ ] Additional theme: "Sky pastels" (Howl/Kiki).
- [ ] Animated mascot that reacts to streaks/completions.
- [ ] Custom app icon set per platform.

---

## 4. Shared Data Model (core entities)

```
Project   id, name, color, icon, archived, sort_order
Column    id, project_id, name, sort_order               -- kanban columns per project
Task      id, project_id, column_id, title, description(md),
          status, priority(P1..P3|none), due_at, scheduled_at,
          rrule (nullable), parent_task_id (nullable → subtask),
          sort_order, completed_at
Tag       id, name, color          + task_tags / note_tags join tables
Event     id, title, notes, start_at, end_at, all_day, rrule, color
Note      id, title, body(md), folder_id, pinned
Folder    id, name, parent_id
NoteLink  source_note_id, target_kind(note|task), target_id   -- powers [[wiki-links]] & backlinks
PomodoroSession  id, task_id (nullable), kind(work|break),
                 started_at, ended_at, completed(bool)
GameScore id, mode, score(height), pieces_placed, duration, played_at,
          submitted(bool)                 -- pushed to Arena leaderboard yet?
PlayerProfile (local copy) id, handle, avatar_id, friend_code, arena_enabled
Routine        id, name, weekdays(bitmask Mon=1..Sun=64), sort_order
RoutineBlock   id, routine_id, start_minute, duration_minutes, title, color
               -- half-hour grid: start/duration are multiples of 30
DayBlock       id, date(date-only), start_minute, duration_minutes, title,
               color, done(bool), routine_block_id (nullable provenance)
Reminder  id, target_kind(task|event), target_id, fire_at, fired
Settings  key, value
```

Integration rules this model enables:
- A task with `due_at`/`scheduled_at` automatically appears on the calendar.
- The kanban board is `Tasks WHERE project_id = X GROUP BY column_id`.
- The todo list is a cross-project query (Today / Upcoming / All).
- `[[Note Title]]` and `[[task:...]]` create `NoteLink` rows → backlinks both ways.
- Starting a pomodoro from a task creates a linked `PomodoroSession`.

---

## 5. Modules

### 5.1 Todo List (cross-project task views)

**V1 scope**
- Views: **Today** (due/scheduled today + overdue), **Upcoming** (next 7 days,
  grouped by day), **All**, and per-tag / per-priority filters.
- Quick-add bar with lightweight syntax: `tomorrow`, `!p1`, `#tag`, `@project`.
- Recurring tasks via rrule (daily/weekly/monthly presets + custom); completing an
  occurrence spawns/advances the next one.
- Subtasks (one level): checklist inside a task, progress shown wherever the task appears.
- Priorities P1–P3 + freeform tags, filterable everywhere.
- Reminders → local notifications on desktop & mobile.
- Completed-task log with undo.

**Future improvements**
- [ ] GTD layer: life Areas above projects + an **Inbox** for frictionless capture
      (explicitly planned — chosen as "future" in discovery).
- [ ] Natural-language quick add ("every 2nd Monday") parsed fully.
- [ ] Task dependencies (blocked-by).
- [ ] Review mode (weekly review wizard).
- [ ] Location-based reminders (mobile).

### 5.2 Kanban Board

**V1 scope**
- One board per project; default columns Backlog / Doing / Done, fully editable
  (add/rename/reorder/delete, per-column color).
- Drag & drop cards between/within columns (touch + mouse); drag to reorder columns.
- Cards show: title, priority dot, due chip, tag chips, subtask progress, a small
  tomato icon with accumulated focus time.
- Card detail sheet = the same task editor used by the todo list.
- WIP limit per column (soft — column header blushes when exceeded).

**Future improvements**
- [ ] Swimlanes (by priority or tag).
- [ ] Board filters & saved views.
- [ ] Column automation (e.g., dropping into "Done" sets `completed_at`; into
      "Doing" offers to start a pomodoro).
- [ ] Cross-project mega-board.
- [ ] Card cover images / illustrated stickers.

### 5.3 Calendar (standalone)

**V1 scope** *(shipped 2026-06-11 as month view + day agenda; week/day
timelines moved to future improvements)*
- Month view, custom-skinned to the theme, with a selected-day agenda.
- Native events (timed + all-day, recurring via rrule) **and** tasks with
  due/scheduled dates rendered side by side (tasks visually distinct, tappable
  through to the task editor).
- Event reminders via local notifications (in-app engine polls while the app
  runs; OS-scheduled notifications are Phase 7 polish).

**Future improvements**
- [ ] Week/day hour-timeline views; drag a task onto a day to schedule it;
      drag events to move/resize.
- [ ] **Year view** (requested 2026-06-11): 12-month overview with busy-day
      shading (event/task density heatmap), tap a month to jump to it; pairs
      naturally with the Day Plan yearly consistency heatmap (§5.8).
- [ ] Read-only overlay of the device OS calendar (mobile first).
- [ ] CalDAV two-way sync (self-hostable — fits the sovereign stack better than
      Google-first); Google Calendar via CalDAV/API after that.
- [ ] Time-blocking mode: drag tasks into time slots, slot completion feeds stats.
- [ ] ICS import/export.
- [ ] Agenda widget (Android home screen).

### 5.4 Notes (markdown + wiki-links)

**V1 scope**
- Markdown editor with live preview toggle; toolbar for common syntax.
- `[[wiki-links]]` with autocomplete: link note↔note and note↔task
  (`[[task:Fix router]]`). Renamed targets keep links (ID-based under the hood).
- **Backlinks panel** on every note and every task ("referenced in…").
- Folders + pins + tags; full-text search (SQLite FTS5) across titles and bodies.
- Image attachments (stored in app dir, relative links).
- Export: single note or whole vault as `.md` files.

**Future improvements**
- [ ] Graph view of the link network.
- [ ] Daily notes + calendar integration (click a day → that day's note).
- [ ] Templates (meeting note, decision record, weekly review).
- [ ] Tables, callouts, and mermaid-style diagrams in preview.
- [ ] Note version history.
- [ ] On-disk vault mode interoperable with Obsidian.
- [ ] AI assist via the local Mushishi stack (summarize note, extract tasks from a
      note into the todo list) — local models only, in keeping with sovereignty.

### 5.5 Pomodoro (task-linked with stats)

**V1 scope**
- Classic cycle: 25 work / 5 short break / 15 long break every 4th — all durations
  customizable.
- Start from anywhere: a task card, the task editor, or the timer screen (task
  optional but encouraged).
- Sessions logged to `PomodoroSession`; **stats screen**: focus time per day/week,
  per project, per task; simple bar charts in the app's art style.
- Phase-change notifications + gentle chime; persistent timer across app
  navigation; mini timer chip visible in the app shell while running.
- When a break starts, a friendly prompt offers the break game (one tap to play,
  easy to dismiss).

**Future improvements — "Full Focus Suite" (explicitly planned)**
- [ ] Daily focus goals & streaks (calm presentation, no guilt).
- [ ] Ambient soundscapes (rain on leaves, train, bathhouse murmur) — local audio.
- [ ] Auto/DND integration during work phases (per platform).
- [ ] Focus heatmap (GitHub-style year view).
- [ ] Smart suggestions: "you usually focus best 9–11am" from session history.

### 5.6 Break Game — "Tsumiki Towers" (Tricky Towers-style)

**V1 scope — Core stacking survival**
- Flame + Forge2D: tetromino-shaped rigid bodies with real physics — pieces drop,
  wobble, slide, and topple believably off a narrow island base.
- Controls: move/rotate falling piece (keyboard on desktop; touch buttons + swipe
  on mobile), soft/hard drop.
- Mode: **Survival** — build the tallest stable tower; lose a heart each time a
  piece falls into the water; 3 hearts and it's over. Score = max stable height.
- Camera follows tower height; gentle wind gusts at higher altitudes for tension.
- Local high-score table (`GameScore`); art style matches the active theme
  (meadow island by day, lantern-lit by night).
- **Arena-ready:** every run records the stats needed for online leaderboards
  (height, pieces, duration, mode). With Arena enabled (§5.7), bests are
  submitted automatically; offline runs queue and submit on reconnect.
- Reachable from the main nav *and* offered automatically on pomodoro breaks; an
  optional "break length" soft cap nudges you back to work, never force-quits.

**Future improvements (explicitly planned in discovery)**
- [ ] **Race mode:** reach a target height as fast as possible; medal times.
- [ ] **Puzzle mode:** fit a limited set of pieces under a laser line.
- [ ] **Magic spells:** light magic (sticky piece, scaffold, enlarge) and dark
      magic earned during play — closest to the PS5 original.
- [ ] **Additional mini-games:** a small card game (e.g., a solitaire variant) as a
      second break option, behind the same "break arcade" entry point.
- [ ] Ghost replays of your best run.
- [ ] Local 2-player split-screen race (desktop).
- [ ] Online real-time races against friends (via Arena, §5.7).

### 5.7 Arena — Profiles & Shared Leaderboards (the online layer)

Komorebi's only networked feature, and the deliberate exception to local-first:
anyone who installs the app can create a **player profile** and compete on shared
leaderboards for Tsumiki Towers. Strictly **opt-in** — the app never touches the
network until the user creates a profile, and disabling Arena returns it to a
fully offline app. Productivity data (tasks, notes, calendar, pomodoro) **never**
goes through Arena; only game scores and the public profile do.

**Architecture**

- Thin client-server: the app talks HTTPS to a small **leaderboard service**.
- Recommended backend: **PocketBase** (single Go binary, SQLite, built-in auth,
  row-level rules, realtime subscriptions). Self-hostable on any small VPS or
  free-tier host now, and trivially migratable onto the Mushishi stack later —
  same sovereignty story as the rest of the project. (Alternative if zero-ops is
  preferred at launch: Supabase free tier; the client gets an abstract
  `ArenaApi` interface so the backend is swappable.)
- Server collections: `players` (handle, avatar, friend_code, created_at),
  `scores` (player_id, mode, score, pieces, duration, client_version, created_at).
- App ships Arena-*capable*; the service URL is a config value, so the backend
  can be stood up after v1 without an app change.

**V1 (first Arena release) scope**

- **Profiles:** pick a handle + one of a set of hand-drawn Ghibli-style avatars
  (forest spirits, soot sprites…). Email optional (only needed for account
  recovery); no real names, no social login required.
- **Leaderboards:** global top-100 and **friends board**, each with all-time /
  weekly / daily tabs, per game mode. Weekly board resets Monday 00:00 UTC and
  crowns a "Spirit of the Week."
- **Friends via friend codes:** share a short code (e.g. `KMRB-7F3K`) in person
  or by message; no contact upload, no discovery feed.
- **Score submission:** personal bests auto-submit when online; offline scores
  queue locally (`GameScore.submitted`) and flush on reconnect.
- **Fair-play basics (honest scope):** server-side sanity checks (height vs.
  pieces vs. duration plausibility, rate limits, authenticated writes). Signed
  client payloads raise the bar, but a determined cheater can fake scores in any
  client-trusting design — acceptable for a friends-scale leaderboard; real
  anti-cheat (replay verification) is a future item.
- **Privacy rules:** public = handle, avatar, scores. Nothing else leaves the
  device. Delete-profile button erases the player and all scores server-side.

**Future improvements**

- [ ] **Online real-time race mode:** head-to-head tower race with live opponent
      view (PocketBase realtime or WebSocket service) — the full Tricky Towers
      feel.
- [ ] Replay-based score verification (client uploads input log; server
      re-simulates the deterministic physics run to validate top scores).
- [ ] Seasons with cosmetic rewards (avatar frames, island skins).
- [ ] Challenges: send a friend a specific piece sequence — same pieces, who
      builds higher?
- [ ] Optional **focus leaderboards** (weekly pomodoro hours among friends) —
      opt-in separately, since it exposes productivity data.
- [ ] Push notifications ("Mushi just beat your high score!").
- [ ] Migrate Arena onto the future Komorebi sync server so one backend serves
      both sync and leaderboards.

### 5.8 Day Plan — half-hour routine planner (added 2026-06-11)

The vision-plan tab: design your ideal day in **half-hour slabs** (wake 5:00,
wash up 5:00–5:30, run 5:30–6:30, stretch, swim 7:00–8:00, breakfast…), then
live against it and track how consistently you hit it.

**V1 scope**
- **Day grid:** 48 half-hour slabs; a block can span any number of consecutive
  slabs (running = 2 slabs, swimming = 2, a deep-work block = 6). Tap an empty
  slab to add a block (title + duration stepper in 30-min steps); tap a block
  to edit, resize, or delete. Auto-scrolls to the morning.
- **Routines (templates):** multiple named routines, each bound to weekdays —
  e.g. *Training day* (Mon–Fri) and *Rest day* (Sat–Sun). The first time a date
  is opened, it materializes a copy of the routine matching that weekday;
  one-off changes (appointments, travel) edit only that day. "Reset day to
  routine" discards the day's edits.
- **Tracking & day score:** every block has a check-off; the day header shows
  a gentle completion summary (7/10 blocks, with a ring).
- **Monthly consistency ranks:** each month earns a calm, Ghibli-toned rank
  from completion behaviour — days with ≥80% of blocks done count as *good
  days*. Ranks: **Stoic** (≥95% of days good), **Disciplined** (≥80%),
  **Steady** (≥60%), **Wandering** (≥40%), **Sprouting** (anything else —
  every month starts as a seed). A month sheet shows the rank, good-day count,
  and a small per-day dot calendar. No guilt mechanics: missed days fade, they
  don't shame.
- Tab name: **Plan**, between Today and Boards.

**Future improvements**
- [ ] Drag blocks to move/resize directly on the grid (v1 uses the editor).
- [ ] "Promote today's edits into the routine" one-tap.
- [ ] Per-block reminders ("running starts in 5 minutes") via the Phase 3
      notification engine.
- [ ] Show calendar events and scheduled tasks as ghost blocks behind the plan
      (deep integration with §5.3).
- [ ] Streaks & yearly consistency view (GitHub-style heatmap).
- [ ] **Arena discipline leaderboard:** opt-in monthly consistency ranking
      among friends (ties into §5.7) — share only the rank/percentage, never
      the plan contents.
- [ ] Energy tagging per block (focus/rest/move) with a daily balance glance.

---

## 6. App Shell & Cross-Cutting

- **Navigation:** left rail (desktop) / bottom bar (mobile): Today · Plan ·
  Boards · Calendar · Notes · Focus · Play. Global quick-add (task/event/note)
  from anywhere.
- **Global search** (Ctrl/Cmd-K): tasks, notes, events in one palette.
- **Settings:** theme (Meadow/Twilight/system), pomodoro durations, notification
  toggles, data export/import, database backup file.
- **Privacy:** zero network calls by default. The only networked feature is the
  opt-in Arena (§5.7), which transmits game scores and the public player profile
  — never tasks, notes, events, or pomodoro data.
- **Accessibility:** all interactions keyboard-reachable on desktop; semantic
  labels; reduced-motion mode swaps physics-feel animations for fades.

**Future improvements (app-wide)**
- [ ] Sync server + multi-device (see §2).
- [ ] Home-screen widgets (Android) / menubar mini app (desktop).
- [ ] Plugin-ish module system so future modules (habits tracker, journal) slot in.
- [ ] Local-LLM command bar ("plan my day") wired to the Mushishi stack.
- [ ] iOS/macOS/Windows release hardening.

---

## 7. Build Plan (v1 milestones)

| Phase | Deliverable | Proves |
|---|---|---|
| **0. Skeleton** | Flutter app, Drift DB + full schema, theming tokens (both themes), nav shell, settings | Foundation & art direction |
| **1. Tasks core** | Task CRUD, projects, todo views, quick-add, priorities/tags/subtasks | The data model works |
| **1.5 Day Plan** | Half-hour slab planner, weekday routines, check-offs, monthly consistency ranks (§5.8, added 2026-06-11) | Daily rhythm loop |
| **2. Kanban** | Boards, columns, drag & drop, card UI | Integration: same tasks, second view |
| **3. Calendar** | Month/week/day, events, tasks-on-calendar, reminders/notifications | Scheduling loop |
| **4. Notes** | Editor, wiki-links, backlinks, search, attachments, export | Knowledge layer |
| **5. Pomodoro** | Timer engine, task linkage, stats, break prompt | Focus loop |
| **6. Game** | Tsumiki Towers survival mode, local high scores (Arena-ready stats) | Break loop — and fun |
| **7. Polish** | Empty-state art, sounds, animations, Android build, export/import, README with this roadmap | Shippable v1 |
| **8. Arena** | PocketBase leaderboard service + profiles, friend codes, global/friends boards (needs a public host — small VPS or free tier) | First online feature, v1.1 |

Each phase ends runnable. Future-improvement checklists above are the backlog for
v2+ — when starting a new iteration, pick items, move them into a phase table, build.
