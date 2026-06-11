import 'package:drift/drift.dart';

import '../db/database.dart';
import '../ids.dart';

/// One month's consistency picture (SPEC §5.8).
typedef MonthConsistency = ({
  int plannedDays,
  int goodDays,
  Map<DateTime, double> perDay,
  String rank,
});

/// Data access for the Day Plan module (SPEC §5.8): weekday routines,
/// per-day materialized blocks, check-offs, and consistency scoring.
class DayPlanRepository {
  DayPlanRepository(this._db);

  final AppDatabase _db;

  /// A day is "good" when at least this share of its blocks is done.
  static const goodDayThreshold = 0.8;

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Mon=1 … Sun=64, matching [DateTime.weekday].
  static int weekdayBit(int weekday) => 1 << (weekday - 1);

  // ---- Routines ------------------------------------------------------------

  Stream<List<Routine>> watchRoutines() {
    return (_db.select(_db.routines)
          ..where((r) => r.deletedAt.isNull())
          ..orderBy([(r) => OrderingTerm.asc(r.sortOrder)]))
        .watch();
  }

  Future<String> createRoutine(String name, {int weekdays = 0}) async {
    final id = newId();
    await _db.into(_db.routines).insert(RoutinesCompanion.insert(
          id: id,
          name: name,
          weekdays: Value(weekdays),
        ));
    return id;
  }

  Future<void> updateRoutine(String id, RoutinesCompanion changes) {
    return (_db.update(_db.routines)..where((r) => r.id.equals(id)))
        .write(changes.copyWith(updatedAt: Value(DateTime.now())));
  }

