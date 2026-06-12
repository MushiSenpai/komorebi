# Changelog

All notable changes to Komorebi are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.2.0] — 2026-06-12 — "Every platform has a path"

### Added
- **Android verified**: local SDK toolchain set up; release APK builds
  (65.5 MB). CI now builds the APK on every push and attaches it as an
  artifact. Store-ready conditional signing via `android/key.properties`
  (example file included; falls back to debug signing for development).
- **iOS & macOS targets added** and compiled on every push by a macOS CI
  runner (`flutter build ios --no-codesign` + `flutter build macos`);
  macOS sandbox entitlements include network client for the Arena.
- **docs/RELEASING.md**: the full runbook from this repo to Google Play,
  the App Store (TestFlight), and the Mac App Store / notarized DMG.
- **Arena backups**: nightly pb_data snapshot to the Hetzner Storage Box
  (systemd timer on the VPS, 14-day local retention, offsite mirror).

## [1.1.2] — 2026-06-12

### Changed (game feel, from first playtest feedback)
- The island now sits low on screen with generous sky above the tower.
- Pieces start slower (1.4 m/s) and speed up a touch every five landed
  pieces, capped at 3.2 m/s — it gets harder, never hopeless.
- **Space rotates** the piece (with ↑/W); Enter hard-drops.

## [1.1.1] — 2026-06-12

### Fixed
- **The blank game** (reported on first play): the game view's Stack sized
  itself to its only non-positioned child — the game-over builder's
  `SizedBox.shrink()` — collapsing the entire view to 0×0 during play and
  snapping visible only at game over. `StackFit.expand` with the game as
  the base child fixes it; a regression test pins the layout.
- The game loop now drives repaints through the painter's `repaint`
  listenable on a steady 30 fps timer instead of per-frame setState.

## [1.1.0] — 2026-06-12 — Phase 8 "Arena"

### Added
- **Opt-in online leaderboards** (SPEC §5.7): join with a handle from the
  Play tab; scores submit automatically (and queue offline) to a
  self-hosted PocketBase at arena.theinvalid.me. Only your handle and game
  scores ever leave the device.
- **Daily duel**: everyone gets the same date-seeded piece sequence; the
  day's board ranks best towers — fair async multiplayer, no realtime
  needed. All-time survival board alongside.
- `server/arena/`: one-command idempotent deploy (PocketBase + systemd +
  Caddy + Cloudflare DNS + collection rules) and an operations README.

### Notes
- Real-time simultaneous racing stays on the roadmap: it needs a WebSocket
  service, state sync, and anti-cheat to do honestly.

## [1.0.0] — 2026-06-12 — Phase 7 "Polish" · v1.0

All seven core modules are live: tasks, day plan, kanban, calendar, notes,
focus, and the tower game — one local database, deeply linked.

### Added
- **Export / import everything** (Settings → Data): the whole database as
  one JSON file, lossless round-trip, import merges by id.
- Journey gallery refreshed with Notes, Focus, and Tsumiki Towers.

### Notes
- Deferred to the roadmap: UI sounds, Android build verification,
  OS-scheduled notifications, seasonal art.

## [0.8.0] — 2026-06-12 — Phase 6 "Tsumiki Towers"

### Added
- **The break game** (SPEC §5.6): survival tower stacking on a tiny island.
  Real rigid-body physics (forge2d) — tetromino pieces wobble, slide, and
  topple; three splashes into the sea end the run; the score is the tallest
  stable height in blocks.
- Controls: ← → move, ↑ rotate, ↓ soft drop, space hard drop, plus on-screen
  touch buttons; gentle wind above ten blocks.
- Local high-score table (Arena-ready `submitted` flag per SPEC §5.7); the
  pomodoro break card links straight here.

### Changed
- Renders through a custom CustomPainter + ticker instead of a game engine
  layer: smaller dependency surface, theme-native art (sky, sea, island),
  identical physics.

## [0.7.0] — 2026-06-11 — Phase 5 "Focus"

