import 'dart:convert';
import 'dart:io';

import 'clinical_schema.dart';
import 'clinical_nom.dart';

import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';
import 'package:sqflite_sqlcipher/sqflite.dart';

class AppDb {
  AppDb._();
  static final instance = AppDb._();
  static const _storage = FlutterSecureStorage();
  Database? _db;
  Future<Database>? _opening;
  String? _key;

  Future<String> get dbKey async {
    if (_key != null) return _key!;
    var k = await _storage.read(key: 'db_key_v2');
    if (k == null) {
      if (await File(await path).exists()) {
        throw StateError(
          'Existe una base cifrada pero falta su clave. No borres datos. Usa un respaldo portátil válido para recuperación asistida.',
        );
      }
      final r = Random.secure();
      final bytes = List<int>.generate(32, (_) => r.nextInt(256));
      k = base64UrlEncode(bytes);
      await _storage.write(key: 'db_key_v2', value: k);
    }
    _key = k;
    return k;
  }

  Future<void> setDbKey(String key) async {
    _key = key;
    await _storage.write(key: 'db_key_v2', value: key);
  }

  Future<String> get path async =>
      join(await getDatabasesPath(), 'angel_medical_secure_v2.db');

  Future<Database> get database async {
    if (_db != null) return _db!;
    return _opening ??= _open().whenComplete(() => _opening = null);
  }

