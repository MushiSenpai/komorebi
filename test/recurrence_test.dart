import 'package:flutter_test/flutter_test.dart';
import 'package:komorebi/data/recurrence.dart';

void main() {
  test('roundtrips RFC 5545 strings', () {
    expect(Recurrence.tryParse('FREQ=DAILY')!.toRrule(), 'FREQ=DAILY');
    expect(Recurrence.tryParse('FREQ=WEEKLY;INTERVAL=2')!.toRrule(),
        'FREQ=WEEKLY;INTERVAL=2');
    expect(Recurrence.tryParse('freq=monthly')!.toRrule(), 'FREQ=MONTHLY');
  });

  test('rejects unsupported rules instead of guessing', () {
    expect(Recurrence.tryParse(null), isNull);
    expect(Recurrence.tryParse(''), isNull);
    expect(Recurrence.tryParse('FREQ=YEARLY'), isNull);
    expect(Recurrence.tryParse('FREQ=WEEKLY;BYDAY=MO'), isNull);
    expect(Recurrence.tryParse('FREQ=DAILY;INTERVAL=0'), isNull);
    expect(Recurrence.tryParse('nonsense'), isNull);
  });

  test('daily and weekly advance by exact days', () {
    final from = DateTime(2026, 6, 10, 9);
    expect(const Recurrence(RecurrenceFreq.daily).nextAfter(from),
        DateTime(2026, 6, 11, 9));
    expect(const Recurrence(RecurrenceFreq.weekly, 2).nextAfter(from),
        DateTime(2026, 6, 24, 9));
  });

  test('monthly clamps the day-of-month', () {
    expect(const Recurrence(RecurrenceFreq.monthly).nextAfter(DateTime(2026, 1, 31)),
        DateTime(2026, 2, 28));
    expect(const Recurrence(RecurrenceFreq.monthly).nextAfter(DateTime(2026, 12, 15)),
        DateTime(2027, 1, 15));
  });
}
