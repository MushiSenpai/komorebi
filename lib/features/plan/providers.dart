import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/repos/day_plan_repository.dart';

final dayPlanRepositoryProvider = Provider<DayPlanRepository>(
  (ref) => DayPlanRepository(ref.watch(databaseProvider)),
);

/// The date shown on the Plan tab.
final selectedPlanDateProvider =
    NotifierProvider<SelectedPlanDateNotifier, DateTime>(
        SelectedPlanDateNotifier.new);

class SelectedPlanDateNotifier extends Notifier<DateTime> {
  @override
  DateTime build() => DayPlanRepository.dateOnly(DateTime.now());

  void set(DateTime date) => state = DayPlanRepository.dateOnly(date);

  void shift(int days) => state = state.add(Duration(days: days));
}

/// Blocks for a date. Materialization from the day's routine runs as a
/// side effect rather than gating the stream: the grid renders immediately
/// and the copied blocks land through the watch stream.
final dayBlocksProvider =
    StreamProvider.family<List<DayBlock>, DateTime>((ref, date) {
  final repo = ref.watch(dayPlanRepositoryProvider);
  Future(() => repo.materializeDay(date)).ignore();
  return repo.watchDay(date);
});

final routinesProvider = StreamProvider<List<Routine>>((ref) {
  return ref.watch(dayPlanRepositoryProvider).watchRoutines();
});

final routineBlocksProvider =
    StreamProvider.family<List<RoutineBlock>, String>((ref, routineId) {
  return ref.watch(dayPlanRepositoryProvider).watchRoutineBlocks(routineId);
});

/// Month stats for the month containing the selected date. Watching the
/// selected day's blocks keeps the rank fresh as blocks get checked off.
final monthConsistencyProvider = FutureProvider<MonthConsistency>((ref) {
  final date = ref.watch(selectedPlanDateProvider);
  ref.watch(dayBlocksProvider(date));
  return ref
      .watch(dayPlanRepositoryProvider)
      .monthConsistency(date.year, date.month);
});
