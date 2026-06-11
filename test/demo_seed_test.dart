// Seeds a Komorebi database with friendly demo data. A no-op in normal test
// runs; activate it by pointing SEED_DB at a database file:
//
//   flutter test test/demo_seed_test.dart \
//     --dart-define=SEED_DB=/abs/path/komorebi.sqlite \
//     --dart-define=SEED_PHASE=3
//
// Used for the README journey screenshots and for trying the app with
// realistic content. SEED_PHASE limits seeding to features of that phase.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komorebi/data/db/database.dart';
import 'package:komorebi/data/repos/day_plan_repository.dart';
import 'package:komorebi/data/repos/event_repository.dart';
import 'package:komorebi/data/repos/task_repository.dart';

const _path = String.fromEnvironment('SEED_DB');
const _phase = String.fromEnvironment('SEED_PHASE', defaultValue: '3');
const _theme = String.fromEnvironment('SEED_THEME', defaultValue: 'system');

void main() {
  test('seed demo database (no-op without SEED_DB)', () async {
    if (_path.isEmpty) return;
    File(_path).parent.createSync(recursive: true);

    final db = AppDatabase(NativeDatabase(File(_path)));
    await db.setSetting('theme_mode', _theme);
    final tasks = TaskRepository(db);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ---- Tasks & projects (Phase 1+) --------------------------------------
    final garden = await tasks.ensureProject('Garden');
    final home = await tasks.ensureProject('Home');
    final gardenTag = await tasks.ensureTag('garden');
    final homeTag = await tasks.ensureTag('home');

    final water = await tasks.createTask(
      title: 'Water the plants',
      projectId: garden,
      priority: 2,
      dueAt: today.add(const Duration(hours: 18)),
      tagIds: [gardenTag],
    );
    await tasks.createTask(
      title: 'Morning run',
      priority: 1,
      dueAt: today.add(const Duration(hours: 6)),
      rrule: 'FREQ=DAILY',
    );
    await tasks.createTask(
      title: 'Read 20 pages',
      priority: 3,
      dueAt: today.add(const Duration(days: 1)),
    );
    final bike = await tasks.createTask(
      title: 'Fix bicycle brakes',
      projectId: home,
      dueAt: today.add(const Duration(days: 3)),
      tagIds: [homeTag],
    );
    final pads =
        await tasks.createTask(title: 'Buy brake pads', parentTaskId: bike);
    await tasks.toggleSubtask(await tasks.getTask(pads));
    await tasks.createTask(title: 'Adjust cables', parentTaskId: bike);
    await tasks.createTask(title: 'Plan weekend hike', projectId: home);
    final seeds = await tasks.createTask(
        title: 'Buy seeds', projectId: garden, dueAt: today);
    await tasks.completeTask(await tasks.getTask(seeds));

    // ---- Board placement (Phase 2+) ----------------------------------------
    if (_phase == '2' || _phase == '3') {
      final columns = await tasks.watchBoardColumns(garden).first;
      final trellis = await tasks.createTask(
          title: 'Build a trellis', projectId: garden, priority: 3);
      final carrots =
          await tasks.createTask(title: 'Plant carrots', projectId: garden);
      await tasks.moveTaskToColumn(trellis, columns[0].id, sortOrder: 1);
      await tasks.moveTaskToColumn(carrots, columns[0].id, sortOrder: 2);
      await tasks.moveTaskToColumn(water, columns[1].id, sortOrder: 1);
    }

    // ---- Day plan (Phase 1.5+) ----------------------------------------------
    if (_phase != '1') {
      final plan = DayPlanRepository(db);
      final routine = await plan.createRoutine('Training day', weekdays: 127);
      Future<void> block(int start, int mins, String title) =>
          plan.addRoutineBlock(
              routineId: routine,
              startMinute: start,
              durationMinutes: mins,
              title: title);
      await block(300, 30, 'Wake up, wash up');
      await block(330, 60, 'Running');
      await block(390, 30, 'Stretches');
      await block(420, 60, 'Swimming');
      await block(480, 30, 'Freshen up, breakfast');
      await block(600, 120, 'Deep work');
      await plan.materializeDay(today);
      final blocks = await plan.watchDay(today).first;
      for (final b in blocks.take(3)) {
        await plan.toggleDone(b);
      }
    }

    // ---- Events (Phase 3) ---------------------------------------------------
    if (_phase == '3') {
      final events = EventRepository(db);
      final lastWednesday = today.subtract(
          Duration(days: (today.weekday - DateTime.wednesday) % 7));
      await events.createEvent(
        title: 'Swim class',
        startAt: lastWednesday.add(const Duration(hours: 7)),
        endAt: lastWednesday.add(const Duration(hours: 8)),
        rrule: 'FREQ=WEEKLY',
        color: 0xFF9DBBC7,
      );
      await events.createEvent(
        title: 'Dentist',
        startAt: today.add(const Duration(days: 7, hours: 9, minutes: 30)),
        endAt: today.add(const Duration(days: 7, hours: 10)),
        color: 0xFFC3514E,
        remindBefore: const Duration(hours: 1),
      );
      await events.createEvent(
        title: 'Hanami picnic',
        startAt: today.add(const Duration(days: 9)),
        allDay: true,
        color: 0xFFE3B7B1,
      );
      await events.createEvent(
        title: 'Pay rent',
        startAt: DateTime(now.year, now.month, 1, 8),
        rrule: 'FREQ=MONTHLY',
        color: 0xFFE8A84C,
      );
    }

    await db.close();
    // ignore: avoid_print
    print('Seeded $_path (phase $_phase)');
  });
}
