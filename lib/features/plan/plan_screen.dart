import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db/database.dart';
import '../../data/repos/day_plan_repository.dart';
import '../../design/tokens.dart';
import 'providers.dart';
import 'routine_manager.dart';

String minuteLabel(int minute) {
  final h = (minute ~/ 60).toString().padLeft(2, '0');
  final m = (minute % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

/// The Day Plan tab (SPEC §5.8): a 48-slab half-hour grid for the selected
/// date, with check-offs, a day score, and the monthly consistency sheet.
class PlanScreen extends ConsumerWidget {
  const PlanScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final date = ref.watch(selectedPlanDateProvider);
    final blocksAsync = ref.watch(dayBlocksProvider(date));
    final isToday = date == DayPlanRepository.dateOnly(DateTime.now());

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Previous day',
                    icon: const Icon(Icons.chevron_left),
                    onPressed: () =>
                        ref.read(selectedPlanDateProvider.notifier).shift(-1),
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: isToday
                          ? null
                          : () => ref
                              .read(selectedPlanDateProvider.notifier)
                              .set(DateTime.now()),
                      child: Column(
                        children: [
                          Text(
                            isToday
                                ? 'Today'
                                : DateFormat.EEEE().format(date),
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          Text(
                            DateFormat.yMMMd().format(date) +
                                (isToday ? '' : '  ·  tap for today'),
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(color: context.komorebi.inkSoft),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Next day',
                    icon: const Icon(Icons.chevron_right),
                    onPressed: () =>
                        ref.read(selectedPlanDateProvider.notifier).shift(1),
                  ),
                  _DayScoreChip(blocks: blocksAsync.value ?? const []),
                  PopupMenuButton<String>(
                    tooltip: 'Plan menu',
                    onSelected: (action) => switch (action) {
                      'month' => _showMonthSheet(context, ref),
                      'routines' => showRoutineManager(context),
                      'reset' => ref
                          .read(dayPlanRepositoryProvider)
                          .resetDayToRoutine(date),
                      _ => null,
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                          value: 'month',
                          child: Text('Month consistency')),
                      PopupMenuItem(
                          value: 'routines', child: Text('Manage routines')),
                      PopupMenuItem(
                          value: 'reset',
                          child: Text('Reset day to routine')),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: blocksAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Could not load plan: $e')),
                data: (blocks) => _DayGrid(date: date, blocks: blocks),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMonthSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (_) => const MonthConsistencySheet(),
    );
  }
}

class _DayScoreChip extends StatelessWidget {
  const _DayScoreChip({required this.blocks});

  final List<DayBlock> blocks;

  @override
  Widget build(BuildContext context) {
    final tokens = context.komorebi;
    if (blocks.isEmpty) return const SizedBox.shrink();
    final done = blocks.where((b) => b.done).length;
    final fraction = done / blocks.length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              value: fraction,
              strokeWidth: 3,
              backgroundColor: tokens.accentSoft,
              color: tokens.accent,
            ),
          ),
          const SizedBox(width: 6),
          Text('$done/${blocks.length}',
              style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

/// The 48-slab grid. Blocks spanning several slabs render once, with
/// proportional height; uncovered slabs are tappable to add a block.
class _DayGrid extends StatefulWidget {
  const _DayGrid({required this.date, required this.blocks});

  final DateTime date;
  final List<DayBlock> blocks;

  static const slabHeight = 48.0;
  static const morningScrollSlab = 10; // 05:00

  @override
  State<_DayGrid> createState() => _DayGridState();
}

class _DayGridState extends State<_DayGrid> {
  final _scroll = ScrollController(
      initialScrollOffset: _DayGrid.morningScrollSlab * _DayGrid.slabHeight);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    var minute = 0;
    final byStart = {for (final b in widget.blocks) b.startMinute: b};

    while (minute < 24 * 60) {
      final block = byStart[minute];
      if (block != null) {
        rows.add(_BlockCard(block: block, date: widget.date));
        minute += block.durationMinutes;
      } else {
        rows.add(_EmptySlab(date: widget.date, minute: minute));
        minute += 30;
      }
    }

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.only(bottom: 32),
      children: rows,
    );
  }
}

class _EmptySlab extends ConsumerWidget {
  const _EmptySlab({required this.date, required this.minute});

  final DateTime date;
  final int minute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.komorebi;
    return SizedBox(
      height: _DayGrid.slabHeight,
      child: InkWell(
        onTap: () => showBlockDialog(context, ref, date: date, startMinute: minute),
        child: Row(
          children: [
            SizedBox(
              width: 64,
              child: Text(
                minuteLabel(minute),
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: tokens.inkSoft),
              ),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                decoration: BoxDecoration(
                  border: Border(
                      top: BorderSide(color: tokens.cardBorder, width: 0.5)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BlockCard extends ConsumerWidget {
  const _BlockCard({required this.block, required this.date});

  final DayBlock block;
  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.komorebi;
    final slabs = block.durationMinutes ~/ 30;
    final repo = ref.read(dayPlanRepositoryProvider);

    return SizedBox(
      height: _DayGrid.slabHeight * slabs,
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(
              minuteLabel(block.startMinute),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: tokens.ink),
            ),
          ),
          Expanded(
            child: Card(
              margin: const EdgeInsets.fromLTRB(0, 3, 16, 3),
              color: block.done
                  ? tokens.accentSoft
                  : tokens.paperRaised,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => showBlockDialog(context, ref,
                    date: date, startMinute: block.startMinute, block: block),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      InkWell(
                        key: ValueKey('block-check-${block.id}'),
                        customBorder: const CircleBorder(),
                        onTap: () => repo.toggleDone(block),
                        child: Icon(
                          block.done
                              ? Icons.check_circle
                              : Icons.circle_outlined,
                          color: block.done ? tokens.accent : tokens.inkSoft,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              block.title,
                              maxLines: slabs,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    decoration: block.done
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                            ),
                            Text(
                              '${minuteLabel(block.startMinute)} – '
                              '${minuteLabel(block.startMinute + block.durationMinutes)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: tokens.inkSoft),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Add (block == null) or edit a day block.
Future<void> showBlockDialog(
  BuildContext context,
  WidgetRef ref, {
  required DateTime date,
  required int startMinute,
  DayBlock? block,
}) {
  final title = TextEditingController(text: block?.title ?? '');
  var start = block?.startMinute ?? startMinute;
  var duration = block?.durationMinutes ?? 30;
  final repo = ref.read(dayPlanRepositoryProvider);

  return showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(block == null ? 'Plan a block' : 'Edit block'),
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
                      DropdownMenuItem(value: m, child: Text(minuteLabel(m))),
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
                  tooltip: 'Shorter',
                  icon: const Icon(Icons.remove),
                  onPressed: duration > 30
                      ? () => setState(() => duration -= 30)
                      : null,
                ),
                Text(duration % 60 == 0
                    ? '${duration ~/ 60} h'
                    : '${duration ~/ 60 > 0 ? '${duration ~/ 60} h ' : ''}30 m'),
                IconButton(
                  tooltip: 'Longer',
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
          if (block != null)
            TextButton(
              onPressed: () async {
                await repo.deleteDayBlock(block.id);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Delete'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (title.text.trim().isEmpty) return;
              try {
                if (block == null) {
                  await repo.addDayBlock(
                    date: date,
                    startMinute: start,
                    durationMinutes: duration,
                    title: title.text.trim(),
                  );
                } else {
                  await repo.updateDayBlock(
                    block.id,
                    DayBlocksCompanion(
                      title: Value(title.text.trim()),
                      startMinute: Value(start),
                      durationMinutes: Value(duration),
                    ),
                  );
                }
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

/// Month sheet: rank, good days, and a dot per planned day.
class MonthConsistencySheet extends ConsumerWidget {
  const MonthConsistencySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.komorebi;
    final date = ref.watch(selectedPlanDateProvider);
    final statsAsync = ref.watch(monthConsistencyProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('Could not load stats: $e'),
        data: (stats) {
          final daysInMonth = DateUtils.getDaysInMonth(date.year, date.month);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(DateFormat.yMMMM().format(date),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${stats.rank} · ${stats.goodDays} good '
                'day${stats.goodDays == 1 ? '' : 's'} of '
                '${stats.plannedDays} planned',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: tokens.inkSoft),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var d = 1; d <= daysInMonth; d++)
                    _DayDot(
                      day: d,
                      fraction:
                          stats.perDay[DateTime(date.year, date.month, d)],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'A day counts as good when at least 80% of its blocks are '
                'done. Quiet days are not judged.',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: tokens.inkSoft),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({required this.day, required this.fraction});

  final int day;
  final double? fraction;

  @override
  Widget build(BuildContext context) {
    final tokens = context.komorebi;
    final Color color;
    if (fraction == null) {
      color = tokens.cardBorder;
    } else if (fraction! >= DayPlanRepository.goodDayThreshold) {
      color = tokens.accent;
    } else if (fraction! > 0) {
      color = tokens.coolAccent;
    } else {
      color = tokens.warmAccent;
    }
    return Tooltip(
      message: fraction == null
          ? '$day — nothing planned'
          : '$day — ${(fraction! * 100).round()}% done',
      child: Container(
        width: 18,
        height: 18,
        alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        child: Text(
          '$day',
          style: TextStyle(fontSize: 8, color: tokens.paper),
        ),
      ),
    );
  }
}
