import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Палитра «уютный свитер».
class Wool {
  static const cream = Color(0xFFF2E4D8); // фон
  static const card = Color(0xFFF9F0E7); // пухлые карточки
  static const cardEdge = Color(0xFFE6D2C1);
  static const raspberry = Color(0xFFC93C5E);
  static const raspberryDark = Color(0xFFA32A4A);
  static const rose = Color(0xFFF6D9DE); // выделенная вкладка
  static const ink = Color(0xFF3B2A23);
  static const muted = Color(0xFF7D685C);
  static const green = Color(0xFF4F7F3A);
  static const sysLine = Color(0xFFE0567A);
  static const diaLine = Color(0xFF3F7FC2);
  static const pulseLine = Color(0xFFD99A3A);
  static const sage = Color(0xFF7E9C7A);
  static const mustard = Color(0xFFDDA23A);
  static const denim = Color(0xFF4F6D8F);
  static const brick = Color(0xFFC0533A);

  static Color dark(Color c, [double t = .25]) => Color.lerp(c, Colors.black, t)!;
  static Color light(Color c, [double t = .25]) => Color.lerp(c, Colors.white, t)!;
}

/// Цвета таблеток (индекс хранится в БД).
const pillColors = [
  Color(0xFFD9475F), // малиновая
  Color(0xFF4F86C6), // голубая
  Color(0xFF6E9B57), // зелёная
  Color(0xFFE0A33C), // горчичная
  Color(0xFF9A7CC0), // лавандовая
  Color(0xFFEDE3D6), // белая
];

/// Лицевая гладь: столбики из «V»-петель. contrast < 1 — для мягких фонов.
class KnitPainter extends CustomPainter {
  final Color color;
  final double stitch;
  final double contrast;
  KnitPainter(this.color, {this.stitch = 14, this.contrast = 1});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Wool.dark(color, .30 * contrast));
    final w = stitch;
    final h = stitch * .82;
    final leg = Paint()
      ..color = color
      ..strokeWidth = w * .46
      ..strokeCap = StrokeCap.round;
    final shine = Paint()
      ..color = Wool.light(color, .30 * contrast)
      ..strokeWidth = w * .12
      ..strokeCap = StrokeCap.round;
    final shade = Paint()
      ..color = Wool.dark(color, .12 * contrast)
      ..strokeWidth = w * .1
      ..strokeCap = StrokeCap.round;
    final rnd = math.Random(7);
    for (double y = -h; y < size.height + h; y += h) {
      for (double x = -w / 2; x < size.width + w; x += w) {
        final j = (rnd.nextDouble() - .5) * w * .06;
        final bot = y + h * 1.15;
        final mid = x + w / 2 + j;
        final l1 = Offset(x + w * .16, y), l2 = Offset(mid - w * .04, bot);
        canvas.drawLine(l1, l2, leg);
        canvas.drawLine(l1 + Offset(w * .02, h * .1), l2 - Offset(w * .08, h * .25), shine);
        final r1 = Offset(x + w * .84, y), r2 = Offset(mid + w * .04, bot);
        canvas.drawLine(r1, r2, leg);
        canvas.drawLine(r1 + Offset(-w * .1, h * .25), r2 + Offset(w * .02, -h * .2), shade);
      }
    }
  }

  @override
  bool shouldRepaint(KnitPainter old) => old.color != color || old.stitch != stitch || old.contrast != contrast;
}

/// Пунктирный «стежок» по контуру.
class StitchBorderPainter extends CustomPainter {
  final Color color;
  final double inset;
  final double radius;
  StitchBorderPainter(this.color, {this.inset = 6, this.radius = 10});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = (Offset.zero & size).deflate(inset);
    final path = Path()..addRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)));
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, math.min(d + 6, metric.length)), paint);
        d += 11;
      }
    }
  }

  @override
  bool shouldRepaint(StitchBorderPainter old) => old.color != color;
}

/// Экран на мягком вязаном полотне с шапкой «← Заголовок  [действие]».
class KnitScaffold extends StatelessWidget {
  final String? title;
  final Widget body;
  final List<Widget> actions;
  final bool back;
  const KnitScaffold({super.key, this.title, required this.body, this.actions = const [], this.back = true});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Wool.cream,
        body: Stack(children: [
          Positioned.fill(child: RepaintBoundary(child: CustomPaint(painter: KnitPainter(Wool.cream, stitch: 15, contrast: .28)))),
          SafeArea(
            bottom: false,
            child: Column(children: [
              if (title != null)
                SizedBox(
                  height: 60,
                  child: Row(children: [
                    SizedBox(
                      width: 56,
                      child: back
                          ? IconButton(
                              icon: const Icon(Icons.arrow_back, color: Wool.ink, size: 26),
                              onPressed: () => Navigator.maybePop(context),
                            )
                          : null,
                    ),
                    Expanded(child: Text(title!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: Wool.ink))),
                    SizedBox(width: 56, child: actions.isEmpty ? null : Row(mainAxisAlignment: MainAxisAlignment.end, children: actions)),
                  ]),
                ),
              Expanded(child: body),
            ]),
          ),
        ]),
      );
}

