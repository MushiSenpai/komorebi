import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komorebi/app/app.dart';
import 'package:komorebi/data/db/database.dart';
import 'package:komorebi/data/providers.dart';

void main() {
  testWidgets('shell navigates between modules and persists theme choice',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: const KomorebiApp(),
      ),
    );
    await tester.pumpAndSettle();

    // Wide test surface (800px) → navigation rail with all six modules.
    expect(find.byType(NavigationRail), findsOneWidget);
    for (final label in ['Today', 'Boards', 'Calendar', 'Notes', 'Focus', 'Play']) {
      expect(find.text(label), findsWidgets, reason: 'missing rail item $label');
    }

    // Today is the initial branch.
    expect(find.textContaining('quiet morning'), findsOneWidget);

    // Switch to Notes.
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('wiki-links'), findsOneWidget);

    // Open settings and switch to the Twilight theme.
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.text('Appearance'), findsOneWidget);

    await tester.tap(find.text('Twilight'));
    await tester.pumpAndSettle();

    final context = tester.element(find.text('Appearance'));
    expect(Theme.of(context).brightness, Brightness.dark);
    expect(await db.getSetting('theme_mode'), 'twilight');
  });
}
