import 'dart:convert';
import 'dart:io';

import 'db/database.dart';

/// Whole-database JSON export/import (SPEC §2: data is never trapped).
///
/// Rows are exported exactly as stored (SQL column names, raw values), so a
/// backup round-trips losslessly. Import upserts by primary key — restoring
/// into an existing database merges rather than wipes.
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  static const formatVersion = 2;

  static const tableNames = [
    'projects',
    'board_columns',
    'tasks',
    'tags',
    'task_tags',
    'note_tags',
    'events',
    'folders',
    'notes',
    'note_links',
    'pomodoro_sessions',
    'game_scores',
    'reminders',
    'routines',
    'routine_blocks',
    'day_blocks',
    'app_settings',
  ];

  Future<File> exportTo(String directory) async {
    final tables = <String, List<Map<String, Object?>>>{};
    var rows = 0;
    for (final name in tableNames) {
      final result = await _db.customSelect('SELECT * FROM $name').get();
      tables[name] = [for (final row in result) row.data];
      rows += result.length;
    }
    final stamp = DateTime.now()
        .toIso8601String()
        .substring(0, 19)
        .replaceAll(':', '-');
    final file = File('$directory/komorebi-backup-$stamp.json');
    file.parent.createSync(recursive: true);
    file.writeAsStringSync(jsonEncode({
      'app': 'komorebi',
      'format': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'rows': rows,
      'tables': tables,
    }));
    return file;
  }

  /// Returns (tables, rows) imported. Rows with existing keys are replaced.
  Future<(int, int)> importFrom(String path) async {
    final raw = jsonDecode(File(path).readAsStringSync());
    if (raw is! Map || raw['app'] != 'komorebi') {
      throw const FormatException('Not a Komorebi backup file');
    }
    final tables = raw['tables'] as Map<String, dynamic>;
    var tableCount = 0;
    var rowCount = 0;
    await _db.transaction(() async {
      for (final name in tableNames) {
        final rows = tables[name];
        if (rows is! List || rows.isEmpty) continue;
        tableCount++;
        for (final row in rows.cast<Map<String, dynamic>>()) {
          final columns = row.keys.toList();
          final placeholders =
              List.filled(columns.length, '?').join(', ');
          await _db.customStatement(
            'INSERT OR REPLACE INTO $name (${columns.join(', ')}) '
            'VALUES ($placeholders)',
            [for (final column in columns) row[column]],
          );
          rowCount++;
        }
      }
    });
    return (tableCount, rowCount);
  }
}
