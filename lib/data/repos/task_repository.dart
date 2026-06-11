import 'package:drift/drift.dart';

import '../db/database.dart';
import '../ids.dart';
import '../recurrence.dart';

/// Counts shown as "2/5" subtask progress on task tiles.
typedef SubtaskProgress = ({int done, int total});

/// All task/project/tag data access for the todo views (SPEC §5.1).
///
/// Queries are reactive Drift streams so every view updates live. Lists show
/// top-level tasks only; subtasks appear as a checklist in the task editor.
class TaskRepository {
  TaskRepository(this._db);

  final AppDatabase _db;

  // ---- View queries -------------------------------------------------------

  Expression<bool> _open($TasksTable t) =>
      t.deletedAt.isNull() & t.completedAt.isNull() & t.parentTaskId.isNull();

  /// Due or scheduled before end of [day] (i.e. today + overdue).
  Stream<List<Task>> watchToday(DateTime day) {
    final cutoff = DateTime(day.year, day.month, day.day + 1);
    return (_db.select(_db.tasks)
          ..where((t) =>
              _open(t) &
              (t.dueAt.isSmallerThanValue(cutoff) |
                  t.scheduledAt.isSmallerThanValue(cutoff))))
        .watch()
        .map(_sorted);
  }

  /// Due or scheduled within the 7 days after [day] (exclusive of today).
  Stream<List<Task>> watchUpcoming(DateTime day) {
    final from = DateTime(day.year, day.month, day.day + 1);
    final to = DateTime(day.year, day.month, day.day + 8);
    Expression<bool> inWindow(GeneratedColumn<DateTime> c) =>
        c.isBiggerOrEqualValue(from) & c.isSmallerThanValue(to);
    return (_db.select(_db.tasks)
          ..where((t) =>
              _open(t) & (inWindow(t.dueAt) | inWindow(t.scheduledAt))))
        .watch()
        .map(_sorted);
  }

  /// Every open top-level task.
  Stream<List<Task>> watchAll() {
    return (_db.select(_db.tasks)..where(_open)).watch().map(_sorted);
  }

