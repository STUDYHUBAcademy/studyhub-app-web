import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> init() async {
    // Local scheduled notifications are Android/iOS-only — permission_handler
    // and flutter_local_notifications have no web implementation, and
    // calling them there throws before the app ever renders.
    if (kIsWeb) return;
    if (_initialized) return;
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const settings = InitializationSettings(android: androidSettings);
    await _plugin.initialize(settings: settings);
    await Permission.notification.request();
    await Permission.scheduleExactAlarm.request();
    _initialized = true;
  }

  static const _reminderOffsets = [Duration(minutes: 10), Duration(minutes: 5)];

  /// Stable 32-bit id derived from a session's UUID + reminder slot so each
  /// of a session's reminders can be scheduled/cancelled independently.
  int _idFor(String sessionId, int slot) =>
      (sessionId.hashCode ^ (slot * 0x9E3779B1)) & 0x7fffffff;

  Future<void> scheduleSessionReminder({
    required String sessionId,
    required String title,
    required String body,
    required DateTime scheduledAt,
  }) async {
    if (kIsWeb) return;
    await init();
    for (var i = 0; i < _reminderOffsets.length; i++) {
      final fireAt = scheduledAt.subtract(_reminderOffsets[i]);
      final id = _idFor(sessionId, i);
      if (fireAt.isBefore(DateTime.now())) {
        await _plugin.cancel(id: id);
        continue;
      }
      await _plugin.zonedSchedule(
        id: id,
        title: title,
        body: body,
        scheduledDate: tz.TZDateTime.from(fireAt, tz.local),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'session_reminders',
            'تذكير الحصص الفردية',
            channelDescription: 'تنبيه قبل موعد الحصة الفردية',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    }
  }

  Future<void> cancelSessionReminder(String sessionId) async {
    if (kIsWeb) return;
    for (var i = 0; i < _reminderOffsets.length; i++) {
      await _plugin.cancel(id: _idFor(sessionId, i));
    }
  }
}
