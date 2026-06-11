import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komorebi/data/db/database.dart';
import 'package:komorebi/data/repos/task_repository.dart';

void main() {
  late AppDatabase db;
  late TaskRepository repo;
  final today = DateTime(2026, 6, 10);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = TaskRepository(db);
  });
  tearDown(() => db.close());

  group('view queries', () {
    test('today includes due today, scheduled today, and overdue', () async {
      await repo.createTask(title: 'due today', dueAt: DateTime(2026, 6, 10, 18));
      await repo.createTask(
          title: 'scheduled today', scheduledAt: DateTime(2026, 6, 10, 9));
      await repo.createTask(title: 'overdue', dueAt: DateTime(2026, 6, 1));
      await repo.createTask(title: 'future', dueAt: DateTime(2026, 6, 20));
      await repo.createTask(title: 'undated');

      final titles =
          (await repo.watchToday(today).first).map((t) => t.title).toSet();
      expect(titles, {'due today', 'scheduled today', 'overdue'});
    });

    test('upcoming covers the next 7 days only', () async {
      await repo.createTask(title: 'today', dueAt: DateTime(2026, 6, 10));
      await repo.createTask(title: 'tomorrow', dueAt: DateTime(2026, 6, 11));
      await repo.createTask(title: 'day 7', dueAt: DateTime(2026, 6, 17));
      await repo.createTask(title: 'day 8', dueAt: DateTime(2026, 6, 18));

      final titles =
          (await repo.watchUpcoming(today).first).map((t) => t.title).toSet();
      expect(titles, {'tomorrow', 'day 7'});
    });

    test('completed and deleted tasks leave the open views', () async {
      final id = await repo.createTask(
          title: 'finish me', dueAt: DateTime(2026, 6, 10));
      final task = await repo.getTask(id);
      await repo.completeTask(task);
      await repo.createTask(title: 'delete me', dueAt: DateTime(2026, 6, 10));
      final all = await repo.watchAll().first;
      final deleteMe = all.firstWhere((t) => t.title == 'delete me');
      await repo.deleteTask(deleteMe.id);

      expect(await repo.watchToday(today).first, isEmpty);
      final done = await repo.watchCompleted().first;
      expect(done.map((t) => t.title), ['finish me']);
    });

    test('sorts by priority, then date', () async {
      await repo.createTask(title: 'p3 early', priority: 3, dueAt: today);
      await repo.createTask(title: 'none', dueAt: today);
      await repo.createTask(
          title: 'p1 late', priority: 1, dueAt: DateTime(2026, 6, 10, 23));
      await repo.createTask(title: 'p1 early', priority: 1, dueAt: today);

      final titles =
          (await repo.watchToday(today).first).map((t) => t.title).toList();
      expect(titles, ['p1 early', 'p1 late', 'p3 early', 'none']);
    });
  });

  group('recurrence on complete', () {
    test('non-recurring task simply completes', () async {
      final id = await repo.createTask(title: 'one-off', dueAt: today);
      final undoId = await repo.completeTask(await repo.getTask(id));
      expect(undoId, id);
      expect((await repo.getTask(id)).completedAt, isNotNull);
    });

    test('recurring task advances and leaves a done copy', () async {
      final id = await repo.createTask(
        title: 'water plants',
        dueAt: DateTime(2026, 6, 10, 8),
        rrule: 'FREQ=DAILY',
      );
      final undoId = await repo.completeTask(await repo.getTask(id),
          now: DateTime(2026, 6, 10, 9));

      final original = await repo.getTask(id);
      expect(original.completedAt, isNull, reason: 'stays open');
      expect(original.dueAt, DateTime(2026, 6, 11, 8), reason: 'advanced 1 day');

      final done = await repo.watchCompleted().first;
      expect(done.single.id, undoId);
      expect(done.single.id, isNot(id));
      expect(done.single.title, 'water plants');
    });

    test('overdue recurring task advances from now, not into the past',
        () async {
      final id = await repo.createTask(
        title: 'stretch',
        dueAt: DateTime(2026, 6, 1, 8),
        rrule: 'FREQ=DAILY',
      );
      await repo.completeTask(await repo.getTask(id),
          now: DateTime(2026, 6, 10, 9));
      final task = await repo.getTask(id);
      expect(task.dueAt!.isAfter(DateTime(2026, 6, 10, 9)), isTrue);
    });

    test('unparseable rrule falls back to plain completion', () async {
      final id = await repo.createTask(
          title: 'odd rule', dueAt: today, rrule: 'FREQ=WEEKLY;BYDAY=MO');
      await repo.completeTask(await repo.getTask(id));
      expect((await repo.getTask(id)).completedAt, isNotNull);
    });
  });

  group('projects, tags, subtasks', () {
    test('ensureProject is idempotent and seeds default columns', () async {
      final a = await repo.ensureProject('Garden');
      final b = await repo.ensureProject('garden');
      expect(a, b);

      final columns = await db.select(db.boardColumns).get();
      expect(columns.map((c) => c.name).toList(),
          TaskRepository.defaultColumns);
    });

    test('tags attach to tasks and ensureTag is idempotent', () async {
      final tagId = await repo.ensureTag('home');
      expect(await repo.ensureTag('HOME'), tagId);

      final taskId = await repo.createTask(title: 'sweep', tagIds: [tagId]);
      final byTask = await repo.watchTagsByTask().first;
      expect(byTask[taskId]!.single.name, 'home');

      await repo.setTaskTags(taskId, []);
      expect((await repo.watchTagsByTask().first)[taskId], isNull);
    });

    test('subtask progress counts done/total per parent', () async {
      final parent = await repo.createTask(title: 'pack for trip');
      await repo.createTask(title: 'clothes', parentTaskId: parent);
      final sub2 =
          await repo.createTask(title: 'chargers', parentTaskId: parent);
      await repo.toggleSubtask(await repo.getTask(sub2));

      final progress = await repo.watchSubtaskProgress().first;
      expect(progress[parent], (done: 1, total: 2));

      // Subtasks never appear in the main lists.
      final all = await repo.watchAll().first;
      expect(all.map((t) => t.title), ['pack for trip']);
    });

    test('deleting a parent soft-deletes its subtasks', () async {
      final parent = await repo.createTask(title: 'parent');
      await repo.createTask(title: 'child', parentTaskId: parent);
      await repo.deleteTask(parent);

      expect(await repo.watchAll().first, isEmpty);
      expect(await repo.watchSubtaskProgress().first, isEmpty);
    });
  });
}