### Added
- **Pomodoro module** (SPEC §5.5): work/short/long-break cycle (every 4th
  break is long), customizable durations, big timer ring on the Focus tab.
- **Task linking**: dedicate a session to any open task; completed and
  abandoned sessions are logged (abandoning still counts the minutes,
  marked incomplete — no guilt).
- **Stats**: minutes today, a 7-day bar chart, and the week's most-focused
  tasks, all live.
- **Break prompt**: when a break starts, a card offers the tower game.
- **Floating timer chip**: leave the Focus tab mid-session and a small
  countdown chip follows you, tap to return.
- Phase-change local notifications via a shared notification service.

## [0.6.1] — 2026-06-11 — "Markdown, gently"

### Added
- **Interactive checklists in notes**: type `- [ ]` (or use the new toolbar
  button); in Preview the checkbox is tappable — ticked items flip to
  `- [x]` in the source and render crossed out.
- **Markdown help (?)** in the editor toolbar: a "you type → you get"
  cheat-sheet covering headings, emphasis, lists, checklists, and
  wiki-links.
- **Starter guide**: a pinned "How to write notes" note is seeded on the
  first visit, written so flipping Edit/Preview teaches the syntax by
  example. Deleting it does not bring it back.

## [0.6.0] — 2026-06-11 — Phase 4 "Notes"

### Added
- **Notes module** (SPEC §5.4): searchable note list with folders and pins,
  markdown editor with toolbar (bold/italic/heading/list/link picker),
  edit/preview toggle, and 600 ms autosave.
- **[[Wiki-links]]**: link note↔note by title and note↔task with
  `[[task:Task title]]`; links are materialized into NoteLinks on save.
  In preview, wiki-links are tappable — notes open in place, tasks open the
  task editor; unresolved note links offer one-tap "Create note".
- **Backlinks both ways**: every note shows "Linked from…" chips, and the
  task editor gains a "Referenced in" section that jumps to the note.
- Export all notes as markdown files from the notes menu.
- Adaptive layout: side-by-side list + editor on desktop, stacked on mobile.

### Notes
- Search is title/body substring for now; FTS5 indexing, image attachments,
  and inline `[[` autocomplete moved to the module's future list.
- Markdown rendering via flutter_markdown_plus (flutter_markdown is
  discontinued).

## [0.5.0] — 2026-06-11 — Phase 3 "Calendar"

### Added
- **Calendar module** (SPEC §5.3): theme-native month grid with event chips
  and task counts per day, plus a selected-day agenda listing events and
  due/scheduled tasks side by side (tasks tap through to the task editor).
- **Events**: timed, all-day, and recurring (shared RFC 5545 subset);
  color palette readable in both themes; notes; full editor with delete.
- **Reminders**: choose none / at start / 10 min / 1 hour / 1 day before;
  an in-app reminder engine polls once a minute and fires local
  notifications (Linux + Android via flutter_local_notifications) while the
  app runs. OS-scheduled notifications remain a Phase 7 polish item.
- Recurring series expand correctly into the visible window even when the
  series starts long before it.

### Notes
- Week/day timeline views and drag-to-schedule (SPEC §5.3) are deferred to
  the module's future-improvements list; month + agenda shipped first.
- Android Gradle config gained core-library desugaring (required by
  flutter_local_notifications); Android build verification stays in Phase 7.

## [0.4.0] — 2026-06-11 — Phase 2 "Kanban"

### Added
- **Boards module** (SPEC §5.2): one kanban board per project with a project
  chip switcher and inline project creation.
- Columns: add, rename, delete (tasks fall back to the first column),
  drag a column header onto another to swap positions, and **soft WIP
  limits** — the column header blushes when exceeded.
- Cards: long-press drag between/within columns (drop on a card to insert
  above it, on a column to append); card shows priority dot, due chip, tag
  chips, and subtask progress; tap opens the shared task editor.
