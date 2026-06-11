import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db/database.dart';
import '../../data/repos/event_repository.dart';
import '../../design/tokens.dart';
import '../today/widgets/task_editor.dart';
import 'event_editor.dart';
import 'providers.dart';

/// The calendar module (SPEC §5.3): custom month grid with events and dated
/// tasks side by side, plus a selected-day agenda.
class CalendarScreen extends ConsumerWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(focusedMonthProvider);
    final selected = ref.watch(selectedDayProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'New event',
        onPressed: () => showEventEditor(context, ref, initialDay: selected),
        child: const Icon(Icons.add),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous month',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () =>
                        ref.read(focusedMonthProvider.notifier).shift(-1),
                  ),
                  Expanded(
                    child: Text(
                      DateFormat.yMMMM().format(month),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next month',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () =>
                        ref.read(focusedMonthProvider.notifier).shift(1),
                  ),
                  TextButton(
                    onPressed: () {
                      ref.read(focusedMonthProvider.notifier).today();
                      ref
                          .read(selectedDayProvider.notifier)
                          .set(DateTime.now());
                    },
                    child: const Text('Today'),
                  ),
                ],
              ),
            ),
            const _WeekdayHeader(),
            const Expanded(flex: 5, child: _MonthGrid()),
            const Divider(height: 1),
            const Expanded(flex: 4, child: _DayAgenda()),
          ],
        ),
      ),
    );
  }
}

class _WeekdayHeader extends StatelessWidget {
  const _WeekdayHeader();

  @override
  Widget build(BuildContext context) {
    final tokens = context.komorebi;
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          for (final label in labels)
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: tokens.inkSoft),
              ),
            ),
        ],
      ),
    );
  }
}

class _MonthGrid extends ConsumerWidget {
  const _MonthGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(focusedMonthProvider);
    final selected = ref.watch(selectedDayProvider);
    final occurrences =
        ref.watch(monthEventsProvider).value ?? const <EventOccurrence>[];
    final tasks = ref.watch(monthTasksProvider).value ?? const <Task>[];
    final tokens = context.komorebi;
    final today = DateUtils.dateOnly(DateTime.now());
    final (gridStart, _) = gridWindow(month);

    final eventsByDay = <DateTime, List<EventOccurrence>>{};
    for (final o in occurrences) {
      final day = DateUtils.dateOnly(o.start);
      eventsByDay.putIfAbsent(day, () => []).add(o);
    }
    final taskCountByDay = <DateTime, int>{};
    for (final t in tasks) {
      final day = DateUtils.dateOnly(t.dueAt ?? t.scheduledAt!);
      taskCountByDay[day] = (taskCountByDay[day] ?? 0) + 1;
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: (MediaQuery.sizeOf(context).width / 7) /
            (MediaQuery.sizeOf(context).height * 5 / 9 / 6),
      ),
      itemCount: 42,
      itemBuilder: (context, index) {
        final day = gridStart.add(Duration(days: index));
        final inMonth = day.month == month.month;
        final isToday = day == today;
        final isSelected = day == selected;
        final dayEvents = eventsByDay[day] ?? const <EventOccurrence>[];
        final taskCount = taskCountByDay[day] ?? 0;

        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => ref.read(selectedDayProvider.notifier).set(day),
          child: Container(
            margin: const EdgeInsets.all(1.5),
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: isSelected ? tokens.accentSoft : null,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isToday ? tokens.accent : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${day.day}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: inMonth ? tokens.ink : tokens.inkSoft,
                        fontWeight: isToday ? FontWeight.bold : null,
                      ),
                ),
                const SizedBox(height: 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final o in dayEvents.take(2))
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 1.5),
                          padding:
                              const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: (o.event.color != null
                                    ? Color(o.event.color!)
                                    : tokens.accent)
                                .withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            o.event.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 9, color: tokens.paper),
                          ),
                        ),
                      Row(
                        children: [
                          if (dayEvents.length > 2)
                            Text('+${dayEvents.length - 2}',
                                style: TextStyle(
                                    fontSize: 9, color: tokens.inkSoft)),
                          if (taskCount > 0) ...[
                            Icon(Icons.check_circle_outline,
                                size: 10, color: tokens.coolAccent),
                            Text('$taskCount',
                                style: TextStyle(
                                    fontSize: 9,
                                    color: tokens.coolAccent)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DayAgenda extends ConsumerWidget {
  const _DayAgenda();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedDayProvider);
    final occurrences =
        ref.watch(monthEventsProvider).value ?? const <EventOccurrence>[];
    final tasks = ref.watch(monthTasksProvider).value ?? const <Task>[];
    final tokens = context.komorebi;

    final dayEvents = occurrences
        .where((o) => DateUtils.dateOnly(o.start) == selected)
        .toList();
    final dayTasks = tasks
        .where((t) =>
            DateUtils.dateOnly(t.dueAt ?? t.scheduledAt!) == selected)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          child: Text(
            DateFormat.MMMMEEEEd().format(selected),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: dayEvents.isEmpty && dayTasks.isEmpty
              ? Center(
                  child: Text(
                    'An open day. Tap + to plan something gentle.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: tokens.inkSoft),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.only(bottom: 80),
                  children: [
                    for (final o in dayEvents)
                      ListTile(
                        dense: true,
                        leading: Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: o.event.color != null
                                ? Color(o.event.color!)
                                : tokens.accent,
                          ),
                        ),
                        title: Text(o.event.title),
                        subtitle: o.event.notes.isEmpty
                            ? null
                            : Text(o.event.notes,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                        trailing: Text(
                          o.allDay
                              ? 'all day'
                              : '${DateFormat.Hm().format(o.start)}'
                                  '${o.end != null ? ' – ${DateFormat.Hm().format(o.end!)}' : ''}',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: tokens.inkSoft),
                        ),
                        onTap: () => showEventEditor(context, ref,
                            event: o.event),
                      ),
                    for (final task in dayTasks)
                      ListTile(
                        dense: true,
                        leading: Icon(Icons.check_circle_outline,
                            size: 18, color: tokens.coolAccent),
                        title: Text(task.title),
                        trailing: Text(
                          task.dueAt != null ? 'due' : 'scheduled',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(color: tokens.coolAccent),
                        ),
                        onTap: () =>
                            showTaskEditor(context, taskId: task.id),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}
