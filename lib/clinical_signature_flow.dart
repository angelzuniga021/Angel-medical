import 'dart:async';
import 'package:flutter/services.dart';

class ClinicalSignatureFailure implements Exception {
  final String stage, code;
  const ClinicalSignatureFailure(this.stage, this.code);
  String get message => 'No se completó la firma. Etapa: $stage. Código: $code. '
      'Las firmas anteriores se conservan. Comparte solamente este código para revisar el fallo.';
}

Future<T> signatureStage<T>(String stage, Future<T> Function() action) async {
  try { return await action(); }
  on FormatException { rethrow; }
  on ClinicalSignatureFailure { rethrow; }
  on PlatformException catch (e) {
    const safe = {'KEY_READ_FAILED', 'KEY_DECRYPT_FAILED', 'CERT_INVALID', 'CERT_EXPIRED', 'CERT_NOT_YET_VALID', 'CERT_KEY_MISMATCH', 'SIGNATURE_FAILED'};
    throw ClinicalSignatureFailure(stage, safe.contains(e.code) ? e.code : 'PLATFORM_FAILURE');
  } catch (_) { throw ClinicalSignatureFailure(stage, 'OPERATION_FAILED'); }
}

/// Cleanup cannot turn a committed signature into a reported signing failure.
Future<void> signatureCleanup(List<FutureOr<void> Function()> actions) async {
  for (final action in actions) { try { await action(); } catch (_) { } }
}
