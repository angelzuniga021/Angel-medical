import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:angel_medical_mobile/clinical_record_view.dart';
import 'package:angel_medical_mobile/clinical_theme.dart';

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('Nota completa visible en $brightness', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: clinicalTheme(brightness),
          home: const ClinicalRecordView(
            patient: {'first_name': 'Paciente', 'last_name': 'Prueba'},
            title: 'Consulta',
            record: {
              'reason': 'Control de seguimiento',
              'illness': 'Historia completa',
              'physical_exam': 'Exploracion detallada',
              'plan': 'PLAN FINAL VISIBLE',
            },
          ),
        ),
      );
      expect(find.text('Paciente Prueba'), findsOneWidget);
      expect(find.text('Historia completa'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('PLAN FINAL VISIBLE'),
        150,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('PLAN FINAL VISIBLE'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
