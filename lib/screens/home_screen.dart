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
    return Scaffold(
      backgroundColor: Wool.cream,
      body: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: KnitPainter(Wool.cream, stitch: 15, contrast: .28))),
        // Котик в клубках (картинка уже содержит «Мурочка» и подпись)
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: size.height * .72,
          child: ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.white, Colors.white, Colors.transparent],
              stops: [0, .82, 1],
            ).createShader(r),
            blendMode: BlendMode.dstIn,
            child: Image.asset('assets/images/hero.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter),
          ),
        ),
        Positioned(
          top: pad.top + 10,
          left: 16,
          right: 16,
          child: Row(children: [
            RoundKnitButton(onTap: () => _go(const SettingsScreen()), child: const Icon(Icons.settings_outlined, color: Wool.ink)),
            const Spacer(),
            RoundKnitButton(
              onTap: () => _go(const TodayScreen()),
              child: Stack(clipBehavior: Clip.none, children: [
                const Icon(Icons.favorite, color: Wool.raspberry),
                if (_left > 0)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Wool.raspberry, shape: BoxShape.circle),
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
                Icon(Icons.favorite, color: Wool.raspberry, size: 28),
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
            ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.asset(image, width: 56, height: 56)),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.15)),
          ]),
        ),
      );
}
