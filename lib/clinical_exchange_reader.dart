import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as hashing;
import 'package:cryptography/cryptography.dart';
import 'clinical_exchange_data.dart';

/// Returns the original signed bytes; this is not a trust-chain verification.
Uint8List originalSignedPdf(Uint8List attachment) {
  final payload = jsonDecode(utf8.decode(attachment));
  if (payload is! Map || payload['format'] != 'angel-medical-signed-pdf-v1' || payload['pdf'] is! String) throw const FormatException('Este paquete no contiene un PDF integrado compatible. Guarda el adjunto original.');
  final bytes = base64Decode(payload['pdf']);
  if (hashing.sha256.convert(bytes).toString() != payload['pdf_sha256']) throw const FormatException('El PDF no coincide con su huella registrada.');
  return bytes;
}

/// AMX v1 reader. No SQL statements are executed and no source file is changed.
class ClinicalSnapshot {
  final Map<String, dynamic> metadata;
  final Map<String, List<Map<String, dynamic>>> tables;
  ClinicalSnapshot._(this.metadata, this.tables);
  List<Map<String, dynamic>> rows(String table) => tables[table] ?? [];
  Map<String, dynamic> get profile {
    for (final row in rows('app_settings')) {
      if (row['setting_key'] == 'nom_profile') {
        try {
          final value = jsonDecode('${row['setting_value']}');
          if (value is Map<String, dynamic>) return value;
        } on FormatException { return {}; }
      }
    }
    return {};
  }
  List<Map<String, dynamic>> patientRows(String table, int patientId) {
    if (table == 'progress_notes' || table == 'medical_orders') {
      final ids = patientRows('hospitalizations', patientId).map((r) => r['id']).toSet();
      return rows(table).where((r) => ids.contains(r['hospitalization_id'])).toList();
    }
    return rows(table).where((r) => r['patient_id'] == patientId).toList();
  }

  static ClinicalSnapshot parse(String content) {
    final obj = jsonDecode(content);
    if (obj is! Map<String, dynamic> || obj['format'] != 'angel-medical-logical-snapshot' || obj['version'] != 1 || obj['schema_version'] != 7 || obj['tables'] is! Map) {
      throw const FormatException('Formato o versión de expediente no compatible. Exporta desde Ángel Medical 3.2.');
    }
    if (obj['database_uuid'] is! String || !RegExp(r'^[a-f0-9]{32}$').hasMatch(obj['database_uuid']) || DateTime.tryParse('${obj['created_at']}') == null) {
      throw const FormatException('Identidad o fecha de la instantánea no válida.');
    }
    final tables = <String, List<Map<String, dynamic>>>{};
    for (final entry in (obj['tables'] as Map).entries) {
      final name = '${entry.key}';
      if (!isExchangeTableName(name) || entry.value is! List) throw const FormatException('Tabla no válida.');
      final rows = <Map<String, dynamic>>[];
      final ids = <Object>{};
      for (final value in entry.value as List) {
        if (value is! Map<String, dynamic>) throw const FormatException('Registro no válido.');
        final row = <String, dynamic>{};
        for (final cell in value.entries) {
          final v = cell.value;
          if (v is Map && v.length == 1 && v.containsKey(r'$binary') && v[r'$binary'] is String) {
            row[cell.key] = base64Decode(v[r'$binary'] as String);
          } else if (v == null || v is String || v is num) {
            row[cell.key] = v;
          } else {
            throw const FormatException('Celda no compatible.');
          }
        }
        final id = row['id'] ?? row['setting_key'] ?? row['draft_key'];
        if (id == null || !ids.add(id)) throw const FormatException('Identificadores ausentes o duplicados.');
        rows.add(Map.unmodifiable(row));
      }
      tables[name] = List.unmodifiable(rows);
    }
    const required = ['patients', 'consultations', 'emergencies', 'hospitalizations', 'progress_notes', 'medical_orders', 'documents', 'appointments', 'app_settings', 'clinical_attachments', 'clinical_scales'];
    if (required.any((t) => !tables.containsKey(t))) throw const FormatException('Faltan tablas del expediente.');
    final patients = tables['patients']!.map((r) => r['id']).toSet();
    final admissions = tables['hospitalizations']!.map((r) => r['id']).toSet();
    if (patients.any((id) => id is! int || id <= 0)) throw const FormatException('Identificador de paciente no válido.');
    for (final table in tables.entries) {
      for (final row in table.value) {
        if (row.containsKey('patient_id') && !patients.contains(row['patient_id'])) throw const FormatException('Registro sin paciente correspondiente.');
        if (row.containsKey('hospitalization_id') && !admissions.contains(row['hospitalization_id'])) throw const FormatException('Registro sin hospitalización correspondiente.');
        if (table.key == 'clinical_attachments') {
          final data = row['data'];
          if (data is! Uint8List || hashing.sha256.convert(data).toString() != row['sha256']) throw const FormatException('Un adjunto no coincide con su huella de integridad.');
        }
      }
    }
    return ClinicalSnapshot._(Map.unmodifiable({...obj}..remove('tables')), Map.unmodifiable(tables));
  }
}

Future<ClinicalSnapshot> readClinicalExchange(String envelope, String password) async {
  final obj = jsonDecode(envelope);
  if (obj is! Map || obj['format'] != 'angel-medical-encrypted-exchange' || obj['v'] != 1) throw const FormatException('Selecciona un archivo .amx; .ambak se utiliza en Android.');
  List<int> field(String name, [int? length]) {
    if (obj[name] is! String) throw const FormatException('Contenedor cifrado incompleto.');
    final bytes = base64Decode(obj[name]);
    if (length != null && bytes.length != length) throw const FormatException('Contenedor cifrado no válido.');
    return bytes;
  }
  final salt = field('salt', 16), nonce = field('nonce', 12), mac = field('mac', 16), data = field('data');
  final kdf = Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 150000, bits: 256);
  final key = await kdf.deriveKey(secretKey: SecretKey(utf8.encode(password)), nonce: salt);
  List<int> plain;
  try {
    plain = await AesGcm.with256bits().decrypt(SecretBox(data, nonce: nonce, mac: Mac(mac)), secretKey: key);
  } on SecretBoxAuthenticationError {
    throw const FormatException('Contraseña incorrecta o archivo alterado.');
  }
  return ClinicalSnapshot.parse(utf8.decode(plain));
}
