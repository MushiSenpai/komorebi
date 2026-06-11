import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komorebi/data/db/database.dart';
import 'package:komorebi/data/repos/day_plan_repository.dart';

void main() {
  late AppDatabase db;
  late DayPlanRepository repo;
  // Wednesday / Saturday of the same week.
  final wednesday = DateTime(2026, 6, 10);
  final saturday = DateTime(2026, 6, 13);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = DayPlanRepository(db);
  });
  tearDown(() => db.close());

  /// Mon–Fri training routine: wake 5:00, run 5:30–6:30.
  Future<String> trainingRoutine() async {
    final id = await repo.createRoutine('Training day',
        weekdays: DayPlanRepository.weekdayBit(1) |
            DayPlanRepository.weekdayBit(2) |
            DayPlanRepository.weekdayBit(3) |
            DayPlanRepository.weekdayBit(4) |
            DayPlanRepository.weekdayBit(5));
    await repo.addRoutineBlock(
        routineId: id, startMinute: 300, durationMinutes: 30, title: 'Wake up');
    await repo.addRoutineBlock(
        routineId: id, startMinute: 330, durationMinutes: 60, title: 'Running');
    return id;
  }

  group('routines & materialization', () {
    test('weekday routine materializes on matching day only', () async {
      await trainingRoutine();

      await repo.materializeDay(wednesday);
      final wed = await repo.watchDay(wednesday).first;
      expect(wed.map((b) => b.title), ['Wake up', 'Running']);
      expect(wed[1].durationMinutes, 60, reason: 'two slabs combined');

      await repo.materializeDay(saturday);
      expect(await repo.watchDay(saturday).first, isEmpty,
          reason: 'no routine bound to Saturday');
    });

    test('materializing twice does not duplicate', () async {
      await trainingRoutine();
      await repo.materializeDay(wednesday);
      await repo.materializeDay(wednesday);
      expect((await repo.watchDay(wednesday).first).length, 2);
    });

    test('a deliberately cleared day stays cleared', () async {
      await trainingRoutine();
      await repo.materializeDay(wednesday);
      for (final block in await repo.watchDay(wednesday).first) {
        await repo.deleteDayBlock(block.id);
      }
      await repo.materializeDay(wednesday);
      expect(await repo.watchDay(wednesday).first, isEmpty);
    });

    test('reset discards edits and re-copies the routine', () async {
      await trainingRoutine();
      await repo.materializeDay(wednesday);
      await repo.addDayBlock(
          date: wednesday,
          startMinute: 600,
          durationMinutes: 30,
          title: 'Dentist');
      await repo.resetDayToRoutine(wednesday);
      expect((await repo.watchDay(wednesday).first).map((b) => b.title),
          ['Wake up', 'Running']);
    });
  });

  group('block rules', () {
    test('rejects off-grid and overlapping blocks', () async {
      await repo.addDayBlock(
          date: wednesday, startMinute: 300, durationMinutes: 60, title: 'Run');

      expect(
          () => repo.addDayBlock(
              date: wednesday,
              startMinute: 315,
              durationMinutes: 30,
              title: 'off-grid'),
          throwsArgumentError);
      expect(
          () => repo.addDayBlock(
              date: wednesday,
              startMinute: 330,
              durationMinutes: 30,
              title: 'overlap'),
          throwsStateError);
      // Adjacent is fine.
      await repo.addDayBlock(
          date: wednesday,
          startMinute: 360,
          durationMinutes: 30,
          title: 'Stretch');
    });

    test('toggle done flips state', () async {
      final id = await repo.addDayBlock(
          date: wednesday, startMinute: 300, durationMinutes: 30, title: 'Wake');
      var block = (await repo.watchDay(wednesday).first).single;
      expect(block.done, isFalse);
      await repo.toggleDone(block);
      block = (await repo.watchDay(wednesday).first).single;
      expect(block.done, isTrue);
      expect(block.id, id);
    });
  });

  group('consistency scoring', () {
    Future<void> planDay(DateTime day, int blocks, int doneCount) async {
      for (var i = 0; i < blocks; i++) {
        final id = await repo.addDayBlock(
            date: day,
            startMinute: 300 + i * 30,
            durationMinutes: 30,
            title: 'b$i');
        if (i < doneCount) {
          await repo.updateDayBlock(id, const DayBlocksCompanion(done: Value(true)));
        }
      }
    }

    test('counts good days at the 80% threshold', () async {
      await planDay(DateTime(2026, 6, 1), 5, 5); // 100% good
      await planDay(DateTime(2026, 6, 2), 5, 4); // 80%  good
      await planDay(DateTime(2026, 6, 3), 5, 3); // 60%  not good
      final stats = await repo.monthConsistency(2026, 6,
          today: DateTime(2026, 6, 30));
      expect(stats.plannedDays, 3);
      expect(stats.goodDays, 2);
      expect(stats.perDay[DateTime(2026, 6, 3)], 0.6);
    });

    test('future planned days are not judged yet', () async {
      await planDay(DateTime(2026, 6, 10), 2, 2);
      await planDay(DateTime(2026, 6, 25), 2, 0); // future
      final stats =
          await repo.monthConsistency(2026, 6, today: DateTime(2026, 6, 10));
      expect(stats.plannedDays, 1);
      expect(stats.goodDays, 1);
      expect(stats.perDay.length, 2, reason: 'dots still shown for future');
    });

    test('rank ladder', () {
      expect(DayPlanRepository.rankFor(0, 0), 'Sprouting');
      expect(DayPlanRepository.rankFor(20, 20), 'Stoic');
      expect(DayPlanRepository.rankFor(20, 19), 'Stoic');
      expect(DayPlanRepository.rankFor(20, 17), 'Disciplined');
      expect(DayPlanRepository.rankFor(20, 13), 'Steady');
      expect(DayPlanRepository.rankFor(20, 9), 'Wandering');
      expect(DayPlanRepository.rankFor(20, 2), 'Sprouting');
    });
  });
}