  Future<Database> _open() async {
    final p = await path;
    final key = await dbKey;
    // Snapshot a closed, checkpointed encrypted database before migration.
    if (await File(p).exists()) {
      final check = await openDatabase(p, password: key, singleInstance: false);
      try {
        final version =
            (await check.rawQuery('PRAGMA user_version')).single['user_version']
                as int;
        if (version < 6) {
          final integrity = await check.rawQuery('PRAGMA integrity_check');
          if (integrity.length != 1 || integrity.first.values.first != 'ok') {
            throw StateError(
              'La base requiere revision. No se aplicaron cambios.',
            );
          }
          final checkpoint = await check.rawQuery(
            'PRAGMA wal_checkpoint(FULL)',
          );
          if (checkpoint.isNotEmpty && checkpoint.first.values.first != 0) {
            throw StateError('No se pudo preparar el respaldo previo.');
          }
          await check.close();
          await File(p)
              .copy('$p.pre_v6_${DateTime.now().microsecondsSinceEpoch}');
        }
      } finally {
        if (check.isOpen) await check.close();
      }
    }
    _db = await openDatabase(
      p,
      password: key,
      version: 6,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys=ON'),
      onCreate: (db, version) async {
        for (final sql in [..._schema, ...clinicalSchema]) {
          await db.execute(sql);
        }
        await _ensureNomColumns(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 4) {
          await _ensureColumn(
            db,
            'patients',
            'is_archived',
            'INTEGER NOT NULL DEFAULT 0',
          );
          await _ensureColumn(
            db,
            'patients',
            'is_deceased',
            'INTEGER NOT NULL DEFAULT 0',
          );
          await _ensureColumn(db, 'patients', 'deceased_at', 'TEXT');
          await _ensureColumn(db, 'patients', 'death_notes', 'TEXT');

          await db.execute(
            'CREATE TABLE IF NOT EXISTS appointments('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'patient_id INTEGER NOT NULL,'
            'start_at TEXT NOT NULL,'
            'reason TEXT,notes TEXT,'
            'status TEXT NOT NULL DEFAULT "programada",'
            'notify_minutes_before INTEGER NOT NULL DEFAULT 30,'
            'created_at TEXT NOT NULL,updated_at TEXT NOT NULL,'
            'FOREIGN KEY(patient_id) REFERENCES patients(id) ON DELETE CASCADE)',
          );

          await db.execute(
            'CREATE TABLE IF NOT EXISTS favorites('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'type TEXT NOT NULL,name TEXT NOT NULL,content TEXT NOT NULL,'
            'created_at TEXT NOT NULL)',
          );

          await db.execute(
            'CREATE TABLE IF NOT EXISTS medications('
            'id INTEGER PRIMARY KEY AUTOINCREMENT,'
            'generic_name TEXT NOT NULL,brand_name TEXT,'
            'form TEXT,strength TEXT,presentation TEXT,'
            'registration TEXT,status TEXT,source TEXT,'
            'favorite INTEGER NOT NULL DEFAULT 0,'
            'use_count INTEGER NOT NULL DEFAULT 0,'
            'last_used_at TEXT,search_text TEXT NOT NULL)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_med_search ON medications(search_text)',
          );
          await db.execute(
            'CREATE INDEX IF NOT EXISTS idx_med_generic ON medications(generic_name)',
          );

          await db.execute(
            'CREATE TABLE IF NOT EXISTS app_settings('
            'setting_key TEXT PRIMARY KEY,setting_value TEXT)',
          );
        }
        if (oldVersion < 5) {
          final counts = <String, int>{};
          const existing = [
            'patients',
            'consultations',
            'emergencies',
            'hospitalizations',
            'progress_notes',
            'medical_orders',
            'documents',
          ];
          for (final table in existing) {
            counts[table] = Sqflite.firstIntValue(
              await db.rawQuery('SELECT COUNT(*) FROM $table'),
            )!;
          }
          for (final sql in clinicalSchema) {
            await db.execute(sql);
          }
          for (final table in existing) {
            if (counts[table] !=
                Sqflite.firstIntValue(
                  await db.rawQuery('SELECT COUNT(*) FROM $table'),
                )) {
              throw StateError('Validacion de migracion fallida');
            }
          }
          final integrity = await db.rawQuery('PRAGMA integrity_check');
          if (integrity.length != 1 || integrity.first.values.first != 'ok')
            throw StateError('Integridad incorrecta');
        }
        if (oldVersion < 6) {
          final counts = <String, int>{};
          for (final table in nomTables) {
            counts[table] =
                (await db.rawQuery('SELECT COUNT(*) AS n FROM $table'))
                        .single['n']
                    as int;
          }
          await _ensureNomColumns(db);
          for (final table in nomTables) {
            final count = (await db.rawQuery(
              'SELECT COUNT(*) AS n FROM $table',
            )).single['n'];
            if (count != counts[table])
              throw StateError('Migración NOM: conteos no coinciden');
          }
          if ((await db.rawQuery('PRAGMA integrity_check'))
                      .single
                      .values
                      .first !=
                  'ok' ||
              (await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) {
            throw StateError('Migración NOM: integridad incorrecta');
          }
        }
      },
    );
    return _db!;
  }

  static Future<void> _ensureNomColumns(Database db) async {
    for (final table in nomTables) {
      await _ensureColumn(db, table, 'nom_json', 'TEXT');
    }
  }

  static Future<void> _ensureColumn(
    Database db,
    String table,
    String column,
    String definition,
  ) async {
    final cols = await db.rawQuery('PRAGMA table_info($table)');
    if (!cols.any((x) => '${x['name']}' == column)) {
      await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
    }
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<void> reopen() async {
    await close();
    await database;
  }

  static final List<String> _schema = [
    'CREATE TABLE patients('
        'id INTEGER PRIMARY KEY AUTOINCREMENT,'
        'first_name TEXT NOT NULL,last_name TEXT NOT NULL,dob TEXT,sex TEXT,phone TEXT,curp TEXT,'
        'blood_type TEXT,occupation TEXT,marital_status TEXT,address TEXT,'
        'emergency_contact TEXT,emergency_phone TEXT,allergies TEXT,'
        'personal_history TEXT,family_history TEXT,surgical_history TEXT,chronic_meds TEXT,notes TEXT,'
        'is_archived INTEGER NOT NULL DEFAULT 0,is_deceased INTEGER NOT NULL DEFAULT 0,'
        'deceased_at TEXT,death_notes TEXT,created_at TEXT NOT NULL,updated_at TEXT NOT NULL)',
    'CREATE INDEX idx_patient_name ON patients(last_name,first_name)',
    'CREATE TABLE consultations('
        'id INTEGER PRIMARY KEY AUTOINCREMENT,patient_id INTEGER NOT NULL,date TEXT NOT NULL,'
        'systolic REAL,diastolic REAL,heart_rate REAL,respiratory_rate REAL,temperature REAL,spo2 REAL,'
        'weight REAL,height REAL,bmi REAL,glucose REAL,reason TEXT,illness TEXT,physical_exam TEXT,'
        'diagnoses TEXT,treatment TEXT,studies TEXT,plan TEXT,created_at TEXT NOT NULL,'
        'FOREIGN KEY(patient_id) REFERENCES patients(id) ON DELETE CASCADE)',
    'CREATE INDEX idx_consult_patient ON consultations(patient_id,date DESC)',
    'CREATE TABLE emergencies('
        'id INTEGER PRIMARY KEY AUTOINCREMENT,patient_id INTEGER NOT NULL,date TEXT NOT NULL,'
        'triage TEXT,pain REAL,glasgow REAL,systolic REAL,diastolic REAL,heart_rate REAL,'
        'respiratory_rate REAL,temperature REAL,spo2 REAL,glucose REAL,reason TEXT,brief_history TEXT,'
        'physical_exam TEXT,diagnoses TEXT,treatment TEXT,studies TEXT,evolution TEXT,disposition TEXT,'
        'disposition_notes TEXT,created_at TEXT NOT NULL,'
        'FOREIGN KEY(patient_id) REFERENCES patients(id) ON DELETE CASCADE)',
    'CREATE TABLE hospitalizations('
        'id INTEGER PRIMARY KEY AUTOINCREMENT,patient_id INTEGER NOT NULL,admitted_at TEXT NOT NULL,'
        'discharged_at TEXT,room TEXT,bed TEXT,reason TEXT,diagnoses TEXT,exam TEXT,plan TEXT,'
        'discharge_diagnoses TEXT,discharge_summary TEXT,discharge_treatment TEXT,'
        'discharge_recommendations TEXT,status TEXT NOT NULL DEFAULT "hospitalizado",'
        'created_at TEXT NOT NULL,FOREIGN KEY(patient_id) REFERENCES patients(id) ON DELETE CASCADE)',
    'CREATE TABLE progress_notes('
        'id INTEGER PRIMARY KEY AUTOINCREMENT,hospitalization_id INTEGER NOT NULL,date TEXT NOT NULL,'
        'subjective TEXT,objective TEXT,assessment TEXT,plan TEXT,systolic REAL,diastolic REAL,'
        'heart_rate REAL,respiratory_rate REAL,temperature REAL,spo2 REAL,glucose REAL,created_at TEXT NOT NULL,'
        'FOREIGN KEY(hospitalization_id) REFERENCES hospitalizations(id) ON DELETE CASCADE)',
    'CREATE TABLE medical_orders('
        'id INTEGER PRIMARY KEY AUTOINCREMENT,hospitalization_id INTEGER NOT NULL,date TEXT NOT NULL,'
        'diet TEXT,activity TEXT,fluids TEXT,oxygen TEXT,medications TEXT,monitoring TEXT,studies TEXT,nursing TEXT,other TEXT,'
        'created_at TEXT NOT NULL,FOREIGN KEY(hospitalization_id) REFERENCES hospitalizations(id) ON DELETE CASCADE)',
    'CREATE TABLE documents('
        'id INTEGER PRIMARY KEY AUTOINCREMENT,patient_id INTEGER NOT NULL,date TEXT NOT NULL,type TEXT NOT NULL,'
        'title TEXT NOT NULL,content TEXT NOT NULL,created_at TEXT NOT NULL,'
        'FOREIGN KEY(patient_id) REFERENCES patients(id) ON DELETE CASCADE)',
    'CREATE TABLE cie10('
        'id INTEGER PRIMARY KEY AUTOINCREMENT,code TEXT NOT NULL UNIQUE,name TEXT NOT NULL,chapter TEXT,'
        'search_text TEXT NOT NULL,favorite INTEGER NOT NULL DEFAULT 0)',
    'CREATE INDEX idx_cie_code ON cie10(code)',
    'CREATE INDEX idx_cie_search ON cie10(search_text)',
    'CREATE TABLE appointments('
        'id INTEGER PRIMARY KEY AUTOINCREMENT,patient_id INTEGER NOT NULL,start_at TEXT NOT NULL,reason TEXT,notes TEXT,'
        'status TEXT NOT NULL DEFAULT "programada",notify_minutes_before INTEGER NOT NULL DEFAULT 30,'
        'created_at TEXT NOT NULL,updated_at TEXT NOT NULL,'
        'FOREIGN KEY(patient_id) REFERENCES patients(id) ON DELETE CASCADE)',
    'CREATE INDEX idx_appointments_start ON appointments(start_at)',
    'CREATE TABLE audit(id INTEGER PRIMARY KEY AUTOINCREMENT,date TEXT NOT NULL,action TEXT NOT NULL,detail TEXT)',
    'CREATE TABLE favorites(id INTEGER PRIMARY KEY AUTOINCREMENT,type TEXT NOT NULL,name TEXT NOT NULL,content TEXT NOT NULL,created_at TEXT NOT NULL)',
    'CREATE TABLE medications('
        'id INTEGER PRIMARY KEY AUTOINCREMENT,generic_name TEXT NOT NULL,brand_name TEXT,form TEXT,strength TEXT,'
        'presentation TEXT,registration TEXT,status TEXT,source TEXT,favorite INTEGER NOT NULL DEFAULT 0,'
        'use_count INTEGER NOT NULL DEFAULT 0,last_used_at TEXT,search_text TEXT NOT NULL)',
    'CREATE INDEX idx_med_search ON medications(search_text)',
    'CREATE INDEX idx_med_generic ON medications(generic_name)',
    'CREATE TABLE app_settings(setting_key TEXT PRIMARY KEY,setting_value TEXT)',
  ];

  Future<int> insert(String table, Map<String, Object?> data) async {
    final db = await database;
    return db.insert(table, data);
  }

  Future<int> update(String table, Map<String, Object?> data, int id) async {
    final db = await database;
    return db.update(table, data, where: 'id=?', whereArgs: [id]);
  }

  Future<List<Map<String, Object?>>> all(
    String table, {
    String? where,
    List<Object?>? args,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return db.query(
      table,
      where: where,
      whereArgs: args,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<Map<String, Object?>?> one(String table, int id) async {
    final r = await all(table, where: 'id=?', args: [id], limit: 1);
    return r.isEmpty ? null : r.first;
  }

  Future<int> count(String table) async {
    final db = await database;
    final r = await db.rawQuery('SELECT COUNT(*) n FROM $table');
    return (r.first['n'] as int?) ?? 0;
  }

  Future<List<Map<String, Object?>>> searchPatients(
    String q, {
    bool includeArchived = false,
  }) async {
    final db = await database;
    q = q.trim();
    final archive = includeArchived ? '1=1' : 'is_archived=0';
    if (q.isEmpty) {
      return db.query(
        'patients',
        where: archive,
        orderBy: 'last_name,first_name',
      );
    }
    final like = '%$q%';
    return db.query(
      'patients',
      where:
          '$archive AND (first_name LIKE ? OR last_name LIKE ? OR curp LIKE ? OR phone LIKE ?)',
      whereArgs: [like, like, like, like],
      orderBy: 'last_name,first_name',
    );
  }

  Future<List<Map<String, Object?>>> findDuplicatePatients({
    required String firstName,
    required String lastName,
    required String dob,
    required String phone,
    required String curp,
    int? excludeId,
  }) async {
    final db = await database;
    final clauses = <String>[];
    final args = <Object?>[];

    if (curp.trim().isNotEmpty) {
      clauses.add('UPPER(curp)=?');
      args.add(curp.trim().toUpperCase());
    }
    if (phone.trim().isNotEmpty) {
      clauses.add('phone=?');
      args.add(phone.trim());
    }
    if (firstName.trim().isNotEmpty &&
        lastName.trim().isNotEmpty &&
        dob.trim().isNotEmpty) {
      clauses.add('(UPPER(first_name)=? AND UPPER(last_name)=? AND dob=?)');
      args.addAll([
        firstName.trim().toUpperCase(),
        lastName.trim().toUpperCase(),
        dob.trim(),
      ]);
    }
    if (clauses.isEmpty) return [];

    var where = '(${clauses.join(' OR ')})';
    if (excludeId != null) {
      where += ' AND id<>?';
      args.add(excludeId);
    }
    return db.query('patients', where: where, whereArgs: args, limit: 10);
  }

  Future<Map<String, Object?>?> latestConsultation(int patientId) async {
    final rows = await all(
      'consultations',
      where: 'patient_id=?',
      args: [patientId],
      orderBy: 'date DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<Map<String, Object?>?> previousMedicalOrder(
    int hospitalizationId,
  ) async {
    final rows = await all(
      'medical_orders',
      where: 'hospitalization_id=?',
      args: [hospitalizationId],
      orderBy: 'date DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> timeline(int pid) async {
    final db = await database;
    final out = <Map<String, Object?>>[];
    void addEvent(
      Map<String, Object?> r,
      String table,
      String type,
      String dateKey,
    ) {
      final preview =
          r['diagnoses'] ??
          r['assessment'] ??
          r['title'] ??
          r['reason'] ??
          r['medications'] ??
          '';
      out.add({
        'date': r[dateKey],
        'type': type,
        'text': preview,
        'table': table,
        'id': r['id'],
        'search': r.entries
            .where((e) => !e.key.endsWith('_id') && e.key != 'id')
            .map((e) => '${e.value ?? ''}')
            .join(' '),
      });
    }

    for (final source in const [
      ['consultations', 'Consulta', 'date'],
      ['emergencies', 'Urgencias', 'date'],
      ['hospitalizations', 'Hospitalización', 'admitted_at'],
      ['documents', 'Documento', 'date'],
    ]) {
      for (final r in await db.query(
        source[0],
        where: 'patient_id=?',
        whereArgs: [pid],
      )) {
        addEvent(
          r,
          source[0],
          source[0] == 'documents' ? '${r['type'] ?? 'Documento'}' : source[1],
          source[2],
        );
      }
    }
    for (final source in const [
      ['progress_notes', 'Evolución hospitalaria'],
      ['medical_orders', 'Indicaciones hospitalarias'],
    ]) {
      final rows = await db.rawQuery(
        'SELECT n.* FROM ${source[0]} n INNER JOIN hospitalizations h ON h.id=n.hospitalization_id WHERE h.patient_id=?',
        [pid],
      );
      for (final r in rows) {
        addEvent(r, source[0], source[1], 'date');
      }
    }
    out.sort((a, b) {
      final ad = DateTime.tryParse('${a['date']}');
      final bd = DateTime.tryParse('${b['date']}');
      final dateOrder = ad != null && bd != null
          ? bd.compareTo(ad)
          : '${b['date'] ?? ''}'.compareTo('${a['date'] ?? ''}');
      return dateOrder != 0
          ? dateOrder
          : '${a['table']}:${a['id']}'.compareTo('${b['table']}:${b['id']}');
    });
    return out;
  }

  Future<List<Map<String, Object?>>> searchCie(String q) async {
    final db = await database;
    q = q.trim().toUpperCase();
    if (q.length < 2) return [];
    final like = '%$q%';
    return db.query(
      'cie10',
      where: 'code LIKE ? OR search_text LIKE ?',
      whereArgs: [like, like],
      orderBy: 'favorite DESC,code',
      limit: 50,
    );
  }

  Future<List<Map<String, Object?>>> searchMedications(String q) async {
    final db = await database;
    q = q.trim().toUpperCase();
    if (q.isEmpty) {
      return db.query(
        'medications',
        orderBy: 'favorite DESC,use_count DESC,last_used_at DESC',
        limit: 30,
      );
    }
    final like = '%$q%';
    return db.query(
      'medications',
      where: 'search_text LIKE ?',
      whereArgs: [like],
      orderBy: 'favorite DESC,use_count DESC,generic_name',
      limit: 40,
    );
  }

  Future<void> markMedicationUsed(Map<String, Object?> medication) async {
    final db = await database;
    final id = medication['id'] as int?;
    if (id == null) return;
    final count = ((medication['use_count'] as int?) ?? 0) + 1;
    await db.update(
      'medications',
      {'use_count': count, 'last_used_at': DateTime.now().toIso8601String()},
      where: 'id=?',
      whereArgs: [id],
    );
  }

  Future<void> upsertFreeMedication(String name) async {
    final clean = name.trim();
    if (clean.isEmpty) return;
    final db = await database;
    final existing = await db.query(
      'medications',
      where: 'UPPER(generic_name)=?',
      whereArgs: [clean.toUpperCase()],
      limit: 1,
    );
    if (existing.isNotEmpty) {
      await markMedicationUsed(existing.first);
      return;
    }
    await db.insert('medications', {
      'generic_name': clean,
      'brand_name': '',
      'form': '',
      'strength': '',
      'presentation': '',
      'registration': '',
      'status': 'captura local',
      'source': 'usuario',
      'favorite': 0,
      'use_count': 1,
      'last_used_at': DateTime.now().toIso8601String(),
      'search_text': clean.toUpperCase(),
    });
  }

  Future<void> setSetting(String key, String value) async {
    final db = await database;
    await db.insert('app_settings', {
      'setting_key': key,
      'setting_value': value,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows = await db.query(
      'app_settings',
      where: 'setting_key=?',
      whereArgs: [key],
      limit: 1,
    );
    return rows.isEmpty ? null : '${rows.first['setting_value']}';
  }

  Future<void> audit(String action, String detail) async {
    await insert('audit', {
      'date': DateTime.now().toIso8601String(),
      'action': action,
      'detail': detail,
    });
  }
}
