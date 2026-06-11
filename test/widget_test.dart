import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komorebi/app/app.dart';
import 'package:komorebi/data/db/database.dart';
import 'package:komorebi/data/providers.dart';
import 'package:komorebi/features/today/widgets/task_editor.dart';

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

    // Switch to Notes (empty library at first).
    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('library in the forest'), findsOneWidget);

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

  testWidgets('board: create project, add card, card opens editor',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Boards'));
    await tester.pumpAndSettle();
    expect(find.text('No projects yet'), findsOneWidget);

    await tester.tap(find.byTooltip('New project'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog), matching: find.byType(TextField)),
        'Garden');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Default columns appear.
    expect(find.textContaining('Backlog'), findsOneWidget);
    expect(find.textContaining('Doing'), findsOneWidget);
    expect(find.textContaining('Done'), findsOneWidget);

    // Add a card to Backlog via the quick field.
    await tester.enterText(find.widgetWithText(TextField, '+ add card').first,
        'plant tomatoes');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('plant tomatoes'), findsOneWidget);
    expect(find.textContaining('Backlog  ·  1'), findsOneWidget);

    // Card tap opens the shared task editor.
    await tester.tap(find.text('plant tomatoes'));
    await tester.pumpAndSettle();
    expect(find.text('Edit task'), findsOneWidget);

    await _unmount(tester);
  });

  testWidgets('calendar: add an event, it shows in grid and agenda',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();
    expect(find.textContaining('An open day'), findsOneWidget);

    await tester.tap(find.byTooltip('New event'));
    await tester.pumpAndSettle();
    expect(find.text('New event'), findsOneWidget);

    await tester.enterText(
        find.descendant(
            of: find.byType(AlertDialog),
            matching: find.widgetWithText(TextField, 'Title')),
        'Swimming');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Title appears twice: grid chip + agenda row.
    expect(find.text('Swimming'), findsNWidgets(2));
    expect(find.textContaining('An open day'), findsNothing);

    // Open it from the agenda and check the editor loads it.
    await tester.tap(find.text('Swimming').last);
    await tester.pumpAndSettle();
    expect(find.text('Edit event'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await _unmount(tester);
  });

  testWidgets('notes: create, wiki-link to a task, backlink appears',
      (tester) async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(_app(db));
    await tester.pumpAndSettle();

    // A task to link against.
    await tester.enterText(
        find.byType(TextField).first, 'water the plants today');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Notes'));
    await tester.pumpAndSettle();
    expect(find.textContaining('library in the forest'), findsOneWidget);

    await tester.tap(find.byTooltip('New note'));
    await tester.pumpAndSettle();

    // Editor opens for the new note; write a body with a task wiki-link.
    await tester.enterText(
        find.widgetWithText(TextField, 'Title'), 'Watering log');
    final bodyField = find.byWidgetPredicate((w) =>
        w is TextField && (w.decoration?.hintText ?? '').contains('markdown'));
    await tester.enterText(
        bodyField, 'Remember [[task:water the plants]] each morning.');
    // Let the autosave debounce fire and links sync.
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Preview renders the wiki-link as a tappable link.
    await tester.tap(find.text('Preview'));
    await tester.pumpAndSettle();
    expect(find.textContaining('task:water the plants'), findsOneWidget);

    // The task editor now shows the note under "Referenced in"
    // (scroll: the section sits below the sheet's fold).
    await tester.tap(find.text('Today'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('water the plants'));
    await tester.pumpAndSettle();
    final sheetScrollable = find
        .descendant(
            of: find.byType(TaskEditorSheet),
            matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('Referenced in'), 100,
        scrollable: sheetScrollable);
    expect(find.text('Referenced in'), findsOneWidget);
    expect(find.text('Watering log'), findsOneWidget);

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
