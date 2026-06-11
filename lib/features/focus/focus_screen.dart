import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../data/db/database.dart';
import '../../data/repos/pomodoro_repository.dart';
import '../../design/tokens.dart';
import '../today/providers.dart' show allTasksProvider;
import 'pomodoro_controller.dart';

final focusStatsProvider = StreamProvider<FocusStats>((ref) {
  ref.watch(pomodoroProvider); // refresh as sessions get logged
  return ref.watch(pomodoroRepositoryProvider).watchStats();
});

/// The Focus module (SPEC §5.5): pomodoro ring, task link, break prompt,
/// and gentle stats.
class FocusScreen extends ConsumerWidget {
  const FocusScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pomo = ref.watch(pomodoroProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text('Focus', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 12),
            Center(child: _TimerRing(state: pomo)),
            const SizedBox(height: 16),
            const _Controls(),
            const SizedBox(height: 8),
            if (pomo.phase == PomodoroPhase.shortBreak ||
                pomo.phase == PomodoroPhase.longBreak)
              const _BreakCard(),
            const Divider(height: 32),
            const _StatsSection(),
          ],
        ),
      ),
    );
  }
}

class _TimerRing extends ConsumerWidget {
  const _TimerRing({required this.state});

  final PomodoroState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.komorebi;
    final config = ref.read(pomodoroProvider.notifier).config;
    final now = DateTime.now();

    final total = switch (state.phase) {
      PomodoroPhase.work || PomodoroPhase.idle => config.work,
      PomodoroPhase.shortBreak => config.shortBreak,
      PomodoroPhase.longBreak => config.longBreak,
    };
    final remaining = state.running ? state.remaining(now) : total;
    final clamped = remaining.isNegative ? Duration.zero : remaining;
    final fraction =
        state.running ? 1 - clamped.inSeconds / max(total.inSeconds, 1) : 0.0;

    final label = switch (state.phase) {
      PomodoroPhase.idle => 'ready',
      PomodoroPhase.work => 'focus',
      PomodoroPhase.shortBreak => 'short break',
      PomodoroPhase.longBreak => 'long break',
    };
    final minutes = clamped.inMinutes.toString().padLeft(2, '0');
    final seconds = (clamped.inSeconds % 60).toString().padLeft(2, '0');