/// Пухлая кремовая вязаная карточка.
class SoftCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color color;
  final double radius;
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.onLongPress,
    this.color = Wool.card,
    this.radius = 20,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: margin,
        child: GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
              boxShadow: [
                BoxShadow(color: const Color(0xFF8A6A55).withOpacity(.22), blurRadius: 10, offset: const Offset(0, 4)),
                const BoxShadow(color: Colors.white70, blurRadius: 2, offset: Offset(0, -1)),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(radius),
              child: CustomPaint(
                painter: KnitPainter(color, stitch: 9, contrast: .22),
                foregroundPainter: StitchBorderPainter(Wool.cardEdge, inset: 5, radius: radius - 5),
                child: Padding(padding: padding, child: child),
              ),
            ),
          ),
        ),
      );
}

/// Вязаная кнопка: малиновая (primary) или кремовая (secondary).
class KnitButton extends StatelessWidget {
  final String label;
  final Widget? leading;
  final VoidCallback? onPressed;
  final bool primary;
  final double height;
  const KnitButton({super.key, required this.label, this.leading, this.onPressed, this.primary = true, this.height = 60});

  @override
  Widget build(BuildContext context) {
    final r = height / 2;
    return GestureDetector(
      onTap: onPressed,
      child: Opacity(
        opacity: onPressed == null ? .5 : 1,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(r),
            boxShadow: [BoxShadow(color: (primary ? Wool.raspberryDark : const Color(0xFF8A6A55)).withOpacity(.35), blurRadius: 8, offset: const Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(r),
            child: CustomPaint(
              painter: primary ? KnitPainter(Wool.raspberry, stitch: 8, contrast: .75) : KnitPainter(Wool.card, stitch: 8, contrast: .25),
              foregroundPainter: StitchBorderPainter(primary ? Colors.white.withOpacity(.45) : Wool.cardEdge, inset: 5, radius: r - 5),
              child: Center(
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  if (leading != null) ...[leading!, const SizedBox(width: 10)],
                  Text(label,
                      style: TextStyle(
                        color: primary ? Colors.white : Wool.ink,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        shadows: primary ? const [Shadow(color: Colors.black38, blurRadius: 3)] : null,
                      )),
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Круглая кнопка в шапке (настройки, сердечко, «+»).
class RoundKnitButton extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color color;
  final double size;
  const RoundKnitButton({super.key, required this.child, required this.onTap, this.color = Wool.card, this.size = 44});
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.black.withOpacity(.2), blurRadius: 5, offset: const Offset(0, 2))]),
          child: ClipOval(
            child: CustomPaint(
              painter: KnitPainter(color, stitch: 7, contrast: color == Wool.card ? .25 : .7),
              child: Center(child: child),
            ),
          ),
        ),
      );
}

/// Вязаная таблетка: капсула, круглая или овальная.
enum PillShape { capsule, round, oval }

class PillPainter extends CustomPainter {
  final PillShape shape;
  final Color color;
  PillPainter(this.shape, this.color);

  void _knitIn(Canvas canvas, Path clip, Rect bounds, Color c) {
    canvas.save();
    canvas.clipPath(clip);
    canvas.translate(bounds.left, bounds.top);
    KnitPainter(c, stitch: bounds.shortestSide * .32, contrast: .7).paint(canvas, bounds.size);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final shadow = Paint()
      ..color = Colors.black.withOpacity(.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    switch (shape) {
      case PillShape.capsule:
        {
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(-math.pi / 4);
        final w = s * .95, h = s * .42;
        final full = Rect.fromCenter(center: Offset.zero, width: w, height: h);
        final rr = RRect.fromRectAndRadius(full, Radius.circular(h / 2));
        canvas.drawRRect(rr.shift(const Offset(1, 3)), shadow);
        final left = Path()..addRRect(rr);
        final leftHalf = Path.combine(PathOperation.intersect, left, Path()..addRect(Rect.fromLTRB(-w / 2, -h, 0, h)));
        final rightHalf = Path.combine(PathOperation.intersect, left, Path()..addRect(Rect.fromLTRB(0, -h, w / 2, h)));
        _knitIn(canvas, leftHalf, full, color);
        _knitIn(canvas, rightHalf, full, const Color(0xFFF1E8DD));
        canvas.drawLine(Offset(0, -h / 2), Offset(0, h / 2), Paint()
          ..color = Colors.black.withOpacity(.15)
          ..strokeWidth = 1.5);
        canvas.restore();
        }
      case PillShape.round:
        {
        final r = s * .4;
        canvas.drawCircle(c + const Offset(1, 3), r, shadow);
        final rect = Rect.fromCircle(center: c, radius: r);
        _knitIn(canvas, Path()..addOval(rect), rect, color);
        final groove = Paint()
          ..color = Wool.dark(color, .25)
          ..strokeWidth = s * .05
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(c + Offset(-r * .6, -r * .6), c + Offset(r * .6, r * .6), groove);
        canvas.drawLine(c + Offset(r * .6, -r * .6), c + Offset(-r * .6, r * .6), groove);
        }
      case PillShape.oval:
        {
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(-math.pi / 5);
        final rect = Rect.fromCenter(center: Offset.zero, width: s * .9, height: s * .5);
        canvas.drawOval(rect.shift(const Offset(1, 3)), shadow);
        _knitIn(canvas, Path()..addOval(rect), rect, color);
        canvas.drawLine(Offset(-s * .25, 0), Offset(s * .25, 0), Paint()
          ..color = Wool.dark(color, .25)
          ..strokeWidth = s * .05
          ..strokeCap = StrokeCap.round);
        canvas.restore();
        }
    }
  }

  @override
  bool shouldRepaint(PillPainter old) => old.shape != shape || old.color != color;
}

class PillIcon extends StatelessWidget {
  final PillShape shape;
  final Color color;
  final double size;
  final bool framed;
  const PillIcon({super.key, required this.shape, required this.color, this.size = 56, this.framed = true});
  @override
  Widget build(BuildContext context) {
    final pill = SizedBox(width: size * .78, height: size * .78, child: CustomPaint(painter: PillPainter(shape, color)));
    if (!framed) return pill;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.55),
        borderRadius: BorderRadius.circular(size * .28),
        border: Border.all(color: Wool.cardEdge, width: 1.5),
      ),
      child: Center(child: pill),
    );
  }
}

