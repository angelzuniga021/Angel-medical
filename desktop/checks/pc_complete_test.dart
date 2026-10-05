import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart' show sha256;
import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/pc_database.dart';
import '../lib/pc_signature.dart';
import '../lib/db.dart';
import '../lib/services.dart';
import '../lib/clinical_pdf_signature.dart';
import '../lib/clinical_prescription_pdf.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Independent PC: encrypted persistent CRUD, current ambak validation and reversible handoff', () async {
    FlutterSecureStorage.setMockInitialValues({'db_key_v2': 'fictitious-PC-database-key'});
    final app = AppDb.instance;
    final date = DateTime.now().toIso8601String();
    final id = await app.insert('patients', {'first_name': 'Paciente', 'last_name': 'Ficticio', 'dob': '2000-01-01', 'created_at': date, 'updated_at': date});
    final consultation = await app.insert('consultations', {'patient_id': id, 'date': date, 'reason': 'Consulta ficticia original', 'created_at': date});
    final bytes = Uint8List.fromList([0, 128, 255, 3]);
    await app.insert('clinical_attachments', {'patient_id': id, 'name': 'Original.bin', 'mime': 'application/octet-stream', 'data': bytes, 'sha256': sha256.convert(bytes).toString(), 'created_at': date});
    await app.insert('clinical_scales', {'patient_id': id, 'scale_id': 'pain', 'scale_name': 'Dolor', 'scale_version': '1.0', 'date': date, 'score': 0, 'unit': 'puntos', 'summary': 'Resultado original cero', 'payload': '{}', 'created_at': date});
    await app.setSetting('nom_profile', '{"doctor":"Medico Ficticio","license":"PRUEBA","logo_base64":"AA=="}');
    await app.close(); await app.reopen();
    var db = await app.database;
    expect((await db.query('consultations')).single['reason'], 'Consulta ficticia original');
    expect((await db.rawQuery('PRAGMA cipher_version')).single.values.first, startsWith('4.'));
    final path = await app.path;
    expect(utf8.decode((await File(path).readAsBytes()).sublist(0, 16), allowMalformed: true), isNot('SQLite format 3\u0000'));
    await expectLater(openDatabase(path, password: 'incorrect-key', singleInstance: false), throwsA(anything));
    final file = await BackupService.createPortable('prueba-ambak-password');
    final envelope = jsonDecode(await file.readAsString());
    final key = await Pbkdf2(macAlgorithm: Hmac.sha256(), iterations: 150000, bits: 256).deriveKey(secretKey: SecretKey(utf8.encode('prueba-ambak-password')), nonce: base64Decode(envelope['salt']));
    final clear = await AesGcm.with256bits().decrypt(SecretBox(base64Decode(envelope['data']), nonce: base64Decode(envelope['nonce']), mac: Mac(base64Decode(envelope['mac']))), secretKey: key);
    final payload = Map<String, dynamic>.from(jsonDecode(utf8.decode(clear)));
    final counts = await BackupService.validatePayload(payload);
    expect(counts['patients'], 1); expect(counts['clinical_scales'], 1); expect(counts['clinical_attachments'], 1);
    // Restore the exact encrypted backup into an isolated DB; verify every
    // original byte and edit there, without replacing production implicitly.
    final copy = File('$path.roundtrip')..writeAsBytesSync(base64Decode(payload['db']));
    final restored = await openDatabase(copy.path, password: payload['dbKey'], version: 7, singleInstance: false);
    expect((await restored.query('clinical_attachments')).single['data'], bytes);
    expect((await restored.query('clinical_scales')).single['score'], 0);
    expect((await restored.query('app_settings', where: 'setting_key=?', whereArgs: ['nom_profile'])).single['setting_value'], contains('logo_base64'));
    await restored.update('consultations', {'reason': 'Consulta modificada desde PC'}, where: 'id=?', whereArgs: [consultation]);
    expect((await restored.query('consultations')).single['reason'], 'Consulta modificada desde PC');
    await restored.close();
    final future = Map<String, dynamic>.from(payload);
    final futureDb = await openDatabase(copy.path, password: payload['dbKey'], singleInstance: false);
    await futureDb.execute('PRAGMA user_version=8'); await futureDb.close();
    future['db'] = base64Encode(await copy.readAsBytes());
    await expectLater(BackupService.validatePayload(future), throwsFormatException);
    // Persist only the encrypted test fixture for independent SQLCipher checks.
    Directory('pc-fixture').createSync(); await file.copy('pc-fixture/compatible.ambak');
    db = await app.database;
    expect((await db.query('consultations')).single['reason'], 'Consulta ficticia original');
    await app.close();
  });

  test('Bundled OpenSSL signs encrypted PKCS8 and integrated PDF; rejects tampering and wrong password', () async {
    const channel = PcSignatureChannel();
    final dir = await Directory.systemTemp.createTemp('angel_test_cms_');
    try {
      final keyPath = '${dir.path}/key.pem', certPath = '${dir.path}/cert.pem';
      expect(await channel.run(['req', '-x509', '-newkey', 'rsa:2048', '-nodes', '-keyout', keyPath, '-out', certPath, '-days', '2', '-subj', '/CN=Medico Ficticio']), 0);
      expect(await channel.run(['x509', '-in', certPath, '-outform', 'DER', '-out', '${dir.path}/cert.der']), 0);
      expect(await channel.run(['pkcs8', '-topk8', '-in', keyPath, '-outform', 'DER', '-out', '${dir.path}/key.der', '-v1', 'PBE-SHA1-3DES', '-passout', 'stdin', '-provider', 'default', '-provider', 'legacy'], password: 'prueba-clave'), 0);
      final cert = Uint8List.fromList(await File('${dir.path}/cert.der').readAsBytes());
      final encryptedKey = Uint8List.fromList(await File('${dir.path}/key.der').readAsBytes());
      Future<Uint8List> sign(Uint8List data) async {
        final result = await channel.invokeMethod<Map>('sign', {'data': data, 'certificate': cert, 'key': encryptedKey, 'password': 'prueba-clave'});
        expect(result!['valid'], true); return result['cms'] as Uint8List;
      }
      final pdf = await buildRecipePdf(patient: {'id': 1, 'first_name': 'Paciente', 'last_name': 'Ficticio'}, record: {'id': 1, 'type': 'Receta', 'date': DateTime.now().toIso8601String(), 'content': 'Documento de prueba'}, legacyProfile: {'doctor': 'Medico Ficticio', 'license': 'PRUEBA'}, certificate: cert, signerName: 'Medico Ficticio', signedAt: DateTime.now(), signer: sign);
      final parts = embeddedPdfParts(pdf);
      final result = await channel.invokeMethod<Map>('verify', {'data': parts.data, 'cms': parts.cms});
      expect(result!['certificate'], cert);
      final modified = Uint8List.fromList(parts.data); modified[0] ^= 1;
      await expectLater(channel.invokeMethod<Map>('verify', {'data': modified, 'cms': parts.cms}), throwsA(anything));
      await expectLater(channel.invokeMethod<Map>('sign', {'data': parts.data, 'certificate': cert, 'key': encryptedKey, 'password': 'incorrecta'}), throwsA(anything));
      Directory('pc-fixture').createSync(); await File('pc-fixture/signed.pdf').writeAsBytes(pdf);
    } finally { await dir.delete(recursive: true); }
  });
}
