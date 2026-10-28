import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import 'db.dart';

/// Что пришло из уведомления: какое лекарство, какое время, какая кнопка.
class ReminderTap {
  final int medId;
  final String slot;
  final String? action; // 'taken' | 'snooze' | null (просто нажали)
  ReminderTap(this.medId, this.slot, this.action);

  static ReminderTap? parse(NotificationResponse r) {
    final p = r.payload;
    if (p == null || !p.contains('|')) return null;
    final parts = p.split('|');
    final id = int.tryParse(parts[0]);
    if (id == null) return null;
    return ReminderTap(id, parts[1], r.actionId);
  }
}

class Notifier {
  Notifier._();
  static final Notifier instance = Notifier._();
  final _plugin = FlutterLocalNotificationsPlugin();

  /// Сюда приложение подписывается, чтобы открыть экран напоминания.
  void Function(ReminderTap tap)? onTap;
  ReminderTap? launchTap;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'meds_v2',
      'Лекарства',
      channelDescription: 'Напоминания о приёме лекарств',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      color: Color(0xFFC93C5E),
      fullScreenIntent: true,
      actions: [
        AndroidNotificationAction('taken', 'Я приняла', showsUserInterface: true),
        AndroidNotificationAction('snooze', 'Отложить 10 мин', showsUserInterface: true),
      ],
    ),
  );

  Future<void> init() async {
    tzdata.initializeTimeZones();
    tz.setLocalLocation(_guessLocation());
    await _plugin.initialize(
      const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
      onDidReceiveNotificationResponse: (r) {
        final t = ReminderTap.parse(r);
        if (t != null) onTap?.call(t);
      },
    );
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp == true && launch!.notificationResponse != null) {
      launchTap = ReminderTap.parse(launch.notificationResponse!);
    }
  }

  /// Без отдельного плагина: подбираем пояс по текущему смещению,
  /// сначала из привычных вариантов (Нидерланды / Россия).
  tz.Location _guessLocation() {
    final offset = DateTime.now().timeZoneOffset.inMilliseconds;
    const preferred = [
      'Europe/Amsterdam', 'Europe/Moscow', 'Europe/London', 'Europe/Athens',
      'Europe/Samara', 'Asia/Yekaterinburg', 'Asia/Omsk', 'Asia/Novosibirsk',
    ];
    final now = DateTime.now().millisecondsSinceEpoch;
    bool matches(tz.Location l) => l.timeZone(now).offset == offset;
    for (final name in preferred) {
      try {
        final l = tz.getLocation(name);
        if (matches(l)) return l;
      } catch (_) {}
    }
    for (final l in tz.timeZoneDatabase.locations.values) {
      if (matches(l)) return l;
    }
    return tz.UTC;
  }

  Future<void> requestPermissions() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
  }

  int _id(int medId, int index) => medId * 100 + index;
  int _snoozeId(int medId) => 900000 + medId;

  String _body(Med m) => m.dose.isEmpty ? 'Пора принять лекарство' : '${m.dose} — пора принять';

  Future<void> _schedule(int id, Med m, String slot, tz.TZDateTime when, {required bool daily}) async {
    Future<void> go(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          id,
          m.name,
          _body(m),
          when,
          _details,
          payload: '${m.id}|$slot',
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: daily ? DateTimeComponents.time : null,
        );
    try {
      await go(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (_) {
      await go(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  Future<void> cancelMed(int medId) async {
    for (var i = 0; i < 24; i++) {
      await _plugin.cancel(_id(medId, i));
    }
    await _plugin.cancel(_snoozeId(medId));
  }

  Future<void> scheduleMed(Med m) async {
    if (m.id == null) return;
    await cancelMed(m.id!);
    if (!m.active) return;
    final now = tz.TZDateTime.now(tz.local);
    for (var i = 0; i < m.times.length && i < 24; i++) {
      final parts = m.times[i].split(':');
      var when = tz.TZDateTime(tz.local, now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1]));
      if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
      await _schedule(_id(m.id!, i), m, m.times[i], when, daily: true);
    }
  }

  Future<void> snooze(Med m, String slot, {int minutes = 10}) async {
    final when = tz.TZDateTime.now(tz.local).add(Duration(minutes: minutes));
    await _schedule(_snoozeId(m.id!), m, slot, when, daily: false);
  }

  Future<void> showTest() async {
    await requestPermissions();
    await _plugin.show(
      999999,
      'Мурочка',
      'Так будут выглядеть напоминания о лекарствах',
      const NotificationDetails(android: AndroidNotificationDetails('meds_v2', 'Лекарства', importance: Importance.max, priority: Priority.high, color: Color(0xFFC93C5E))),
    );
  }

  /// Тестовое напоминание через минуту — тем же путём, что и настоящие.
  Future<void> scheduleTest() async {
    await requestPermissions();
    final when = tz.TZDateTime.now(tz.local).add(const Duration(minutes: 1));
    Future<void> go(AndroidScheduleMode mode) => _plugin.zonedSchedule(
          999998,
          'Мурочка',
          'Проверка: напоминания работают',
          when,
          const NotificationDetails(android: AndroidNotificationDetails('meds_v2', 'Лекарства', importance: Importance.max, priority: Priority.high, color: Color(0xFFC93C5E))),
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        );
    try {
      await go(AndroidScheduleMode.exactAllowWhileIdle);
    } catch (_) {
      await go(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  /// Сколько напоминаний сейчас поставлено в системе.
  Future<int> pendingCount() async => (await _plugin.pendingNotificationRequests()).length;

  /// Включены ли уведомления для приложения.
  Future<bool> enabled() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    return await android?.areNotificationsEnabled() ?? true;
  }

  Future<void> rescheduleAll() async {
    await _plugin.cancelAll();
    for (final m in await AppDb.instance.meds()) {
      await scheduleMed(m);
    }
  }
}
