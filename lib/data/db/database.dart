import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/material.dart' show ThemeMode;

import 'tables.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Projects,
    BoardColumns,
    Tasks,
    Tags,
    TaskTags,
    NoteTags,
    Events,
    Folders,
    Notes,
    NoteLinks,
    PomodoroSessions,
    GameScores,
    Reminders,
    Routines,
    RoutineBlocks,
    DayBlocks,
    AppSettings,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _open());

  static QueryExecutor _open() {
    return driftDatabase(name: 'komorebi');
  }

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            // v2 (Phase 1.5): Day Plan module — SPEC §5.8.
            await m.createTable(routines);
            await m.createTable(routineBlocks);
            await m.createTable(dayBlocks);
          }
        },
      );

  // ---- Settings -----------------------------------------------------------

  static const _themeModeKey = 'theme_mode';

  Future<String?> getSetting(String key) async {
    final row = await (select(appSettings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> setSetting(String key, String value) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion.insert(key: key, value: value),
    );
  }

  Future<ThemeMode> loadThemeMode() async {
    return switch (await getSetting(_themeModeKey)) {
      'meadow' => ThemeMode.light,
      'twilight' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> saveThemeMode(ThemeMode mode) {
    final value = switch (mode) {
      ThemeMode.light => 'meadow',
      ThemeMode.dark => 'twilight',
      ThemeMode.system => 'system',
    };
    return setSetting(_themeModeKey, value);
  }
}
