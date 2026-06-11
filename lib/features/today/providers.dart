import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/repos/task_repository.dart';

/// The four task views (SPEC §5.1). "Today" includes overdue tasks.
enum TaskView { today, upcoming, all, done }

final taskViewProvider =
    NotifierProvider<TaskViewNotifier, TaskView>(TaskViewNotifier.new);

class TaskViewNotifier extends Notifier<TaskView> {
  @override
  TaskView build() => TaskView.today;

  void set(TaskView view) => state = view;
}

final todayTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(taskRepositoryProvider).watchToday(DateTime.now());
});

final upcomingTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(taskRepositoryProvider).watchUpcoming(DateTime.now());
});

final allTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(taskRepositoryProvider).watchAll();
});

final completedTasksProvider = StreamProvider<List<Task>>((ref) {
  return ref.watch(taskRepositoryProvider).watchCompleted();
});

final subtaskProgressProvider =
    StreamProvider<Map<String, SubtaskProgress>>((ref) {
  return ref.watch(taskRepositoryProvider).watchSubtaskProgress();
});

final tagsByTaskProvider = StreamProvider<Map<String, List<Tag>>>((ref) {
  return ref.watch(taskRepositoryProvider).watchTagsByTask();
});

final projectsProvider = StreamProvider<List<Project>>((ref) {
  return ref.watch(taskRepositoryProvider).watchProjects();
});

final tagsProvider = StreamProvider<List<Tag>>((ref) {
  return ref.watch(taskRepositoryProvider).watchTags();
});

final subtasksProvider =
    StreamProvider.family<List<Task>, String>((ref, parentId) {
  return ref.watch(taskRepositoryProvider).watchSubtasks(parentId);
});

/// Nullable single-value filter (priority / tag) on the All view;
/// null = show everything.
class FilterNotifier<T> extends Notifier<T?> {
  @override
  T? build() => null;

  void set(T? value) => state = value;
}

/// Priority filter on the All view.
final priorityFilterProvider =
    NotifierProvider<FilterNotifier<int>, int?>(FilterNotifier<int>.new);

/// Tag-id filter on the All view.
final tagFilterProvider =
    NotifierProvider<FilterNotifier<String>, String?>(FilterNotifier<String>.new);
