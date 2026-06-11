import 'package:drift/drift.dart';

import '../db/database.dart';
import '../ids.dart';
import '../recurrence.dart';

/// One concrete occurrence of an event inside a queried window. For
/// recurring events, [start]/[end] are shifted copies of the series row;
/// [event] keeps the underlying row for editing.
class EventOccurrence {
  const EventOccurrence({
    required this.event,
    required this.start,
    this.end,
  });

  final Event event;
  final DateTime start;
  final DateTime? end;

  bool get allDay => event.allDay;
}

/// Data access for calendar events (SPEC §5.3) and reminders.
class EventRepository {
  EventRepository(this._db);

  final AppDatabase _db;

  // ---- Events --------------------------------------------------------------

  Future<String> createEvent({
    required String title,
    required DateTime startAt,
    DateTime? endAt,
    bool allDay = false,
    String notes = '',
    String? rrule,
    int? color,
    Duration? remindBefore,
  }) async {
    final id = newId();
    await _db.transaction(() async {
      await _db.into(_db.events).insert(EventsCompanion.insert(
            id: id,
            title: title,
            startAt: startAt,
            endAt: Value(endAt),
            allDay: Value(allDay),
            notes: Value(notes),
            rrule: Value(rrule),
            color: Value(color),
          ));
      if (remindBefore != null) {
        await _db.into(_db.reminders).insert(RemindersCompanion.insert(
              id: newId(),
              targetKind: 'event',
              targetId: id,
              fireAt: startAt.subtract(remindBefore),
            ));
      }
    });
    return id;
  }

  Future<void> updateEvent(String id, EventsCompanion changes) {
    return (_db.update(_db.events)..where((e) => e.id.equals(id)))
        .write(changes.copyWith(updatedAt: Value(DateTime.now())));
  }

  Future<void> deleteEvent(String id) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await updateEvent(id, EventsCompanion(deletedAt: Value(now)));
      await (_db.update(_db.reminders)
            ..where((r) =>
                r.targetKind.equals('event') & r.targetId.equals(id)))
          .write(RemindersCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ));
    });
  }

  Future<Event> getEvent(String id) =>
      (_db.select(_db.events)..where((e) => e.id.equals(id))).getSingle();

  /// All occurrences intersecting [from, to) — one-off events directly,
  /// recurring events expanded with the shared Recurrence subset.
  Stream<List<EventOccurrence>> watchWindow(DateTime from, DateTime to) {
    // Recurring series can start long before the window, so fetch all live
    // events and expand in Dart; event counts stay small for a personal app.
    return (_db.select(_db.events)..where((e) => e.deletedAt.isNull()))
        .watch()
        .map((events) {
      final occurrences = <EventOccurrence>[];
      for (final event in events) {
        occurrences.addAll(_expand(event, from, to));
      }
      occurrences.sort((a, b) {
        // All-day occurrences float to the top of a day.
        if (a.allDay != b.allDay && _sameDay(a.start, b.start)) {
          return a.allDay ? -1 : 1;
        }
        return a.start.compareTo(b.start);
      });
      return occurrences;
    });
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Iterable<EventOccurrence> _expand(
      Event event, DateTime from, DateTime to) sync* {
    final duration = event.endAt?.difference(event.startAt);

    bool intersects(DateTime start) {
      final end = duration == null ? start : start.add(duration);
      final dayEnd = event.allDay
          ? DateTime(start.year, start.month, start.day + 1)
          : end;
      return start.isBefore(to) && dayEnd.isAfter(from);
    }

    final recurrence = Recurrence.tryParse(event.rrule);
    if (recurrence == null) {
      if (intersects(event.startAt)) {
        yield EventOccurrence(
          event: event,
          start: event.startAt,
          end: event.endAt,
        );
      }
      return;
    }

    var start = event.startAt;
    // Cap the expansion defensively; a window is at most ~6 weeks of cells.
    for (var i = 0; i < 1000 && start.isBefore(to); i++) {
      if (intersects(start)) {
        yield EventOccurrence(
          event: event,
          start: start,
          end: duration == null ? null : start.add(duration),
        );
      }
      start = recurrence.nextAfter(start);
    }
  }

  // ---- Reminders -----------------------------------------------------------

  /// Reminders that should fire at or before [now].
  Future<List<Reminder>> dueReminders(DateTime now) {
    return (_db.select(_db.reminders)
          ..where((r) =>
              r.deletedAt.isNull() &
              r.fired.equals(false) &
              r.fireAt.isSmallerOrEqualValue(now)))
        .get();
  }

  Future<void> markReminderFired(String id) {
    return (_db.update(_db.reminders)..where((r) => r.id.equals(id))).write(
      RemindersCompanion(
        fired: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Replaces the reminder for an event (null clears it).
  Future<void> setEventReminder(String eventId, Duration? before) async {
    final now = DateTime.now();
    await _db.transaction(() async {
      await (_db.update(_db.reminders)
            ..where((r) =>
                r.targetKind.equals('event') & r.targetId.equals(eventId)))
          .write(RemindersCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ));
      if (before != null) {
        final event = await getEvent(eventId);
        await _db.into(_db.reminders).insert(RemindersCompanion.insert(
              id: newId(),
              targetKind: 'event',
              targetId: eventId,
              fireAt: event.startAt.subtract(before),
            ));
      }
    });
  }
}
