import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/repos/day_plan_repository.dart';
import '../../design/tokens.dart';
import 'plan_screen.dart' show minuteLabel;
import 'providers.dart';

const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Opens the routine manager: create routines, bind them to weekdays,
/// and edit their blocks (SPEC §5.8).
Future<void> showRoutineManager(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => const FractionallySizedBox(
      heightFactor: 0.8,
      child: _RoutineManagerSheet(),
    ),
  );
}

class _RoutineManagerSheet extends ConsumerWidget {
  const _RoutineManagerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routines = ref.watch(routinesProvider).value ?? const <Routine>[];
    final repo = ref.read(dayPlanRepositoryProvider);
    final tokens = context.komorebi;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Routines',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('New routine'),
                onPressed: () async {
                  final name = await _promptName(context);
                  if (name == null || name.trim().isEmpty) return;
                  await repo.createRoutine(name.trim());
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Each weekday uses the first routine bound to it. New days copy '
            'their routine; edits to a day stay on that day.',
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: tokens.inkSoft),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: routines.isEmpty
                ? Center(
                    child: Text(
                      'No routines yet.\nCreate "Training day" or '
                      '"Rest day" to plan your ideal days.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: tokens.inkSoft),
                    ),
                  )
                : ListView(
                    children: [
                      for (final routine in routines)
                        _RoutineTile(routine: routine),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Future<String?> _promptName(BuildContext context) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New routine'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'e.g. Training day'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(controller.text),
              child: const Text('Create')),
        ],
      ),
    );
  }
}

class _RoutineTile extends ConsumerWidget {
  const _RoutineTile({required this.routine});

  final Routine routine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(dayPlanRepositoryProvider);
    final blocks =
        ref.watch(routineBlocksProvider(routine.id)).value ?? const [];
    final tokens = context.komorebi;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(routine.name,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                IconButton(
                  tooltip: 'Delete routine',
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () => repo.deleteRoutine(routine.id),
                ),
              ],
            ),
            Wrap(
              spacing: 4,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    label: Text(_weekdayLabels[day - 1]),
                    visualDensity: VisualDensity.compact,
                    selected: routine.weekdays &
                            DayPlanRepository.weekdayBit(day) !=
                        0,
                    onSelected: (sel) {
                      final bit = DayPlanRepository.weekdayBit(day);
                      repo.updateRoutine(
                        routine.id,
                        RoutinesCompanion(
                          weekdays: Value(sel
                              ? routine.weekdays | bit
                              : routine.weekdays & ~bit),
                        ),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (final block in blocks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    Text(
                      '${minuteLabel(block.startMinute)} – '
                      '${minuteLabel(block.startMinute + block.durationMinutes)}',
                      style: Theme.of(context)
                          .textTheme
                          .labelMedium
                          ?.copyWith(color: tokens.inkSoft),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(block.title)),
                    InkWell(
                      onTap: () => repo.deleteRoutineBlock(block.id),
                      child: Icon(Icons.close,
                          size: 16, color: tokens.inkSoft),
                    ),
                  ],
                ),
              ),
            TextButton.icon(
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add block'),
              onPressed: () =>
                  _showRoutineBlockDialog(context, ref, routine.id),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRoutineBlockDialog(
      BuildContext context, WidgetRef ref, String routineId) {
    final title = TextEditingController();
    var start = 5 * 60;
    var duration = 30;
    final repo = ref.read(dayPlanRepositoryProvider);

    return showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Routine block'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: title,
                autofocus: true,
                decoration: const InputDecoration(
                    labelText: 'What happens here?',
                    hintText: 'e.g. Running'),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('Starts'),
                  const Spacer(),
                  DropdownButton<int>(
                    value: start,
                    items: [
                      for (var m = 0; m < 24 * 60; m += 30)
                        DropdownMenuItem(
                            value: m, child: Text(minuteLabel(m))),
                    ],
                    onChanged: (v) => setState(() => start = v!),
                  ),
                ],
              ),
              Row(
                children: [
                  const Text('Duration'),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove),
                    onPressed: duration > 30
                        ? () => setState(() => duration -= 30)
                        : null,
                  ),
                  Text(duration % 60 == 0
                      ? '${duration ~/ 60} h'
                      : '${duration ~/ 60 > 0 ? '${duration ~/ 60} h ' : ''}30 m'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: start + duration + 30 <= 24 * 60
                        ? () => setState(() => duration += 30)
                        : null,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                if (title.text.trim().isEmpty) return;
                try {
                  await repo.addRoutineBlock(
                    routineId: routineId,
                    startMinute: start,
                    durationMinutes: duration,
                    title: title.text.trim(),
                  );
                  if (context.mounted) Navigator.of(context).pop();
                } on StateError catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(e.message)));
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
