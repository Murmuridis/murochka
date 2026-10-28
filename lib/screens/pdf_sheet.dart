import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../knit.dart';
import '../pdf_report.dart';

/// Диалог «Данные пациента». Возвращает true, если сохранили.
Future<bool> editPatient(BuildContext context) async {
  final current = await Patient.load();
  if (!context.mounted) return false;
  final name = TextEditingController(text: current.name);
  DateTime? dob = current.dob;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, setD) => AlertDialog(
        backgroundColor: Wool.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Пациент', style: TextStyle(fontWeight: FontWeight.w800, color: Wool.ink)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            decoration: feltInput('Фамилия, имя, отчество'),
          ),
          const SizedBox(height: 12),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () async {
              final d = await showDatePicker(
                context: c,
                initialDate: dob ?? DateTime(1960),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
                initialEntryMode: DatePickerEntryMode.input,
                helpText: 'Дата рождения',
              );
              if (d != null) setD(() => dob = d);
            },
            child: InputDecorator(
              decoration: feltInput('Дата рождения'),
              child: Text(dob == null ? 'Выбрать' : DateFormat('dd.MM.yyyy').format(dob!), style: const TextStyle(fontSize: 16)),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Хранится только на этом телефоне и в резервной копии.', style: TextStyle(fontSize: 12, color: Wool.muted)),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Отмена', style: TextStyle(color: Wool.muted))),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Сохранить', style: TextStyle(color: Wool.raspberry, fontWeight: FontWeight.w800))),
        ],
      ),
    ),
  );
  if (ok == true) await Patient.save(name.text, dob);
  return ok == true;
}

/// Выбор периода и способа: «Отправить» или «Сохранить» PDF для врача.
Future<void> showPdfSheet(BuildContext context) async {
  var patient = await Patient.load();
  if (!context.mounted) return;
  if (patient.isEmpty) {
    final saved = await editPatient(context);
    if (!saved || !context.mounted) return;
    patient = await Patient.load();
    if (!context.mounted) return;
  }
  int? days = 30;
  bool busy = false;
  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setS) {
        Future<void> run(Future<void> Function() job) async {
          setS(() => busy = true);
          try {
            await job();
            if (c.mounted) Navigator.pop(c);
          } catch (e) {
            if (c.mounted) toast(c, 'Не получилось сделать PDF: $e');
            setS(() => busy = false);
          }
        }

        Widget chip(String label, int? value) => ChoiceChip(
              label: Text(label, style: TextStyle(fontWeight: FontWeight.w700, color: days == value ? Colors.white : Wool.ink)),
              selected: days == value,
              showCheckmark: false,
              selectedColor: Wool.raspberry,
              backgroundColor: Wool.card,
              side: const BorderSide(color: Wool.cardEdge, width: 1.5),
              onSelected: (_) => setS(() => days = value),
            );

        return Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(c).padding.bottom),
          decoration: const BoxDecoration(color: Wool.cream, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: Container(width: 44, height: 5, decoration: BoxDecoration(color: Wool.cardEdge, borderRadius: BorderRadius.circular(3)))),
            const SizedBox(height: 14),
            const Text('PDF для врача', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () async {
                await editPatient(c);
                patient = await Patient.load();
                setS(() {});
              },
              child: Row(children: [
                Expanded(
                  child: Text(
                    '${patient.name}${patient.dob == null ? '' : ', ${DateFormat('dd.MM.yyyy').format(patient.dob!)}'}',
                    style: const TextStyle(fontSize: 15, color: Wool.muted),
                  ),
                ),
                const Icon(Icons.edit_outlined, size: 18, color: Wool.muted),
              ]),
            ),
            const SizedBox(height: 14),
            const Text('За какой период', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [
              chip('7 дней', 7),
              chip('14 дней', 14),
              chip('30 дней', 30),
              chip('3 месяца', 90),
              chip('Всё время', null),
            ]),
            const SizedBox(height: 8),
            const Text('В PDF: данные пациента, лекарства с дозировкой, сводка и все измерения.', style: TextStyle(fontSize: 13, color: Wool.muted)),
            const SizedBox(height: 18),
            if (busy)
              const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Wool.raspberry)))
            else ...[
              KnitButton(
                label: 'Отправить',
                leading: const Icon(Icons.send_outlined, color: Colors.white),
                onPressed: () => run(() => PdfReport.share(days: days)),
              ),
              const SizedBox(height: 12),
              KnitButton(
                label: 'Сохранить в файл',
                primary: false,
                leading: const Icon(Icons.save_alt, color: Wool.ink),
                onPressed: () => run(() async {
                  final ok = await PdfReport.saveToFile(days: days);
                  if (ok && context.mounted) toast(context, 'PDF сохранён');
                }),
              ),
            ],
          ]),
        );
      },
    ),
  );
}
