import 'dart:io';
import 'dart:typed_data';

import '../lib/clinical_certificate.dart';
import '../lib/clinical_birthdate.dart';

void require(bool ok) {
  if (!ok) throw StateError('Validation failed');
}

final certificateDateCases = <String, void Function()>{
  'Lee certificado de prueba sin afirmar confianza SAT': () {
    final cert = readCertificate(
      File('test/fixtures/certificate_test.cer').readAsBytesSync(),
    );
    require(
      cert.name == 'Medico Ficticio de Prueba' && cert.rfc == 'AAAA900101AB1',
    );
    require(cert.validAt(cert.notBefore) && cert.validAt(cert.notAfter));
    require(!cert.validAt(cert.notAfter.add(const Duration(seconds: 1))));
  },
  'Rechaza clave privada, basura y archivo truncado': () {
    final fixture = File('test/fixtures/certificate_test.cer')
        .readAsBytesSync();
    for (final bytes in [
      Uint8List(0),
      Uint8List.fromList([48, 130, 255, 255]),
      Uint8List.fromList(fixture.take(40).toList()),
      Uint8List.fromList(
        '-----BEGIN PRIVATE KEY-----\nAAAA\n-----END PRIVATE KEY-----'
            .codeUnits,
      ),
    ]) {
      var failed = false;
      try {
        readCertificate(bytes);
      } on FormatException {
        failed = true;
      }
      require(failed);
    }
  },
  'Fecha local y ISO conservan el mismo dia sin desbordamientos': () {
    final now = DateTime(2026, 9, 30);
    final d = parseBirthDate('13/07/1994', now: now)!;
    require(
      birthDateIso(d) == '1994-07-13' && birthDateDisplay(d) == '13/07/1994',
    );
    require(parseBirthDate('1994-07-13', now: now) == d);
    for (final text in [
      '31/02/2000',
      '29/02/2001',
      '01/10/2026',
      '99/12/1994',
      '13/07/1849',
    ]) {
      require(parseBirthDate(text, now: now) == null);
    }
    require(parseBirthDate('29/02/2000', now: now) != null);
  },
};
void main() {
  for (final c in certificateDateCases.entries) {
    c.value();
    print('PASS: ${c.key}');
  }
}
