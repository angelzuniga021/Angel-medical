import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/main.dart';
import '../lib/clinical_exchange_reader.dart';

void main() {
  testWidgets('Patient search and consultation retain original clinical text', (tester) async {
    tester.view.physicalSize = const Size(1280, 900); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    final snapshot = ClinicalSnapshot.parse(jsonEncode({
      'format': 'angel-medical-logical-snapshot', 'version': 1, 'schema_version': 7,
      'database_uuid': '0123456789abcdef0123456789abcdef', 'app_version': '3.2.0', 'created_at': '2026-10-05T00:00:00Z',
      'tables': {
        'patients': [{'id': 19, 'first_name': 'Paciente', 'last_name': 'Ficticio'}],
        'consultations': [{'id': 3, 'patient_id': 19, 'illness': 'Valoración original completa', 'date': '2026-10-05'}],
        'emergencies': [], 'hospitalizations': [], 'progress_notes': [], 'medical_orders': [], 'documents': [],
        'appointments': [], 'app_settings': [], 'clinical_attachments': [], 'clinical_scales': [],
      },
    }));
    await tester.pumpWidget(MaterialApp(home: DesktopHome(initialSnapshot: snapshot)));
    await tester.enterText(find.byType(TextField), 'Ficticio'); await tester.pump();
    await tester.tap(find.text('Paciente Ficticio').first); await tester.pump();
    await tester.tap(find.byType(DropdownButtonFormField<String>)); await tester.pumpAndSettle();
    await tester.tap(find.text('Consultas').last); await tester.pumpAndSettle();
    expect(find.text('Valoración original completa'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Cerrar expediente')); await tester.pump();
    expect(find.text('Valoración original completa'), findsNothing);
    expect(find.text('Abrir expediente cifrado'), findsOneWidget);
  });
  testWidgets('Desktop explains encryption and read-only scope', (tester) async {
    await tester.pumpWidget(const AngelPc());
    expect(find.text('Abrir expediente cifrado'), findsOneWidget);
    expect(find.textContaining('No se guarda una copia descifrada'), findsOneWidget);
    expect(find.text('Ángel Medical PC · 0.1 · Consulta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Opening page works at narrow width and enlarged text', (tester) async {
    tester.view.physicalSize = const Size(680, 900); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(textScaler: const TextScaler.linear(1.3)), child: child!), home: const DesktopHome()));
    expect(tester.takeException(), isNull);
  });
}
