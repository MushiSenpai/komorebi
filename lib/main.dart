import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'data/db/database.dart';
import 'data/providers.dart';
import 'data/repos/event_repository.dart';
import 'data/repos/task_repository.dart';
import 'services/reminder_engine.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // The database opens lazily; the saved theme is restored asynchronously by
  // ThemeModeNotifier so the first frame is never blocked on I/O.
  final db = AppDatabase();

  // In-app reminder polling (SPEC §5.3); no-op where notifications are
  // unsupported. Skipped on web, which has no reliable backend.
  if (!kIsWeb) {
    ReminderEngine(EventRepository(db), TaskRepository(db)).start();
  }

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const KomorebiApp(),
    ),
  );
}
