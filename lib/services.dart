import 'clinical_prescription_pdf.dart';
import 'clinical_pdf_signature.dart';
import 'dart:typed_data';
import 'clinical_profile.dart';
import 'clinical_exchange_data.dart';
import 'clinical_catalog.dart';
import 'clinical_guidance.dart';

import 'dart:convert';
import 'dart:math';
import 'dart:io';

import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography/cryptography.dart';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:local_auth/local_auth.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite_sqlcipher/sqflite.dart'
    show openDatabase;

import 'db.dart';
import 'clinical_nom.dart';

class SecurityService {
  static const _storage = FlutterSecureStorage();
  static final _auth = LocalAuthentication();
  static String _hash(String pin) =>
      sha256.convert(utf8.encode('angel-medical::$pin')).toString();
  static Future<bool> hasPin() async =>
      (await _storage.read(key: 'pin_hash')) != null;
  static Future<void> setPin(String pin) =>
      _storage.write(key: 'pin_hash', value: _hash(pin));
  static Future<bool> verifyPin(String pin) async =>
      (await _storage.read(key: 'pin_hash')) == _hash(pin);
  static Future<bool> biometric() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'Desbloquear Angel Medical',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }
}

class BackupService {
  static final _cipher = AesGcm.with256bits();
  static final _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: 150000,
    bits: 256,
  );

  static Future<SecretKey> _derive(String password, List<int> salt) =>
      _kdf.deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);

  /// Encrypted logical snapshot for a future desktop reader; not live sync.
  static Future<File> createExchange(String password) async {
    if (password.trim().length < 8) throw const FormatException('Usa al menos 8 caracteres para el archivo de intercambio.');
    final db = await AppDb.instance.database;
    var databaseId = await AppDb.instance.getSetting('database_uuid');
    if (databaseId == null) {
      final random = Random.secure();
      databaseId = List.generate(16, (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();
      await AppDb.instance.setSetting('database_uuid', databaseId);
    }
    final snapshot = await db.transaction((tx) async {
      if ((await tx.rawQuery('PRAGMA integrity_check')).single.values.first != 'ok' || (await tx.rawQuery('PRAGMA foreign_key_check')).isNotEmpty) throw const FormatException('La base requiere revisión antes de exportar.');
      final tables = await tx.rawQuery("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%' AND name!='android_metadata' ORDER BY name");
      final data = <String, dynamic>{};
      for (final table in tables) {
        final name = '${table['name']}';
        if (!RegExp(r'^[a-z_]+$').hasMatch(name)) throw const FormatException('Tabla no reconocida.');
        data[name] = (await tx.query(name)).map(exchangeRow).toList();
      }
      return {'format': 'angel-medical-logical-snapshot', 'version': 1, 'app_version': '2.9.1', 'database_uuid': databaseId, 'schema_version': (await tx.rawQuery('PRAGMA user_version')).single['user_version'], 'created_at': DateTime.now().toUtc().toIso8601String(), 'blob_encoding': r'base64/$binary', 'tables': data};
    });
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final encrypted = await _cipher.encrypt(utf8.encode(jsonEncode(snapshot)), secretKey: await _derive(password, salt));
    final file = File(join((await getApplicationDocumentsDirectory()).path, 'Angel_PC_${DateTime.now().microsecondsSinceEpoch}.amx'));
    await file.writeAsString(jsonEncode({'format': 'angel-medical-encrypted-exchange', 'v': 1, 'salt': base64Encode(salt), 'nonce': base64Encode(encrypted.nonce), 'mac': base64Encode(encrypted.mac.bytes), 'data': base64Encode(encrypted.cipherText)}), flush: true);
    await AppDb.instance.audit('EXPORT_ENCRYPTED_EXCHANGE', 'Instantánea lógica cifrada para PC; sin sincronización');
    return file;
  }

  static Future<File> createPortable(String password) async {
    if (password.trim().length < 6) {
      throw Exception(
        'Usa una contraseña de respaldo de al menos 6 caracteres.',
      );
    }

    final live = await AppDb.instance.database;
    final integrity = await live.rawQuery('PRAGMA integrity_check');
    if (integrity.length != 1 || integrity.first.values.first != 'ok')
      throw StateError('La base requiere revision antes del respaldo');
    await AppDb.instance.close();

    try {
      final dbPath = await AppDb.instance.path;
      final dbKey = await AppDb.instance.dbKey;
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        throw Exception('No se encontró la base de datos.');
      }

      final dbBytes = await dbFile.readAsBytes();
      final createdAt = DateTime.now().toIso8601String();

      final payload = utf8.encode(
        jsonEncode({
          'format': 'angel_medical_portable_backup',
          'version': 2,
          'createdAt': createdAt,
          'dbKey': dbKey,
          'db': base64Encode(dbBytes),
        }),
      );

      final secure = Random.secure();
      final salt = List<int>.generate(16, (_) => secure.nextInt(256));
      final key = await _derive(password, salt);
      final box = await _cipher.encrypt(payload, secretKey: key);

      final data = jsonEncode({
        'v': 2,
        'salt': base64Encode(salt),
        'nonce': base64Encode(box.nonce),
        'mac': base64Encode(box.mac.bytes),
        'data': base64Encode(box.cipherText),
      });

      final dir = await getApplicationDocumentsDirectory();
      final stamp = createdAt.replaceAll(':', '-').replaceAll('.', '-');
      final file = File(join(dir.path, 'Angel_Medical_$stamp.ambak'));

      await file.writeAsString(data, flush: true);

      await AppDb.instance.reopen();
      await AppDb.instance.setSetting('last_backup_at', createdAt);
      await AppDb.instance.setSetting('last_backup_file', file.path);
      await AppDb.instance.audit('CREATE_BACKUP', file.path);
      return file;
    } catch (_) {
      try {
        await AppDb.instance.reopen();
      } catch (_) {}
      rethrow;
    }
  }

  static Future<File> createAndShareToCloud(String password) async {
    final file = await createPortable(password);

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Respaldo Angel Medical',
      text: 'Respaldo cifrado de Angel Medical. Guarda este archivo en Google Drive, OneDrive u otra nube segura.',
    );

    await AppDb.instance.audit('SHARE_BACKUP_CLOUD', file.path);
    return file;
  }

  static Future<Map<String, dynamic>> _decodeBackup(
    String raw,
    String password,
  ) async {
    final j = jsonDecode(raw) as Map<String, dynamic>;

    for (final requiredKey in ['salt', 'nonce', 'mac', 'data']) {
      if (!j.containsKey(requiredKey)) {
        throw Exception(
          'El archivo no es un respaldo válido de Angel Medical.',
        );
      }
    }

    final salt = base64Decode(j['salt']);
    final nonce = base64Decode(j['nonce']);
    final mac = Mac(base64Decode(j['mac']));
    final cipherText = base64Decode(j['data']);

    final key = await _derive(password, salt);
    final clear = await _cipher.decrypt(
      SecretBox(cipherText, nonce: nonce, mac: mac),
      secretKey: key,
    );

    final payload = jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;

    if (!payload.containsKey('dbKey') || !payload.containsKey('db')) {
      throw Exception('El respaldo está incompleto o dañado.');
    }

    return payload;
  }

  static Future<Map<String, dynamic>?> inspect(String password) async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (pick == null) return null;

    final bytes =
        pick.files.single.bytes ??
        await File(pick.files.single.path!).readAsBytes();
    final raw = utf8.decode(bytes);
    final payload = await _decodeBackup(raw, password);

    final counts = await validatePayload(payload);
    final dbBytes = base64Decode(payload['db']);
    return {
      'counts': counts,
      'fileName': pick.files.single.name,
      'createdAt': payload['createdAt'] ?? 'Respaldo anterior',
      'sizeBytes': dbBytes.length,
      'payload': payload,
    };
  }

  static Future<Map<String, Object?>> validatePayload(
    Map<String, dynamic> payload,
  ) async {
    final dir = await Directory.systemTemp.createTemp('angel_backup_check_');
    try {
      final bytes = base64Decode(payload['db']);
      if (bytes.length < 1024)
        throw const FormatException('Respaldo incompleto');
      final file = File(join(dir.path, 'verify.db'));
      await file.writeAsBytes(bytes, flush: true);
      final db = await openDatabase(
        file.path,
        password: '${payload['dbKey']}',
        readOnly: true,
        singleInstance: false,
      );
      try {
        final integrity = await db.rawQuery('PRAGMA integrity_check');
        if (integrity.length != 1 || integrity.first.values.first != 'ok')
          throw const FormatException('Respaldo dañado');
        final versionRows = await db.rawQuery('PRAGMA user_version');
        final schemaVersion = versionRows.single['user_version'] as int;
        if (schemaVersion > 6)
          throw const FormatException(
            'El respaldo pertenece a una versión más reciente',
          );
        if ((await db.rawQuery('PRAGMA foreign_key_check')).isNotEmpty)
          throw const FormatException(
            'El respaldo tiene relaciones inconsistentes',
          );
        if (schemaVersion >= 6) {
          for (final table in [
            'consultations',
            'emergencies',
            'hospitalizations',
            'progress_notes',
            'medical_orders',
            'documents',
          ]) {
            final columns = await db.rawQuery('PRAGMA table_info($table)');
            if (!columns.any((c) => c['name'] == 'nom_json')) {
              throw const FormatException(
                'Respaldo v6 con estructura incompleta',
              );
            }
          }
        }
        final counts = <String, Object?>{};
        for (final table in [
          'patients',
          'consultations',
          'emergencies',
          'hospitalizations',
          'progress_notes',
          'medical_orders',
          'documents',
          if (schemaVersion >= 5) ...[
            'clinical_drafts',
            'clinical_revisions',
            'clinical_tasks',
            'clinical_attachments',
            'clinical_measurements',
            'clinical_templates',
          ],
        ]) {
          counts[table] = (await db.rawQuery(
            'SELECT COUNT(*) AS n FROM $table',
          )).first['n'];
        }
        return counts;
      } finally {
        await db.close();
      }
    } finally {
      await dir.delete(recursive: true);
    }
  }

  static Future<bool> restoreFromCloudOrFile(String password) async {
    final pick = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: true,
    );
    if (pick == null) return false;
    File? safety;
    String? currentPath, oldKey;
    bool replaced = false;
    try {
      final bytes =
          pick.files.single.bytes ??
          await File(pick.files.single.path!).readAsBytes();
      final payload = await _decodeBackup(utf8.decode(bytes), password);
      final expected = await validatePayload(payload);
      final localProfile = await AppDb.instance.getSetting('nom_profile');
      currentPath = await AppDb.instance.path;
      oldKey = await AppDb.instance.dbKey;
      final temp = File('$currentPath.restore_tmp');
      await temp.writeAsBytes(base64Decode(payload['db']), flush: true);
      await AppDb.instance.close();
      final current = File(currentPath);
      if (!await current.exists())
        throw StateError(
          'No se encontró la base actual; no se reemplazó nada.',
        );
      final stamp = DateTime.now().microsecondsSinceEpoch;
      // Retain the old encrypted file and its key in secure storage for rollback.
      await const FlutterSecureStorage().write(
        key: 'pre_restore_key_$stamp',
        value: oldKey,
      );
      safety = await current.rename('$currentPath.pre_restore_$stamp');
      replaced = true;
      await temp.rename(currentPath);
      await AppDb.instance.setDbKey('${payload['dbKey']}');
      await AppDb.instance.reopen();
      for (final entry in expected.entries) {
        if (await AppDb.instance.count(entry.key) != entry.value)
          throw StateError('El conteo restaurado no coincide');
      }
      final preserve = localProfileToPreserve(localProfile, await AppDb.instance.getSetting('nom_profile'));
      // Keep the local doctor only if the older backup lacks saved identity.
      if (preserve != null) {
        await AppDb.instance.setSetting('nom_profile', preserve);
        await AppDb.instance.audit('PRESERVE_PROFILE_ON_RESTORE', 'Perfil local conservado al restaurar respaldo sin identidad');
      }
      await AppDb.instance.setSetting(
        'last_restore_at',
        DateTime.now().toIso8601String(),
      );
      await AppDb.instance.audit('RESTORE_BACKUP', pick.files.single.name);
      return true;
    } catch (_) {
      if (replaced && safety != null && currentPath != null && oldKey != null) {
        try {
          await AppDb.instance.close();
          for (final suffix in ['', '-wal', '-shm']) {
            final f = File('$currentPath$suffix');
            if (await f.exists()) await f.delete();
          }
          // Copy retains the safety snapshot even if reopening fails.
          await safety.copy(currentPath);
          await AppDb.instance.setDbKey(oldKey);
          await AppDb.instance.reopen();
        } catch (_) {
          /* Retain the encrypted safety file for recovery. */
        }
      } else {
        try {
          await AppDb.instance.reopen();
        } catch (_) {}
      }
      return false;
    }
  }

  static Future<bool> restore(String password) =>
      restoreFromCloudOrFile(password);

  static Future<void> share(String password) async {
    await createAndShareToCloud(password);
  }
}

