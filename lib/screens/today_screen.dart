import 'package:flutter/material.dart';

import '../db.dart';
import '../knit.dart';
import '../today.dart';

/// «Сегодня» — отметки о приёме (кнопка-сердечко на главном экране).
class TodayScreen extends StatefulWidget {
  const TodayScreen({super.key});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  List<Slot>? _slots;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await todaySlots();
    if (mounted) setState(() => _slots = s);
  }

  @override
  Widget build(BuildContext context) {
    final slots = _slots;
    final done = slots?.where((s) => s.taken).length ?? 0;
    final now = nowHm();
    return KnitScaffold(
      title: 'Сегодня',
      body: slots == null
          ? const SizedBox()
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.of(context).padding.bottom),
              children: [
                if (slots.isEmpty)
                  const SoftCard(child: Text('На сегодня приёмов нет. Добавь лекарства в разделе «Мои лекарства».', textAlign: TextAlign.center, style: TextStyle(fontSize: 16)))
                else ...[
                  SoftCard(
                    child: Column(children: [
                      Text(done == slots.length ? 'Всё принято — умница!' : 'Принято $done из ${slots.length}',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: SizedBox(
                          height: 14,
                          child: Stack(children: [
                            Container(color: Wool.cardEdge),
                            FractionallySizedBox(
                              widthFactor: done / slots.length,
                              child: CustomPaint(painter: KnitPainter(Wool.green, stitch: 7, contrast: .6), child: const SizedBox.expand()),
                            ),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  for (final s in slots)
                    SoftCard(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                      onTap: () async {
                        await AppDb.instance.setTaken(s.med.id!, s.time, DateTime.now(), !s.taken);
                        _load();
                      },
                      child: Row(children: [
                        SizedBox(
                          width: 72,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(s.time,
                                maxLines: 1,
                                softWrap: false,
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: !s.taken && s.time.compareTo(now) < 0 ? Wool.raspberry : Wool.ink)),
                          ),
                        ),
                        const SizedBox(width: 6),
                        PillIcon(shape: s.med.shape, color: pillColors[s.med.color % pillColors.length], size: 46),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(s.med.name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, decoration: s.taken ? TextDecoration.lineThrough : null)),
                            if (s.med.dose.isNotEmpty) Text(s.med.dose, style: const TextStyle(fontSize: 14, color: Wool.muted)),
                          ]),
                        ),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: s.taken
                              ? const Icon(Icons.check_circle, key: ValueKey(1), color: Wool.green, size: 34)
                              : const Icon(Icons.radio_button_unchecked, key: ValueKey(0), color: Wool.cardEdge, size: 34),
                        ),
                      ]),
                    ),
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Text('Нажми на лекарство, чтобы отметить приём', textAlign: TextAlign.center, style: TextStyle(color: Wool.muted, fontSize: 13)),
                  ),
                ],
              ],
            ),
    );
  }
}
