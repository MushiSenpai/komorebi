import 'package:drift/native.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_test/flutter_test.dart';
import 'package:komorebi/data/db/database.dart';
import 'package:komorebi/data/ids.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('settings roundtrip', () async {
    expect(await db.getSetting('missing'), isNull);
    await db.setSetting('greeting', 'konnichiwa');
    expect(await db.getSetting('greeting'), 'konnichiwa');

    await db.setSetting('greeting', 'konbanwa');
    expect(await db.getSetting('greeting'), 'konbanwa');
  });

  test('theme mode persists and defaults to system', () async {
    expect(await db.loadThemeMode(), ThemeMode.system);

    await db.saveThemeMode(ThemeMode.dark);
    expect(await db.loadThemeMode(), ThemeMode.dark);
    expect(await db.getSetting('theme_mode'), 'twilight');

    await db.saveThemeMode(ThemeMode.light);
    expect(await db.getSetting('theme_mode'), 'meadow');
  });

  test('tasks get sync-ready defaults (timestamps, soft delete)', () async {
    final projectId = newId();
    await db.into(db.projects).insert(
          ProjectsCompanion.insert(id: projectId, name: 'Komorebi'),
        );
    final taskId = newId();
    await db.into(db.tasks).insert(
          TasksCompanion.insert(id: taskId, title: 'Plant the first task'),
        );

    final task = await (db.select(db.tasks)
          ..where((t) => t.id.equals(taskId)))
        .getSingle();

    expect(task.title, 'Plant the first task');
    expect(task.createdAt, isNotNull);
    expect(task.updatedAt, isNotNull);
    expect(task.deletedAt, isNull);
    expect(task.completedAt, isNull);
    expect(task.description, isEmpty);
  });

  test('uuid v7 ids are time-ordered', () {
    final a = newId();
    final b = newId();
    expect(a.compareTo(b), lessThan(0));
  });

  test('game scores start unsubmitted (Arena-ready)', () async {
    await db.into(db.gameScores).insert(
          GameScoresCompanion.insert(
            id: newId(),
            score: 42,
            playedAt: DateTime.now(),
          ),
        );
    final score = await db.select(db.gameScores).getSingle();
    expect(score.mode, 'survival');
    expect(score.submitted, isFalse);
  });
}
