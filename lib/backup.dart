import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'db.dart';
import 'notifications.dart';

/// Резервная копия: один JSON-файл со всеми записями, лекарствами и отметками.
class Backup {
  static const _app = 'murochka';
  static const _format = 1;

  static String _fileName() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'murochka_${n.year}-${two(n.month)}-${two(n.day)}_${two(n.hour)}${two(n.minute)}.json';
  }

  static Future<Uint8List> _bytes() async {
    final data = await AppDb.instance.dumpAll();
    final json = const JsonEncoder.withIndent(' ').convert({
      'app': _app,
      'format': _format,
      'exported_at': DateTime.now().toIso8601String(),
      ...data,
    });
    return Uint8List.fromList(utf8.encode(json));
  }

  /// Сохранить файл туда, куда выберет пользователь (Загрузки, Google Диск…).
  /// Возвращает true, если файл сохранён.
  static Future<bool> saveToFile() async {
    final bytes = await _bytes();
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Куда сохранить копию',
      fileName: _fileName(),
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
    if (path == null) return false;
    await AppDb.instance.setMeta('last_backup', DateTime.now().toIso8601String());
    return true;
  }

  /// Отправить файл через Telegram, почту, Google Диск и т.п.
  static Future<void> share() async {
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, _fileName()));
    await file.writeAsBytes(await _bytes());
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/json')],
      subject: 'Мурочка — резервная копия',
      text: 'Резервная копия «Мурочки». Чтобы восстановить: Настройки → Восстановить из копии.',
    ));
    await AppDb.instance.setMeta('last_backup', DateTime.now().toIso8601String());
  }

  /// Выбрать файл копии. Возвращает разобранные данные или бросает FormatException.
  static Future<Map<String, dynamic>?> pick() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.any, withData: true);
    if (res == null || res.files.isEmpty) return null;
    final f = res.files.single;
    final bytes = f.bytes ?? (f.path != null ? await File(f.path!).readAsBytes() : null);
    if (bytes == null) throw const FormatException('Не удалось прочитать файл');
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const FormatException('Это не файл резервной копии «Мурочки»');
    }
    if (decoded is! Map<String, dynamic> || decoded['app'] != _app) {
      throw const FormatException('Это не файл резервной копии «Мурочки»');
    }
    if ((decoded['format'] as int? ?? 0) > _format) {
      throw const FormatException('Копия сделана в более новой версии — обнови приложение');
    }
    return decoded;
  }

  static String describe(Map<String, dynamic> d) {
    final r = (d['readings'] as List?)?.length ?? 0;
    final m = (d['meds'] as List?)?.length ?? 0;
    final at = DateTime.tryParse(d['exported_at'] as String? ?? '');
    final when = at == null
        ? ''
        : ' от ${at.day.toString().padLeft(2, '0')}.${at.month.toString().padLeft(2, '0')}.${at.year}';
    return 'Копия$when: записей давления — $r, лекарств — $m.';
  }

  /// Заменить все данные содержимым копии и заново поставить напоминания.
  static Future<void> restore(Map<String, dynamic> d) async {
    await AppDb.instance.replaceAll(d);
    await Notifier.instance.rescheduleAll();
  }
}
