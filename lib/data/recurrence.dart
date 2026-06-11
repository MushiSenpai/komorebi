/// Minimal RFC 5545 RRULE subset for v1 recurrence (SPEC §5.1).
///
/// Stored strings stay RFC-compatible (`FREQ=WEEKLY;INTERVAL=2`) so the full
/// `rrule` package can replace this without a data migration when custom
/// rules (BYDAY etc.) land — see SPEC §5.1 future improvements.
library;

enum RecurrenceFreq { daily, weekly, monthly }

class Recurrence {
  const Recurrence(this.freq, [this.interval = 1])
      : assert(interval >= 1, 'interval must be >= 1');

  final RecurrenceFreq freq;
  final int interval;

  static const presets = {
    'Every day': Recurrence(RecurrenceFreq.daily),
    'Every week': Recurrence(RecurrenceFreq.weekly),
    'Every 2 weeks': Recurrence(RecurrenceFreq.weekly, 2),
    'Every month': Recurrence(RecurrenceFreq.monthly),
  };

  /// Parses the supported RRULE subset; returns null for anything it does not
  /// understand (callers must treat the task as non-recurring rather than
  /// guessing).
  static Recurrence? tryParse(String? rrule) {
    if (rrule == null || rrule.isEmpty) return null;
    RecurrenceFreq? freq;
    var interval = 1;
    for (final part in rrule.split(';')) {
      final kv = part.split('=');
      if (kv.length != 2) return null;
      switch (kv[0].toUpperCase()) {
        case 'FREQ':
          freq = switch (kv[1].toUpperCase()) {
            'DAILY' => RecurrenceFreq.daily,
            'WEEKLY' => RecurrenceFreq.weekly,
            'MONTHLY' => RecurrenceFreq.monthly,
            _ => null,
          };
          if (freq == null) return null;
        case 'INTERVAL':
          interval = int.tryParse(kv[1]) ?? -1;
          if (interval < 1) return null;
        default:
          return null; // BYDAY etc. — not supported yet, don't half-apply.
      }
    }
    return freq == null ? null : Recurrence(freq, interval);
  }

  String toRrule() {
    final f = switch (freq) {
      RecurrenceFreq.daily => 'DAILY',
      RecurrenceFreq.weekly => 'WEEKLY',
      RecurrenceFreq.monthly => 'MONTHLY',
    };
    return interval == 1 ? 'FREQ=$f' : 'FREQ=$f;INTERVAL=$interval';
  }

  /// Next occurrence strictly after [from].
  DateTime nextAfter(DateTime from) {
    switch (freq) {
      case RecurrenceFreq.daily:
        return from.add(Duration(days: interval));
      case RecurrenceFreq.weekly:
        return from.add(Duration(days: 7 * interval));
      case RecurrenceFreq.monthly:
        return _addMonths(from, interval);
    }
  }

  /// Adds months clamping the day-of-month (Jan 31 + 1mo = Feb 28/29).
  static DateTime _addMonths(DateTime d, int months) {
    final zeroBased = d.month - 1 + months;
    final year = d.year + zeroBased ~/ 12;
    final month = zeroBased % 12 + 1;
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = d.day > lastDay ? lastDay : d.day;
    return DateTime(year, month, day, d.hour, d.minute, d.second);
  }

  String get label {
    final unit = switch (freq) {
      RecurrenceFreq.daily => 'day',
      RecurrenceFreq.weekly => 'week',
      RecurrenceFreq.monthly => 'month',
    };
    return interval == 1 ? 'Every $unit' : 'Every $interval ${unit}s';
  }
}
