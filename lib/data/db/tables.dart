import 'package:drift/drift.dart';

/// Sync-ready columns shared by every synchronizable entity (SPEC §2/§4):
/// UUIDv7 primary key, UTC timestamps, soft delete.
mixin SyncColumns on Table {
  TextColumn get id => text()();

  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class Projects extends Table with SyncColumns {
  TextColumn get name => text()();

  IntColumn get color => integer().nullable()();

  TextColumn get icon => text().nullable()();

  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  RealColumn get sortOrder => real().withDefault(const Constant(0))();
}

/// Kanban columns, per project (SPEC §5.2).
class BoardColumns extends Table with SyncColumns {
  TextColumn get projectId => text().references(Projects, #id)();

  TextColumn get name => text()();

  IntColumn get color => integer().nullable()();

  /// Soft WIP limit; null = unlimited.
  IntColumn get wipLimit => integer().nullable()();

  RealColumn get sortOrder => real().withDefault(const Constant(0))();
}

class Tasks extends Table with SyncColumns {
  TextColumn get title => text()();

  /// Markdown body.
  TextColumn get description => text().withDefault(const Constant(''))();

  TextColumn get projectId => text().nullable().references(Projects, #id)();

  TextColumn get columnId => text().nullable().references(BoardColumns, #id)();

  /// Self-reference for subtasks; kept as a plain id to avoid circular
  /// foreign-key codegen. One level deep by convention (SPEC §5.1).
  TextColumn get parentTaskId => text().nullable()();

  /// 1 = P1 (highest) .. 3 = P3; null = no priority.
  IntColumn get priority => integer().nullable()();

  DateTimeColumn get dueAt => dateTime().nullable()();

  DateTimeColumn get scheduledAt => dateTime().nullable()();

  /// RFC 5545 recurrence rule; null = one-off.
  TextColumn get rrule => text().nullable()();

  RealColumn get sortOrder => real().withDefault(const Constant(0))();

  DateTimeColumn get completedAt => dateTime().nullable()();
}

class Tags extends Table with SyncColumns {
  TextColumn get name => text()();

  IntColumn get color => integer().nullable()();
}

class TaskTags extends Table {
  TextColumn get taskId => text().references(Tasks, #id)();

  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {taskId, tagId};
}

class NoteTags extends Table {
  TextColumn get noteId => text().references(Notes, #id)();

  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {noteId, tagId};
}

class Events extends Table with SyncColumns {
  TextColumn get title => text()();

  TextColumn get notes => text().withDefault(const Constant(''))();

  DateTimeColumn get startAt => dateTime()();

  DateTimeColumn get endAt => dateTime().nullable()();

  BoolColumn get allDay => boolean().withDefault(const Constant(false))();

  TextColumn get rrule => text().nullable()();

  IntColumn get color => integer().nullable()();
}

class Folders extends Table with SyncColumns {
  TextColumn get name => text()();

  TextColumn get parentId => text().nullable()();
}

class Notes extends Table with SyncColumns {
  TextColumn get title => text()();

  /// Markdown body; [[wiki-links]] resolved via NoteLinks.
  TextColumn get body => text().withDefault(const Constant(''))();

  TextColumn get folderId => text().nullable().references(Folders, #id)();

  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
}

/// Materialized [[wiki-links]] — powers backlinks for notes and tasks.
class NoteLinks extends Table with SyncColumns {
  TextColumn get sourceNoteId => text().references(Notes, #id)();

  /// 'note' | 'task'
  TextColumn get targetKind => text()();

  TextColumn get targetId => text()();
}

class PomodoroSessions extends Table with SyncColumns {
  TextColumn get taskId => text().nullable().references(Tasks, #id)();

  /// 'work' | 'break'
  TextColumn get kind => text()();

  DateTimeColumn get startedAt => dateTime()();

  DateTimeColumn get endedAt => dateTime().nullable()();

  BoolColumn get completed => boolean().withDefault(const Constant(false))();
}

class GameScores extends Table with SyncColumns {
  /// 'survival' for v1; race/puzzle later (SPEC §5.6).
  TextColumn get mode => text().withDefault(const Constant('survival'))();

  /// Max stable tower height (the score).
  IntColumn get score => integer()();

  IntColumn get piecesPlaced => integer().withDefault(const Constant(0))();

  /// Run duration in seconds.
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();

  DateTimeColumn get playedAt => dateTime()();

  /// Whether this score has been pushed to the Arena leaderboard (SPEC §5.7).
  BoolColumn get submitted => boolean().withDefault(const Constant(false))();
}

class Reminders extends Table with SyncColumns {
  /// 'task' | 'event'
  TextColumn get targetKind => text()();

  TextColumn get targetId => text()();

  DateTimeColumn get fireAt => dateTime()();

  BoolColumn get fired => boolean().withDefault(const Constant(false))();
}

/// Simple key-value store for app settings (theme, pomodoro durations...).
@DataClassName('AppSetting')
class AppSettings extends Table {
  TextColumn get key => text()();

  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {key};
}
