import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../design/tokens.dart';
import '../today/providers.dart' show subtaskProgressProvider, tagsByTaskProvider;
import '../today/widgets/task_editor.dart';
import 'providers.dart';

/// Kanban boards (SPEC §5.2): one board per project, drag & drop cards,
/// editable columns with soft WIP limits.
class BoardsScreen extends ConsumerWidget {
  const BoardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final selected = ref.watch(selectedProjectProvider);
    final tokens = context.komorebi;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final project in projects)
                            Padding(
                              padding: const EdgeInsets.only(right: 6),
                              child: ChoiceChip(
                                label: Text(project.name),
                                selected: project.id == selected,
                                onSelected: (_) => ref
                                    .read(selectedProjectProvider.notifier)
                                    .set(project.id),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'New project',
                    icon: const Icon(Icons.add),
                    onPressed: () async {
                      final name =
                          await _promptText(context, 'New project');
                      if (name == null || name.trim().isEmpty) return;
                      final id = await ref
                          .read(taskRepositoryProvider)
                          .ensureProject(name.trim());
                      ref.read(selectedProjectProvider.notifier).set(id);
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: selected == null
                  ? Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 380),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.view_kanban_outlined,
                                size: 48, color: tokens.inkSoft),
                            const SizedBox(height: 12),
                            Text('No projects yet',
                                style:
                                    Theme.of(context).textTheme.titleLarge),
                            const SizedBox(height: 6),
                            Text(
                              'Create a project here, or type '
                              '"@project" in the quick-add bar on Today.',
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(color: tokens.inkSoft),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _Board(projectId: selected),
            ),
          ],
        ),
      ),
    );
  }
}

class _Board extends ConsumerWidget {
  const _Board({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final columns =
        ref.watch(boardColumnsProvider(projectId)).value ?? const [];
    final tasks = ref.watch(boardTasksProvider(projectId)).value ?? const [];
    if (columns.isEmpty) return const SizedBox.shrink();

    // Tasks that never got a column (e.g. quick-add @project) belong to the
    // first column visually; moving them writes a real columnId.
    final byColumn = <String, List<Task>>{for (final c in columns) c.id: []};
    for (final task in tasks) {
      final key = byColumn.containsKey(task.columnId)
          ? task.columnId!
          : columns.first.id;
      byColumn[key]!.add(task);
    }

    return ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 16),
      children: [
        for (final column in columns)
          _BoardColumn(
            column: column,
            columns: columns,
            tasks: byColumn[column.id]!,
          ),
        _AddColumnButton(projectId: projectId),
      ],
    );
  }
}

class _BoardColumn extends ConsumerWidget {
  const _BoardColumn({
    required this.column,
    required this.columns,
    required this.tasks,
  });

  final BoardColumn column;
  final List<BoardColumn> columns;
  final List<Task> tasks;

  double _appendOrder() =>
      tasks.isEmpty ? 1 : tasks.last.sortOrder + 1;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.komorebi;
    final repo = ref.read(taskRepositoryProvider);
    final overWip =
        column.wipLimit != null && tasks.length > column.wipLimit!;

    return DragTarget<Task>(
      onWillAcceptWithDetails: (_) => true,
      onAcceptWithDetails: (details) => repo.moveTaskToColumn(
          details.data.id, column.id,
          sortOrder: _appendOrder()),
      builder: (context, candidates, _) => Container(
        width: 280,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: candidates.isNotEmpty
              ? tokens.accentSoft.withValues(alpha: 0.6)
              : tokens.paperRaised.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: tokens.cardBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Draggable<BoardColumn>(
              data: column,
              axis: Axis.horizontal,
              feedback: Material(
                color: Colors.transparent,
                child: Chip(label: Text(column.name)),
              ),
              child: DragTarget<BoardColumn>(
                onWillAcceptWithDetails: (d) => d.data.id != column.id,
                onAcceptWithDetails: (d) =>
                    repo.swapColumns(d.data, column),
                builder: (context, columnCandidates, _) => Container(
                  padding: const EdgeInsets.fromLTRB(12, 10, 4, 6),
                  decoration: BoxDecoration(
                    color: overWip
                        ? tokens.warmAccent.withValues(alpha: 0.18)
                        : columnCandidates.isNotEmpty
                            ? tokens.accentSoft
                            : null,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${column.name}  ·  ${tasks.length}'
                          '${column.wipLimit != null ? '/${column.wipLimit}' : ''}',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                color: overWip
                                    ? tokens.warmAccent
                                    : tokens.ink,
                              ),
                        ),
                      ),
                      _ColumnMenu(column: column, columns: columns),
                    ],
                  ),
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                children: [
                  for (final task in tasks)
                    _DraggableCard(task: task, column: column, tasks: tasks),
                ],
              ),
            ),
            _QuickCardField(column: column, appendOrder: _appendOrder),
          ],
        ),
      ),
    );
  }
}

class _ColumnMenu extends ConsumerWidget {
  const _ColumnMenu({required this.column, required this.columns});

