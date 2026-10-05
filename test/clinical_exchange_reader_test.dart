import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' as hashing;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/clinical_exchange_data.dart';
import '../lib/clinical_exchange_reader.dart';

Map<String, dynamic> fixture() {
  final data = Uint8List.fromList([0, 1, 2, 128, 255]);
  return {
    'format': 'angel-medical-logical-snapshot', 'version': 1, 'schema_version': 7,
    'database_uuid': '0123456789abcdef0123456789abcdef', 'app_version': '3.2.0', 'created_at': '2026-10-05T00:00:00Z',
    'tables': {
      'patients': [{'id': 19, 'first_name': 'Paciente', 'last_name': 'Ficticio'}],
      'consultations': [{'id': 3, 'patient_id': 19, 'illness': 'Texto original'}],
      'emergencies': [], 'hospitalizations': [{'id': 8, 'patient_id': 19}],
      'progress_notes': [{'id': 10, 'hospitalization_id': 8, 'assessment': 'Evolución original'}],
      'medical_orders': [], 'documents': [], 'appointments': [],
      'app_settings': [{'setting_key': 'nom_profile', 'setting_value': '{"doctor":"Médico ficticio","license":"PRUEBA"}'}],
      'clinical_attachments': [exchangeRow({'id': 5, 'patient_id': 19, 'data': data, 'sha256': hashing.sha256.convert(data).toString(), 'name': 'test.bin'})],
      'clinical_scales': [{'id': 6, 'patient_id': 19, 'score': 0, 'summary': 'Resultado original', 'payload': '{"answers":{"a":0}}'}],
    },
  };
}

// Independent producer reproduces the Android createExchange contract.
Future<Map<String, dynamic>> encrypted(Map<String, dynamic> snapshot) async {
  final salt = List<int>.generate(16, (i) => i);
  final key = await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 150000, bits: 256).deriveKey(secretKey: SecretKey(utf8.encode('contraseña prueba')), nonce: salt);
  final box = await AesGcm.with256bits().encrypt(utf8.encode(jsonEncode(snapshot)), secretKey: key);
  return {'format': 'angel-medical-encrypted-exchange', 'v': 1, 'salt': base64Encode(salt), 'nonce': base64Encode(box.nonce), 'mac': base64Encode(box.mac.bytes), 'data': base64Encode(box.cipherText)};
}

void main() {
  test('Signed PDF extraction retains exact bytes and rejects modified payload', () {
    final pdf = Uint8List.fromList([37, 80, 68, 70, 45, 49, 10, 0, 255]);
    final payload = {'format': 'angel-medical-signed-pdf-v1', 'pdf': base64Encode(pdf), 'pdf_sha256': hashing.sha256.convert(pdf).toString()};
    expect(originalSignedPdf(Uint8List.fromList(utf8.encode(jsonEncode(payload)))), pdf);
    payload['pdf'] = base64Encode([37, 80, 68, 70, 0]);
    expect(() => originalSignedPdf(Uint8List.fromList(utf8.encode(jsonEncode(payload)))), throwsFormatException);
  });
  test('Android encrypted exchange preserves identity, profile, relations, zero scores and binary bytes', () async {
    final envelope = await encrypted(fixture());
    final result = await readClinicalExchange(jsonEncode(envelope), 'contraseña prueba');
    expect(result.rows('patients').single['id'], 19);
    expect(result.profile['doctor'], 'Médico ficticio');
    expect(result.patientRows('progress_notes', 19).single['assessment'], 'Evolución original');
    expect(result.rows('clinical_scales').single['score'], 0);
    expect(result.rows('clinical_attachments').single['data'], [0, 1, 2, 128, 255]);
    expect(() => result.rows('patients').clear(), throwsUnsupportedError);
  });
  test('Incorrect password and changed ciphertext rejected before interpretation', () async {
    final envelope = await encrypted(fixture());
    await expectLater(readClinicalExchange(jsonEncode(envelope), 'incorrecta'), throwsFormatException);
    final bytes = base64Decode(envelope['data']); bytes[0] ^= 1; envelope['data'] = base64Encode(bytes);
    await expectLater(readClinicalExchange(jsonEncode(envelope), 'contraseña prueba'), throwsFormatException);
  });
  test('Unsupported versions, missing tables, duplicate IDs and orphan records rejected', () {
    final future = fixture()..['schema_version'] = 8;
    expect(() => ClinicalSnapshot.parse(jsonEncode(future)), throwsFormatException);
    final missing = fixture(); (missing['tables'] as Map).remove('documents');
    expect(() => ClinicalSnapshot.parse(jsonEncode(missing)), throwsFormatException);
    final duplicate = fixture(); duplicate['tables']['patients'].add({'id': 19});
    expect(() => ClinicalSnapshot.parse(jsonEncode(duplicate)), throwsFormatException);
    final orphan = fixture(); orphan['tables']['progress_notes'][0]['hospitalization_id'] = 99;
    expect(() => ClinicalSnapshot.parse(jsonEncode(orphan)), throwsFormatException);
    final orphanPatient = fixture(); orphanPatient['tables']['consultations'][0]['patient_id'] = 99;
    expect(() => ClinicalSnapshot.parse(jsonEncode(orphanPatient)), throwsFormatException);
  });
  test('Attachment alteration detected even in a successfully decrypted snapshot', () {
    final changed = fixture(); changed['tables']['clinical_attachments'][0]['data'] = {r'$binary': base64Encode([9])};
    expect(() => ClinicalSnapshot.parse(jsonEncode(changed)), throwsFormatException);
  });
}
