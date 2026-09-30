import 'db.dart';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _plugin.initialize(settings);

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await androidPlugin?.requestNotificationsPermission();
  }

  Future<void> scheduleAppointment({
    required int id,
    required String patientName,
    required DateTime when,
    int minutesBefore = 30,
  }) async {
    final notifyAt = when.subtract(Duration(minutes: minutesBefore));
    if (notifyAt.isBefore(DateTime.now())) return;

    final scheduled = tz.TZDateTime.from(notifyAt, tz.local);

    await _plugin.zonedSchedule(
      id,
      'Cita médica próxima',
      'Cita programada · ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}',
      scheduled,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'appointments',
          'Citas',
          channelDescription: 'Recordatorios de citas de Angel Medical',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: null,
    );
  }

  Future<void> showTodayReminder({
    required int id,
    required String patientName,
    required DateTime when,
  }) async {
    await _plugin.show(
      id,
      'Cita de hoy',
      'Cita programada · ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'appointments_today',
          'Citas de hoy',
          channelDescription: 'Citas programadas para hoy',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  Future<void> reconcile() async {
    await _plugin.cancelAll();
    final rows = await AppDb.instance.all(
      'appointments',
      where: 'status=?',
      args: ['programada'],
    );
    for (final row in rows) {
      final when = DateTime.tryParse('${row['start_at']}');
      if (when == null || !when.isAfter(DateTime.now())) continue;
      await scheduleAppointment(
        id: row['id'] as int,
        patientName: 'Cita programada',
        when: when,
        minutesBefore: (row['notify_minutes_before'] as num?)?.toInt() ?? 30,
      );
    }
  }

  Future<void> cancel(int id) => _plugin.cancel(id);
}
