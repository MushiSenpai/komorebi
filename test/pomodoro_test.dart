import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komorebi/data/db/database.dart';
import 'package:komorebi/data/providers.dart';
import 'package:komorebi/data/repos/pomodoro_repository.dart';
import 'package:komorebi/features/focus/pomodoro_controller.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  var now = DateTime(2026, 6, 11, 9);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    now = DateTime(2026, 6, 11, 9);
    container = ProviderContainer(overrides: [
      databaseProvider.overrideWithValue(db),
      pomodoroProvider
          .overrideWith(() => PomodoroController(clock: () => now)),
    ]);
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  PomodoroController controller() =>
      container.read(pomodoroProvider.notifier);
  PomodoroState state() => container.read(pomodoroProvider);

  test('full cycle: work completes into a break, break returns to idle',
      () async {
    controller().startWork(taskId: 't1', taskTitle: 'Deep work');
    expect(state().phase, PomodoroPhase.work);
    expect(state().endsAt, now.add(const Duration(minutes: 25)));

    // Finish the work session.
    now = now.add(const Duration(minutes: 25, seconds: 1));
    await controller().tickNow();
    expect(state().phase, PomodoroPhase.shortBreak);
    expect(state().completedWork, 1);
    expect(state().breakSuggested, isTrue);

    final sessions = await db.select(db.pomodoroSessions).get();
    expect(sessions.single.kind, 'work');
    expect(sessions.single.taskId, 't1');
    expect(sessions.single.completed, isTrue);

    // Finish the break.
    now = now.add(const Duration(minutes: 6));
    await controller().tickNow();
    expect(state().phase, PomodoroPhase.idle);
    expect((await db.select(db.pomodoroSessions).get()).length, 2);
  });

  test('every 4th completed work earns a long break', () async {
    for (var i = 0; i < 3; i++) {
      controller().startWork();
      now = now.add(const Duration(minutes: 26));
      await controller().tickNow();
      expect(state().phase, PomodoroPhase.shortBreak);
      controller().skipBreak();
    }
    controller().startWork();
    now = now.add(const Duration(minutes: 26));
    await controller().tickNow();
    expect(state().phase, PomodoroPhase.longBreak);
    expect(state().endsAt!.difference(state().startedAt!),
        const Duration(minutes: 15));
  });

  test('giving up logs the partial work session as incomplete', () async {
    controller().startWork(taskId: 't1');
    now = now.add(const Duration(minutes: 10));
    await controller().stop();
    expect(state().phase, PomodoroPhase.idle);

    final session = (await db.select(db.pomodoroSessions).get()).single;
    expect(session.completed, isFalse);
    expect(session.endedAt!.difference(session.startedAt),
        const Duration(minutes: 10));
  });

  test('stats aggregate work minutes per day and per task', () async {
    final repo = PomodoroRepository(db);
    final today = DateTime(2026, 6, 11);
    Future<void> log(DateTime start, int minutes,
        {String? taskId, String kind = 'work'}) {
      return repo.logSession(
        taskId: taskId,
        kind: kind,
        startedAt: start,
        endedAt: start.add(Duration(minutes: minutes)),
        completed: true,
      );
    }

    final taskId = 'task-1';
    await db.into(db.tasks).insert(
        TasksCompanion.insert(id: taskId, title: 'Write spec'));
    await log(today.add(const Duration(hours: 8)), 25, taskId: taskId);
    await log(today.add(const Duration(hours: 9)), 25);
    await log(today.subtract(const Duration(days: 2)), 50, taskId: taskId);
    await log(today.add(const Duration(hours: 10)), 5, kind: 'break');
    await log(today.subtract(const Duration(days: 10)), 25); // out of window

    final stats = await repo.watchStats(today: today.add(const Duration(hours: 12))).first;
    expect(stats.todayMinutes, 50);
    expect(stats.last7Days.length, 7);
    expect(stats.last7Days.last.minutes, 50, reason: 'today is last');
    expect(stats.last7Days[4].minutes, 50, reason: 'two days ago');
    expect(stats.topTasks.first, (title: 'Write spec', minutes: 75));
  });

  test('config roundtrips through settings', () async {
    final repo = PomodoroRepository(db);
    expect((await repo.loadConfig()).work, const Duration(minutes: 25));
    await repo.saveConfig((
      work: const Duration(minutes: 50),
      shortBreak: const Duration(minutes: 10),
      longBreak: const Duration(minutes: 30),
      longEvery: 3,
    ));
    final loaded = await repo.loadConfig();
    expect(loaded.work, const Duration(minutes: 50));
    expect(loaded.longEvery, 3);
  });
}