/// Смайлики самочувствия: 0 — отлично … 4 — очень плохо.
const moodLabels = ['Отлично', 'Хорошо', 'Так себе', 'Плохо', 'Очень плохо'];

class MoodPainter extends CustomPainter {
  final int mood;
  final bool selected;
  MoodPainter(this.mood, this.selected);

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = size.center(Offset.zero);
    final colors = [Wool.green, const Color(0xFF8FA84A), Wool.mustard, const Color(0xFFD9772E), Wool.brick];
    final base = selected ? colors[mood] : const Color(0xFFEFE2D4);
    canvas.drawCircle(c + const Offset(0, 2), r * .95, Paint()..color = Colors.black.withOpacity(.12));
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: c, radius: r * .95)));
    canvas.translate(c.dx - r, c.dy - r);
    KnitPainter(base, stitch: r * .38, contrast: selected ? .6 : .3).paint(canvas, Size(r * 2, r * 2));
    canvas.restore();
    final ink = Paint()
      ..color = selected ? Colors.white : Wool.ink.withOpacity(.75)
      ..strokeWidth = r * .1
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final eyeY = c.dy - r * .2;
    canvas.drawCircle(Offset(c.dx - r * .32, eyeY), r * .07, ink..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(c.dx + r * .32, eyeY), r * .07, ink);
    ink.style = PaintingStyle.stroke;
    // рот: от улыбки до грусти
    final curve = [.32, .18, 0.0, -.16, -.3][mood];
    final mouthY = c.dy + r * .3;
    final p = Path()
      ..moveTo(c.dx - r * .38, mouthY - curve * r * .5)
      ..quadraticBezierTo(c.dx, mouthY + curve * r, c.dx + r * .38, mouthY - curve * r * .5);
    canvas.drawPath(p, ink);
  }

  @override
  bool shouldRepaint(MoodPainter old) => old.mood != mood || old.selected != selected;
}

class MoodPicker extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  const MoodPicker({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        for (var i = 0; i < 5; i++)
          GestureDetector(
            onTap: () => onChanged(value == i ? null : i),
            child: Column(children: [
              AnimatedScale(
                scale: value == i ? 1.12 : 1,
                duration: const Duration(milliseconds: 200),
                child: SizedBox(width: 50, height: 50, child: CustomPaint(painter: MoodPainter(i, value == i))),
              ),
              const SizedBox(height: 4),
              Text(moodLabels[i], style: TextStyle(fontSize: 11, color: value == i ? Wool.ink : Wool.muted, fontWeight: value == i ? FontWeight.w700 : FontWeight.w400)),
            ]),
          ),
      ]);
}

