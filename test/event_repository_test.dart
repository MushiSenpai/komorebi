import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:komorebi/data/db/database.dart';
import 'package:komorebi/data/repos/event_repository.dart';

void main() {
  late AppDatabase db;
  late EventRepository repo;
  // June 2026 window (month grid range).
  final from = DateTime(2026, 6, 1);
  final to = DateTime(2026, 7, 1);

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = EventRepository(db);
  });
  tearDown(() => db.close());

  test('one-off events appear only in their window', () async {
    await repo.createEvent(
        title: 'dentist', startAt: DateTime(2026, 6, 15, 9, 30));
    await repo.createEvent(
        title: 'in july', startAt: DateTime(2026, 7, 2, 9));

    final window = await repo.watchWindow(from, to).first;
    expect(window.map((o) => o.event.title), ['dentist']);
  });

  test('weekly recurrence expands into every matching day', () async {
    await repo.createEvent(
      title: 'swim class',
      startAt: DateTime(2026, 6, 3, 7), // Wednesday
      endAt: DateTime(2026, 6, 3, 8),
      rrule: 'FREQ=WEEKLY',
    );

    final window = await repo.watchWindow(from, to).first;
    expect(window.length, 4, reason: 'Jun 3, 10, 17, 24');
    expect(window.map((o) => o.start.day), [3, 10, 17, 24]);
    expect(window.first.end, DateTime(2026, 6, 3, 8),
        reason: 'duration preserved per occurrence');
  });

  test('series starting before the window still lands inside it', () async {
    await repo.createEvent(
      title: 'rent',
      startAt: DateTime(2026, 1, 1, 8),
      rrule: 'FREQ=MONTHLY',
    );
    final window = await repo.watchWindow(from, to).first;
    expect(window.single.start, DateTime(2026, 6, 1, 8));
  });

  test('all-day events sort before timed events of the same day', () async {
    await repo.createEvent(
        title: 'standup', startAt: DateTime(2026, 6, 5, 0, 30));
    await repo.createEvent(
        title: 'holiday', startAt: DateTime(2026, 6, 5), allDay: true);

    final window = await repo.watchWindow(from, to).first;
    expect(window.map((o) => o.event.title), ['holiday', 'standup']);
  });

  test('deleting an event removes it and its reminders', () async {
    final id = await repo.createEvent(
      title: 'call',
      startAt: DateTime(2026, 6, 20, 15),
      remindBefore: const Duration(minutes: 10),
    );
    expect(await repo.dueReminders(DateTime(2026, 6, 20, 14, 50)), hasLength(1));

    await repo.deleteEvent(id);
    expect(await repo.watchWindow(from, to).first, isEmpty);
    expect(await repo.dueReminders(DateTime(2026, 6, 20, 15)), isEmpty);
  });

  test('reminders fire once and can be replaced', () async {
    final id = await repo.createEvent(
      title: 'run',
      startAt: DateTime(2026, 6, 8, 5, 30),
      remindBefore: Duration.zero,
    );

    final due = await repo.dueReminders(DateTime(2026, 6, 8, 5, 30));
    expect(due, hasLength(1));
    await repo.markReminderFired(due.single.id);
    expect(await repo.dueReminders(DateTime(2026, 6, 8, 6)), isEmpty);

    await repo.setEventReminder(id, const Duration(hours: 1));
    final replaced = await repo.dueReminders(DateTime(2026, 6, 8, 5));
    expect(replaced, hasLength(1));
    expect(replaced.single.fireAt, DateTime(2026, 6, 8, 4, 30));
  });
}
