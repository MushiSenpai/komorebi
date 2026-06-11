import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komorebi/data/backup.dart';
import 'package:komorebi/data/db/database.dart';
import 'package:komorebi/data/repos/day_plan_repository.dart';
import 'package:komorebi/data/repos/note_repository.dart';
import 'package:komorebi/data/repos/task_repository.dart';

void main() {
  test('backup round-trips every module into a fresh database', () async {
    final source = AppDatabase(NativeDatabase.memory());
    addTearDown(source.close);

    // Seed a slice of every module.
    final tasks = TaskRepository(source);
    final project = await tasks.ensureProject('Garden');
    final tag = await tasks.ensureTag('home');
    final taskId = await tasks.createTask(
        title: 'Water plants',
        projectId: project,
        tagIds: [tag],
        dueAt: DateTime(2026, 6, 12, 18));
    final notes = NoteRepository(source);
    await notes.createNote(
        title: 'Journal', body: 'See [[task:Water plants]]');
    final plan = DayPlanRepository(source);
    final routine = await plan.createRoutine('Training', weekdays: 127);
    await plan.addRoutineBlock(
        routineId: routine,
        startMinute: 300,
        durationMinutes: 60,
        title: 'Run');
    await source.setSetting('theme_mode', 'twilight');

    final dir = Directory.systemTemp.createTempSync('komorebi-bk').path;
    addTearDown(() => Directory(dir).deleteSync(recursive: true));
    final file = await BackupService(source).exportTo(dir);
    expect(file.existsSync(), isTrue);

    // Restore into a brand-new database.
    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(target.close);
    final (tables, rows) = await BackupService(target).importFrom(file.path);
    expect(tables, greaterThanOrEqualTo(7));
    expect(rows, greaterThanOrEqualTo(8));

    final restoredTask =
        await TaskRepository(target).getTask(taskId);
    expect(restoredTask.title, 'Water plants');
    expect(restoredTask.dueAt, DateTime(2026, 6, 12, 18));
    expect(await target.getSetting('theme_mode'), 'twilight');
    final backlinks = await NoteRepository(target)
        .watchBacklinks('task', taskId)
        .first;
    expect(backlinks.single.title, 'Journal');

    // Importing again is idempotent (upsert by key).
    final (_, rows2) = await BackupService(target).importFrom(file.path);
    expect(rows2, rows);
    expect((await TaskRepository(target).watchAll().first).length, 1);
  });

  test('rejects files that are not komorebi backups', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final file = File(
        '${Directory.systemTemp.createTempSync('komorebi-bad').path}/x.json')
      ..writeAsStringSync('{"app":"other"}');
    expect(() => BackupService(db).importFrom(file.path),
        throwsFormatException);
  });
}