/// Вкладки-«пуговки»: Давление / Пульс / Лекарства.
class KnitTabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;
  const KnitTabs({super.key, required this.labels, required this.index, required this.onChanged});
  @override
  Widget build(BuildContext context) => Row(children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: SoftCard(
                radius: 22,
                color: i == index ? Wool.rose : Wool.card,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                onTap: () => onChanged(i),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(labels[i],
                      maxLines: 1,
                      softWrap: false,
                      style: TextStyle(fontSize: 15, fontWeight: i == index ? FontWeight.w800 : FontWeight.w500, color: i == index ? Wool.raspberryDark : Wool.ink)),
                ),
              ),
            ),
          ),
      ]);
}

/// Поле ввода без рамки — внутри карточек.
InputDecoration plainInput(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Wool.muted.withOpacity(.55)),
      border: InputBorder.none,
      isDense: true,
      contentPadding: EdgeInsets.zero,
    );

/// Поле ввода в карточке-«фетре».
InputDecoration feltInput(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white.withOpacity(.6),
      labelStyle: const TextStyle(color: Wool.muted),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Wool.cardEdge)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Wool.cardEdge, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Wool.raspberry, width: 2)),
    );

Future<bool?> confirmDialog(BuildContext context, String title, String text, {String yes = 'Удалить'}) => showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        backgroundColor: Wool.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800, color: Wool.ink)),
        content: Text(text, style: const TextStyle(color: Wool.ink)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена', style: TextStyle(color: Wool.muted))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: Text(yes, style: const TextStyle(color: Wool.raspberry, fontWeight: FontWeight.w800))),
        ],
      ),
    );

void toast(BuildContext context, String text) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating, backgroundColor: Wool.ink));

/// Контур сердечка в квадрате size×size.
Path heartPath(Size s) {
  final w = s.width, h = s.height;
  return Path()
    ..moveTo(w * .5, h * .92)
    ..cubicTo(w * .18, h * .70, w * .02, h * .50, w * .04, h * .30)
    ..cubicTo(w * .06, h * .10, w * .30, h * .02, w * .5, h * .22)
    ..cubicTo(w * .70, h * .02, w * .94, h * .10, w * .96, h * .30)
    ..cubicTo(w * .98, h * .50, w * .82, h * .70, w * .5, h * .92)
    ..close();
}

/// Вязаное сердечко: лицевая гладь + пунктирный шов по краю.
class KnitHeartPainter extends CustomPainter {
  final Color color;
  KnitHeartPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final path = heartPath(size);
    canvas.drawPath(path.shift(Offset(0, size.height * .05)), Paint()
      ..color = Colors.black.withOpacity(.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    canvas.save();
    canvas.clipPath(path);
    KnitPainter(color, stitch: math.max(4, size.width * .17), contrast: .75).paint(canvas, size);
    // объём: светлее сверху-слева, темнее снизу
    canvas.drawPath(path, Paint()
      ..shader = RadialGradient(
        center: const Alignment(-.35, -.45),
        radius: .9,
        colors: [Colors.white.withOpacity(.18), Colors.transparent, Colors.black.withOpacity(.22)],
        stops: const [0, .55, 1],
      ).createShader(Offset.zero & size));
    canvas.restore();
    if (size.width >= 22) {
      final inner = heartPath(size.deflateBy(size.width * .24))
          .shift(Offset(size.width * .12, size.height * .13));
      final stitch = Paint()
        ..color = Colors.white.withOpacity(.55)
        ..strokeWidth = math.max(1, size.width * .035)
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;
      for (final m in inner.computeMetrics()) {
        final dash = size.width * .07, gap = size.width * .06;
        for (double d = 0; d < m.length; d += dash + gap) {
          canvas.drawPath(m.extractPath(d, math.min(d + dash, m.length)), stitch);
        }
      }
    }
  }

  @override
  bool shouldRepaint(KnitHeartPainter old) => old.color != color;
}

extension on Size {
  Size deflateBy(double d) => Size(width - d, height - d);
}

class KnitHeart extends StatelessWidget {
  final double size;
  final Color color;
  const KnitHeart({super.key, this.size = 28, this.color = Wool.raspberry});
  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size, child: CustomPaint(painter: KnitHeartPainter(color)));
}

/// Крупный вязаный переключатель с подписью «Вкл / Выкл».
class KnitSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const KnitSwitch({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Semantics(
        toggled: value,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                width: 62,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(.18), blurRadius: 4, offset: const Offset(0, 2))],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17),
                  child: CustomPaint(
                    painter: KnitPainter(value ? Wool.green : const Color(0xFFCDB8A6), stitch: 7, contrast: .55),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOut,
                      alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        width: 26,
                        height: 26,
                        margin: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: Colors.black.withOpacity(.25), blurRadius: 3, offset: const Offset(0, 1))],
                        ),
                        child: Icon(value ? Icons.check : Icons.close, size: 16, color: value ? Wool.green : Wool.muted),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
              Text(value ? 'Вкл' : 'Выкл', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: value ? Wool.green : Wool.muted)),
            ]),
          ),
        ),
      );
}
