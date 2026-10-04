import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/clinical_certificate.dart';

void main() {
  test('Public DER certificate dates preserve bounds and reject expiry', () {
    final cert = readCertificate(File('test/fixtures/certificate_test.cer').readAsBytesSync());
    expect(cert.name, 'Medico Ficticio de Prueba');
    expect(cert.rfc, 'AAAA900101AB1');
    expect(cert.validAt(cert.notBefore), isTrue);
    expect(cert.validAt(cert.notAfter), isTrue);
    expect(cert.validAt(cert.notBefore.subtract(const Duration(seconds: 1))), isFalse);
    expect(cert.validAt(cert.notAfter.add(const Duration(seconds: 1))), isFalse);
    expect(certificateDateStatus(cert.notBefore, cert.notAfter, cert.notAfter.add(const Duration(seconds: 1))), 'Certificado vencido');
  });
  test('Validity diagnosis distinguishes future validity, expiry and exact endpoints', () {
    final start = DateTime.utc(2026, 10, 4, 12), end = DateTime.utc(2030, 10, 4, 12);
    expect(certificateDateStatus(start, end, start.subtract(const Duration(seconds: 1))), 'La vigencia aún no inicia');
    expect(certificateDateStatus(start, end, start), 'Dentro del periodo de vigencia');
    expect(certificateDateStatus(start, end, end), 'Dentro del periodo de vigencia');
    expect(certificateDateStatus(start, end, end.add(const Duration(seconds: 1))), 'Certificado vencido');
    final equivalent = DateTime.parse('2026-10-04T07:00:00-05:00');
    expect(certificateDateStatus(start, end, equivalent), 'Dentro del periodo de vigencia');
    expect(certificateDateDisplay(equivalent), '04/10/2026 12:00:00 UTC');
    final details = certificateValidityDetails(start, end, equivalent);
    expect(details, contains('Inicio:')); expect(details, contains('Vencimiento:'));
    expect(details, contains('Reloj del teléfono:')); expect(details, contains('No cambies la fecha'));
  });
}
