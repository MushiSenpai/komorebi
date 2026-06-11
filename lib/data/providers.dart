import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'db/database.dart';
import 'repos/event_repository.dart';
import 'repos/note_repository.dart';
import 'repos/task_repository.dart';

/// The single app database. Overridden in main() with the opened instance
/// (and in tests with an in-memory one).
final databaseProvider = Provider<AppDatabase>(
  (ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final taskRepositoryProvider = Provider<TaskRepository>(
  (ref) => TaskRepository(ref.watch(databaseProvider)),
);

final eventRepositoryProvider = Provider<EventRepository>(
  (ref) => EventRepository(ref.watch(databaseProvider)),
);

final noteRepositoryProvider = Provider<NoteRepository>(
  (ref) => NoteRepository(ref.watch(databaseProvider)),
);

/// Active theme mode; system = follow OS. Persisted to the settings table.
final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

class ThemeModeNotifier extends Notifier<ThemeMode> {
  ThemeModeNotifier([this._initial = ThemeMode.system]);

  final ThemeMode _initial;

  @override
  ThemeMode build() {
    // Restore the saved choice without blocking the first frame.
    Future(() async {
      state = await ref.read(databaseProvider).loadThemeMode();
    });
    return _initial;
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await ref.read(databaseProvider).saveThemeMode(mode);
  }
}
