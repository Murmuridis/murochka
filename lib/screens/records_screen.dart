import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bp.dart';
import '../db.dart';
import '../knit.dart';
import 'pdf_sheet.dart';
import 'record_screen.dart';

/// Текст дневника для врача (последние [days] дней).
Future<String> doctorReport({int days = 30}) async {
  final from = DateTime.now().subtract(Duration(days: days));
  final items = (await AppDb.instance.readings()).where((r) => r.time.isAfter(from)).toList();
  if (items.isEmpty) return '';
  final f = DateFormat('dd.MM.yyyy HH:mm');
  final b = StringBuffer('Дневник давления (последние $days дн.)\n\n');
  for (final r in items) {
    b.write('${f.format(r.time)}   ${r.sys}/${r.dia}');
    if (r.pulse != null) b.write('   пульс ${r.pulse}');
    if (r.mood != null) b.write('   самочувствие: ${moodLabels[r.mood!].toLowerCase()}');
    if (r.note.isNotEmpty) b.write('   (${r.note})');
    b.writeln();
  }
  final s = items.map((e) => e.sys).reduce((a, b) => a + b) / items.length;
  final d = items.map((e) => e.dia).reduce((a, b) => a + b) / items.length;
  b.write('\nСреднее: ${s.round()}/${d.round()}, измерений: ${items.length}');
  return b.toString();
}

class RecordsScreen extends StatefulWidget {
  const RecordsScreen({super.key});
  @override
  State<RecordsScreen> createState() => _RecordsScreenState();
}

class _RecordsScreenState extends State<RecordsScreen> {
  List<Reading>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await AppDb.instance.readings();
    if (mounted) setState(() => _items = r);
  }

  Widget _addPast() => SoftCard(
        margin: const EdgeInsets.only(top: 4, bottom: 6),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const RecordScreen(past: true)));
          _load();
        },
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: const Row(children: [
          Icon(Icons.history, color: Wool.raspberry, size: 28),
          SizedBox(width: 12),
          Expanded(child: Text('Добавить прошлые показания', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
          Icon(Icons.add_circle_outline, color: Wool.raspberry),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final dayF = DateFormat('EEEE, d MMMM', 'ru');
    final widgets = <Widget>[];
    String? lastDay;
    for (final r in items ?? <Reading>[]) {
      final d = dayKey(r.time);
      if (d != lastDay) {
        lastDay = d;
        final title = dayF.format(r.time);
        widgets.add(Padding(
          padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
          child: Text(title[0].toUpperCase() + title.substring(1), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Wool.muted)),
        ));
      }
      final cat = classify(r.sys, r.dia);
      widgets.add(SoftCard(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => RecordScreen(initial: r)));
          _load();
        },
        child: Row(children: [
          Text(DateFormat('HH:mm').format(r.time), style: const TextStyle(fontSize: 15, color: Wool.muted, fontWeight: FontWeight.w600)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('${r.sys}/${r.dia}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
                if (r.pulse != null) ...[
                  const SizedBox(width: 14),
                  const KnitHeart(size: 18),
                  const SizedBox(width: 4),
                  Text('${r.pulse}', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ],
              ]),
              if (r.note.isNotEmpty) Text(r.note, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Wool.muted)),
            ]),
          ),
          if (r.mood != null) SizedBox(width: 28, height: 28, child: CustomPaint(painter: MoodPainter(r.mood!, true))),
          const SizedBox(width: 8),
          Container(width: 10, height: 34, decoration: BoxDecoration(color: cat.color, borderRadius: BorderRadius.circular(5))),
        ]),
      ));
    }
    return KnitScaffold(
      title: 'Все записи',
      actions: [IconButton(tooltip: 'PDF для врача', icon: const Icon(Icons.picture_as_pdf_outlined, color: Wool.raspberry), onPressed: () => showPdfSheet(context))],
      body: items == null
          ? const SizedBox()
          : items.isEmpty
              ? ListView(padding: const EdgeInsets.all(14), children: [
                  _addPast(),
                  const SizedBox(height: 30),
                  const Center(child: Text('Записей пока нет', style: TextStyle(fontSize: 17, color: Wool.muted))),
                ])
              : ListView(padding: EdgeInsets.fromLTRB(14, 0, 14, 24 + MediaQuery.of(context).padding.bottom), children: [_addPast(), ...widgets]),
    );
  }
}
