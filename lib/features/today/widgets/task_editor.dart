import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../data/db/database.dart';
import '../../../data/providers.dart';
import '../../../data/recurrence.dart';
import '../providers.dart';

/// Opens the full task editor as a modal bottom sheet.
Future<void> showTaskEditor(BuildContext context, {required String taskId}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.88,
      child: TaskEditorSheet(taskId: taskId),
    ),
  );
}

class TaskEditorSheet extends ConsumerStatefulWidget {
  const TaskEditorSheet({super.key, required this.taskId});

  final String taskId;

  @override
  ConsumerState<TaskEditorSheet> createState() => _TaskEditorSheetState();
}

class _TaskEditorSheetState extends ConsumerState<TaskEditorSheet> {
  Task? _task;
  late TextEditingController _title;
  late TextEditingController _description;
  final _newSubtask = TextEditingController();
  final _newTag = TextEditingController();

  String? _projectId;
  int? _priority;
  DateTime? _dueAt;
  DateTime? _scheduledAt;
  String? _rrule;
  Set<String> _tagIds = {};

  @override
  void initState() {
    super.initState();
    _title = TextEditingController();
    _description = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final repo = ref.read(taskRepositoryProvider);
    final task = await repo.getTask(widget.taskId);
    final tags = await repo.tagsForTask(widget.taskId);
    if (!mounted) return;
    setState(() {
      _task = task;
      _title.text = task.title;
      _description.text = task.description;
      _projectId = task.projectId;
      _priority = task.priority;
      _dueAt = task.dueAt;
      _scheduledAt = task.scheduledAt;
      _rrule = task.rrule;
      _tagIds = tags.map((t) => t.id).toSet();
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _newSubtask.dispose();
    _newTag.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(taskRepositoryProvider);
    await repo.updateTask(
      widget.taskId,
      TasksCompanion(
        title: Value(_title.text.trim().isEmpty ? 'Untitled' : _title.text.trim()),
        description: Value(_description.text),
        projectId: Value(_projectId),
        priority: Value(_priority),
        dueAt: Value(_dueAt),
        scheduledAt: Value(_scheduledAt),
        rrule: Value(_rrule),
      ),
    );
    await repo.setTaskTags(widget.taskId, _tagIds.toList());
    if (mounted) Navigator.of(context).pop();
  }

  Future<DateTime?> _pickDate(DateTime? current) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: current ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final task = _task;
    if (task == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final projects = ref.watch(projectsProvider).value ?? const <Project>[];
    final allTags = ref.watch(tagsProvider).value ?? const <Tag>[];
    final isSubtask = task.parentTaskId != null;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 12,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 12,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Edit task',
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Delete task',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  await ref
                      .read(taskRepositoryProvider)
                      .deleteTask(widget.taskId);
                  if (context.mounted) Navigator.of(context).pop();
                },
              ),
              FilledButton(onPressed: _save, child: const Text('Save')),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                TextField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Title'),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _description,
                  decoration: const InputDecoration(
                    labelText: 'Notes (markdown)',
                    alignLabelWithHint: true,
                  ),
                  minLines: 2,
                  maxLines: 6,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _projectId,
                        decoration:
                            const InputDecoration(labelText: 'Project'),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: Text('No project')),
                          for (final p in projects)
                            DropdownMenuItem(value: p.id, child: Text(p.name)),
                        ],
                        onChanged: (v) => setState(() => _projectId = v),
                      ),
                    ),
                    IconButton(
                      tooltip: 'New project',
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        final name = await _promptText(context, 'New project');
                        if (name == null || name.trim().isEmpty) return;
                        final id = await ref
                            .read(taskRepositoryProvider)
                            .ensureProject(name.trim());
                        setState(() => _projectId = id);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Priority',
                    style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                SegmentedButton<int?>(
                  segments: const [
                    ButtonSegment(value: null, label: Text('None')),
                    ButtonSegment(value: 1, label: Text('P1')),
                    ButtonSegment(value: 2, label: Text('P2')),
                    ButtonSegment(value: 3, label: Text('P3')),
                  ],
                  selected: {_priority},
                  onSelectionChanged: (s) =>
                      setState(() => _priority = s.first),
                ),
                const SizedBox(height: 16),
                _DateRow(
                  label: 'Due',
                  value: _dueAt,
                  onPick: () async {
                    final picked = await _pickDate(_dueAt);
                    if (picked != null) setState(() => _dueAt = picked);
                  },
                  onClear: () => setState(() => _dueAt = null),
                ),
                _DateRow(
                  label: 'Scheduled',
                  value: _scheduledAt,
                  onPick: () async {
                    final picked = await _pickDate(_scheduledAt);
                    if (picked != null) {
                      setState(() => _scheduledAt = picked);
                    }
                  },
                  onClear: () => setState(() => _scheduledAt = null),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: _rrule,
                  decoration: const InputDecoration(labelText: 'Repeat'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Does not repeat')),
                    for (final entry in Recurrence.presets.entries)
                      DropdownMenuItem(
                        value: entry.value.toRrule(),
                        child: Text(entry.key),
                      ),
                  ],
                  onChanged: (v) => setState(() => _rrule = v),
                ),
                const SizedBox(height: 16),
                Text('Tags', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final tag in allTags)
                      FilterChip(
                        label: Text(tag.name),
                        selected: _tagIds.contains(tag.id),
                        onSelected: (sel) => setState(() {
                          sel ? _tagIds.add(tag.id) : _tagIds.remove(tag.id);
                        }),
                      ),
                    SizedBox(
                      width: 140,
                      child: TextField(
                        controller: _newTag,
                        decoration:
                            const InputDecoration(hintText: '+ new tag'),
                        onSubmitted: (value) async {
                          if (value.trim().isEmpty) return;
                          final id = await ref
                              .read(taskRepositoryProvider)
                              .ensureTag(value.trim());
                          _newTag.clear();
                          setState(() => _tagIds.add(id));
                        },
                      ),
                    ),
                  ],
                ),
                if (!isSubtask) ...[
                  const SizedBox(height: 16),
                  Text('Subtasks',
                      style: Theme.of(context).textTheme.labelLarge),
                  _SubtaskList(parentId: task.id, controller: _newSubtask),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.value,
    required this.onPick,
    required this.onClear,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label)),
        TextButton.icon(
          icon: const Icon(Icons.event, size: 18),
          label: Text(
              value == null ? 'None' : DateFormat.yMMMd().format(value!)),
          onPressed: onPick,
        ),
        if (value != null)
          IconButton(
            tooltip: 'Clear $label date',
            icon: const Icon(Icons.close, size: 16),
            onPressed: onClear,
          ),
      ],
    );
  }
}

class _SubtaskList extends ConsumerWidget {
  const _SubtaskList({required this.parentId, required this.controller});

  final String parentId;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(taskRepositoryProvider);
    final subtasks =
        ref.watch(subtasksProvider(parentId)).value ?? const <Task>[];

    return Column(
      children: [
        for (final sub in subtasks)
          CheckboxListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            value: sub.completedAt != null,
            onChanged: (_) => repo.toggleSubtask(sub),
            title: Text(
              sub.title,
              style: TextStyle(
                decoration: sub.completedAt != null
                    ? TextDecoration.lineThrough
                    : null,
              ),
            ),
            secondary: IconButton(
              icon: const Icon(Icons.close, size: 16),
              onPressed: () => repo.deleteTask(sub.id),
            ),
          ),
        TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '+ add subtask'),
          onSubmitted: (value) async {
            if (value.trim().isEmpty) return;
            await repo.createTask(title: value.trim(), parentTaskId: parentId);
            controller.clear();
          },
        ),
      ],
    );
  }
}

Future<String?> _promptText(BuildContext context, String title) {
  final controller = TextEditingController();
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
          child: const Text('Create'),
        ),
      ],
    ),
  );
}
