import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komorebi/app/app.dart';
import 'package:komorebi/data/db/database.dart';
import 'package:komorebi/data/providers.dart';

Widget _app(AppDatabase db) => ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: const KomorebiApp(),
    );

/// Unmounts the app inside the test body so drift's stream-cleanup timer
/// (scheduled when Riverpod cancels query streams) fires before flutter_test
/// asserts that no timers are pending.
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  testWidgets('shell navigates between modules and persists theme choice',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    // Wide test surface (800px) → navigation rail with all six modules.
    expect(find.byType(NavigationRail), findsOneWidget);
    for (final label in [
      'Today', 'Plan', 'Boards', 'Calendar', 'Notes', 'Focus', 'Play',
    ]) {
      expect(find.text(label), findsWidgets, reason: 'missing rail item $label');
    }

    // Switch to Notes (still a placeholder until Phase 4).
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

    await _unmount(tester);
  });

  testWidgets('quick add creates a task; checkbox completes it with undo',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    // Today view starts empty.
    expect(find.text('Nothing due today'), findsOneWidget);

    // Add a task due today via the quick-add bar.
    await tester.enterText(
        find.byType(TextField).first, 'water the plants today !p1');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('water the plants'), findsOneWidget);
    expect(find.text('Nothing due today'), findsNothing);

    // Complete it — it leaves Today and a snackbar offers undo.
    await tester.tap(find.byKey(const ValueKey('task-checkbox')));
    await tester.pumpAndSettle();
    expect(find.text('Nothing due today'), findsOneWidget);
    expect(find.textContaining('Completed'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(find.text('water the plants'), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('day plan: add a block, check it off, day score updates',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Plan'));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsWidgets); // header + rail

    // Tap the 05:00 slab and plan a one-hour run.
    await tester.tap(find.text('05:00'));
    await tester.pumpAndSettle();
    expect(find.text('Plan a block'), findsOneWidget);
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        'Running');
    await tester.tap(find.byTooltip('Longer'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(find.text('Running'), findsOneWidget);
    expect(find.text('05:00 – 06:00'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);

    // Check it off — score chip becomes 1/1.
    await tester.tap(find.byKey(find
        .byWidgetPredicate((w) =>
            w.key != null && '${w.key}'.contains('block-check-'))
        .evaluate()
        .single
        .widget
        .key!));
    await tester.pumpAndSettle();
    expect(find.text('1/1'), findsOneWidget);

    await _unmount(tester);
  });
}
