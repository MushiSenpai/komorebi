import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../data/repos/event_repository.dart';
import '../data/repos/task_repository.dart';

/// Fires due reminders as local notifications while the app runs.
///
/// Linux has no OS-level scheduled notifications (and Android's exact alarms
/// need extra permissions), so v1 polls the reminders table once a minute
/// in-app and shows the notification when a row comes due. OS-scheduled
/// notifications are a Phase 7 polish item (SPEC §5.3/§7).
class ReminderEngine {
  ReminderEngine(this._events, this._tasks);

  final EventRepository _events;
  final TaskRepository _tasks;
  final _plugin = FlutterLocalNotificationsPlugin();

  Timer? _timer;
  var _notificationId = 0;

  static const _checkEvery = Duration(seconds: 60);

  Future<void> start() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          linux: LinuxInitializationSettings(defaultActionName: 'Open'),
        ),
      );
    } catch (e) {
      // No notification backend (tests, unsupported platform) — stay quiet.
      debugPrint('Komorebi: notifications unavailable: $e');
      return;
    }
    _timer = Timer.periodic(_checkEvery, (_) => _tick());
    await _tick();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _tick() async {
    final due = await _events.dueReminders(DateTime.now());
    for (final reminder in due) {
      final body = await _describe(reminder.targetKind, reminder.targetId);
      // Mark first: a notification backend hiccup must not re-fire forever.
      await _events.markReminderFired(reminder.id);
      if (body != null) {
        await _show(body.$1, body.$2);
      }
    }
  }

  Future<(String, String)?> _describe(String kind, String id) async {
    try {
      switch (kind) {
        case 'event':
          final event = await _events.getEvent(id);
          if (event.deletedAt != null) return null;
          return ('Coming up', event.title);
        case 'task':
          final task = await _tasks.getTask(id);
          if (task.deletedAt != null || task.completedAt != null) return null;
          return ('Task due', task.title);
      }
    } catch (_) {
      // Target was hard-deleted; nothing to announce.
    }
    return null;
  }

  Future<void> _show(String title, String body) async {
    try {
      await _plugin.show(
        id: _notificationId++,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'komorebi_reminders',
            'Reminders',
            channelDescription: 'Event and task reminders',
          ),
          linux: LinuxNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('Komorebi: could not show notification: $e');
    }
  }
}
