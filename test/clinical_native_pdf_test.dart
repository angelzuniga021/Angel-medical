import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:angel_medical_mobile/clinical_pdf_signature.dart';

void main() {
  test('real Android CMS integrates in PDF and verifies independently', () async {
    final dir = Directory('recipe-fixture');
    final prepared = File('${dir.path}/prepared.pdf').readAsBytesSync();
    final cms = File('${dir.path}/native-cms.der').readAsBytesSync();
    expect(cms[1], isNot(0x80));
    final pdf = completeEmbeddedPdf(prepared, cms);
    final parts = embeddedPdfParts(pdf);
    expect(parts.data, File('${dir.path}/prepared-data.bin').readAsBytesSync());
    File('${dir.path}/native-signed.pdf').writeAsBytesSync(pdf);
    File('${dir.path}/native-extracted.p7s').writeAsBytesSync(parts.cms);
    File('${dir.path}/native-extracted-data.bin').writeAsBytesSync(parts.data);
    Future<ProcessResult> verify() => Process.run('openssl', ['cms','-verify','-binary','-inform','DER','-in','${dir.path}/native-extracted.p7s','-content','${dir.path}/native-extracted-data.bin','-noverify','-out','${dir.path}/native-verified.bin']);
    var result = await verify();
    expect(result.exitCode, 0, reason: '${result.stderr}');
    final altered = Uint8List.fromList(parts.data); altered[10] ^= 1;
    File('${dir.path}/native-extracted-data.bin').writeAsBytesSync(altered);
    result = await verify(); expect(result.exitCode, isNot(0));
  }, skip: !const bool.fromEnvironment('NATIVE_PDF_FIXTURE'));
}
