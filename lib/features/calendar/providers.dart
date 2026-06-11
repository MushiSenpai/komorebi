import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/repos/event_repository.dart';

/// First day of the month currently shown.
final focusedMonthProvider =
    NotifierProvider<FocusedMonthNotifier, DateTime>(FocusedMonthNotifier.new);

class FocusedMonthNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month);
  }

  void shift(int months) => state = DateTime(state.year, state.month + months);

  void today() {
    final now = DateTime.now();
    state = DateTime(now.year, now.month);
  }
}

final selectedDayProvider =
    NotifierProvider<SelectedDayNotifier, DateTime>(SelectedDayNotifier.new);

class SelectedDayNotifier extends Notifier<DateTime> {
  @override
  DateTime build() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  void set(DateTime day) => state = DateTime(day.year, day.month, day.day);
}

/// The visible grid window: Monday before the 1st → after the last cell.
(DateTime, DateTime) gridWindow(DateTime month) {
  final first = DateTime(month.year, month.month);
  final start = first.subtract(Duration(days: first.weekday - 1));
  return (start, start.add(const Duration(days: 42)));
}

final monthEventsProvider = StreamProvider<List<EventOccurrence>>((ref) {
  final month = ref.watch(focusedMonthProvider);
  final (from, to) = gridWindow(month);
  return ref.watch(eventRepositoryProvider).watchWindow(from, to);
});

final monthTasksProvider = StreamProvider<List<Task>>((ref) {
  final month = ref.watch(focusedMonthProvider);
  final (from, to) = gridWindow(month);
  return ref.watch(taskRepositoryProvider).watchDatedInWindow(from, to);
});
