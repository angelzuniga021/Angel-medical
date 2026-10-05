import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:flutter/services.dart';

/// OpenSSL is bundled. Passwords use stdin, never command-line arguments.
/// Only the encrypted PKCS#8 key is placed in a short-lived directory.
class PcSignatureChannel {
  const PcSignatureChannel();
  String get executable => Platform.environment['ANGEL_OPENSSL_EXE'] ?? p.join(p.dirname(Platform.resolvedExecutable), 'openssl.exe');
  Future<int> run(List<String> args, {String? password}) async {
    final process = await Process.start(executable, args, environment: {'OPENSSL_MODULES': p.dirname(executable)}, includeParentEnvironment: true);
    final output = process.stdout.drain<void>(), errors = process.stderr.drain<void>();
    if (password != null) process.stdin.writeln(password);
    await process.stdin.close();
    final code = await process.exitCode;
    await Future.wait([output, errors]);
    return code;
  }
  Future<T?> invokeMethod<T>(String method, Map<String, dynamic> args) async {
    final dir = await Directory.systemTemp.createTemp('angel_cms_');
    try {
      final data = File(p.join(dir.path, 'document.bin'));
      final cms = File(p.join(dir.path, 'signature.der'));
      final cert = File(p.join(dir.path, 'certificate.pem'));
      await data.writeAsBytes(args['data'] as List<int>, flush: true);
      if (method == 'sign') {
        final password = args['password'] as String;
        if (password.contains('\n') || password.contains('\r')) throw PlatformException(code: 'PASSWORD_FORMAT');
        String pem(String type, List<int> bytes) {
          final encoded = base64Encode(bytes);
          return '-----BEGIN $type-----\n${RegExp('.{1,64}').allMatches(encoded).map((m) => m.group(0)).join('\n')}\n-----END $type-----\n';
        }
        final key = File(p.join(dir.path, 'encrypted_key.pem'));
        await key.writeAsString(pem('ENCRYPTED PRIVATE KEY', args['key'] as List<int>));
        await cert.writeAsString(pem('CERTIFICATE', args['certificate'] as List<int>));
        final code = await run(['cms', '-sign', '-binary', '-md', 'sha256', '-in', data.path, '-signer', cert.path, '-inkey', key.path, '-passin', 'stdin', '-outform', 'DER', '-out', cms.path, '-provider', 'default', '-provider', 'legacy'], password: password);
        if (code != 0) throw PlatformException(code: 'KEY_PASSWORD_OR_CERTIFICATE');
      } else if (method == 'verify') {
        await cms.writeAsBytes(args['cms'] as List<int>);
      } else { throw PlatformException(code: 'UNSUPPORTED_OPERATION'); }
      final signers = File(p.join(dir.path, 'signers.pem'));
      final code = await run(['cms', '-verify', '-binary', '-inform', 'DER', '-in', cms.path, '-content', data.path, '-noverify', '-out', p.join(dir.path, 'verified.bin'), '-signer', signers.path]);
      if (code != 0) throw PlatformException(code: 'CMS_INVALID');
      final content = await signers.readAsString();
      final certificates = RegExp(r'-----BEGIN CERTIFICATE-----([\s\S]*?)-----END CERTIFICATE-----').allMatches(content).toList();
      if (certificates.length != 1) throw PlatformException(code: 'AMBIGUOUS_SIGNER');
      final result = <String, dynamic>{'valid': true, 'certificate': base64Decode(certificates.single[1]!.replaceAll(RegExp(r'\s'), '')), 'cms': Uint8List.fromList(await cms.readAsBytes())};
      return result as T;
    } finally { if (await dir.exists()) await dir.delete(recursive: true); }
  }
}