    return SizedBox(
      width: 220,
      height: 220,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: fraction.clamp(0, 1),
              strokeWidth: 10,
              strokeCap: StrokeCap.round,
              backgroundColor: tokens.accentSoft,
              color: state.phase == PomodoroPhase.work
                  ? tokens.accent
                  : tokens.coolAccent,
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('$minutes:$seconds',
                  style: Theme.of(context).textTheme.displaySmall),
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .labelMedium
                      ?.copyWith(color: tokens.inkSoft)),
              if (state.taskTitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Chip(
                    label: Text(state.taskTitle!,
                        style: const TextStyle(fontSize: 11)),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Controls extends ConsumerWidget {
  const _Controls();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pomo = ref.watch(pomodoroProvider);
    final controller = ref.read(pomodoroProvider.notifier);

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: switch (pomo.phase) {
        PomodoroPhase.idle => [
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow),
              label: const Text('Start focus'),
              onPressed: () => controller.startWork(
                  taskId: pomo.taskId, taskTitle: pomo.taskTitle),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.link),
              label: Text(pomo.taskTitle == null
                  ? 'Link a task'
                  : 'Task: ${pomo.taskTitle}'),
              onPressed: () => _pickTask(context, ref),
            ),
            IconButton(
              tooltip: 'Timer settings',
              icon: const Icon(Icons.tune),
              onPressed: () => _showDurations(context, ref),
            ),
          ],
        PomodoroPhase.work => [
            OutlinedButton.icon(
              icon: const Icon(Icons.stop),
              label: const Text('Give up gently'),
              onPressed: controller.stop,
            ),
          ],
        _ => [
            OutlinedButton.icon(
              icon: const Icon(Icons.skip_next),
              label: const Text('Skip break'),
              onPressed: controller.skipBreak,
            ),
          ],
      },
    );
  }

  Future<void> _pickTask(BuildContext context, WidgetRef ref) async {
    final tasks = ref.read(allTasksProvider).value ?? const <Task>[];
    final controller = ref.read(pomodoroProvider.notifier);
    await showDialog<void>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Focus on…'),
        children: [
          SimpleDialogOption(
            child: const Text('Nothing in particular'),
            onPressed: () {
              controller.linkTask();
              Navigator.of(context).pop();
            },
          ),
          for (final task in tasks.take(12))
            SimpleDialogOption(
              child: Text(task.title),
              onPressed: () {
                controller.linkTask(taskId: task.id, taskTitle: task.title);
                Navigator.of(context).pop();
              },
            ),
        ],
      ),
    );
  }

  Future<void> _showDurations(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(pomodoroProvider.notifier);
    var config = controller.config;
    final repo = ref.read(pomodoroRepositoryProvider);

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          Widget stepper(
              String label, int value, void Function(int) onChanged) {
            return Row(
              children: [
                Expanded(child: Text(label)),
                IconButton(
                  icon: const Icon(Icons.remove),
                  onPressed: value > 5
                      ? () => setState(() => onChanged(value - 5))
                      : null,
                ),
                Text('$value min'),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: () => setState(() => onChanged(value + 5)),
                ),
              ],
            );
          }

          return AlertDialog(
            title: const Text('Timer settings'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                stepper('Focus', config.work.inMinutes, (v) {
                  config = (
                    work: Duration(minutes: v),
                    shortBreak: config.shortBreak,
                    longBreak: config.longBreak,
                    longEvery: config.longEvery,
                  );
                }),
                stepper('Short break', config.shortBreak.inMinutes, (v) {
                  config = (
                    work: config.work,
                    shortBreak: Duration(minutes: v),
                    longBreak: config.longBreak,
                    longEvery: config.longEvery,
                  );
                }),
                stepper('Long break', config.longBreak.inMinutes, (v) {
                  config = (
                    work: config.work,
                    shortBreak: config.shortBreak,
                    longBreak: Duration(minutes: v),
                    longEvery: config.longEvery,
                  );
                }),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  await repo.saveConfig(config);
                  await controller.reloadConfig();
                  if (context.mounted) Navigator.of(context).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BreakCard extends ConsumerWidget {
  const _BreakCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.komorebi;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.castle_outlined, color: tokens.accent, size: 32),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('A real break: stack a quick tower while '
                  'the kettle boils?'),
            ),
            FilledButton(
              onPressed: () => context.go('/play'),
              child: const Text('Play'),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsSection extends ConsumerWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.komorebi;
    final stats = ref.watch(focusStatsProvider).value;
    if (stats == null) return const SizedBox.shrink();

    final maxMinutes =
        stats.last7Days.fold<int>(1, (acc, d) => max(acc, d.minutes));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('This week', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          '${stats.todayMinutes} focused minute'
          '${stats.todayMinutes == 1 ? '' : 's'} today',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: tokens.inkSoft),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final day in stats.last7Days)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (day.minutes > 0)
                          Text('${day.minutes}',
                              style: TextStyle(
                                  fontSize: 9, color: tokens.inkSoft)),
                        const SizedBox(height: 2),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          height: 64 * day.minutes / maxMinutes + 2,
                          decoration: BoxDecoration(
                            color: tokens.accent,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(DateFormat.E().format(day.day).substring(0, 1),
                            style: TextStyle(
                                fontSize: 10, color: tokens.inkSoft)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (stats.topTasks.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Most focused on',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          for (final task in stats.topTasks)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Icon(Icons.local_florist, size: 14, color: tokens.accent),
                  const SizedBox(width: 8),
                  Expanded(child: Text(task.title)),
                  Text('${task.minutes} min',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: tokens.inkSoft)),
                ],
              ),
            ),
        ],
      ],
    );
  }
}
