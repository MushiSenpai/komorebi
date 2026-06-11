import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../design/tokens.dart';
import 'providers.dart';
import 'quick_add_parser.dart';
import 'widgets/task_tile.dart';

/// The todo module: quick-add bar + Today / Upcoming / All / Done views
/// (SPEC §5.1).
class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(taskViewProvider);

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Text(
                DateFormat.MMMMEEEEd().format(DateTime.now()),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: _QuickAddBar(),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: SegmentedButton<TaskView>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: TaskView.today, label: Text('Today')),
                  ButtonSegment(
                      value: TaskView.upcoming, label: Text('Upcoming')),
                  ButtonSegment(value: TaskView.all, label: Text('All')),
                  ButtonSegment(value: TaskView.done, label: Text('Done')),
                ],
                selected: {view},
                onSelectionChanged: (s) =>
                    ref.read(taskViewProvider.notifier).set(s.first),
              ),
            ),
            Expanded(
              child: switch (view) {
                TaskView.today => const _TodayView(),
                TaskView.upcoming => const _UpcomingView(),
                TaskView.all => const _AllView(),
                TaskView.done => const _DoneView(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAddBar extends ConsumerStatefulWidget {
  const _QuickAddBar();

  @override
  ConsumerState<_QuickAddBar> createState() => _QuickAddBarState();
}

class _QuickAddBarState extends ConsumerState<_QuickAddBar> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit(String input) async {
    if (input.trim().isEmpty) return;
    final parsed = parseQuickAdd(input);
    if (parsed.title.isEmpty) return;
    final repo = ref.read(taskRepositoryProvider);

    final projectId = parsed.project == null
        ? null
        : await repo.ensureProject(parsed.project!);
    final tagIds = <String>[
      for (final tag in parsed.tags) await repo.ensureTag(tag),
    ];
    await repo.createTask(
      title: parsed.title,
      projectId: projectId,
      priority: parsed.priority,
      dueAt: parsed.dueAt,
      tagIds: tagIds,
    );
    _controller.clear();
    _focus.requestFocus();

    // A task without a date won't appear on the default Today view — make
    // sure the user sees where it went.
    if (parsed.dueAt == null &&
        ref.read(taskViewProvider) == TaskView.today &&
        mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('Added "${parsed.title}" — no date, see All'),
          action: SnackBarAction(
            label: 'View',
            onPressed: () =>
                ref.read(taskViewProvider.notifier).set(TaskView.all),
          ),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focus,
      decoration: InputDecoration(
        hintText: 'Add a task…  e.g. "water plants tomorrow !p1 #home @garden"',
        prefixIcon: const Icon(Icons.add),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        isDense: true,
      ),
      textInputAction: TextInputAction.done,
      onSubmitted: _submit,
    );
  }
}

class _TodayView extends ConsumerWidget {
  const _TodayView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _TaskListView(
      tasks: ref.watch(todayTasksProvider),
      emptyTitle: 'Nothing due today',
      emptyMessage:
          'The meadow is quiet. Add a task above, or enjoy the sunshine.',
    );
  }
}

class _UpcomingView extends ConsumerWidget {
  const _UpcomingView();

  String _dayLabel(DateTime day) {
    final today = DateUtils.dateOnly(DateTime.now());
    final diff = day.difference(today).inDays;
    if (diff == 1) return 'Tomorrow';
    return DateFormat.EEEE().format(day);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(upcomingTasksProvider);
    final tokens = context.komorebi;

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load tasks: $e')),
      data: (tasks) {
        if (tasks.isEmpty) {
          return const _EmptyState(
            title: 'A clear week ahead',
            message: 'Nothing scheduled for the next seven days.',
          );
        }
        final byDay = <DateTime, List<Task>>{};
        for (final task in tasks) {
          final date = DateUtils.dateOnly(task.dueAt ?? task.scheduledAt!);
          byDay.putIfAbsent(date, () => []).add(task);
        }
        final days = byDay.keys.toList()..sort();
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            for (final day in days) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
                child: Text(
                  '${_dayLabel(day)} · ${DateFormat.MMMd().format(day)}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(color: tokens.inkSoft),
                ),
              ),
              for (final task in byDay[day]!) TaskTile(task: task),
            ],
          ],
        );
      },
    );
  }
}

class _AllView extends ConsumerWidget {
  const _AllView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(allTasksProvider);
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final tags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final tagsByTask = ref.watch(tagsByTaskProvider).value ?? const {};
    final priorityFilter = ref.watch(priorityFilterProvider);
    final tagFilter = ref.watch(tagFilterProvider);
    final tokens = context.komorebi;

    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load tasks: $e')),
      data: (tasks) {
        var filtered = tasks;
        if (priorityFilter != null) {
          filtered =
              filtered.where((t) => t.priority == priorityFilter).toList();
        }
        if (tagFilter != null) {
          filtered = filtered
              .where((t) =>
                  (tagsByTask[t.id] ?? []).any((tag) => tag.id == tagFilter))
              .toList();
        }

        final projectNames = {for (final p in projects) p.id: p.name};
        final byProject = <String?, List<Task>>{};
        for (final task in filtered) {
          byProject.putIfAbsent(task.projectId, () => []).add(task);
        }
        final keys = byProject.keys.toList()
          ..sort((a, b) => (projectNames[a] ?? 'zzz No project')
              .compareTo(projectNames[b] ?? 'zzz No project'));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  for (final p in const [1, 2, 3])
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text('P$p'),
                        selected: priorityFilter == p,
                        onSelected: (sel) => ref
                            .read(priorityFilterProvider.notifier)
                            .set(sel ? p : null),
                      ),
                    ),
                  for (final tag in tags)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text('#${tag.name}'),
                        selected: tagFilter == tag.id,
                        onSelected: (sel) => ref
                            .read(tagFilterProvider.notifier)
                            .set(sel ? tag.id : null),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? const _EmptyState(
                      title: 'No tasks here',
                      message: 'Nothing matches — adjust the filters or add '
                          'a task above.',
                    )
                  : ListView(
                      padding: const EdgeInsets.only(bottom: 24),
                      children: [
                        for (final key in keys) ...[
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(20, 16, 20, 4),
                            child: Text(
                              projectNames[key] ?? 'No project',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(color: tokens.inkSoft),
                            ),
                          ),
                          for (final task in byProject[key]!)
                            TaskTile(task: task),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _DoneView extends ConsumerWidget {
  const _DoneView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(completedTasksProvider);
    return tasksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load tasks: $e')),
      data: (tasks) => tasks.isEmpty
          ? const _EmptyState(
              title: 'Nothing finished yet',
              message: 'Completed tasks rest here, in case you need them back.',
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                for (final task in tasks)
                  TaskTile(task: task, showRestore: true),
              ],
            ),
    );
  }
}

class _TaskListView extends StatelessWidget {
  const _TaskListView({
    required this.tasks,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final AsyncValue<List<Task>> tasks;
  final String emptyTitle;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    return tasks.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load tasks: $e')),
      data: (list) => list.isEmpty
          ? _EmptyState(title: emptyTitle, message: emptyMessage)
          : ListView(
              padding: const EdgeInsets.only(top: 4, bottom: 24),
              children: [for (final task in list) TaskTile(task: task)],
            ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final tokens = context.komorebi;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: tokens.accentSoft,
                shape: BoxShape.circle,
                border: Border.all(color: tokens.cardBorder),
              ),
              child: Icon(Icons.eco, size: 32, color: tokens.ink),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: tokens.inkSoft),
            ),
          ],
        ),
      ),
    );
  }
}
