import 'package:flutter_test/flutter_test.dart';
import 'package:angel_medical_mobile/clinical_record.dart';

void main() {
  test('Valoracion completa conserva texto y signos en cero', () {
    final longText = List.filled(800, 'Exploracion detallada.').join(' ');
    final fields = Map.fromEntries(
      clinicalFields({
        'illness': 'Inicio ayer',
        'physical_exam': longText,
        'diagnoses': 'Diagnostico',
        'treatment': 'Tratamiento',
        'studies': 'Estudios solicitados',
        'plan': 'Revision',
        'pain': 0,
        'id': 23,
        'patient_id': 5,
        'glucose': null,
      }),
    );
    expect(fields['Exploración física'], longText);
    expect(fields['Padecimiento actual'], 'Inicio ayer');
    expect(fields['Tratamiento'], 'Tratamiento');
    expect(fields['Dolor (EVA)'], '0');
    expect(fields.containsKey('patient_id'), false);
    expect(fields.containsKey('Glucosa (mg/dL)'), false);
  });
  test('Busqueda encuentra contenido oculto y omite acentos', () {
    final event = <String, Object?>{
      'type': 'Consulta',
      'date': '2026-09-24',
      'text': 'Control',
      'search': 'Exploración sin dolor. Tratamiento previo.',
    };
    expect(matchesClinical(event, 'exploracion previo'), true);
    expect(matchesClinical(event, '  '), true);
    expect(matchesClinical(event, 'fractura'), false);
    expect(matchesClinical(event, '2026-09-24'), true);
  });
  test('Incluye SOAP, indicaciones, documentos y egreso', () {
    final fields = Map.fromEntries(
      clinicalFields({
        'subjective': 'S',
        'objective': 'O',
        'assessment': 'A',
        'plan': 'P',
        'diet': 'D',
        'fluids': 'F',
        'medications': 'M',
        'nursing': 'N',
        'content': 'Receta completa',
        'discharge_summary': 'Resumen',
        'discharge_recommendations': 'Seguimiento',
      }),
    );
    expect(fields.length, 12);
    expect(fields['Documentación'], contains('Registro previo'));
    expect(fields['Contenido'], 'Receta completa');
    expect(fields['Resumen de egreso'], 'Resumen');
  });
}