class MedicationImporter {
  static String _norm(String s) =>
      CieImporter.norm(s.replaceAll(RegExp(r'\s+'), ' '));

  static int? _firstHeader(Map<String, int> h, List<String> names) {
    for (final n in names) {
      if (h.containsKey(n)) return h[n];
    }
    return null;
  }

  static Future<int> importXlsx() async {
    final p = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (p == null) return 0;

    if (p.files.single.size > 20 * 1024 * 1024) {
      throw const FormatException('El catálogo supera 20 MB.');
    }
    final bytes =
        p.files.single.bytes ?? await File(p.files.single.path!).readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return 0;
    final sheet = excel.tables.values.first;
    if (sheet.rows.isEmpty) return 0;

    final headers = <String, int>{};
    for (var i = 0; i < sheet.rows.first.length; i++) {
      final v = CieImporter.norm(
        sheet.rows.first[i]?.value?.toString().trim() ?? '',
      );
      headers[v] = i;
    }

    final generic = _firstHeader(headers, [
      'DENOMINACION GENERICA',
      'DENOMINACION_GENERICA',
      'GENERICA',
      'PRINCIPIO ACTIVO',
      'PRINCIPIO_ACTIVO',
      'SUSTANCIA ACTIVA',
    ]);
    final brand = _firstHeader(headers, [
      'DENOMINACION DISTINTIVA',
      'DENOMINACION_DISTINTIVA',
      'NOMBRE COMERCIAL',
      'NOMBRE_COMERCIAL',
      'MARCA',
    ]);
    final form = _firstHeader(headers, [
      'FORMA FARMACEUTICA',
      'FORMA_FARMACEUTICA',
      'FORMA',
    ]);
    final strength = _firstHeader(headers, [
      'CONCENTRACION',
      'CONCENTRACIÓN',
      'FUERZA',
    ]);
    final presentation = _firstHeader(headers, [
      'PRESENTACION',
      'PRESENTACIÓN',
    ]);
    final registration = _firstHeader(headers, [
      'REGISTRO SANITARIO',
      'REGISTRO_SANITARIO',
      'NO REGISTRO',
      'REGISTRO',
    ]);
    final status = _firstHeader(headers, [
      'VIGENCIA',
      'ESTATUS',
      'STATUS',
      'ESTADO',
    ]);

    if (generic == null && brand == null) {
      throw Exception(
        'El XLSX necesita una columna de denominación genérica, principio activo o nombre comercial.',
      );
    }

    String cell(List<Data?> row, int? i) => i == null || i >= row.length
        ? ''
        : (row[i]?.value?.toString().trim() ?? '');

    final db = await AppDb.instance.database;
    var n = 0;
    final batch = db.batch();

    for (final row in sheet.rows.skip(1)) {
      final g = cell(row, generic);
      final b = cell(row, brand);
      if (g.isEmpty && b.isEmpty) continue;
      final f = cell(row, form);
      final s = cell(row, strength);
      final pr = cell(row, presentation);
      final reg = cell(row, registration);
      final st = cell(row, status);

      batch.insert('medications', {
        'generic_name': g.isEmpty ? b : g,
        'brand_name': b,
        'form': f,
        'strength': s,
        'presentation': pr,
        'registration': reg,
        'status': st,
        'source': 'COFEPRIS/importado',
        'favorite': 0,
        'use_count': 0,
        'last_used_at': null,
        'search_text': _norm('$g $b $f $s $pr $reg'),
      });
      n++;
    }

    await batch.commit(noResult: true);
    await AppDb.instance.audit('IMPORT_MEDICATIONS', '$n medicamentos');
    return n;
  }
}

