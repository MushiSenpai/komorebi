import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Shared local-notification sink for reminders and pomodoro phase changes.
/// Fails quietly where no backend exists (tests, unsupported platforms).
class Notifications {
  Notifications._();

  static final instance = Notifications._();

  final _plugin = FlutterLocalNotificationsPlugin();
  var _ready = false;
  var _id = 0;

  Future<void> init() async {
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          linux: LinuxInitializationSettings(defaultActionName: 'Open'),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Komorebi: notifications unavailable: $e');
    }
  }

  Future<void> show(String title, String body) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: _id++,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'komorebi_reminders',
            'Reminders',
            channelDescription: 'Event, task, and focus reminders',
          ),
          linux: LinuxNotificationDetails(),
        ),
      );
    } catch (e) {
      debugPrint('Komorebi: could not show notification: $e');
    }
  }
}
