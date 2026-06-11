import 'package:flutter_test/flutter_test.dart';
import 'package:komorebi/features/today/quick_add_parser.dart';

void main() {
  // Wednesday 2026-06-10, mid-afternoon.
  final now = DateTime(2026, 6, 10, 15, 30);

  test('plain title passes through untouched', () {
    final r = parseQuickAdd('buy bird seed', now: now);
    expect(r.title, 'buy bird seed');
    expect(r.priority, isNull);
    expect(r.dueAt, isNull);
    expect(r.tags, isEmpty);
    expect(r.project, isNull);
  });

  test('full syntax: date, priority, tags, project', () {
    final r =
        parseQuickAdd('water plants tomorrow !p1 #home #garden @chores', now: now);
    expect(r.title, 'water plants');
    expect(r.priority, 1);
    expect(r.dueAt, DateTime(2026, 6, 11));
    expect(r.tags, ['home', 'garden']);
    expect(r.project, 'chores');
  });

  test('today resolves to midnight today', () {
    final r = parseQuickAdd('stretch today', now: now);
    expect(r.dueAt, DateTime(2026, 6, 10));
    expect(r.title, 'stretch');
  });

  test('weekday name means next such day, never today', () {
    // "wednesday" said on a Wednesday = next week's Wednesday.
    expect(parseQuickAdd('review wednesday', now: now).dueAt,
        DateTime(2026, 6, 17));
    // Friday this week.
    expect(parseQuickAdd('review fri', now: now).dueAt, DateTime(2026, 6, 12));
  });

  test('next week resolves to next Monday', () {
    final r = parseQuickAdd('plan sprint next week', now: now);
    expect(r.dueAt, DateTime(2026, 6, 15));
    expect(r.title, 'plan sprint');
  });

  test('in N days', () {
    final r = parseQuickAdd('renew certs in 10 days', now: now);
    expect(r.dueAt, DateTime(2026, 6, 20));
    expect(r.title, 'renew certs');
  });

  test('date words embedded in other words are not parsed', () {
    final r = parseQuickAdd('tomorrowland trip report', now: now);
    expect(r.dueAt, isNull);
    expect(r.title, 'tomorrowland trip report');
  });

  test('only the first date wins', () {
    final r = parseQuickAdd('ship today tomorrow', now: now);
    expect(r.dueAt, DateTime(2026, 6, 10));
    expect(r.title, 'ship tomorrow');
  });

  test('bare # and @ stay in the title', () {
    final r = parseQuickAdd('fix # and @ handling', now: now);
    expect(r.title, 'fix # and @ handling');
    expect(r.tags, isEmpty);
    expect(r.project, isNull);
  });
}