class CieImporter {
  static String norm(String s) => normalizeCatalogText(s);

  static Future<int> importXlsx() async {
    final p = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (p == null) return 0;
    final bytes =
        p.files.single.bytes ?? await File(p.files.single.path!).readAsBytes();
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return 0;
    final sheet = excel.tables.values.first;
    if (sheet.rows.isEmpty) return 0;
    final headers = <String, int>{};
    for (var i = 0; i < sheet.rows.first.length; i++) {
      final v =
          sheet.rows.first[i]?.value?.toString().trim().toUpperCase() ?? '';
      headers[v] = i;
    }
    final ci = headers['CATALOG_KEY'],
        ni = headers['NOMBRE'],
        li = headers['LETRA'];
    if (ci == null || ni == null)
      throw Exception('El XLSX requiere columnas CATALOG_KEY y NOMBRE.');
    final entries = validateCatalogRows(
      sheet.rows.skip(1).map((row) {
        String val(int? i) => i == null || i >= row.length
            ? ''
            : (row[i]?.value?.toString() ?? '');
        return [val(ci), val(ni), val(li)];
      }),
    );
    final db = await AppDb.instance.database;
    await db.transaction((tx) async {
      final batch = tx.batch();
      for (final entry in entries) {
        batch.rawInsert(
          'INSERT INTO cie10(code,name,chapter,search_text) VALUES(?,?,?,?) ON CONFLICT(code) DO UPDATE SET name=excluded.name,chapter=excluded.chapter,search_text=excluded.search_text',
          [entry.code, entry.name, entry.chapter, entry.searchText],
        );
      }
      await batch.commit(noResult: true);
    });
    await AppDb.instance.audit(
      'IMPORT_CIE10',
      '${entries.length} diagnósticos',
    );
    return entries.length;
  }
}

