import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../bp.dart';
import '../db.dart';
import '../knit.dart';
import 'records_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});
  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  int _tab = 0;
  late DateTime _end = _today();
  List<Reading> _readings = [];
  Map<String, int> _taken = {};
  int _plannedPerDay = 0;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime get _start => _end.subtract(const Duration(days: 6));

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await AppDb.instance.readingsBetween(_start, _end.add(const Duration(days: 1)));
    final t = await AppDb.instance.takenCountBetween(_start, _end);
    final meds = await AppDb.instance.meds();
    if (!mounted) return;
    setState(() {
      _readings = r;
      _taken = t;
      _plannedPerDay = meds.where((m) => m.active).fold(0, (a, m) => a + m.times.length);
    });
  }

  void _shift(int weeks) {
    final next = _end.add(Duration(days: 7 * weeks));
    if (next.isAfter(_today())) return;
    setState(() => _end = next);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('d MMM', 'ru');
    final canForward = _end.isBefore(_today());
    return KnitScaffold(
      title: 'Статистика',
      body: ListView(
        padding: EdgeInsets.fromLTRB(12, 2, 12, 24 + MediaQuery.of(context).padding.bottom),
        children: [
          KnitTabs(labels: const ['Давление', 'Пульс', 'Лекарства'], index: _tab, onChanged: (i) => setState(() => _tab = i)),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(children: [
              RoundKnitButton(size: 42, onTap: () => _shift(-1), child: const Icon(Icons.chevron_left, color: Wool.ink)),
              const SizedBox(width: 10),
              Expanded(
                child: SoftCard(
                  radius: 22,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  child: Text('${df.format(_start)} – ${df.format(_end)} ${_end.year}', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Opacity(
                opacity: canForward ? 1 : .35,
                child: RoundKnitButton(size: 42, onTap: () => _shift(1), child: const Icon(Icons.chevron_right, color: Wool.ink)),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _chartCard()),
          const SizedBox(height: 12),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: _summaryCard()),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SoftCard(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const RecordsScreen()));
                _load();
              },
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: const Row(children: [
                Icon(Icons.event_note_outlined, color: Wool.raspberry, size: 30),
                SizedBox(width: 14),
                Expanded(child: Text('Все записи', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))),
                Icon(Icons.chevron_right, color: Wool.ink),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legend(Color c, String t) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 11, height: 11, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(t, style: const TextStyle(fontSize: 13, color: Wool.muted)),
      ]);

  Widget _chartCard() {
    if (_tab == 2) {
      return SoftCard(
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 10),
        child: _plannedPerDay == 0
            ? const SizedBox(height: 150, child: Center(child: Text('Добавь лекарства — здесь появятся отметки о приёме', textAlign: TextAlign.center, style: TextStyle(color: Wool.muted))))
            : SizedBox(height: 210, child: CustomPaint(painter: _BarsPainter(_start, _taken, _plannedPerDay), size: Size.infinite)),
      );
    }
    final pulse = _tab == 1;
    final series = pulse
        ? [_Series(Wool.pulseLine, [for (final r in _readings) if (r.pulse != null) (r.time, r.pulse!)])]
        : [
            _Series(Wool.sysLine, [for (final r in _readings) (r.time, r.sys)]),
            _Series(Wool.diaLine, [for (final r in _readings) (r.time, r.dia)]),
          ];
    final has = series.first.points.isNotEmpty;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(12, 14, 14, 10),
      child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: pulse
            ? [_legend(Wool.pulseLine, 'Пульс')]
            : [_legend(Wool.sysLine, 'Систолическое'), _legend(Wool.diaLine, 'Диастолическое')]),
        const SizedBox(height: 10),
        SizedBox(
          height: 220,
          child: has
              ? CustomPaint(
                  painter: _LineChartPainter(start: _start, series: series, lo: pulse ? 40 : 60, hi: pulse ? 140 : 180, step: pulse ? 20 : 40),
                  size: Size.infinite,
                )
              : const Center(child: Text('За эту неделю записей нет', style: TextStyle(color: Wool.muted, fontSize: 15))),
        ),
      ]),
    );
  }

  Widget _summaryCard() {
    Widget cell(String v, String label) => Expanded(
          child: Column(children: [
            Text(v, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
            Text(label, style: const TextStyle(fontSize: 12, color: Wool.muted)),
          ]),
        );
    int avg(Iterable<int> l) => l.isEmpty ? 0 : (l.reduce((a, b) => a + b) / l.length).round();
    final List<Widget> cells;
    String? tag;
    Color tagColor = Wool.sage;
    if (_tab == 2) {
      final taken = _taken.values.fold(0, (a, b) => a + b);
      final planned = _plannedPerDay * 7;
      final pct = planned == 0 ? 0 : (taken * 100 / planned).round().clamp(0, 100);
      cells = [cell('$pct%', 'вовремя'), cell('$taken', 'принято'), cell('${math.max(0, planned - taken)}', 'пропущено')];
    } else if (_tab == 1) {
      final p = _readings.where((r) => r.pulse != null).map((r) => r.pulse!).toList();
      cells = p.isEmpty
          ? [cell('—', 'среднее')]
          : [cell('${avg(p)}', 'средний'), cell('${p.reduce(math.min)}', 'мин.'), cell('${p.reduce(math.max)}', 'макс.')];
    } else {
      final r = _readings;
      if (r.isEmpty) {
        cells = [cell('—', 'нет данных')];
      } else {
        final s = avg(r.map((e) => e.sys)), d = avg(r.map((e) => e.dia));
        final p = r.where((e) => e.pulse != null).map((e) => e.pulse!);
        final cat = classify(s, d);
        tag = cat.label;
        tagColor = cat.color;
        cells = [cell('$s', 'Систолическое'), cell('$d', 'Диастолическое'), if (p.isNotEmpty) cell('${avg(p)}', 'Пульс')];
      }
    }
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(children: [
        Row(children: [
          Text(_tab == 2 ? 'Приём за неделю' : 'Средние значения', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          const Spacer(),
          if (tag != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: tagColor, borderRadius: BorderRadius.circular(10)),
              child: Text(tag, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
            ),
        ]),
        const SizedBox(height: 12),
        Row(children: cells),
      ]),
    );
  }
}

