import 'package:flutter_test/flutter_test.dart';
import 'package:angel_medical_mobile/clinical_store.dart';

void main() {
  test('Calcula IMC y admite decimales con coma', () {
    final data = parseClinicalInput('consultations', {
      'weight': '80,5',
      'height': '175',
      'spo2': '98',
    });
    expect(data['weight'], 80.5);
    expect(data['bmi'], closeTo(80.5 / (1.75 * 1.75), .00001));
  });
  test('No interpreta entradas incorrectas como signo ausente', () {
    for (final value in ['abc', 'NaN', 'Infinity', '-1']) {
      expect(
        () => parseClinicalInput('consultations', {'weight': value}),
        throwsFormatException,
      );
    }
    expect(
      () => parseClinicalInput('consultations', {'spo2': '101'}),
      throwsFormatException,
    );
    expect(
      () => parseClinicalInput('emergencies', {'pain': '11'}),
      throwsFormatException,
    );
    expect(
      () => parseClinicalInput('emergencies', {'glasgow': '14.5'}),
      throwsFormatException,
    );
  });
  test(
    'No copia identificadores ni cambia paciente o fecha desde formulario',
    () {
      final data = parseClinicalInput('consultations', {
        'patient_id': '999',
        'date': '2000-01-01',
        'reason': 'Control',
      });
      expect(data.containsKey('patient_id'), false);
      expect(data.containsKey('date'), false);
      expect(data['systolic'], null);
      expect(data['reason'], 'Control');
    },
  );
}