  Future<void> deleteRoutine(String id) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await updateRoutine(id, RoutinesCompanion(deletedAt: Value(now)));
      await (_db.update(_db.routineBlocks)
            ..where((b) => b.routineId.equals(id)))
          .write(RoutineBlocksCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ));
    });
  }

  Stream<List<RoutineBlock>> watchRoutineBlocks(String routineId) {
    return _routineBlocksQuery(routineId).watch();
  }

  SimpleSelectStatement<$RoutineBlocksTable, RoutineBlock>
      _routineBlocksQuery(String routineId) {
    return _db.select(_db.routineBlocks)
      ..where((b) => b.deletedAt.isNull() & b.routineId.equals(routineId))
      ..orderBy([(b) => OrderingTerm.asc(b.startMinute)]);
  }

  Future<String> addRoutineBlock({
    required String routineId,
    required int startMinute,
    required int durationMinutes,
    required String title,
  }) async {
    _validateSlab(startMinute, durationMinutes);
    final existing = await _routineBlocksQuery(routineId).get();
    _ensureNoOverlap(existing.map((b) => (b.startMinute, b.durationMinutes)),
        startMinute, durationMinutes);
    final id = newId();
    await _db.into(_db.routineBlocks).insert(RoutineBlocksCompanion.insert(
          id: id,
          routineId: routineId,
          startMinute: startMinute,
          durationMinutes: Value(durationMinutes),
          title: title,
        ));
    return id;
  }

  Future<void> deleteRoutineBlock(String id) {
    return (_db.update(_db.routineBlocks)..where((b) => b.id.equals(id)))
        .write(RoutineBlocksCompanion(
      deletedAt: Value(DateTime.now()),
      updatedAt: Value(DateTime.now()),
    ));
  }

  /// The routine whose weekday mask covers [date]; lowest sortOrder wins.
  Future<Routine?> routineForDate(DateTime date) async {
    final all = await (_db.select(_db.routines)
          ..where((r) => r.deletedAt.isNull())
          ..orderBy([(r) => OrderingTerm.asc(r.sortOrder)]))
        .get();
    final bit = weekdayBit(date.weekday);
    for (final routine in all) {
      if (routine.weekdays & bit != 0) return routine;
    }
    return null;
  }

  // ---- Day blocks ----------------------------------------------------------

  Stream<List<DayBlock>> watchDay(DateTime date) {
    return _dayQuery(dateOnly(date)).watch();
  }

  SimpleSelectStatement<$DayBlocksTable, DayBlock> _dayQuery(DateTime day) {
    return _db.select(_db.dayBlocks)
      ..where((b) => b.deletedAt.isNull() & b.date.equals(day))
      ..orderBy([(b) => OrderingTerm.asc(b.startMinute)]);
  }

  /// Copies the matching routine into [date] the first time that day is
  /// opened. A day that has ever had blocks (even all soft-deleted) is left
  /// alone, so clearing a day on purpose sticks.
  Future<void> materializeDay(DateTime date) async {
    final day = dateOnly(date);
    final everPlanned = await (_db.select(_db.dayBlocks)
          ..where((b) => b.date.equals(day))
          ..limit(1))
        .get();
    if (everPlanned.isNotEmpty) return;

    final routine = await routineForDate(day);
    if (routine == null) return;
    await _copyRoutineIntoDay(routine, day);
  }

  /// Discards the day's edits and re-copies its routine.
  Future<void> resetDayToRoutine(DateTime date) async {
    final day = dateOnly(date);
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.dayBlocks)
            ..where((b) => b.deletedAt.isNull() & b.date.equals(day)))
          .write(DayBlocksCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ));
      final routine = await routineForDate(day);
      if (routine != null) await _copyRoutineIntoDay(routine, day);
    });
  }

  Future<void> _copyRoutineIntoDay(Routine routine, DateTime day) async {
    final blocks = await _routineBlocksQuery(routine.id).get();
    for (final block in blocks) {
      await _db.into(_db.dayBlocks).insert(DayBlocksCompanion.insert(
            id: newId(),
            date: day,
            startMinute: block.startMinute,
            durationMinutes: Value(block.durationMinutes),
            title: block.title,
            color: Value(block.color),
            routineBlockId: Value(block.id),
          ));
    }
  }

  Future<String> addDayBlock({
    required DateTime date,
    required int startMinute,
    required int durationMinutes,
    required String title,
  }) async {
    _validateSlab(startMinute, durationMinutes);
    final day = dateOnly(date);
    final existing = await _dayQuery(day).get();
    _ensureNoOverlap(existing.map((b) => (b.startMinute, b.durationMinutes)),
        startMinute, durationMinutes);
    final id = newId();
    await _db.into(_db.dayBlocks).insert(DayBlocksCompanion.insert(
          id: id,
          date: day,
          startMinute: startMinute,
          durationMinutes: Value(durationMinutes),
          title: title,
        ));
    return id;
  }

  Future<void> updateDayBlock(String id, DayBlocksCompanion changes) async {
    if (changes.startMinute.present || changes.durationMinutes.present) {
      final current = await (_db.select(_db.dayBlocks)
            ..where((b) => b.id.equals(id)))
          .getSingle();
      final start = changes.startMinute.present
          ? changes.startMinute.value
          : current.startMinute;
      final duration = changes.durationMinutes.present
          ? changes.durationMinutes.value
          : current.durationMinutes;
      _validateSlab(start, duration);
      final others = (await _dayQuery(current.date).get())
          .where((b) => b.id != id)
          .map((b) => (b.startMinute, b.durationMinutes));
      _ensureNoOverlap(others, start, duration);
    }
    await (_db.update(_db.dayBlocks)..where((b) => b.id.equals(id)))
        .write(changes.copyWith(updatedAt: Value(DateTime.now())));
  }

  Future<void> toggleDone(DayBlock block) {
    return updateDayBlock(block.id, DayBlocksCompanion(done: Value(!block.done)));
  }

  Future<void> deleteDayBlock(String id) {
    return updateDayBlock(
        id, DayBlocksCompanion(deletedAt: Value(DateTime.now())));
  }

  // ---- Scoring -------------------------------------------------------------

  /// Completion stats for one month. Only days that were actually planned
  /// (≥1 block) and are not in the future count toward the rank — quiet days
  /// are not failures (SPEC §5.8: no guilt mechanics).
  Future<MonthConsistency> monthConsistency(int year, int month,
      {DateTime? today}) async {
    today = dateOnly(today ?? DateTime.now());
    final from = DateTime(year, month);
    final to = DateTime(year, month + 1);
    final blocks = await (_db.select(_db.dayBlocks)
          ..where((b) =>
              b.deletedAt.isNull() &
              b.date.isBiggerOrEqualValue(from) &
              b.date.isSmallerThanValue(to)))
        .get();

    final done = <DateTime, int>{};
    final total = <DateTime, int>{};
    for (final block in blocks) {
      total[block.date] = (total[block.date] ?? 0) + 1;
      if (block.done) done[block.date] = (done[block.date] ?? 0) + 1;
    }

    final perDay = <DateTime, double>{};
    var plannedDays = 0;
    var goodDays = 0;
    for (final day in total.keys) {
      final fraction = (done[day] ?? 0) / total[day]!;
      perDay[day] = fraction;
      if (!day.isAfter(today)) {
        plannedDays++;
        if (fraction >= goodDayThreshold) goodDays++;
      }
    }

    return (
      plannedDays: plannedDays,
      goodDays: goodDays,
      perDay: perDay,
      rank: rankFor(plannedDays, goodDays),
    );
  }

  /// Calm, Ghibli-toned consistency ranks (SPEC §5.8).
  static String rankFor(int plannedDays, int goodDays) {
    if (plannedDays == 0) return 'Sprouting';
    final ratio = goodDays / plannedDays;
    if (ratio >= 0.95) return 'Stoic';
    if (ratio >= 0.8) return 'Disciplined';
    if (ratio >= 0.6) return 'Steady';
    if (ratio >= 0.4) return 'Wandering';
    return 'Sprouting';
  }

  // ---- Validation ----------------------------------------------------------

  void _validateSlab(int startMinute, int durationMinutes) {
    if (startMinute % 30 != 0 || durationMinutes % 30 != 0) {
      throw ArgumentError('Blocks live on a 30-minute grid');
    }
    if (startMinute < 0 || durationMinutes < 30) {
      throw ArgumentError('Invalid block timing');
    }
    if (startMinute + durationMinutes > 24 * 60) {
      throw ArgumentError('Blocks cannot cross midnight');
    }
  }

  void _ensureNoOverlap(
      Iterable<(int, int)> existing, int start, int duration) {
    final end = start + duration;
    for (final (otherStart, otherDuration) in existing) {
      if (start < otherStart + otherDuration && otherStart < end) {
        throw StateError('That time is already planned');
      }
    }
  }
}
