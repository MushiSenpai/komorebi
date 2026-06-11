import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';

export '../../data/providers.dart' show noteRepositoryProvider;

/// The note open in the editor pane; null = list only / empty state.
final selectedNoteIdProvider =
    NotifierProvider<SelectedNoteNotifier, String?>(SelectedNoteNotifier.new);

class SelectedNoteNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String? id) => state = id;
}

final noteSearchProvider =
    NotifierProvider<NoteSearchNotifier, String>(NoteSearchNotifier.new);

class NoteSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

/// Folder filter; null = all notes.
final noteFolderFilterProvider =
    NotifierProvider<NoteFolderFilterNotifier, String?>(
        NoteFolderFilterNotifier.new);

class NoteFolderFilterNotifier extends Notifier<String?> {
  void set(String? id) => state = id;

  @override
  String? build() => null;
}

/// Creates the pinned "How to write notes" guide on the very first visit.
final welcomeNoteProvider = FutureProvider<void>((ref) {
  return ref.watch(noteRepositoryProvider).ensureWelcomeNote();
});

final notesListProvider = StreamProvider<List<Note>>((ref) {
  return ref.watch(noteRepositoryProvider).watchNotes(
        folderId: ref.watch(noteFolderFilterProvider),
        query: ref.watch(noteSearchProvider),
      );
});

final foldersProvider = StreamProvider<List<Folder>>((ref) {
  return ref.watch(noteRepositoryProvider).watchFolders();
});

/// Backlinks for a `(kind, id)` target — kind is `note` or `task`.
final backlinksProvider =
    StreamProvider.family<List<Note>, (String, String)>((ref, target) {
  return ref
      .watch(noteRepositoryProvider)
      .watchBacklinks(target.$1, target.$2);
});
