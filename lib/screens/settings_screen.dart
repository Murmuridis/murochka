import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../knit.dart';
import '../notifications.dart';
import 'records_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Widget _item(IconData icon, String title, String sub, VoidCallback onTap) => SoftCard(
        margin: const EdgeInsets.only(bottom: 12),
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(children: [
          Icon(icon, color: Wool.raspberry, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
              Text(sub, style: const TextStyle(fontSize: 13, color: Wool.muted)),
            ]),
          ),
          const Icon(Icons.chevron_right, color: Wool.muted),
        ]),
      );

  @override
  Widget build(BuildContext context) => KnitScaffold(
        title: 'Настройки',
        body: ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.of(context).padding.bottom),
          children: [
            _item(Icons.notifications_active_outlined, 'Проверить напоминание', 'Пришлю тестовое уведомление прямо сейчас', () async {
              await Notifier.instance.showTest();
            }),
            _item(Icons.copy_all_outlined, 'Дневник для врача', 'Скопировать записи за месяц', () async {
              final text = await doctorReport();
              if (!context.mounted) return;
              if (text.isEmpty) {
      toast(context, 'За последний месяц записей нет');
      return;
    }
              await Clipboard.setData(ClipboardData(text: text));
              if (context.mounted) toast(context, 'Скопировано — можно вставить в сообщение врачу');
            }),
            _item(Icons.refresh, 'Обновить напоминания', 'Если уведомления перестали приходить', () async {
              await Notifier.instance.requestPermissions();
              await Notifier.instance.rescheduleAll();
              if (context.mounted) toast(context, 'Напоминания обновлены');
            }),
            const SizedBox(height: 6),
            const SoftCard(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Чтобы напоминания не опаздывали', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                SizedBox(height: 6),
                Text(
                  'В настройках телефона: Приложения → Мурочка → Батарея → «Без ограничений». '
                  'На Xiaomi ещё включи «Автозапуск».',
                  style: TextStyle(fontSize: 14, color: Wool.muted, height: 1.4),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            const SoftCard(
              child: Text(
                'Категории давления ориентировочные и не заменяют консультацию врача.',
                style: TextStyle(fontSize: 13, color: Wool.muted, height: 1.4),
              ),
            ),
          ],
        ),
      );
}
