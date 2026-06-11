# Changelog

All notable changes to Komorebi are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
