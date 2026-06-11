/// Parser for the quick-add bar syntax (SPEC §5.1):
///
///     water the plants tomorrow !p1 #home #garden @chores
///
/// Recognized tokens (anywhere in the input, case-insensitive):
///  - `!p1` `!p2` `!p3` — priority
///  - `#tag`            — tags (repeatable)
///  - `@project`        — project by name (created if missing)
///  - dates: `today`, `tomorrow`, weekday names (`mon`..`sunday` = next such
///    day), `next week`, `in N days`
///
/// Everything else becomes the title. Date words only count when they appear
/// as standalone words, so "tomorrowland trip report" stays intact.
library;

class QuickAddResult {
  const QuickAddResult({
    required this.title,
    this.priority,
    this.dueAt,
    this.tags = const [],
    this.project,
  });

  final String title;
  final int? priority;
  final DateTime? dueAt;
  final List<String> tags;
  final String? project;
}

QuickAddResult parseQuickAdd(String input, {DateTime? now}) {
  now ??= DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final tags = <String>[];
  String? project;
  int? priority;
  DateTime? dueAt;

  const weekdays = {
    'monday': DateTime.monday,
    'mon': DateTime.monday,
    'tuesday': DateTime.tuesday,
    'tue': DateTime.tuesday,
    'wednesday': DateTime.wednesday,
    'wed': DateTime.wednesday,
    'thursday': DateTime.thursday,
    'thu': DateTime.thursday,
    'friday': DateTime.friday,
    'fri': DateTime.friday,
    'saturday': DateTime.saturday,
    'sat': DateTime.saturday,
    'sunday': DateTime.sunday,
    'sun': DateTime.sunday,
  };

  // Multi-word date phrases first, so their words don't leak into the title.
  var text = input;
  final inDays = RegExp(r'\bin (\d+) days?\b', caseSensitive: false);
  final inDaysMatch = inDays.firstMatch(text);
  if (inDaysMatch != null) {
    dueAt = today.add(Duration(days: int.parse(inDaysMatch.group(1)!)));
    text = text.replaceFirst(inDays, ' ');
  } else {
    final nextWeek = RegExp(r'\bnext week\b', caseSensitive: false);
    if (nextWeek.hasMatch(text)) {
      // Next Monday.
      dueAt = today.add(Duration(days: 8 - today.weekday));
      text = text.replaceFirst(nextWeek, ' ');
    }
  }

  final titleWords = <String>[];
  for (final word in text.split(RegExp(r'\s+'))) {
    if (word.isEmpty) continue;
    final lower = word.toLowerCase();

    final priorityMatch = RegExp(r'^!p([1-3])$').firstMatch(lower);
    if (priorityMatch != null) {
      priority = int.parse(priorityMatch.group(1)!);
      continue;
    }
    if (word.length > 1 && word.startsWith('#')) {
      tags.add(word.substring(1));
      continue;
    }
    if (word.length > 1 && word.startsWith('@')) {
      project = word.substring(1);
      continue;
    }
    if (dueAt == null) {
      if (lower == 'today') {
        dueAt = today;
        continue;
      }
      if (lower == 'tomorrow') {
        dueAt = today.add(const Duration(days: 1));
        continue;
      }
      final weekday = weekdays[lower];
      if (weekday != null) {
        // Next occurrence of that weekday, never today.
        var ahead = (weekday - today.weekday + 7) % 7;
        if (ahead == 0) ahead = 7;
        dueAt = today.add(Duration(days: ahead));
        continue;
      }
    }
    titleWords.add(word);
  }

  return QuickAddResult(
    title: titleWords.join(' ').trim(),
    priority: priority,
    dueAt: dueAt,
    tags: tags,
    project: project,
  );
}