class CieBootstrap {
  static Future<void> ensureLoaded() async {
    final raw = await rootBundle.loadString('assets/data/cie10_full.json');
    final items = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    validateCatalogRows(items.map((m) => ['${m['code']}', '${m['name']}', '${m['chapter']}']));
    BundledCie.entries = {for (final m in items) '${m['code']}': m};
    final version = sha256.convert(utf8.encode(raw)).toString();
    if (await AppDb.instance.getSetting('bundled_cie_version') == version) return;
    final db = await AppDb.instance.database;
    await db.transaction((txn) async {
      final batch = txn.batch();
      for (final m in items.where((m) => m['valid'] == true)) {
        // IGNORE preserves imported labels, row IDs and favorites. No REPLACE.
        batch.rawInsert(
          'INSERT OR IGNORE INTO cie10(code,name,chapter,search_text,favorite) VALUES(?,?,?,?,0)',
          [m['code'], m['name'], m['chapter'], normalizeCatalogText('${m['code']} ${BundledCie.displayCode('${m['code']}')} ${m['name']}')],
        );
      }
      await batch.commit(noResult: true);
      await txn.rawInsert(
        'INSERT INTO app_settings(setting_key,setting_value) VALUES(?,?) ON CONFLICT(setting_key) DO UPDATE SET setting_value=excluded.setting_value',
        ['bundled_cie_version', version],
      );
    });
  }
}

