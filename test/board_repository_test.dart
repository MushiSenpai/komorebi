import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komorebi/data/db/database.dart';
import 'package:komorebi/data/repos/task_repository.dart';

void main() {
  late AppDatabase db;
  late TaskRepository repo;
  late String projectId;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = TaskRepository(db);
    projectId = await repo.ensureProject('Garden');
  });
  tearDown(() => db.close());

  test('new project has the default columns in order', () async {
    final columns = await repo.watchBoardColumns(projectId).first;
    expect(columns.map((c) => c.name), ['Backlog', 'Doing', 'Done']);
  });

  test('moving a task between columns updates column and order', () async {
    final columns = await repo.watchBoardColumns(projectId).first;
    final taskId = await repo.createTask(title: 'plant seeds', projectId: projectId);

    await repo.moveTaskToColumn(taskId, columns[1].id, sortOrder: 5);
    final task = await repo.getTask(taskId);
    expect(task.columnId, columns[1].id);
    expect(task.sortOrder, 5);
  });

  test('add, rename, wip-limit, and swap columns', () async {
    final id = await repo.addColumn(projectId, 'Review');
    var columns = await repo.watchBoardColumns(projectId).first;
    expect(columns.last.name, 'Review');

    await repo.updateColumn(id, const BoardColumnsCompanion(name: Value('QA')));
    await repo.updateColumn(id, const BoardColumnsCompanion(wipLimit: Value(2)));
    columns = await repo.watchBoardColumns(projectId).first;
    expect(columns.last.name, 'QA');
    expect(columns.last.wipLimit, 2);

    await repo.swapColumns(columns[0], columns[1]);
    columns = await repo.watchBoardColumns(projectId).first;
    expect(columns.map((c) => c.name).take(2), ['Doing', 'Backlog']);
  });

  test('deleting a column reassigns its tasks to the first column', () async {
    final columns = await repo.watchBoardColumns(projectId).first;
    final doing = columns[1];
    final taskId = await repo.createTask(title: 'water', projectId: projectId);
    await repo.moveTaskToColumn(taskId, doing.id, sortOrder: 1);

    await repo.deleteColumn(doing.id);

    final remaining = await repo.watchBoardColumns(projectId).first;
    expect(remaining.map((c) => c.name), ['Backlog', 'Done']);
    final task = await repo.getTask(taskId);
    expect(task.columnId, remaining.first.id);
  });

  test('project task stream follows manual sort order', () async {
    final columns = await repo.watchBoardColumns(projectId).first;
    final a = await repo.createTask(title: 'a', projectId: projectId);
    final b = await repo.createTask(title: 'b', projectId: projectId);
    await repo.moveTaskToColumn(a, columns.first.id, sortOrder: 2);
    await repo.moveTaskToColumn(b, columns.first.id, sortOrder: 1);

    final tasks = await repo.watchProjectTasks(projectId).first;
    expect(tasks.map((t) => t.title), ['b', 'a']);
  });
}
