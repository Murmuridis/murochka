import 'package:flutter/material.dart';

import '../knit.dart';
import '../today.dart';
import 'meds_screen.dart';
import 'record_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'today_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  Slot? _next;
  int _left = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _load();
  }

  Future<void> _load() async {
    final slots = await todaySlots();
    if (!mounted) return;
    setState(() {
      _next = nextSlot(slots);
      _left = slots.where((s) => !s.taken).length;
    });
  }

  Future<void> _go(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final pad = MediaQuery.of(context).padding;
    final next = _next;
    // Картинка котика: натуральная пропорция 288×448. Надпись и подзаголовок
    // стоят под кнопками, а картинка сдвигается вниз, если места не хватает.
    final imgH = size.width * 448 / 288;
    final logoTop = pad.top + 66;
    final logoH = size.width * .80 / 4.3;
    final textBottom = logoTop + logoH + 74;
    final catTopInImage = imgH * .41;
    final imgTop = (textBottom - catTopInImage).clamp(0.0, 200.0);
    return Scaffold(
      backgroundColor: Wool.cream,
      body: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: KnitPainter(Wool.cream, stitch: 15, contrast: .28))),
        // Котик в клубках
        Positioned(
          top: imgTop,
          left: 0,
          right: 0,
          height: imgH,
          child: ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0, .80, .97],
            ).createShader(r),
            blendMode: BlendMode.dstIn,
            child: Image.asset('assets/images/hero.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter, filterQuality: FilterQuality.high),
          ),
        ),
        if (imgTop > 0)
          // мягкий переход от вязаного фона к комнате
          Positioned(
            top: imgTop - 1,
            left: 0,
            right: 0,
            height: 40,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Wool.cream, Color(0x00F2E4D8)]),
              ),
            ),
          ),
        // Затемнение за надписью, чтобы текст читался
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: textBottom + 30,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x26000000), Color(0x14000000), Color(0x00000000)],
              ),
            ),
          ),
        ),
        Positioned(
          top: logoTop,
          left: size.width * .10,
          right: size.width * .10,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Image.asset('assets/images/logo.png', height: logoH, fit: BoxFit.contain, filterQuality: FilterQuality.high),
            const SizedBox(height: 10),
            const Text(
              'Забота о твоём\nздоровье каждый день',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                height: 1.25,
                fontWeight: FontWeight.w600,
                shadows: [Shadow(color: Color(0xAA3B2A23), blurRadius: 8), Shadow(color: Color(0x663B2A23), blurRadius: 2, offset: Offset(0, 1))],
              ),
            ),
          ]),
        ),
        Positioned(
          top: pad.top + 10,
          left: 16,
          right: 16,
          child: Row(children: [
            RoundKnitButton(size: 48, onTap: () => _go(const SettingsScreen()), child: const Icon(Icons.settings_outlined, color: Wool.ink)),
            const Spacer(),
            RoundKnitButton(
              size: 48,
              onTap: () => _go(const TodayScreen()),
              child: Stack(clipBehavior: Clip.none, children: [
                Image.asset('assets/images/heart.png', width: 30, height: 30, filterQuality: FilterQuality.high),
                if (_left > 0)
                  Positioned(
                    right: -9,
                    top: -9,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(color: Wool.raspberry, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 1.5)),
                      child: Text('$_left', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
                    ),
                  ),
              ]),
            ),
          ]),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: pad.bottom + 18,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (next != null) ...[
              SoftCard(
                onTap: () => _go(const TodayScreen()),
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(children: [
                  PillIcon(shape: next.med.shape, color: pillColors[next.med.color % pillColors.length], size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(next.time.compareTo(nowHm()) < 0 ? 'Пропущено в ${next.time}' : 'Следующий приём в ${next.time}',
                          style: TextStyle(fontSize: 13, color: next.time.compareTo(nowHm()) < 0 ? Wool.raspberry : Wool.muted, fontWeight: FontWeight.w600)),
                      Text('${next.med.name}${next.med.dose.isNotEmpty ? ', ${next.med.dose}' : ''}',
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  const Icon(Icons.chevron_right, color: Wool.muted),
                ]),
              ),
              const SizedBox(height: 12),
            ],
            SoftCard(
              radius: 34,
              onTap: () => _go(const RecordScreen()),
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Image(image: AssetImage('assets/images/heart.png'), width: 34, height: 34),
                SizedBox(width: 12),
                Text('Записать давление', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: _Tile(image: 'assets/images/ic_pill.png', label: 'Мои\nлекарства', onTap: () => _go(const MedsScreen()))),
              const SizedBox(width: 12),
              Expanded(child: _Tile(image: 'assets/images/ic_chart.png', label: 'Статистика', onTap: () => _go(const StatsScreen()))),
            ]),
          ]),
        ),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  final String image;
  final String label;
  final VoidCallback onTap;
  const _Tile({required this.image, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) => SoftCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(10, 12, 10, 14),
        child: SizedBox(
          height: 104,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.asset(image, width: 60, height: 60, filterQuality: FilterQuality.high)),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.15)),
          ]),
        ),
      );
}