class PdfService {
  static pw.Widget section(String t, String v) => pw.Padding(
    padding: const pw.EdgeInsets.only(top: 8),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          t,
          style: pw.TextStyle(
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.blue900,
          ),
        ),
        pw.SizedBox(height: 2),
        pw.Text(v.trim().isEmpty ? '—' : v),
      ],
    ),
  );

  static Future<pw.MemoryImage?> _assetImage(String path) async {
    try {
      final data = await rootBundle.load(path);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  static pw.MemoryImage? _profileLogo(Map<String, dynamic> profile) {
    final text = profile['logo_base64'];
    if (text == null || '$text'.isEmpty) return null;
    return pw.MemoryImage(base64Decode('$text'));
  }

  static Future<pw.Widget> _header(Map<String, dynamic> profile) async {
    final logo =
        _profileLogo(profile) ??
        (communityEdition
            ? null
            : await _assetImage('assets/images/logo_dr_angel.png'));
    return pw.Row(
      children: [
        if (logo != null)
          pw.Container(
            width: 135,
            height: 55,
            child: pw.Image(logo, fit: pw.BoxFit.contain),
          ),
        pw.Spacer(),
        pw.Text(
          'ANGEL MEDICAL · DOCUMENTACIÓN CLÍNICA',
          style: const pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  static Future<void> printClinical({required String title, required Map<String, Object?> patient, required List<MapEntry<String, String>> fields, Map<String, Object?>? record}) async {
    final bytes = await buildClinicalPdf(title: title, patient: patient, fields: fields, record: record);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }

  static Future<Uint8List> buildClinicalPdf({
    required String title,
    required Map<String, Object?> patient,
    required List<MapEntry<String, String>> fields,
    Map<String, Object?>? record,
    bool signatureCopy = false,
    PdfCmsSigner? embeddedSigner, String? signerName, Uint8List? certificate, DateTime? signedAt,
  }) async {
    if (record?['type'] == 'Receta') {
      return buildRecipePdf(patient: patient, record: record!, legacyProfile: decodeNom(await AppDb.instance.getSetting('nom_profile')), signer: embeddedSigner, signerName: signerName, certificate: certificate, signedAt: signedAt);
    }
    final doc = pw.Document();
    final nom = decodeNom(record?['nom_json']);
    final author = nom['profile'] is Map
        ? Map<String, dynamic>.from(nom['profile'] as Map)
        : <String, dynamic>{};
    final header = await _header(author);
    final signatureAuthor = nom['correction_profile'] is Map
        ? Map<String, dynamic>.from(nom['correction_profile'] as Map)
        : author;
    final extras = nomInput(record);
    final signatures = <String>[
      if ('${signatureAuthor['doctor'] ?? ''}'.isNotEmpty)
        '${signatureAuthor['doctor']} · Cédula ${signatureAuthor['license'] ?? ''}${nom['correction_profile'] is Map ? ' · Responsable de la corrección' : ''}'
      else
        'Médico responsable: ____________________',
      if (record?['type'] == 'Consentimiento informado' ||
          record?['type'] == 'Egreso voluntario') ...[
        'Paciente / representante: ${extras['nom_signer'] ?? ''}',
        'Testigo 1: ${extras['nom_witness1'] ?? ''}',
        'Testigo 2: ${extras['nom_witness2'] ?? ''}',
      ],
    ];
    doc.addPage(
      pw.MultiPage(
        maxPages: 500,
        pageFormat: PdfPageFormat.letter,
        margin: const pw.EdgeInsets.all(28),
        header: (c) => pw.Text(
          'Expediente ${nom['patient'] is Map ? (nom['patient'] as Map)['id'] : patient['id'] ?? 'sin número'} · $title',
          style: const pw.TextStyle(fontSize: 8),
        ),
        footer: (c) => pw.Text(
          '${signatureCopy ? 'Firma separada: conservar este PDF con su archivo .p7s' : 'Impresión sin firma electrónica'} · ${c.pageNumber}/${c.pagesCount}',
          style: const pw.TextStyle(fontSize: 8),
        ),
        build: (_) => [
          header,
          pw.SizedBox(height: 14),
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Paciente: ${nom['patient'] is Map ? (nom['patient'] as Map)['name'] : '${patient['first_name']} ${patient['last_name']}'}',
          ),
          for (final e in fields.where((e) => !signatureCopy || e.key != 'Firma del documento')) ...[
            pw.SizedBox(height: 10),
            pw.Text(e.key, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            for (var i = 0; i < e.value.length; i += 1200)
              pw.Text(
                e.value.substring(i, min(i + 1200, e.value.length)),
                style: const pw.TextStyle(fontSize: 10),
              ),
          ],
          pw.SizedBox(height: 20),
          pw.Text(
            'ESPACIOS PARA FIRMA AUTÓGRAFA',
            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
          ),
          for (final signer in signatures)
            pw.Column(
              children: [
                pw.SizedBox(height: 30),
                pw.Container(
                  width: 220,
                  decoration: const pw.BoxDecoration(
                    border: pw.Border(top: pw.BorderSide()),
                  ),
                ),
                pw.Text(signer, style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          pw.SizedBox(height: 10),
          pw.Text(
            signatureCopy ? 'La firma electrónica del médico se verifica con el archivo .p7s separado. No firma por el paciente ni los testigos. Recaba sus firmas cuando corresponda. No certifica cumplimiento normativo.' : 'Recaba las firmas correspondientes y conserva el original firmado. La impresión no acredita una firma ni certifica cumplimiento normativo.',
            style: const pw.TextStyle(fontSize: 8),
          ),
        ],
      ),
    );
    return doc.save();
  }

  static int? ageFromDob(String dob) {
    try {
      final birth = DateTime.parse(dob);
      final now = DateTime.now();
      var age = now.year - birth.year;
      if (now.month < birth.month ||
          (now.month == birth.month && now.day < birth.day)) {
        age--;
      }
      return age >= 0 ? age : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> printPrescription({
    required Map<String, Object?> patient,
    required List<Map<String, String>> medications,
    required String generalInstructions,
    required String diagnosis,
    Map<String, Object?>? vitals,
    Map<String, Object?>? record,
  }) async {
    if (record == null) throw const FormatException('Guarda la receta antes de imprimir.');
    final bytes = await buildClinicalPdf(title: 'Receta médica', patient: patient, fields: [], record: record);
    await Printing.layoutPdf(onLayout: (_) async => bytes);
  }
}