- Quick "+ add card" field at the bottom of every column.
- Tasks created via "@project" quick-add (no column yet) appear in the first
  column automatically.

### Fixed
- Task editor initial load no longer reads tags via a stream (same
  fake-async deadlock class as 0.3.0's fix).

## [0.3.0] — 2026-06-11 — Phase 1.5 "Day Plan"

### Added
- **Day Plan module** (SPEC §5.8, new "Plan" tab): plan your day in half-hour
  slabs; blocks span multiple slabs (run 5:30–6:30, swim 7:00–8:00).
- **Routines**: named templates bound to weekdays (e.g. Training day Mon–Fri,
  Rest day Sat–Sun). Days materialize from their routine on first open;
  per-day edits stay on that day; "Reset day to routine" available.
- **Tracking**: check off blocks as the day goes; the header shows a gentle
  day score ring (7/10).
- **Monthly consistency ranks**: days with ≥80% blocks done are *good days*;
  months earn Stoic / Disciplined / Steady / Wandering / Sprouting. Month
  sheet with per-day dot calendar. Future days and quiet days are not judged.
- Schema v2 migration (routines, routine_blocks, day_blocks).

### Fixed
- Repository mutations no longer read via stream `.first` (deadlocked under
  widget-test fake-async; direct `get()` queries now).

## [0.2.0] — 2026-06-11 — Phase 1 "Tasks core"

### Added
- **Todo module** (SPEC §5.1): Today (incl. overdue), Upcoming (7 days grouped
  by day), All (grouped by project, priority/tag filters), and Done views —
  all reactive Drift streams.
- **Quick-add bar** with lightweight syntax: dates (`today`, `tomorrow`,
  weekday names, `next week`, `in N days`), `!p1`–`!p3` priority, `#tag`,
  `@project` (projects/tags created on the fly).
- **Task editor sheet**: title, markdown notes, project picker (+ create),
  priority, due & scheduled dates, repeat presets, tag chips, one-level
  subtask checklist, delete.
- **Recurrence**: minimal RFC 5545 subset (`FREQ` daily/weekly/monthly +
  `INTERVAL`), kept string-compatible with the full `rrule` package for
  later. Completing a recurring task leaves a completed copy in Done and
  advances the open task past "now", preserving time of day.
- **Complete/undo flow**: round checkbox with settle animation, snackbar
  undo, restore from the Done log; new projects seed Backlog/Doing/Done
  board columns for Phase 2.
- Tests: 32 passing (parser, recurrence, repository, widget flows).

### Fixed
- Router is now created per app instance (was a leaky global).
- Drift stream-cleanup timers no longer trip widget-test teardown.

## [0.1.0] — 2026-06-11 — Phase 0 "Skeleton"

### Added
- Flutter project targeting Linux desktop, Android, and web (preview only).
- **Design system**: Meadow (Totoro daytime) and Twilight (Spirited Away
  evening) themes as full `ThemeData` + `KomorebiTokens` ThemeExtension;
  follow-system or manual switch, persisted across restarts.
- **Database**: complete Drift/SQLite schema for all SPEC §4 entities —
  projects, board columns, tasks (subtasks, priorities, rrule recurrence
  fields), tags, events, folders, notes, note links, pomodoro sessions, game
  scores (Arena-ready `submitted` flag), reminders, settings. Every entity
  carries UUIDv7 id + created/updated/deleted timestamps (sync-ready).
- **App shell**: adaptive navigation (rail ≥720px, bottom bar below) across the
  six modules — Today, Boards, Calendar, Notes, Focus, Play — with illustrated
  placeholder screens, plus a working Settings screen.
- Tests: database settings/sync-columns/game-score tests and a widget test
  covering navigation and theme persistence (6 passing).

### Notes
- First frame is never blocked on I/O: the saved theme loads asynchronously.
- SPEC.md v1.1 adds §5.7 **Arena** (profiles, friend codes, shared
  leaderboards via self-hosted PocketBase) as Phase 8 / v1.1.
