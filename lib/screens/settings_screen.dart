import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../backup.dart';
import '../db.dart';
import '../knit.dart';
import '../notifications.dart';
import 'pdf_sheet.dart';
import 'records_screen.dart';
import '../pdf_report.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  DateTime? _lastBackup;
  bool _busy = false;
  int? _pending;
  bool? _notifOn;
  List<String> _bpTimes = [];
  Patient _patient = const Patient('', null);
  bool _bpOn = true;

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  Future<void> _loadMeta() async {
    final v = await AppDb.instance.getMeta('last_backup');
    int? pending;
    bool? on;
    final bpTimes = await Notifier.instance.bpTimes();
    final bpOn = await Notifier.instance.bpEnabled();
    final patient = await Patient.load();
    try {
      pending = await Notifier.instance.pendingCount();
      on = await Notifier.instance.enabled();
    } catch (_) {}
    if (mounted) {
      setState(() {
        _lastBackup = v == null ? null : DateTime.tryParse(v);
        _pending = pending;
        _notifOn = on;
        _bpTimes = bpTimes;
        _bpOn = bpOn;
        _patient = patient;
      });
    }
  }

  Future<void> _run(Future<void> Function() job) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await job();
    } on FormatException catch (e) {
      if (mounted) toast(context, e.message);
    } on PlatformException catch (e) {
      if (mounted) toast(context, 'Ошибка: ${e.message ?? e.code}');
    } catch (e) {
      if (mounted) toast(context, 'Не получилось: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
      _loadMeta();
    }
  }

  Future<void> _saveBp(List<String> times, bool on) => _run(() async {
        setState(() {
          _bpTimes = List.of(times)..sort();
          _bpOn = on;
        });
        await Notifier.instance.requestPermissions();
        await Notifier.instance.saveBp(times, on);
        if (!mounted) return;
        toast(
          context,
          !on || times.isEmpty ? 'Напоминания о давлении выключены' : 'Напомню измерить давление: ${(List.of(times)..sort()).join(', ')}',
        );
      });

  Future<void> _addBpTime() async {
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0), helpText: 'Когда измерять давление');
    if (t == null) return;
    final s = hm(t.hour, t.minute);
    if (_bpTimes.contains(s)) return;
    await _saveBp([..._bpTimes, s], true);
  }

  Widget _bpCard() => SoftCard(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const KnitHeart(size: 30),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Измерить давление', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                Text('Напомню в выбранное время каждый день', style: TextStyle(fontSize: 13, color: Wool.muted)),
              ]),
            ),
            if (_bpTimes.isNotEmpty) KnitSwitch(value: _bpOn, onChanged: (v) => _saveBp(_bpTimes, v)),
          ]),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Opacity(
              opacity: _bpOn || _bpTimes.isEmpty ? 1 : .5,
              child: Wrap(spacing: 8, runSpacing: 8, children: [
                for (final t in _bpTimes)
                  InputChip(
                    avatar: const Icon(Icons.alarm, color: Colors.white, size: 18),
                    label: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white)),
                    backgroundColor: Wool.raspberry,
                    deleteIconColor: Colors.white,
                    side: BorderSide.none,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onDeleted: _busy ? null : () => _saveBp(_bpTimes.where((x) => x != t).toList(), _bpOn),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add_alarm, color: Wool.raspberry),
                  label: const Text('Добавить время', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  backgroundColor: Wool.card,
                  side: const BorderSide(color: Wool.cardEdge, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onPressed: _busy ? null : _addBpTime,
                ),
                if (_bpTimes.isEmpty)
                  ActionChip(
                    label: const Text('Утром и вечером: 08:00, 20:00', style: TextStyle(fontSize: 14)),
                    backgroundColor: Wool.card,
                    side: const BorderSide(color: Wool.cardEdge, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    onPressed: _busy ? null : () => _saveBp(['08:00', '20:00'], true),
                  ),
              ]),
            ),
          ),
        ]),
      );

  Future<void> _save() => _run(() async {
        final ok = await Backup.saveToFile();
        if (ok && mounted) toast(context, 'Копия сохранена');
      });

  Future<void> _share() => _run(Backup.share);

  Future<void> _restore() => _run(() async {
        final data = await Backup.pick();
        if (data == null || !mounted) return;
        final ok = await confirmDialog(
          context,
          'Восстановить из копии?',
          '${Backup.describe(data)}\n\nВсе текущие записи и лекарства в приложении будут заменены данными из копии.',
          yes: 'Восстановить',
        );
        if (ok != true) return;
        await Backup.restore(data);
        if (mounted) toast(context, 'Данные восстановлены');
      });

  Widget _item(Widget icon, String title, String sub, VoidCallback onTap) => SoftCard(
        margin: const EdgeInsets.only(bottom: 12),
        onTap: _busy ? null : onTap,
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Row(children: [
          SizedBox(width: 32, child: Center(child: icon)),
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

  Widget _section(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
        child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
      );

  Icon _ic(IconData i) => Icon(i, color: Wool.raspberry, size: 28);

  @override
  Widget build(BuildContext context) {
    final last = _lastBackup;
    final stale = last == null || DateTime.now().difference(last).inDays > 14;
    return KnitScaffold(
      title: 'Настройки',
      body: Stack(children: [
        ListView(
          padding: EdgeInsets.fromLTRB(16, 0, 16, 24 + MediaQuery.of(context).padding.bottom),
          children: [
            _section('Напоминания'),
            _bpCard(),
            if (_pending != null)
              SoftCard(
                margin: const EdgeInsets.only(bottom: 12),
                color: _notifOn == false ? Wool.rose : Wool.card,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                child: Row(children: [
                  Icon(_notifOn == false ? Icons.notifications_off_outlined : Icons.alarm_on, color: _notifOn == false ? Wool.raspberry : Wool.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _notifOn == false
                          ? 'Уведомления для Мурочки выключены в настройках телефона. Без них напоминания не придут.'
                          : 'Поставлено напоминаний: $_pending',
                      style: const TextStyle(fontSize: 14, height: 1.35),
                    ),
                  ),
                ]),
              ),
            _item(_ic(Icons.notifications_active_outlined), 'Проверить сейчас', 'Тестовое уведомление прямо сейчас', () => _run(Notifier.instance.showTest)),
            _item(_ic(Icons.timer_outlined), 'Проверить через минуту', 'Поставлю напоминание на минуту вперёд — закрой приложение и подожди', () => _run(() async {
                  await Notifier.instance.scheduleTest();
                  if (mounted) toast(context, 'Жди уведомление через минуту');
                })),
            _item(_ic(Icons.refresh), 'Обновить напоминания', 'Если уведомления перестали приходить', () => _run(() async {
                  await Notifier.instance.requestPermissions();
                  await Notifier.instance.rescheduleAll();
                  if (mounted) toast(context, 'Напоминания обновлены');
                })),
            _section('Резервная копия'),
            SoftCard(
              margin: const EdgeInsets.only(bottom: 12),
              color: stale ? Wool.rose : Wool.card,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
                Icon(stale ? Icons.info_outline : Icons.verified_outlined, color: stale ? Wool.raspberry : Wool.green),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    last == null
                        ? 'Копия ещё ни разу не сохранялась. Сохрани её, чтобы не потерять записи при смене телефона или переустановке.'
                        : 'Последняя копия: ${DateFormat('d MMMM yyyy, HH:mm', 'ru').format(last)}${stale ? '. Пора сделать новую.' : ''}',
                    style: const TextStyle(fontSize: 14, height: 1.35),
                  ),
                ),
              ]),
            ),
            _item(_ic(Icons.save_alt), 'Сохранить копию в файл', 'Выбери папку: Загрузки или Google Диск', _save),
            _item(_ic(Icons.send_outlined), 'Отправить копию', 'В Telegram, на почту или в облако', _share),
            _item(_ic(Icons.settings_backup_restore), 'Восстановить из копии', 'После переустановки или на новом телефоне', _restore),
            _section('Для врача'),
            _item(
              _ic(Icons.person_outline),
              'Пациент',
              _patient.isEmpty
                  ? 'Укажи ФИО и дату рождения — они будут в PDF'
                  : '${_patient.name}${_patient.dob == null ? '' : ', ${DateFormat('dd.MM.yyyy').format(_patient.dob!)}'}',
              () async {
                await editPatient(context);
                _loadMeta();
              },
            ),
            _item(_ic(Icons.picture_as_pdf_outlined), 'PDF для врача', 'Давление, лекарства с дозировкой, сводка', () async {
              await showPdfSheet(context);
              _loadMeta();
            }),
            _item(const KnitHeart(size: 26), 'Дневник текстом', 'Скопировать записи за месяц в буфер', () => _run(() async {
                  final text = await doctorReport();
                  if (!mounted) return;
                  if (text.isEmpty) {
                    toast(context, 'За последний месяц записей нет');
                    return;
                  }
                  await Clipboard.setData(ClipboardData(text: text));
                  if (mounted) toast(context, 'Скопировано — можно вставить в сообщение врачу');
                })),
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
        if (_busy) const Positioned.fill(child: ColoredBox(color: Color(0x33000000), child: Center(child: CircularProgressIndicator(color: Wool.raspberry)))),
      ]),
    );
  }
}
