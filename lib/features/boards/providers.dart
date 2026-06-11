import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../today/providers.dart' show projectsProvider;

export '../today/providers.dart' show projectsProvider;

/// The project whose board is shown; null until projects exist, then the
/// first project is used unless the user picked one.
final selectedProjectProvider =
    NotifierProvider<SelectedProjectNotifier, String?>(
        SelectedProjectNotifier.new);

class SelectedProjectNotifier extends Notifier<String?> {
  @override
  String? build() {
    final projects = ref.watch(projectsProvider).value ?? const [];
    if (projects.isEmpty) return null;
    // Keep the user's explicit pick if it still exists.
    final picked = stateOrNull;
    if (picked != null && projects.any((p) => p.id == picked)) return picked;
    return projects.first.id;
  }

  void set(String id) => state = id;
}

final boardColumnsProvider =
    StreamProvider.family<List<BoardColumn>, String>((ref, projectId) {
  return ref.watch(taskRepositoryProvider).watchBoardColumns(projectId);
});

final boardTasksProvider =
    StreamProvider.family<List<Task>, String>((ref, projectId) {
  return ref.watch(taskRepositoryProvider).watchProjectTasks(projectId);
});
