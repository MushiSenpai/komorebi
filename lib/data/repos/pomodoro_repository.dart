import 'package:drift/drift.dart';

import '../db/database.dart';
import '../ids.dart';

/// Focus minutes for one day plus per-task totals (SPEC §5.5 stats).
typedef FocusStats = ({
  int todayMinutes,
  List<({DateTime day, int minutes})> last7Days,
  List<({String title, int minutes})> topTasks,
});

/// Pomodoro durations, persisted in settings (SPEC §5.5).
typedef PomodoroConfig = ({
  Duration work,
  Duration shortBreak,
  Duration longBreak,
  int longEvery,
});

class PomodoroRepository {
  PomodoroRepository(this._db);

  final AppDatabase _db;

  static const defaults = (
    work: Duration(minutes: 25),
    shortBreak: Duration(minutes: 5),
    longBreak: Duration(minutes: 15),
    longEvery: 4,
  );

  Future<PomodoroConfig> loadConfig() async {
    Future<int> minutes(String key, Duration fallback) async =>
        int.tryParse(await _db.getSetting(key) ?? '') ?? fallback.inMinutes;
    return (
      work: Duration(minutes: await minutes('pomo_work', defaults.work)),
      shortBreak:
          Duration(minutes: await minutes('pomo_short', defaults.shortBreak)),
      longBreak:
          Duration(minutes: await minutes('pomo_long', defaults.longBreak)),
      longEvery: int.tryParse(await _db.getSetting('pomo_long_every') ?? '') ??
          defaults.longEvery,
    );
  }

  Future<void> saveConfig(PomodoroConfig config) async {
    await _db.setSetting('pomo_work', '${config.work.inMinutes}');
    await _db.setSetting('pomo_short', '${config.shortBreak.inMinutes}');
    await _db.setSetting('pomo_long', '${config.longBreak.inMinutes}');
    await _db.setSetting('pomo_long_every', '${config.longEvery}');
  }

  Future<void> logSession({
    String? taskId,
    required String kind,
    required DateTime startedAt,
    required DateTime endedAt,
    required bool completed,
  }) {
    return _db.into(_db.pomodoroSessions).insert(
          PomodoroSessionsCompanion.insert(
            id: newId(),
            taskId: Value(taskId),
            kind: kind,
            startedAt: startedAt,
            endedAt: Value(endedAt),
            completed: Value(completed),
          ),
        );
  }

  /// Work-minute totals: today, the trailing week, and the most-focused
  /// tasks of that week.
  Stream<FocusStats> watchStats({DateTime? today}) {
    final now = today ?? DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final weekStart = dayStart.subtract(const Duration(days: 6));

    final query = _db.select(_db.pomodoroSessions).join([
      leftOuterJoin(
          _db.tasks, _db.tasks.id.equalsExp(_db.pomodoroSessions.taskId)),
    ])
      ..where(_db.pomodoroSessions.deletedAt.isNull() &
          _db.pomodoroSessions.kind.equals('work') &
          _db.pomodoroSessions.endedAt.isNotNull() &
          _db.pomodoroSessions.startedAt.isBiggerOrEqualValue(weekStart));

    return query.watch().map((rows) {
      var todayMinutes = 0;
      final byDay = <DateTime, int>{
        for (var i = 0; i < 7; i++) weekStart.add(Duration(days: i)): 0,
      };
      final byTask = <String, int>{};

      for (final row in rows) {
        final session = row.readTable(_db.pomodoroSessions);
        final task = row.readTableOrNull(_db.tasks);
        final minutes =
            session.endedAt!.difference(session.startedAt).inMinutes;
        if (minutes <= 0) continue;
        final day = DateTime(session.startedAt.year, session.startedAt.month,
            session.startedAt.day);
        byDay[day] = (byDay[day] ?? 0) + minutes;
        if (!day.isBefore(dayStart)) todayMinutes += minutes;
        final title = task?.title ?? 'Unlinked focus';
        byTask[title] = (byTask[title] ?? 0) + minutes;
      }

      final top = byTask.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return (
        todayMinutes: todayMinutes,
        last7Days: [
          for (final entry in byDay.entries.toList()
            ..sort((a, b) => a.key.compareTo(b.key)))
            (day: entry.key, minutes: entry.value),
        ],
        topTasks: [
          for (final entry in top.take(5))
            (title: entry.key, minutes: entry.value),
        ],
      );
    });
  }
}