  /// Recently completed tasks, newest first (the Done log, SPEC §5.1).
  Stream<List<Task>> watchCompleted({int limit = 100}) {
    return (_db.select(_db.tasks)
          ..where((t) =>
              t.deletedAt.isNull() &
              t.completedAt.isNotNull() &
              t.parentTaskId.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.completedAt)])
          ..limit(limit))
        .watch();
  }

  /// Priority first (P1 < P3 < none), then due date, then manual order.
  List<Task> _sorted(List<Task> tasks) {
    int dateOf(Task t) =>
        (t.dueAt ?? t.scheduledAt)?.millisecondsSinceEpoch ?? 1 << 52;
    tasks.sort((a, b) {
      final p = (a.priority ?? 9).compareTo(b.priority ?? 9);
      if (p != 0) return p;
      final d = dateOf(a).compareTo(dateOf(b));
      if (d != 0) return d;
      return a.sortOrder.compareTo(b.sortOrder);
    });
    return tasks;
  }

  Stream<List<Task>> watchSubtasks(String parentId) {
    return (_db.select(_db.tasks)
          ..where((t) =>
              t.deletedAt.isNull() & t.parentTaskId.equals(parentId))
          ..orderBy([(t) => OrderingTerm.asc(t.createdAt)]))
        .watch();
  }

  /// Progress per parent task id, across all subtasks.
  Stream<Map<String, SubtaskProgress>> watchSubtaskProgress() {
    return (_db.select(_db.tasks)
          ..where((t) => t.deletedAt.isNull() & t.parentTaskId.isNotNull()))
        .watch()
        .map((subs) {
      final progress = <String, ({int done, int total})>{};
      for (final s in subs) {
        final prev = progress[s.parentTaskId!] ?? (done: 0, total: 0);
        progress[s.parentTaskId!] = (
          done: prev.done + (s.completedAt != null ? 1 : 0),
          total: prev.total + 1,
        );
      }
      return progress;
    });
  }

  /// Tag rows per task id, for tag chips on tiles.
  Stream<Map<String, List<Tag>>> watchTagsByTask() {
    final query = _db.select(_db.taskTags).join([
      innerJoin(_db.tags, _db.tags.id.equalsExp(_db.taskTags.tagId)),
    ]);
    return query.watch().map((rows) {
      final byTask = <String, List<Tag>>{};
      for (final row in rows) {
        final link = row.readTable(_db.taskTags);
        byTask.putIfAbsent(link.taskId, () => []).add(row.readTable(_db.tags));
      }
      return byTask;
    });
  }

  Stream<List<Project>> watchProjects() {
    return (_db.select(_db.projects)
          ..where((p) => p.deletedAt.isNull() & p.archived.equals(false))
          ..orderBy([(p) => OrderingTerm.asc(p.sortOrder)]))
        .watch();
  }

  Stream<List<Tag>> watchTags() {
    return (_db.select(_db.tags)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .watch();
  }

  Future<Task> getTask(String id) =>
      (_db.select(_db.tasks)..where((t) => t.id.equals(id))).getSingle();

  // ---- Mutations -----------------------------------------------------------

  Future<String> createTask({
    required String title,
    String description = '',
    String? projectId,
    String? parentTaskId,
    int? priority,
    DateTime? dueAt,
    DateTime? scheduledAt,
    String? rrule,
    List<String> tagIds = const [],
  }) async {
    final id = newId();
    await _db.transaction(() async {
      await _db.into(_db.tasks).insert(TasksCompanion.insert(
            id: id,
            title: title,
            description: Value(description),
            projectId: Value(projectId),
            parentTaskId: Value(parentTaskId),
            priority: Value(priority),
            dueAt: Value(dueAt),
            scheduledAt: Value(scheduledAt),
            rrule: Value(rrule),
          ));
      for (final tagId in tagIds) {
        await _db.into(_db.taskTags).insert(
            TaskTagsCompanion.insert(taskId: id, tagId: tagId),
            mode: InsertMode.insertOrIgnore);
      }
    });
    return id;
  }

  Future<void> updateTask(String id, TasksCompanion changes) {
    return (_db.update(_db.tasks)..where((t) => t.id.equals(id))).write(
      changes.copyWith(updatedAt: Value(DateTime.now())),
    );
  }

  /// Completes a task. Recurring tasks (SPEC §5.1) leave a completed copy in
  /// the Done log and advance their dates to the next occurrence instead of
  /// closing. Returns the id whose completion can be undone.
  Future<String> completeTask(Task task, {DateTime? now}) async {
    now ??= DateTime.now();
    final recurrence = Recurrence.tryParse(task.rrule);
    final anchor = task.dueAt ?? task.scheduledAt;

    if (recurrence == null || anchor == null) {
      await updateTask(task.id, TasksCompanion(completedAt: Value(now)));
      return task.id;
    }

    // Step occurrences forward until we clear "now", so an overdue
    // "every day" task lands tomorrow (keeping its time of day) rather
    // than on a string of past days.
    var next = recurrence.nextAfter(anchor);
    while (!next.isAfter(now)) {
      next = recurrence.nextAfter(next);
    }
    final shift = next.difference(anchor);

    final doneCopyId = newId();
    await _db.transaction(() async {
      await _db.into(_db.tasks).insert(TasksCompanion.insert(
            id: doneCopyId,
            title: task.title,
            description: Value(task.description),
            projectId: Value(task.projectId),
            priority: Value(task.priority),
            dueAt: Value(task.dueAt),
            scheduledAt: Value(task.scheduledAt),
            completedAt: Value(now),
          ));
      await updateTask(
        task.id,
        TasksCompanion(
          dueAt: Value(task.dueAt?.add(shift)),
          scheduledAt: Value(task.scheduledAt?.add(shift)),
        ),
      );
    });
    return doneCopyId;
  }

  Future<void> uncompleteTask(String id) =>
      updateTask(id, const TasksCompanion(completedAt: Value(null)));

  Future<void> toggleSubtask(Task subtask) => updateTask(
        subtask.id,
        TasksCompanion(
          completedAt:
              Value(subtask.completedAt == null ? DateTime.now() : null),
        ),
      );

  /// Soft delete (sync-friendly); cascades to subtasks.
  Future<void> deleteTask(String id) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.tasks)
            ..where((t) => t.id.equals(id) | t.parentTaskId.equals(id)))
          .write(TasksCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ));
    });
  }

  static const defaultColumns = ['Backlog', 'Doing', 'Done'];

  /// Finds a project by name (case-insensitive) or creates it, including the
  /// default kanban columns so Phase 2 boards work out of the box.
  Future<String> ensureProject(String name) async {
    final existing = await (_db.select(_db.projects)
          ..where((p) => p.deletedAt.isNull() & p.name.lower().equals(name.toLowerCase())))
        .getSingleOrNull();
    if (existing != null) return existing.id;

    final id = newId();
    await _db.transaction(() async {
      await _db.into(_db.projects).insert(
          ProjectsCompanion.insert(id: id, name: name));
      for (final (i, column) in defaultColumns.indexed) {
        await _db.into(_db.boardColumns).insert(BoardColumnsCompanion.insert(
              id: newId(),
              projectId: id,
              name: column,
              sortOrder: Value(i.toDouble()),
            ));
      }
    });
    return id;
  }

  Future<String> ensureTag(String name) async {
    final existing = await (_db.select(_db.tags)
          ..where((t) => t.deletedAt.isNull() & t.name.lower().equals(name.toLowerCase())))
        .getSingleOrNull();
    if (existing != null) return existing.id;
    final id = newId();
    await _db.into(_db.tags).insert(TagsCompanion.insert(id: id, name: name));
    return id;
  }

  Future<void> setTaskTags(String taskId, List<String> tagIds) async {
    await _db.transaction(() async {
      await (_db.delete(_db.taskTags)..where((t) => t.taskId.equals(taskId)))
          .go();
      for (final tagId in tagIds) {
        await _db.into(_db.taskTags).insert(
            TaskTagsCompanion.insert(taskId: taskId, tagId: tagId),
            mode: InsertMode.insertOrIgnore);
      }
      await updateTask(taskId, const TasksCompanion());
    });
  }
}
