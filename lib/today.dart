import 'db.dart';

class Slot {
  final String time;
  final Med med;
  final bool taken;
  Slot(this.time, this.med, this.taken);
  String get key => '${med.id}|$time';
}

/// Все приёмы на сегодня, по времени.
Future<List<Slot>> todaySlots() async {
  final meds = await AppDb.instance.meds();
  final taken = await AppDb.instance.takenOn(DateTime.now());
  final list = <Slot>[
    for (final m in meds.where((m) => m.active))
      for (final t in m.times) Slot(t, m, taken.contains('${m.id}|$t')),
  ]..sort((a, b) => a.time.compareTo(b.time));
  return list;
}

String nowHm() {
  final n = DateTime.now();
  return hm(n.hour, n.minute);
}

/// Ближайший непринятый приём (сначала просроченные).
Slot? nextSlot(List<Slot> slots) {
  final pending = slots.where((s) => !s.taken).toList();
  return pending.isEmpty ? null : pending.first;
}
