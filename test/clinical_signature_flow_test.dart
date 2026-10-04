import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/clinical_signature_flow.dart';
import '../lib/clinical_signature_password.dart';

void main() {
  test('Cleanup errors do not hide committed success and all cleanup actions run', () async {
    final order = <int>[];
    Future<String> operation() async {
      try { return 'committed'; }
      finally { await signatureCleanup([() { order.add(1); throw StateError('cleanup'); }, () { order.add(2); }]); }
    }
    expect(await operation(), 'committed'); expect(order, [1, 2]);
  });
  test('Cleanup cannot replace the actual operation error', () async {
    Future<void> operation() async {
      try { throw const ClinicalSignatureFailure('Guardar', 'OPERATION_FAILED'); }
      finally { await signatureCleanup([() { throw StateError('cleanup'); }]); }
    }
    await expectLater(operation(), throwsA(isA<ClinicalSignatureFailure>().having((e) => e.stage, 'stage', 'Guardar')));
  });
  test('Diagnostics identify stage without exposing platform exception content', () async {
    await expectLater(signatureStage('Firmar PDF', () async { throw PlatformException(code: 'KEY_DECRYPT_FAILED', message: 'private content fixture'); }), throwsA(isA<ClinicalSignatureFailure>().having((e) => e.message, 'safe message', allOf(contains('Firmar PDF'), contains('KEY_DECRYPT_FAILED'), isNot(contains('private content'))))));
    await expectLater(signatureStage('Guardar', () async { throw StateError('patient data fixture'); }), throwsA(isA<ClinicalSignatureFailure>().having((e) => e.message, 'safe message', isNot(contains('patient data')))));
  });
  testWidgets('Password controller remains owned by its route across repeated submit/cancel', (tester) async {
    String? result;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (ctx) => TextButton(onPressed: () async { result = await showDialog<String>(context: ctx, builder: (_) => const ClinicalSignaturePassword()); }, child: const Text('Abrir'))))));
    for (final cancel in [false, true, false]) {
      await tester.tap(find.text('Abrir')); await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'fictional-password');
      await tester.tap(find.text(cancel ? 'Cancelar' : 'Firmar')); await tester.pumpAndSettle();
      expect(result, cancel ? isNull : 'fictional-password');
      expect(tester.takeException(), isNull);
    }
  });
}
