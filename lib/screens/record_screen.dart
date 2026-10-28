import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../bp.dart';
import '../db.dart';
import '../knit.dart';

/// «Запись давления» — новая или редактирование.
class RecordScreen extends StatefulWidget {
  final Reading? initial;
  const RecordScreen({super.key, this.initial});
  @override
  State<RecordScreen> createState() => _RecordScreenState();
}

class _RecordScreenState extends State<RecordScreen> {
  late final _sys = TextEditingController(text: widget.initial?.sys.toString() ?? '');
  late final _dia = TextEditingController(text: widget.initial?.dia.toString() ?? '');
  late final _pulse = TextEditingController(text: widget.initial?.pulse?.toString() ?? '');
  late final _note = TextEditingController(text: widget.initial?.note ?? '');
  late DateTime _time = widget.initial?.time ?? DateTime.now();
  late int? _mood = widget.initial?.mood;
  final _diaFocus = FocusNode();
  final _pulseFocus = FocusNode();
  String? _error;

  Future<void> _pickTime() async {
    final d = await showDatePicker(context: context, initialDate: _time, firstDate: DateTime(2020), lastDate: DateTime.now());
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_time));
    if (t == null) return;
    setState(() => _time = DateTime(d.year, d.month, d.day, t.hour, t.minute));
  }

  Future<void> _save() async {
    final sys = int.tryParse(_sys.text);
    final dia = int.tryParse(_dia.text);
    final pulse = _pulse.text.isEmpty ? null : int.tryParse(_pulse.text);
    String? err;
    if (sys == null || dia == null) {
      err = 'Впиши верхнее и нижнее давление';
    } else if (sys < 50 || sys > 300 || dia < 30 || dia > 200) {
      err = 'Проверь цифры: верхнее 50–300, нижнее 30–200';
    } else if (dia >= sys) {
      err = 'Нижнее должно быть меньше верхнего';
    } else if (_pulse.text.isNotEmpty && (pulse == null || pulse < 30 || pulse > 250)) {
      err = 'Пульс бывает от 30 до 250';
    }
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final r = Reading(id: widget.initial?.id, sys: sys!, dia: dia!, pulse: pulse, mood: _mood, time: _time, note: _note.text.trim());
    await AppDb.instance.saveReading(r);
    if (!mounted) return;
    final cat = classify(r.sys, r.dia);
    toast(context, 'Записано: ${r.sys}/${r.dia} — ${cat.label.toLowerCase()}');
    Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    final ok = await confirmDialog(context, 'Удалить запись?', '${widget.initial!.sys}/${widget.initial!.dia}');
    if (ok != true) return;
    await AppDb.instance.deleteReading(widget.initial!.id!);
    if (mounted) Navigator.pop(context, true);
  }

  Widget _bigNumber(String label, TextEditingController c, {FocusNode? focus, FocusNode? next, String unit = 'мм рт. ст.', bool autofocus = false}) => SoftCard(
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
        child: Column(children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Wool.muted, fontWeight: FontWeight.w600)),
          TextField(
            controller: c,
            focusNode: focus,
            autofocus: autofocus,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
            style: const TextStyle(fontSize: 46, fontWeight: FontWeight.w800, color: Wool.ink, height: 1.15),
            decoration: plainInput(label == 'Систолическое' ? '120' : '80'),
            onChanged: (v) {
              setState(() => _error = null);
              if (next != null && (v.length == 3 || (v.length == 2 && !v.startsWith('1')))) next.requestFocus();
            },
          ),
          Text(unit, style: const TextStyle(fontSize: 13, color: Wool.muted)),
        ]),
      );

  @override
  Widget build(BuildContext context) => KnitScaffold(
        title: 'Запись давления',
        actions: [
          if (widget.initial != null) IconButton(icon: const Icon(Icons.delete_outline, color: Wool.muted), onPressed: _delete),
        ],
        body: ListView(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 24 + MediaQuery.of(context).padding.bottom),
          children: [
            Row(children: [
              Expanded(child: _bigNumber('Систолическое', _sys, next: _diaFocus, autofocus: widget.initial == null)),
              const SizedBox(width: 12),
              Expanded(child: _bigNumber('Диастолическое', _dia, focus: _diaFocus, next: _pulseFocus)),
            ]),
            const SizedBox(height: 12),
            SoftCard(
              padding: const EdgeInsets.fromLTRB(14, 10, 16, 10),
              child: Row(children: [
                Column(children: [
                  ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.asset('assets/images/ic_pressure.png', width: 50, height: 50)),
                  const Text('Пульс', style: TextStyle(fontSize: 12, color: Wool.muted)),
                ]),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Пульс', style: TextStyle(fontSize: 14, color: Wool.muted, fontWeight: FontWeight.w600)),
                    Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                      SizedBox(
                        width: 90,
                        child: TextField(
                          controller: _pulse,
                          focusNode: _pulseFocus,
                          keyboardType: TextInputType.number,
                          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Wool.ink),
                          decoration: plainInput('70'),
                        ),
                      ),
                      const Text('уд/мин', style: TextStyle(fontSize: 14, color: Wool.muted)),
                    ]),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            SoftCard(
              onTap: _pickTime,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Row(children: [
                const Icon(Icons.calendar_month_outlined, color: Wool.ink, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Дата и время', style: TextStyle(fontSize: 13, color: Wool.muted, fontWeight: FontWeight.w600)),
                    Text(DateFormat('d MMM yyyy, HH:mm', 'ru').format(_time), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                  ]),
                ),
                const Icon(Icons.edit_outlined, color: Wool.muted),
              ]),
            ),
            const SizedBox(height: 18),
            const Padding(padding: EdgeInsets.only(left: 4, bottom: 10), child: Text('Как самочувствие?', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
            SoftCard(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
              child: MoodPicker(value: _mood, onChanged: (v) => setState(() => _mood = v)),
            ),
            const SizedBox(height: 18),
            const Padding(padding: EdgeInsets.only(left: 4, bottom: 8), child: Text('Заметка (по желанию)', style: TextStyle(fontSize: 15, color: Wool.muted, fontWeight: FontWeight.w600))),
            SoftCard(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: TextField(
                controller: _note,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(fontSize: 16, color: Wool.ink),
                decoration: plainInput('Например: после прогулки, утром, головная боль…'),
              ),
            ),
            if (_error != null)
              Padding(padding: const EdgeInsets.only(top: 12), child: Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Wool.raspberry, fontWeight: FontWeight.w700, fontSize: 15))),
            const SizedBox(height: 22),
            KnitButton(label: 'Сохранить', onPressed: _save),
          ],
        ),
      );
}
