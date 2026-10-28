import 'package:flutter/material.dart';

import '../db.dart';
import '../knit.dart';
import '../notifications.dart';

enum _State { ask, taken, snoozed }

/// Экран «Пора принять лекарство!» — открывается из уведомления.
class ReminderScreen extends StatefulWidget {
  final int medId;
  final String slot;
  final String? action;
  const ReminderScreen({super.key, required this.medId, required this.slot, this.action});
  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  Med? _med;
  _State _state = _State.ask;
  String _snoozeAt = '';

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final m = await AppDb.instance.med(widget.medId);
    if (!mounted) return;
    setState(() => _med = m);
    if (m == null) return;
    if (widget.action == 'taken') await _taken();
    if (widget.action == 'snooze') await _snooze();
  }

  Future<void> _taken() async {
    await AppDb.instance.setTaken(widget.medId, widget.slot, DateTime.now(), true);
    if (mounted) setState(() => _state = _State.taken);
  }

  Future<void> _snooze() async {
    await Notifier.instance.snooze(_med!, widget.slot);
    final t = DateTime.now().add(const Duration(minutes: 10));
    if (mounted) {
      setState(() {
        _snoozeAt = hm(t.hour, t.minute);
        _state = _State.snoozed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _med;
    final pad = MediaQuery.of(context).padding;
    final h = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: Wool.cream,
      body: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: KnitPainter(Wool.cream, stitch: 15, contrast: .28))),
        Positioned(top: 0, left: 0, right: 0, height: h * .46, child: Image.asset('assets/images/cat_reminder.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter)),
        Positioned(
          top: pad.top + 8,
          left: 12,
          child: RoundKnitButton(onTap: () => Navigator.maybePop(context), child: const Icon(Icons.close, color: Wool.ink)),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: pad.bottom + 16,
          top: h * .39,
          child: SoftCard(
            radius: 28,
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            child: m == null
                ? const Center(child: Text('Лекарство не найдено', style: TextStyle(fontSize: 18)))
                : Column(children: [
                    Text(
                      switch (_state) {
                        _State.ask => 'Пора принять\nлекарство!',
                        _State.taken => 'Умница!\nПриём отмечен',
                        _State.snoozed => 'Хорошо,\nнапомню в $_snoozeAt',
                      },
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.2),
                    ),
                    const SizedBox(height: 18),
                    SoftCard(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      child: Row(children: [
                        PillIcon(shape: m.shape, color: pillColors[m.color % pillColors.length], size: 60, framed: false),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(m.name, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                            Text([if (m.dose.isNotEmpty) m.dose, widget.slot].join(' · '), style: const TextStyle(fontSize: 16, color: Wool.muted)),
                          ]),
                        ),
                        if (_state == _State.taken) const Icon(Icons.check_circle, color: Wool.green, size: 32),
                      ]),
                    ),
                    const Spacer(),
                    if (_state == _State.ask) ...[
                      KnitButton(label: 'Я приняла', onPressed: _taken),
                      const SizedBox(height: 14),
                      KnitButton(label: 'Отложить на 10 минут', primary: false, onPressed: _snooze),
                    ] else
                      KnitButton(label: 'Готово', onPressed: () => Navigator.maybePop(context)),
                  ]),
          ),
        ),
      ]),
    );
  }
}