class _Series {
  final Color color;
  final List<(DateTime, int)> points;
  _Series(this.color, this.points);
}

void _label(Canvas canvas, String s, Offset at, {double size = 11, TextAlign align = TextAlign.left, double width = 40}) {
  final tp = TextPainter(
    text: TextSpan(text: s, style: TextStyle(color: Wool.muted, fontSize: size)),
    textDirection: TextDirection.ltr,
    textAlign: align,
  )..layout(minWidth: width, maxWidth: width);
  tp.paint(canvas, at);
}

/// Линии-нитки за 7 дней.
class _LineChartPainter extends CustomPainter {
  final DateTime start;
  final List<_Series> series;
  final int lo, hi, step;
  _LineChartPainter({required this.start, required this.series, required this.lo, required this.hi, required this.step});

  @override
  void paint(Canvas canvas, Size size) {
    const left = 30.0, bottom = 22.0, top = 6.0, right = 6.0;
    final w = size.width - left - right;
    final h = size.height - top - bottom;
    final dayW = w / 7;
    double y(num v) => top + (1 - (v.clamp(lo, hi) - lo) / (hi - lo)) * h;
    double x(DateTime t) {
      final days = t.difference(start).inMinutes / (24 * 60);
      return left + days * dayW;
    }

    final grid = Paint()
      ..color = Wool.cardEdge
      ..strokeWidth = 1;
    for (var v = lo; v <= hi; v += step) {
      canvas.drawLine(Offset(left, y(v)), Offset(left + w, y(v)), grid);
      _label(canvas, '$v', Offset(0, y(v) - 7), width: 26);
    }
    final df = DateFormat('dd.MM');
    for (var i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      final cx = left + dayW * (i + .5);
      canvas.drawLine(Offset(cx, top), Offset(cx, top + h), grid..color = Wool.cardEdge.withOpacity(.5));
      _label(canvas, df.format(d), Offset(cx - 20, size.height - 15), width: 40, align: TextAlign.center);
    }

    for (final s in series) {
      if (s.points.isEmpty) continue;
      final pts = [for (final p in s.points) Offset(x(p.$1), y(p.$2))];
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, Paint()
        ..color = s.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round);
      // «скрутка» нитки
      final twist = Paint()
        ..color = Wool.dark(s.color, .25)
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round;
      for (final m in path.computeMetrics()) {
        for (double d = 0; d < m.length; d += 4) {
          final t = m.getTangentForOffset(d);
          if (t == null) continue;
          final n = Offset(-t.vector.dy, t.vector.dx);
          canvas.drawLine(t.position + n * 1.6 - t.vector * 1.2, t.position - n * 1.6 + t.vector * 1.2, twist);
        }
      }
      for (final p in pts) {
        canvas.drawCircle(p, 5.5, Paint()..color = Colors.white);
        canvas.drawCircle(p, 4, Paint()..color = s.color);
      }
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter old) => true;
}

/// Столбики-«вязаные полоски»: сколько приёмов отмечено по дням.
class _BarsPainter extends CustomPainter {
  final DateTime start;
  final Map<String, int> taken;
  final int planned;
  _BarsPainter(this.start, this.taken, this.planned);

  @override
  void paint(Canvas canvas, Size size) {
    const bottom = 40.0, top = 6.0;
    final h = size.height - bottom - top;
    final colW = size.width / 7;
    final df = DateFormat('EE', 'ru');
    final dm = DateFormat('dd.MM');
    for (var i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      final n = taken[dayKey(d)] ?? 0;
      final frac = (n / planned).clamp(0.0, 1.0);
      final bw = colW * .52;
      final x = colW * i + (colW - bw) / 2;
      final bg = RRect.fromRectAndRadius(Rect.fromLTWH(x, top, bw, h), Radius.circular(bw / 2));
      canvas.drawRRect(bg, Paint()..color = Wool.cardEdge.withOpacity(.6));
      if (frac > 0) {
        final barH = math.max(bw, h * frac);
        final r = Rect.fromLTWH(x, top + h - barH, bw, barH);
        final rr = RRect.fromRectAndRadius(r, Radius.circular(bw / 2));
        canvas.save();
        canvas.clipRRect(rr);
        canvas.translate(r.left, r.top);
        KnitPainter(frac >= 1 ? Wool.green : Wool.mustard, stitch: bw * .5, contrast: .6).paint(canvas, r.size);
        canvas.restore();
      }
      _label(canvas, '$n/$planned', Offset(colW * i, top + h + 4), width: colW, align: TextAlign.center, size: 12);
      _label(canvas, '${df.format(d)} ${dm.format(d)}', Offset(colW * i, top + h + 20), width: colW, align: TextAlign.center, size: 10.5);
    }
  }

  @override
  bool shouldRepaint(_BarsPainter old) => true;
}
