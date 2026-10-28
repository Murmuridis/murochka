import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'knit.dart' show PillShape;

class Reading {
  final int? id;
  final int sys;
  final int dia;
  final int? pulse;
  final int? mood; // 0 — отлично … 4 — очень плохо
  final DateTime time;
  final String note;

  Reading({this.id, required this.sys, required this.dia, this.pulse, this.mood, required this.time, this.note = ''});

  Map<String, Object?> toMap() => {
        'id': id,
        'sys': sys,
        'dia': dia,
        'pulse': pulse,
        'mood': mood,
        'time': time.millisecondsSinceEpoch,
        'note': note,
      };

  static Reading fromMap(Map<String, Object?> m) => Reading(
        id: m['id'] as int,
        sys: m['sys'] as int,
        dia: m['dia'] as int,
        pulse: m['pulse'] as int?,
        mood: m['mood'] as int?,
        time: DateTime.fromMillisecondsSinceEpoch(m['time'] as int),
        note: (m['note'] as String?) ?? '',
      );
}

class Med {
  final int? id;
  final String name;
  final String dose;
  final List<String> times; // "HH:mm"
  final bool active;
  final PillShape shape;
  final int color;

  Med({this.id, required this.name, this.dose = '', required this.times, this.active = true, this.shape = PillShape.capsule, this.color = 0});

  Med copyWith({int? id, bool? active}) =>
      Med(id: id ?? this.id, name: name, dose: dose, times: times, active: active ?? this.active, shape: shape, color: color);

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'dose': dose,
        'times': times.join(','),
        'active': active ? 1 : 0,
        'shape': shape.name,
        'color': color,
      };

  static Med fromMap(Map<String, Object?> m) {
    final t = (m['times'] as String?) ?? '';
    final list = t.split(',').where((s) => s.trim().isNotEmpty).toList()..sort();
    final shapeName = (m['shape'] as String?) ?? 'capsule';
    return Med(
      id: m['id'] as int,
      name: m['name'] as String,
      dose: (m['dose'] as String?) ?? '',
      times: list,
      active: (m['active'] as int? ?? 1) == 1,
      shape: PillShape.values.firstWhere((s) => s.name == shapeName, orElse: () => PillShape.capsule),
      color: (m['color'] as int?) ?? 0,
    );
  }
}

String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

String hm(int h, int m) => '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

class AppDb {
  AppDb._();
  static final AppDb instance = AppDb._();
  Database? _db;

