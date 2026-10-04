import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/clinical_patient_design.dart';
import '../lib/clinical_note_review.dart';
import '../lib/clinical_theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Patient summary and timeline are readable on narrow large-text screen ($brightness)', (tester) async {
      tester.view.physicalSize = const Size(320, 700); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      const patient = <String, Object?>{'first_name': 'Paciente de prueba', 'last_name': 'Apellido largo ficticio', 'allergies': 'Alergia documentada de prueba', 'chronic_meds': 'Medicación de prueba', 'personal_history': 'Antecedente documentado'};
      const event = <String, Object?>{'table': 'consultations', 'type': 'Consulta', 'date': '2026-10-04T09:00:00', 'text': 'Valoración de prueba'};
      await tester.pumpWidget(MaterialApp(theme: clinicalTheme(brightness), builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(textScaler: const TextScaler.linear(1.5)), child: child!), home: Scaffold(body: ListView(children: const [ClinicalPatientBanner(patient: patient, events: 1, drafts: 0), ClinicalPatientOverview(patient: patient, lastAssessment: event), ClinicalTimelineTile(event: event)]))));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Medicación habitual'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Medicación de prueba'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Registro guardado · Sin firma electrónica'), 200, scrollable: find.byType(Scrollable).first);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('Review can return to editing without finalizing and states signature limitation', (tester) async {
    bool? approved;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Builder(builder: (ctx) => TextButton(onPressed: () async { approved = await showDialog<bool>(context: ctx, builder: (_) => const ClinicalNoteReview(patientName: 'Paciente ficticio', input: {'diagnoses': 'Diagnóstico registrado'})); }, child: const Text('Revisar'))))));
    await tester.tap(find.text('Revisar')); await tester.pumpAndSettle();
    expect(find.text('Diagnóstico registrado'), findsOneWidget);
    expect(find.textContaining('No aplica una firma electrónica'), findsOneWidget);
    await tester.tap(find.text('Seguir editando')); await tester.pumpAndSettle();
    expect(approved, false); expect(tester.takeException(), isNull);
  });
}
