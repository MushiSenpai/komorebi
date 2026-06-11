# Changelog

All notable changes to Komorebi are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

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
