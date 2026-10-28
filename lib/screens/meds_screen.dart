import 'package:flutter/material.dart';

import '../db.dart';
import '../knit.dart';
import '../notifications.dart';

class MedsScreen extends StatefulWidget {
  const MedsScreen({super.key});
  @override
  State<MedsScreen> createState() => _MedsScreenState();
}

class _MedsScreenState extends State<MedsScreen> {
  List<Med>? _meds;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final m = await AppDb.instance.meds();
    if (mounted) setState(() => _meds = m);
  }

  Future<void> _edit(Med? m) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => MedEditScreen(initial: m)));
    _load();
  }

  Future<void> _toggle(Med m, bool v) async {
    final upd = m.copyWith(active: v);
    await AppDb.instance.saveMed(upd);
    await Notifier.instance.scheduleMed(upd);
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final meds = _meds;
    return KnitScaffold(
      title: 'Лекарства',
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: RoundKnitButton(size: 40, color: Wool.raspberry, onTap: () => _edit(null), child: const Icon(Icons.add, color: Colors.white, size: 26)),
        ),
      ],
      body: meds == null
          ? const SizedBox()
          : ListView(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 16 + MediaQuery.of(context).padding.bottom),
              children: [
                if (meds.isEmpty)
                  SoftCard(
                    margin: const EdgeInsets.only(top: 20),
                    onTap: () => _edit(null),
                    child: const Column(children: [
                      Text('Пока пусто', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                      SizedBox(height: 6),
                      Text('Нажми «+», чтобы добавить лекарство и время приёма — я буду напоминать.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Wool.muted)),
                    ]),
                  ),
                for (final m in meds)
                  SoftCard(
                    margin: const EdgeInsets.only(bottom: 12),
                    onTap: () => _edit(m),
                    padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                    child: Opacity(
                      opacity: m.active ? 1 : .55,
                      child: Row(children: [
                        PillIcon(shape: m.shape, color: pillColors[m.color % pillColors.length], size: 62),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(m.name, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                            if (m.dose.isNotEmpty) Text(m.dose, style: const TextStyle(fontSize: 15, color: Wool.muted)),
                            const SizedBox(height: 4),
                            Row(children: [
                              const Icon(Icons.alarm, size: 18, color: Wool.raspberry),
                              const SizedBox(width: 6),
                              Flexible(child: Text(m.times.join(', '), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                            ]),
                          ]),
                        ),
                        Switch(value: m.active, onChanged: (v) => _toggle(m, v)),
                      ]),
                    ),
                  ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.asset('assets/images/basket.jpg', fit: BoxFit.cover, height: 170),
                ),
              ],
            ),
    );
  }
}

class MedEditScreen extends StatefulWidget {
  final Med? initial;
  const MedEditScreen({super.key, this.initial});
  @override
  State<MedEditScreen> createState() => _MedEditScreenState();
}

class _MedEditScreenState extends State<MedEditScreen> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late final _dose = TextEditingController(text: widget.initial?.dose ?? '');
  late final List<String> _times = [...?widget.initial?.times];
  late PillShape _shape = widget.initial?.shape ?? PillShape.capsule;
  late int _color = widget.initial?.color ?? 0;
  String? _error;

  Future<void> _addTime() async {
    final t = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0), helpText: 'Время приёма');
    if (t == null) return;
    final s = hm(t.hour, t.minute);
    if (!_times.contains(s)) setState(() => _times..add(s)..sort());
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Как называется лекарство?');
      return;
    }
    if (_times.isEmpty) {
      setState(() => _error = 'Добавь хотя бы одно время приёма');
      return;
    }
    final m = Med(
      id: widget.initial?.id,
      name: _name.text.trim(),
      dose: _dose.text.trim(),
      times: List.of(_times),
      active: widget.initial?.active ?? true,
      shape: _shape,
      color: _color,
    );
    final id = await AppDb.instance.saveMed(m);
    await Notifier.instance.requestPermissions();
    await Notifier.instance.scheduleMed(m.copyWith(id: id));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final m = widget.initial!;
    final ok = await confirmDialog(context, 'Удалить лекарство?', '${m.name} и все его напоминания');
    if (ok != true) return;
    await Notifier.instance.cancelMed(m.id!);
    await AppDb.instance.deleteMed(m.id!);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => KnitScaffold(
        title: widget.initial == null ? 'Новое лекарство' : 'Лекарство',
        actions: [if (widget.initial != null) IconButton(icon: const Icon(Icons.delete_outline, color: Wool.muted), onPressed: _delete)],
        body: ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.of(context).padding.bottom),
          children: [
            Center(child: PillIcon(shape: _shape, color: pillColors[_color], size: 96)),
            const SizedBox(height: 16),
            TextField(controller: _name, autofocus: widget.initial == null, textCapitalization: TextCapitalization.sentences, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700), decoration: feltInput('Название', hint: 'Бисопролол')),
            const SizedBox(height: 12),
            TextField(controller: _dose, style: const TextStyle(fontSize: 16), decoration: feltInput('Дозировка', hint: '1,25 мг')),
            const SizedBox(height: 18),
            const Text('Как выглядит', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            SoftCard(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  for (final s in PillShape.values)
                    GestureDetector(
                      onTap: () => setState(() => _shape = s),
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), border: Border.all(color: _shape == s ? Wool.raspberry : Colors.transparent, width: 2.5)),
                        child: PillIcon(shape: s, color: pillColors[_color], size: 58),
                      ),
                    ),
                ]),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  for (var i = 0; i < pillColors.length; i++)
                    GestureDetector(
                      onTap: () => setState(() => _color = i),
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: pillColors[i],
                          shape: BoxShape.circle,
                          border: Border.all(color: _color == i ? Wool.ink : Wool.cardEdge, width: _color == i ? 3 : 1.5),
                        ),
                        child: _color == i ? Icon(Icons.check, size: 20, color: i == pillColors.length - 1 ? Wool.ink : Colors.white) : null,
                      ),
                    ),
                ]),
              ]),
            ),
            const SizedBox(height: 18),
            const Text('Когда напоминать', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 10, runSpacing: 10, children: [
              for (final t in _times)
                InputChip(
                  avatar: const Icon(Icons.alarm, color: Colors.white, size: 18),
                  label: Text(t, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Colors.white)),
                  backgroundColor: Wool.raspberry,
                  deleteIconColor: Colors.white,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  onDeleted: () => setState(() => _times.remove(t)),
                ),
              ActionChip(
                avatar: const Icon(Icons.add_alarm, color: Wool.raspberry),
                label: const Text('Добавить время', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                backgroundColor: Wool.card,
                side: const BorderSide(color: Wool.cardEdge, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                onPressed: _addTime,
              ),
            ]),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, style: const TextStyle(color: Wool.raspberry, fontWeight: FontWeight.w700, fontSize: 15))),
            const SizedBox(height: 24),
            KnitButton(label: 'Сохранить', onPressed: _save),
          ],
        ),
      );
}