  Future<Database> get db async {
    if (_db != null) return _db!;
    final dir = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dir, 'murochka.db'),
      version: 3,
      onCreate: (db, v) async {
        await db.execute('''CREATE TABLE readings(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          sys INTEGER NOT NULL, dia INTEGER NOT NULL, pulse INTEGER, mood INTEGER,
          time INTEGER NOT NULL, note TEXT)''');
        await db.execute('''CREATE TABLE meds(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL, dose TEXT, times TEXT, active INTEGER DEFAULT 1,
          shape TEXT DEFAULT 'capsule', color INTEGER DEFAULT 0)''');
        await db.execute('''CREATE TABLE intakes(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          med_id INTEGER NOT NULL, day TEXT NOT NULL, slot TEXT NOT NULL,
          taken_at INTEGER NOT NULL)''');
        await db.execute('CREATE TABLE meta(key TEXT PRIMARY KEY, value TEXT)');
      },
      onUpgrade: (db, from, to) async {
        if (from < 2) {
          await db.execute('ALTER TABLE readings ADD COLUMN mood INTEGER');
          await db.execute("ALTER TABLE meds ADD COLUMN shape TEXT DEFAULT 'capsule'");
          await db.execute('ALTER TABLE meds ADD COLUMN color INTEGER DEFAULT 0');
        }
        if (from < 3) {
          await db.execute('CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT)');
        }
      },
    );
    return _db!;
  }

  // --- давление
  Future<List<Reading>> readings() async {
    final rows = await (await db).query('readings', orderBy: 'time DESC');
    return rows.map(Reading.fromMap).toList();
  }

  Future<List<Reading>> readingsBetween(DateTime from, DateTime to) async {
    final rows = await (await db).query('readings',
        where: 'time >= ? AND time < ?', whereArgs: [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch], orderBy: 'time ASC');
    return rows.map(Reading.fromMap).toList();
  }

  Future<void> saveReading(Reading r) async {
    final d = await db;
    if (r.id == null) {
      await d.insert('readings', r.toMap()..remove('id'));
    } else {
      await d.update('readings', r.toMap(), where: 'id = ?', whereArgs: [r.id]);
    }
  }

  Future<void> deleteReading(int id) async {
    await (await db).delete('readings', where: 'id = ?', whereArgs: [id]);
  }

  // --- лекарства
  Future<List<Med>> meds() async {
    final rows = await (await db).query('meds', orderBy: 'name COLLATE NOCASE');
    return rows.map(Med.fromMap).toList();
  }

  Future<Med?> med(int id) async {
    final rows = await (await db).query('meds', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Med.fromMap(rows.first);
  }

  Future<int> saveMed(Med m) async {
    final d = await db;
    if (m.id == null) return d.insert('meds', m.toMap()..remove('id'));
    await d.update('meds', m.toMap(), where: 'id = ?', whereArgs: [m.id]);
    return m.id!;
  }

  Future<void> deleteMed(int id) async {
    final d = await db;
    await d.delete('meds', where: 'id = ?', whereArgs: [id]);
    await d.delete('intakes', where: 'med_id = ?', whereArgs: [id]);
  }

  // --- приёмы
  Future<Set<String>> takenOn(DateTime day) async {
    final rows = await (await db).query('intakes', where: 'day = ?', whereArgs: [dayKey(day)]);
    return rows.map((r) => '${r['med_id']}|${r['slot']}').toSet();
  }

  /// Сколько приёмов отмечено по дням: { '2026-10-28': 3 }
  Future<Map<String, int>> takenCountBetween(DateTime from, DateTime to) async {
    final rows = await (await db).rawQuery(
        'SELECT day, COUNT(*) AS n FROM intakes WHERE day >= ? AND day <= ? GROUP BY day', [dayKey(from), dayKey(to)]);
    return {for (final r in rows) r['day'] as String: (r['n'] as int)};
  }

  Future<void> setTaken(int medId, String slot, DateTime day, bool taken) async {
    final d = await db;
    await d.delete('intakes', where: 'med_id = ? AND day = ? AND slot = ?', whereArgs: [medId, dayKey(day), slot]);
    if (taken) {
      await d.insert('intakes', {'med_id': medId, 'day': dayKey(day), 'slot': slot, 'taken_at': DateTime.now().millisecondsSinceEpoch});
    }
  }

  // --- служебное
  Future<String?> getMeta(String key) async {
    final rows = await (await db).query('meta', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setMeta(String key, String value) async {
    await (await db).insert('meta', {'key': key, 'value': value}, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // --- резервная копия
  Future<Map<String, List<Map<String, Object?>>>> dumpAll() async {
    final d = await db;
    return {
      'readings': await d.query('readings', orderBy: 'time'),
      'meds': await d.query('meds', orderBy: 'id'),
      'intakes': await d.query('intakes', orderBy: 'id'),
    };
  }

  Future<void> replaceAll(Map<String, dynamic> data) async {
    const columns = {
      'readings': ['id', 'sys', 'dia', 'pulse', 'mood', 'time', 'note'],
      'meds': ['id', 'name', 'dose', 'times', 'active', 'shape', 'color'],
      'intakes': ['id', 'med_id', 'day', 'slot', 'taken_at'],
    };
    final d = await db;
    await d.transaction((txn) async {
      for (final table in columns.keys) {
        await txn.delete(table);
      }
      for (final table in columns.keys) {
        final rows = (data[table] as List?) ?? const [];
        for (final r in rows) {
          if (r is! Map) continue;
          final row = <String, Object?>{
            for (final c in columns[table]!)
              if (r.containsKey(c)) c: r[c],
          };
          await txn.insert(table, row, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      }
    });
  }
}
