import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/recurrence.dart';
import '../../design/palette.dart';

/// Small fixed palette for event colors, drawn from both themes so events
/// read well in Meadow and Twilight alike.
const eventPalette = [
  MeadowPalette.leaf,
  TwilightPalette.lantern,
  MeadowPalette.sky,
  TwilightPalette.vermilion,
  MeadowPalette.blossom,
];

const _reminderChoices = <String, Duration?>{
  'No reminder': null,
  'At start': Duration.zero,
  '10 minutes before': Duration(minutes: 10),
  '1 hour before': Duration(hours: 1),
  '1 day before': Duration(days: 1),
};

/// Creates (event == null) or edits an event.
Future<void> showEventEditor(
  BuildContext context,
  WidgetRef ref, {
  DateTime? initialDay,
  Event? event,
}) {
  final title = TextEditingController(text: event?.title ?? '');
  final notes = TextEditingController(text: event?.notes ?? '');
  var allDay = event?.allDay ?? false;
  var day = DateUtils.dateOnly(event?.startAt ?? initialDay ?? DateTime.now());
  var startTime = event == null
      ? const TimeOfDay(hour: 9, minute: 0)
      : TimeOfDay.fromDateTime(event.startAt);
  var endTime =
      event?.endAt == null ? null : TimeOfDay.fromDateTime(event!.endAt!);
  var rrule = event?.rrule;
  var color = event?.color;
  Duration? remindBefore = event == null ? null : _NoChange.sentinel;
  final repo = ref.read(eventRepositoryProvider);

  DateTime compose(TimeOfDay t) =>
      DateTime(day.year, day.month, day.day, t.hour, t.minute);

  return showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(event == null ? 'New event' : 'Edit event'),
        content: SizedBox(
          width: 360,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: title,
                  autofocus: event == null,
                  decoration: const InputDecoration(labelText: 'Title'),
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          icon: const Icon(Icons.event, size: 18),
                          label: Text(
                            DateFormat.MMMd().format(day),
                            overflow: TextOverflow.ellipsis,
                          ),
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: day,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2035),
                            );
                            if (picked != null) {
                              setState(() => day = picked);
                            }
                          },
                        ),
                      ),
                    ),
                    const Text('All day'),
                    Switch(
                      value: allDay,
                      onChanged: (v) => setState(() => allDay = v),
                    ),
                  ],
                ),
                if (!allDay)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      TextButton(
                        child: Text('from ${startTime.format(context)}'),
                        onPressed: () async {
                          final picked = await showTimePicker(
                              context: context, initialTime: startTime);
                          if (picked != null) {
                            setState(() => startTime = picked);
                          }
                        },
                      ),
                      TextButton(
                        child: Text(endTime == null
                            ? 'add end time'
                            : 'to ${endTime!.format(context)}'),
                        onPressed: () async {
                          final picked = await showTimePicker(
                              context: context,
                              initialTime: endTime ?? startTime);
                          if (picked != null) {
                            setState(() => endTime = picked);
                          }
                        },
                      ),
                    ],
                  ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String?>(
                  initialValue: rrule,
                  decoration: const InputDecoration(labelText: 'Repeat'),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('Does not repeat')),
                    for (final entry in Recurrence.presets.entries)
                      DropdownMenuItem(
                          value: entry.value.toRrule(),
                          child: Text(entry.key)),
                  ],
                  onChanged: (v) => setState(() => rrule = v),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<Duration?>(
                  initialValue:
                      remindBefore == _NoChange.sentinel ? null : remindBefore,
                  decoration: InputDecoration(
                    labelText: event == null
                        ? 'Reminder'
                        : 'Reminder (changing replaces the old one)',
                  ),
                  items: [
                    for (final entry in _reminderChoices.entries)
                      DropdownMenuItem(
                          value: entry.value, child: Text(entry.key)),
                  ],
                  onChanged: (v) => setState(() => remindBefore = v),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final c in eventPalette)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () =>
                              setState(() => color = c.toARGB32()),
                          child: Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              color: c,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: color == c.toARGB32()
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.transparent,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(labelText: 'Notes'),
                  minLines: 1,
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ),
        actions: [
          if (event != null)
            TextButton(
              onPressed: () async {
                await repo.deleteEvent(event.id);
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Delete'),
            ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              if (title.text.trim().isEmpty) return;
              final startAt =
                  allDay ? day : compose(startTime);
              final endAt = allDay || endTime == null
                  ? null
                  : compose(endTime!);
              if (event == null) {
                await repo.createEvent(
                  title: title.text.trim(),
                  startAt: startAt,
                  endAt: endAt,
                  allDay: allDay,
                  notes: notes.text,
                  rrule: rrule,
                  color: color,
                  remindBefore: remindBefore,
                );
              } else {
                await repo.updateEvent(
                  event.id,
                  EventsCompanion(
                    title: Value(title.text.trim()),
                    startAt: Value(startAt),
                    endAt: Value(endAt),
                    allDay: Value(allDay),
                    notes: Value(notes.text),
                    rrule: Value(rrule),
                    color: Value(color),
                  ),
                );
                if (remindBefore != _NoChange.sentinel) {
                  await repo.setEventReminder(event.id, remindBefore);
                }
              }
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
}

/// Sentinel distinguishing "user did not touch the reminder dropdown" from
/// "user chose No reminder" when editing.
abstract final class _NoChange {
  static const sentinel = Duration(microseconds: -9007199254740991);
}
