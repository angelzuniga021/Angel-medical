import 'dart:async';
import 'package:flutter/material.dart';
import 'db.dart';

final pcReminder = ValueNotifier<String?>(null);
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();
  final timers = <int, Timer>{};
  Future<void> init() async {}
  Future<void> scheduleAppointment({required int id, required String patientName, required DateTime when, int minutesBefore = 30}) async {
    await cancel(id);
    final delay = when.subtract(Duration(minutes: minutesBefore)).difference(DateTime.now());
    if (delay.isNegative) return;
    timers[id] = Timer(delay, () { pcReminder.value = 'Cita próxima · ${when.hour.toString().padLeft(2, '0')}:${when.minute.toString().padLeft(2, '0')}'; });
  }
  Future<void> showTodayReminder({required int id, required String patientName, required DateTime when}) async { pcReminder.value = 'Cita de hoy · ${when.hour}:${when.minute.toString().padLeft(2, '0')}'; }
  Future<void> cancel(int id) async { timers.remove(id)?.cancel(); }
  Future<void> reconcile() async {
    for (final timer in timers.values) { timer.cancel(); } timers.clear();
    final rows = await AppDb.instance.all('appointments', where: 'status=?', args: ['programada']);
    for (final row in rows) {
      final when = DateTime.tryParse('${row['start_at']}');
      if (when != null && when.isAfter(DateTime.now())) await scheduleAppointment(id: row['id'] as int, patientName: '', when: when, minutesBefore: (row['notify_minutes_before'] as num?)?.toInt() ?? 30);
    }
  }
}
