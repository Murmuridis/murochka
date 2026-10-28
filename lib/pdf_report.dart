import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart' show DateFormat;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import 'bp.dart';
import 'db.dart';
import 'knit.dart' show moodLabels;

/// Данные пациента хранятся только на телефоне (таблица meta).
class Patient {
  final String name;
  final DateTime? dob;
  const Patient(this.name, this.dob);

  bool get isEmpty => name.trim().isEmpty;

  static Future<Patient> load() async {
    final name = await AppDb.instance.getMeta('patient_name') ?? '';
    final dob = DateTime.tryParse(await AppDb.instance.getMeta('patient_dob') ?? '');
    return Patient(name, dob);
  }

  static Future<void> save(String name, DateTime? dob) async {
    await AppDb.instance.setMeta('patient_name', name.trim());
    await AppDb.instance.setMeta('patient_dob', dob == null ? '' : dayKey(dob));
  }

  int? ageAt(DateTime d) {
    final b = dob;
    if (b == null) return null;
    var a = d.year - b.year;
    if (d.month < b.month || (d.month == b.month && d.day < b.day)) a--;
    return a;
  }
}

String _years(int n) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return '$n год';
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return '$n года';
  return '$n лет';
}

class PdfReport {
  static const _raspberry = PdfColor.fromInt(0xFFC93C5E);
  static const _ink = PdfColor.fromInt(0xFF3B2A23);
  static const _muted = PdfColor.fromInt(0xFF7D685C);
  static const _cream = PdfColor.fromInt(0xFFF9F0E7);
  static const _edge = PdfColor.fromInt(0xFFE6D2C1);

  /// [days] == null — за всё время.
  static Future<Uint8List> build({int? days}) async {
    final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans.ttf'));
    final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/DejaVuSans-Bold.ttf'));
    final patient = await Patient.load();
    final now = DateTime.now();
    final all = await AppDb.instance.readings(); // от новых к старым
    final from = days == null ? null : DateTime(now.year, now.month, now.day).subtract(Duration(days: days - 1));
    final items = from == null ? all : all.where((r) => !r.time.isBefore(from)).toList();
    final meds = (await AppDb.instance.meds()).where((m) => m.active).toList();

    final dF = DateFormat('dd.MM.yyyy');
    final tF = DateFormat('HH:mm');
    final periodFrom = items.isEmpty ? from : (from ?? items.last.time);
    final periodText = periodFrom == null ? '—' : '${dF.format(periodFrom)} — ${dF.format(now)}';

    final doc = pw.Document(
      title: 'Дневник артериального давления',
      author: patient.isEmpty ? 'Мурочка' : patient.name,
      creator: 'Мурочка',
      theme: pw.ThemeData.withFont(base: regular, bold: bold),
    );

    pw.Widget label(String t) => pw.Text(t, style: const pw.TextStyle(fontSize: 9, color: _muted));
    pw.Widget section(String t) => pw.Padding(
          padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
          child: pw.Text(t, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: _raspberry)),
        );

    // --- сводка
    int avg(Iterable<int> l) => l.isEmpty ? 0 : (l.reduce((a, b) => a + b) / l.length).round();
    final sys = items.map((e) => e.sys).toList();
    final dia = items.map((e) => e.dia).toList();
    final pulse = items.where((e) => e.pulse != null).map((e) => e.pulse!).toList();
    final high = items.where((e) => e.sys >= 140 || e.dia >= 90).length;
    final low = items.where((e) => e.sys < 90 || e.dia < 60).length;
    final morning = items.where((e) => e.time.hour >= 4 && e.time.hour < 12).toList();
    final evening = items.where((e) => e.time.hour >= 17 || e.time.hour < 4).toList();

