import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/clinical_body_data.dart';
import '../lib/clinical_body_map.dart';
import '../lib/clinical_signature_data.dart';
import '../lib/clinical_exchange_data.dart';

void main() {
  test('Body map preserves unspecified severity and patient laterality', () {
    final raw = jsonEncode({'schema': 1, 'points': [
      {'region': 'right_arm', 'view': 'front', 'severity': null, 'notes': 'Irradia a mano'},
      {'region': 'right_arm', 'view': 'back', 'severity': 0, 'notes': ''},
    ]});
    expect(parseBodyMap(raw)['points'][0]['severity'], isNull);
    expect(describeBodyMap(raw), contains('Brazo derecho · vista anterior · intensidad sin registro'));
    expect(describeBodyMap(raw), contains('intensidad 0/10'));
    expect(bodyPositions(false)['right_arm']!.dx, lessThan(.5));
    expect(bodyPositions(true)['right_arm']!.dx, greaterThan(.5));
    expect(parseBodyMap('')['points'], isEmpty);
  });
  test('Malformed body maps cannot bypass editor validation', () {
    final point = {'region': 'right_arm', 'view': 'front', 'severity': 4, 'notes': ''};
    for (final points in [
      [point, point], [{...point, 'severity': 11}], [{...point, 'severity': 1.5}],
      [{...point, 'view': 'unknown'}], [{...point, 'region': 'unknown'}],
      [{...point, 'notes': List.filled(2001, 'a').join()}],
    ]) { expect(() => parseBodyMap(jsonEncode({'schema': 1, 'points': points})), throwsFormatException); }
  });
  test('Canonical hash changes with a correction and ignores map key ordering', () {
    final a = <String, Object?>{'id': 9, 'date': '2026-10-04', 'nom_json': '{"author":"original"}'};
    final reordered = <String, Object?>{'nom_json': a['nom_json'], 'date': a['date'], 'id': 9};
    expect(clinicalRecordHash(a), clinicalRecordHash(reordered));
    expect(clinicalRecordHash({...a, 'nom_json': '{"author":"correction"}'}), isNot(clinicalRecordHash(a)));
    expect(signatureBoundFields, containsAll(['record_sha256', 'pdf_sha256', 'record_id', 'patient_id', 'signed_at_device']));
  });
  test('Portable exchange preserves attachment bytes, identity and nulls', () {
    final bytes = Uint8List.fromList([0, 255, 10, 128]);
    final row = exchangeRow({'id': 7, 'data': bytes, 'missing': null, 'name': 'Paciente ficticio'});
    final roundtrip = jsonDecode(jsonEncode(row)) as Map;
    expect(base64Decode(roundtrip['data'][r'$binary'] as String), bytes);
    expect(roundtrip['id'], 7); expect(roundtrip['missing'], isNull);
    expect(roundtrip['name'], 'Paciente ficticio');
  });
  testWidgets('Narrow large-text body map stores region without inventing intensity', (tester) async {
    tester.view.physicalSize = const Size(320, 700); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    String? saved;
    await tester.pumpWidget(MaterialApp(builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(textScaler: const TextScaler.linear(1.5)), child: child!), home: Scaffold(body: Builder(builder: (ctx) => TextButton(onPressed: () async { saved = await Navigator.push<String>(ctx, MaterialPageRoute(builder: (_) => const ClinicalBodyMap())); }, child: const Text('Abrir'))))));
    await tester.tap(find.text('Abrir')); await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Brazo derecho'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Brazo derecho')); await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Usar este mapa en la nota'), 250, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Usar este mapa en la nota')); await tester.pumpAndSettle();
    final point = parseBodyMap(saved!)['points'].single;
    expect(point['region'], 'right_arm'); expect(point['view'], 'front'); expect(point['severity'], isNull);
    expect(tester.takeException(), isNull);
  });
}
