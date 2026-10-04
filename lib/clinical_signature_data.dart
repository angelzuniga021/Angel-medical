import 'dart:convert';
import 'package:crypto/crypto.dart';

Object? canonicalValue(Object? value) {
  if (value is Map) {
    final keys = value.keys.map((k) => '$k').toList()..sort();
    return {for (final k in keys) k: canonicalValue(value[k])};
  }
  if (value is List) return value.map(canonicalValue).toList();
  return value;
}
String clinicalRecordHash(Map<String, Object?> record) => sha256.convert(utf8.encode(jsonEncode(canonicalValue(record)))).toString();
const signedNoteMime = 'application/vnd.angel-medical.signed-note+json';

const signatureBoundFields = ['format', 'table', 'record_id', 'patient_id', 'record_sha256', 'pdf_sha256', 'signed_at_device', 'signer_name', 'signer_rfc', 'certificate_serial', 'trust_verified', 'revocation_verified', 'trusted_timestamp'];
