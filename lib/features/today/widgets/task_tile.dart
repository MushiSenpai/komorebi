import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../design/tokens.dart';
import '../providers.dart';
import 'task_editor.dart';

/// One task row: round checkbox, title, priority dot, due chip, tag chips,
/// subtask progress (SPEC §5.1/§5.2 card anatomy).
class TaskTile extends ConsumerWidget {
  const TaskTile({super.key, required this.task, this.showRestore = false});

  final Task task;

  /// Done-log mode: checkbox is replaced by a restore action.
  final bool showRestore;

  Color _priorityColor(BuildContext context, int priority) {
    final tokens = context.komorebi;
    return switch (priority) {
      1 => tokens.danger,
      2 => tokens.warmAccent,
      _ => tokens.coolAccent,
    };
  }

  String _dueLabel(DateTime due) {
    final today = DateUtils.dateOnly(DateTime.now());
    final day = DateUtils.dateOnly(due);
    final days = day.difference(today).inDays;
    if (days < 0) return days == -1 ? 'yesterday' : '${-days}d overdue';
    if (days == 0) return 'today';
    if (days == 1) return 'tomorrow';
    if (days < 7) return DateFormat.E().format(due);
    return DateFormat.MMMd().format(due);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.komorebi;
    final repo = ref.watch(taskRepositoryProvider);
    final tags = ref.watch(tagsByTaskProvider).value?[task.id] ?? const [];
    final progress = ref.watch(subtaskProgressProvider).value?[task.id];
    final done = task.completedAt != null;
    final due = task.dueAt ?? task.scheduledAt;
    final overdue = !done &&
        due != null &&
        DateUtils.dateOnly(due).isBefore(DateUtils.dateOnly(DateTime.now()));

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => showTaskEditor(context, taskId: task.id),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              if (showRestore)
                IconButton(
                  tooltip: 'Restore',
                  icon: const Icon(Icons.undo),
                  onPressed: () => repo.uncompleteTask(task.id),
                )
              else
                _RoundCheckbox(
                  checked: done,
                  onChanged: () async {
                    final undoId = await repo.completeTask(task);
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(SnackBar(
                        content: Text('Completed "${task.title}"'),
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: () => repo.uncompleteTask(undoId),
                        ),
                      ));
                  },
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            decoration:
                                done ? TextDecoration.lineThrough : null,
                            color: done ? tokens.inkSoft : tokens.ink,
                          ),
                    ),
                    if (due != null ||
                        tags.isNotEmpty ||
                        progress != null ||
                        task.rrule != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (due != null)
                              _MetaChip(
                                icon: Icons.event,
                                label: _dueLabel(due),
                                color:
                                    overdue ? tokens.danger : tokens.inkSoft,
                              ),
                            if (task.rrule != null)
                              _MetaChip(
                                icon: Icons.repeat,
                                label: '',
                                color: tokens.inkSoft,
                              ),
                            if (progress != null)
                              _MetaChip(
                                icon: Icons.checklist,
                                label: '${progress.done}/${progress.total}',
                                color: tokens.inkSoft,
                              ),
                            for (final tag in tags)
                              _MetaChip(
                                icon: Icons.tag,
                                label: tag.name,
                                color: tokens.coolAccent,
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (task.priority != null)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _priorityColor(context, task.priority!),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundCheckbox extends StatelessWidget {
  const _RoundCheckbox({required this.checked, required this.onChanged});

  final bool checked;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final tokens = context.komorebi;
    return InkWell(
      key: const ValueKey('task-checkbox'),
      customBorder: const CircleBorder(),
      onTap: onChanged,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: checked ? tokens.accent : Colors.transparent,
          border: Border.all(
            color: checked ? tokens.accent : tokens.inkSoft,
            width: 2,
          ),
        ),
        child: checked
            ? Icon(Icons.check, size: 18, color: tokens.paper)
            : null,
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 2),
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: color)),
        ],
      ],
    );
  }
}