  final BoardColumn column;
  final List<BoardColumn> columns;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(taskRepositoryProvider);
    return PopupMenuButton<String>(
      tooltip: 'Column menu',
      iconSize: 18,
      onSelected: (action) async {
        switch (action) {
          case 'rename':
            final name = await _promptText(context, 'Rename column',
                initial: column.name);
            if (name != null && name.trim().isNotEmpty) {
              await repo.updateColumn(
                  column.id, BoardColumnsCompanion(name: Value(name.trim())));
            }
          case 'wip':
            final raw = await _promptText(context, 'WIP limit (empty = none)',
                initial: column.wipLimit?.toString() ?? '');
            if (raw == null) return;
            final limit = int.tryParse(raw.trim());
            await repo.updateColumn(
                column.id, BoardColumnsCompanion(wipLimit: Value(limit)));
          case 'delete':
            if (columns.length > 1) await repo.deleteColumn(column.id);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(value: 'rename', child: Text('Rename')),
        const PopupMenuItem(value: 'wip', child: Text('Set WIP limit')),
        if (columns.length > 1)
          const PopupMenuItem(value: 'delete', child: Text('Delete column')),
      ],
    );
  }
}

class _DraggableCard extends ConsumerWidget {
  const _DraggableCard({
    required this.task,
    required this.column,
    required this.tasks,
  });

  final Task task;
  final BoardColumn column;
  final List<Task> tasks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(taskRepositoryProvider);
    final card = _BoardCard(task: task);

    return DragTarget<Task>(
      onWillAcceptWithDetails: (d) => d.data.id != task.id,
      onAcceptWithDetails: (details) {
        // Insert the dropped card just above this one.
        final index = tasks.indexWhere((t) => t.id == task.id);
        final prev = index > 0 ? tasks[index - 1].sortOrder : task.sortOrder - 2;
        repo.moveTaskToColumn(details.data.id, column.id,
            sortOrder: (prev + task.sortOrder) / 2);
      },
      builder: (context, candidates, _) => Padding(
        padding: EdgeInsets.only(top: candidates.isNotEmpty ? 24 : 0),
        child: LongPressDraggable<Task>(
          data: task,
          feedback: Material(
            color: Colors.transparent,
            child: SizedBox(width: 256, child: card),
          ),
          childWhenDragging: Opacity(opacity: 0.35, child: card),
          child: card,
        ),
      ),
    );
  }
}

class _BoardCard extends ConsumerWidget {
  const _BoardCard({required this.task});

  final Task task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.komorebi;
    final tags = ref.watch(tagsByTaskProvider).value?[task.id] ?? const [];
    final progress = ref.watch(subtaskProgressProvider).value?[task.id];
    final due = task.dueAt ?? task.scheduledAt;
    final overdue = due != null &&
        DateUtils.dateOnly(due).isBefore(DateUtils.dateOnly(DateTime.now()));

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showTaskEditor(context, taskId: task.id),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(task.title,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  if (task.priority != null)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(left: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: switch (task.priority!) {
                          1 => tokens.danger,
                          2 => tokens.warmAccent,
                          _ => tokens.coolAccent,
                        },
                      ),
                    ),
                ],
              ),
              if (due != null || tags.isNotEmpty || progress != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (due != null)
                        _meta(
                            context,
                            Icons.event,
                            DateFormat.MMMd().format(due),
                            overdue ? tokens.danger : tokens.inkSoft),
                      if (progress != null)
                        _meta(context, Icons.checklist,
                            '${progress.done}/${progress.total}',
                            tokens.inkSoft),
                      for (final tag in tags)
                        _meta(context, Icons.tag, tag.name, tokens.coolAccent),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _meta(BuildContext context, IconData icon, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 2),
        Text(label,
            style:
                Theme.of(context).textTheme.labelSmall?.copyWith(color: color)),
      ],
    );
  }
}

class _QuickCardField extends ConsumerStatefulWidget {
  const _QuickCardField({required this.column, required this.appendOrder});

  final BoardColumn column;
  final double Function() appendOrder;

  @override
  ConsumerState<_QuickCardField> createState() => _QuickCardFieldState();
}

class _QuickCardFieldState extends ConsumerState<_QuickCardField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: '+ add card',
          isDense: true,
          border: InputBorder.none,
        ),
        onSubmitted: (value) async {
          if (value.trim().isEmpty) return;
          final repo = ref.read(taskRepositoryProvider);
          final id = await repo.createTask(
            title: value.trim(),
            projectId: widget.column.projectId,
          );
          await repo.moveTaskToColumn(id, widget.column.id,
              sortOrder: widget.appendOrder());
          _controller.clear();
        },
      ),
    );
  }
}

class _AddColumnButton extends ConsumerWidget {
  const _AddColumnButton({required this.projectId});

  final String projectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: SizedBox(
        width: 180,
        child: OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: const Text('Add column'),
          onPressed: () async {
            final name = await _promptText(context, 'New column');
            if (name == null || name.trim().isEmpty) return;
            await ref
                .read(taskRepositoryProvider)
                .addColumn(projectId, name.trim());
          },
        ),
      ),
    );
  }
}

Future<String?> _promptText(BuildContext context, String title,
    {String initial = ''}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: TextField(controller: controller, autofocus: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(controller.text),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
