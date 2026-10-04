import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:cross_file/cross_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'clinical_certificate.dart';
import 'clinical_signature_flow.dart';
import 'clinical_signature_password.dart';
import 'clinical_nom.dart';
import 'clinical_record.dart';
import 'clinical_signature_data.dart';
import 'clinical_store.dart';
import 'clinical_ui.dart';
import 'db.dart';
import 'services.dart';

const signatureChannel = MethodChannel('angel_medical/signature');

class ClinicalSignatureService {
  static Future<void> showCertificate(BuildContext context, CertificateProfile certificate, DateTime now) async {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Vigencia del certificado seleccionado'),
      scrollable: true,
      content: SelectableText('Titular: ${certificate.name}\nRFC: ${certificate.rfc}\n\n${certificateValidityDetails(certificate.notBefore, certificate.notAfter, now)}'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar'))],
    ));
  }
  static Future<void> inspectCertificate(BuildContext context) async {
    try {
      final certificate = await pick('cer');
      if (certificate == null || !context.mounted) return;
      final parsed = readCertificate(certificate);
      await showCertificate(context, parsed, DateTime.now());
    } finally {
      try { await FilePicker.platform.clearTemporaryFiles(); } catch (_) { }
    }
  }
  static Future<Uint8List?> pick(String extension) async {
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: [extension], withData: true);
    if (picked == null) return null;
    if (picked.files.single.size > 128 * 1024) throw const FormatException('Archivo demasiado grande (máximo 128 KB).');
    final bytes = picked.files.single.bytes ?? await File(picked.files.single.path!).readAsBytes();
    if (bytes.isEmpty) throw const FormatException('El archivo seleccionado está vacío o no pudo leerse. Selecciona el archivo original.');
    return Uint8List.fromList(bytes);
  }
  static Future<Map<String, dynamic>?> sign(BuildContext context, {required String table, required Map<String, Object?> patient, required Map<String, Object?> record, required String title}) async {
    Uint8List? key;
    String? password;
    var stage = 'Leer certificado';
    try {
      final certificate = await pick('cer'); if (certificate == null || !context.mounted) return null;
      final parsed = readCertificate(certificate);
      final profile = decodeNom(await AppDb.instance.getSetting('nom_profile'));
      final rfc = '${profile['rfc'] ?? ''}'.trim().toUpperCase();
      if (rfc.isEmpty || parsed.rfc.isEmpty || parsed.rfc.toUpperCase() != rfc) throw const FormatException('Registra tu RFC en el perfil y utiliza un certificado que corresponda a ese RFC.');
      final now = DateTime.now();
      if (!parsed.validAt(now)) {
        if (context.mounted) await showCertificate(context, parsed, now);
        return null;
      }
      if (!context.mounted) return null;
      final accepted = await clinicalConfirm(context, 'Firmar versión actual', 'Firmante: ${parsed.name}\nRFC: ${parsed.rfc}\n\nLa firma se realiza hoy sobre esta versión; no cambia la fecha ni el autor original de la atención. Se verificará integridad, correspondencia de la clave y fechas. La confianza de la cadena SAT, la revocación y el sello de tiempo confiable no se verifican. Seleccionarás la .key cifrada y su contraseña, que no se guardarán en el expediente.');
      if (!accepted || !context.mounted) return null;
      stage = 'Leer clave cifrada';
      key = await pick('key'); if (key == null || !context.mounted) return null;
      stage = 'Solicitar contraseña';
      password = await showDialog<String>(context: context, builder: (_) => const ClinicalSignaturePassword());
      if (password == null || !context.mounted) return null;
      stage = 'Generar PDF';
      final pdf = await PdfService.buildClinicalPdf(title: title, patient: patient, record: record, fields: clinicalFields(record), signatureCopy: true);
      stage = 'Firmar PDF';
      final result = await nativeSign(pdf, certificate, key, password!, stage);
      if (result['valid'] != true) throw const FormatException('La firma no pasó la verificación.');
      final cms = result['cms'] as Uint8List;
      final payload = <String, dynamic>{'format': 'angel-medical-signed-pdf-v1', 'table': table, 'record_id': record['id'], 'patient_id': patient['id'], 'record_sha256': clinicalRecordHash(record), 'pdf_sha256': sha256.convert(pdf).toString(), 'pdf': base64Encode(pdf), 'cms': base64Encode(cms), 'certificate': base64Encode(certificate), 'signed_at_device': DateTime.now().toUtc().toIso8601String(), 'signer_name': parsed.name, 'signer_rfc': parsed.rfc, 'certificate_serial': parsed.serial, 'trust_verified': false, 'revocation_verified': false, 'trusted_timestamp': false};
      final manifest = Uint8List.fromList(utf8.encode(jsonEncode(canonicalValue({
        for (final field in signatureBoundFields) field: payload[field],
      }))));
      stage = 'Firmar manifiesto';
      final manifestResult = await nativeSign(manifest, certificate, key, password!, stage);
      password = null;
      payload['manifest'] = base64Encode(manifest);
      payload['manifest_cms'] = base64Encode(manifestResult['cms'] as Uint8List);
      stage = 'Verificar PDF y manifiesto';
      await verify(payload);
      final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payload)));
      if (bytes.length > 8 * 1024 * 1024) throw const FormatException('El paquete excede 8 MB. No se guardó la firma.');
      stage = 'Guardar firma en el expediente';
      final db = await AppDb.instance.database;
      await db.transaction((tx) async {
        final fresh = await tx.query(table, where: 'id=?', whereArgs: [record['id']]);
        if (fresh.length != 1) throw const FormatException('Nota no encontrada.');
        await ClinicalStore.verifyOwner(tx, table, fresh.single, patient['id'] as int);
        if (clinicalRecordHash(fresh.single) != payload['record_sha256']) throw const FormatException('La nota cambió durante la firma. Revisa y vuelve a firmar.');
        final total = (await tx.rawQuery('SELECT COALESCE(SUM(LENGTH(data)),0) AS n FROM clinical_attachments')).first['n'] as int;
        if (total + bytes.length > 100 * 1024 * 1024) throw const FormatException('Límite de adjuntos alcanzado.');
        await tx.insert('clinical_attachments', {'patient_id': patient['id'], 'name': 'Firma_${table}_${record['id']}.amfirma', 'description': 'firma:$table:${record['id']}', 'mime': signedNoteMime, 'data': bytes, 'sha256': sha256.convert(bytes).toString(), 'created_at': payload['signed_at_device']});
        await tx.insert('audit', {'date': payload['signed_at_device'], 'action': 'SIGN_CLINICAL_PDF', 'detail': '$table:${record['id']} · ${payload['pdf_sha256']} · sin validación de confianza SAT'});
      });
      return payload;
    } on FormatException { rethrow; }
    on ClinicalSignatureFailure { rethrow; }
    catch (_) { throw ClinicalSignatureFailure(stage, 'OPERATION_FAILED'); }
    finally {
      password = null;
      await signatureCleanup([
        () { if (key != null) key!.fillRange(0, key!.length, 0); },
        () async { await FilePicker.platform.clearTemporaryFiles(); },
      ]);
    }
  }
  static Future<Map<String, dynamic>> nativeSign(Uint8List data, Uint8List certificate, Uint8List key, String password, String stage) async {
    final operationKey = Uint8List.fromList(key);
    try {
      return await signatureStage(stage, () async => Map<String, dynamic>.from((await signatureChannel.invokeMethod<Map>('sign', {'data': data, 'certificate': certificate, 'key': operationKey, 'password': password}))!));
    } finally { operationKey.fillRange(0, operationKey.length, 0); }
  }
  static Future<Map<String, dynamic>> verify(Map<String, dynamic> payload) async {
    final pdf = base64Decode('${payload['pdf']}'); final cms = base64Decode('${payload['cms']}');
    if (sha256.convert(pdf).toString() != payload['pdf_sha256']) throw const FormatException('PDF modificado.');
    final result = Map<String, dynamic>.from((await signatureChannel.invokeMethod<Map>('verify', {'data': pdf, 'cms': cms}))!);
    final manifest = base64Decode('${payload['manifest']}');
    final signedManifest = Map<String, dynamic>.from(jsonDecode(utf8.decode(manifest)) as Map);
    if (jsonEncode(canonicalValue(signedManifest)) != jsonEncode(canonicalValue({for (final field in signatureBoundFields) field: payload[field]}))) throw const FormatException('Metadatos de firma modificados.');
    final binding = Map<String, dynamic>.from((await signatureChannel.invokeMethod<Map>('verify', {'data': manifest, 'cms': base64Decode('${payload['manifest_cms']}')}))!);
    if (result['valid'] != true || binding['valid'] != true ||
        sha256.convert(result['certificate'] as Uint8List).toString() != sha256.convert(binding['certificate'] as Uint8List).toString()) throw const FormatException('Firma o vínculo del registro no válido.');
    return result;
  }
  static Future<void> export(Map<String, dynamic> payload) async {
    final result = await verify(payload);
    if (result['valid'] != true) throw const FormatException('Firma no válida para este PDF.');
    final archive = Archive();
    void add(String name, List<int> bytes) => archive.addFile(ArchiveFile(name, bytes.length, bytes));
    add('nota.pdf', base64Decode('${payload['pdf']}')); add('nota.pdf.p7s', base64Decode('${payload['cms']}'));
    add('certificado.cer', result['certificate'] as Uint8List);
    add('registro.amfirma', utf8.encode(jsonEncode(payload)));
    add('manifest.json', base64Decode('${payload['manifest']}')); add('manifest.json.p7s', base64Decode('${payload['manifest_cms']}'));
    add('LEEME.txt', utf8.encode('Firma CMS/PKCS#7 separada del PDF. Conservar ambos archivos.\nVerificación de integridad con OpenSSL:\nopenssl cms -verify -binary -inform DER -in nota.pdf.p7s -content nota.pdf -noverify -out /dev/null\n-noverify verifica la firma matemática, no la confianza SAT ni la revocación.\nLa fecha de la firma usa el reloj del dispositivo y no un sello de tiempo confiable.\nEl manifiesto firmado vincula la huella del PDF, la versión de la nota y la fecha declarada. Verificar también manifest.json con manifest.json.p7s.'));
    final directory = await Directory('${(await getTemporaryDirectory()).path}/angel_signature_${DateTime.now().microsecondsSinceEpoch}').create();
    final file = File('${directory.path}/Nota_firmada.zip'); await file.writeAsBytes(ZipEncoder().encode(archive)!, flush: true);
    try { await Share.shareXFiles([XFile(file.path)], text: 'PDF y firma separada. Confianza y revocación SAT pendientes de verificar.'); }
    finally { if (await directory.exists()) await directory.delete(recursive: true); }
  }
}