    pw.Widget stat(String value, String name) => pw.Expanded(
          child: pw.Container(
            margin: const pw.EdgeInsets.symmetric(horizontal: 3),
            padding: const pw.EdgeInsets.symmetric(vertical: 8),
            decoration: pw.BoxDecoration(color: _cream, border: pw.Border.all(color: _edge), borderRadius: pw.BorderRadius.circular(6)),
            child: pw.Column(children: [
              pw.Text(value, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold, color: _ink)),
              pw.SizedBox(height: 2),
              label(name),
            ]),
          ),
        );

    final headerStyle = pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white);
    const cellStyle = pw.TextStyle(fontSize: 9, color: _ink);

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 32, 36, 32),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        label('Сформировано ${DateFormat('dd.MM.yyyy HH:mm').format(now)} в приложении «Мурочка»'),
        label('Стр. ${ctx.pageNumber} из ${ctx.pagesCount}'),
      ]),
      build: (ctx) => [
        pw.Text('Дневник артериального давления', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: _ink)),
        pw.SizedBox(height: 10),
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(color: _cream, border: pw.Border.all(color: _edge), borderRadius: pw.BorderRadius.circular(6)),
          child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Row(children: [
              pw.SizedBox(width: 110, child: label('Пациент')),
              pw.Expanded(child: pw.Text(patient.isEmpty ? '—' : patient.name, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold))),
            ]),
            pw.SizedBox(height: 4),
            pw.Row(children: [
              pw.SizedBox(width: 110, child: label('Дата рождения')),
              pw.Text(
                patient.dob == null ? '—' : '${dF.format(patient.dob!)}  (${_years(patient.ageAt(now)!)})',
                style: const pw.TextStyle(fontSize: 11),
              ),
            ]),
            pw.SizedBox(height: 4),
            pw.Row(children: [
              pw.SizedBox(width: 110, child: label('Период')),
              pw.Text('$periodText,  измерений: ${items.length}', style: const pw.TextStyle(fontSize: 11)),
            ]),
          ]),
        ),

        section('Принимаемые лекарства'),
        if (meds.isEmpty)
          pw.Text('Не указаны', style: const pw.TextStyle(fontSize: 10, color: _muted))
        else
          pw.TableHelper.fromTextArray(
            headers: ['Препарат', 'Дозировка', 'Время приёма', 'Раз в день'],
            data: [for (final m in meds) [m.name, m.dose.isEmpty ? '—' : m.dose, m.times.join(', '), '${m.times.length}']],
            headerStyle: headerStyle,
            headerDecoration: const pw.BoxDecoration(color: _raspberry),
            cellStyle: cellStyle,
            cellAlignments: {3: pw.Alignment.center},
            columnWidths: {0: const pw.FlexColumnWidth(3), 1: const pw.FlexColumnWidth(2.2), 2: const pw.FlexColumnWidth(2.6), 3: const pw.FlexColumnWidth(1.1)},
            border: pw.TableBorder.all(color: _edge, width: .6),
            oddRowDecoration: const pw.BoxDecoration(color: _cream),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
          ),

        section('Сводка за период'),
        if (items.isEmpty)
          pw.Text('За выбранный период измерений нет', style: const pw.TextStyle(fontSize: 10, color: _muted))
        else ...[
          pw.Row(children: [
            stat('${avg(sys)}/${avg(dia)}', 'среднее, мм рт. ст.'),
            stat('${sys.reduce((a, b) => a > b ? a : b)}/${dia.reduce((a, b) => a > b ? a : b)}', 'максимум'),
            stat('${sys.reduce((a, b) => a < b ? a : b)}/${dia.reduce((a, b) => a < b ? a : b)}', 'минимум'),
            stat(pulse.isEmpty ? '—' : '${avg(pulse)}', 'пульс, уд/мин'),
          ]),
          pw.SizedBox(height: 6),
          pw.Row(children: [
            stat(morning.isEmpty ? '—' : '${avg(morning.map((e) => e.sys))}/${avg(morning.map((e) => e.dia))}', 'утро (до 12:00)'),
            stat(evening.isEmpty ? '—' : '${avg(evening.map((e) => e.sys))}/${avg(evening.map((e) => e.dia))}', 'вечер (после 17:00)'),
            stat('$high', 'от 140/90 и выше'),
            stat('$low', 'ниже 90/60'),
          ]),
          pw.SizedBox(height: 4),
          label('Средняя оценка: ${classify(avg(sys), avg(dia)).label.toLowerCase()} (ориентировочно, по ESC/ESH).'),

          section('Измерения'),
          pw.TableHelper.fromTextArray(
            headers: ['Дата', 'Время', 'Давление', 'Пульс', 'Оценка', 'Самочувствие', 'Заметка'],
            data: [
              for (final r in items.reversed)
                [
                  dF.format(r.time),
                  tF.format(r.time),
                  '${r.sys}/${r.dia}',
                  r.pulse?.toString() ?? '—',
                  classify(r.sys, r.dia).label,
                  r.mood == null ? '' : moodLabels[r.mood!],
                  r.note,
                ],
            ],
            headerStyle: headerStyle,
            headerDecoration: const pw.BoxDecoration(color: _raspberry),
            cellStyle: cellStyle,
            cellAlignments: {1: pw.Alignment.center, 2: pw.Alignment.center, 3: pw.Alignment.center},
            columnWidths: {
              0: const pw.FlexColumnWidth(1.7),
              1: const pw.FlexColumnWidth(1.1),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FlexColumnWidth(1.0),
              4: const pw.FlexColumnWidth(2.2),
              5: const pw.FlexColumnWidth(1.8),
              6: const pw.FlexColumnWidth(3.2),
            },
            border: pw.TableBorder.all(color: _edge, width: .6),
            oddRowDecoration: const pw.BoxDecoration(color: _cream),
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          ),
        ],
      ],
    ));
    return doc.save();
  }

  static String fileName() {
    final n = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'davlenie_${n.year}-${two(n.month)}-${two(n.day)}.pdf';
  }

  static Future<void> share({int? days}) async {
    final bytes = await build(days: days);
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, fileName()));
    await file.writeAsBytes(bytes);
    await SharePlus.instance.share(ShareParams(
      files: [XFile(file.path, mimeType: 'application/pdf')],
      subject: 'Дневник давления',
    ));
  }

  static Future<bool> saveToFile({int? days}) async {
    final bytes = await build(days: days);
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Куда сохранить PDF',
      fileName: fileName(),
      type: FileType.custom,
      allowedExtensions: ['pdf'],
      bytes: bytes,
    );
    return path != null;
  }
}
