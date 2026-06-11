import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'data/db/database.dart';
import 'data/providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // The database opens lazily; the saved theme is restored asynchronously by
  // ThemeModeNotifier so the first frame is never blocked on I/O.
  final db = AppDatabase();

  runApp(
    ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const KomorebiApp(),
    ),
  );
}
