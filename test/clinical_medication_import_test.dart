import 'package:flutter_test/flutter_test.dart';
import '../lib/clinical_medication_import.dart';

void main() {
  test('Repeated catalogue import preserves existing favorites and skips repeated rows', () {
    final existing = <String, Object?>{'generic_name': 'Medicamento de prueba', 'brand_name': 'Marca A', 'strength': '10 mg', 'favorite': 1, 'use_count': 9};
    final repeated = <String, Object?>{'generic_name': ' MEDICAMENTO  DE PRUEBA ', 'brand_name': 'marca a', 'strength': '10 mg'};
    final newDose = {...repeated, 'strength': '20 mg'};
    final result = newMedicationRows([repeated, newDose, newDose], [existing]);
    expect(result, [newDose]);
    expect(existing['favorite'], 1); expect(existing['use_count'], 9);
    expect(newMedicationRows(result, [existing, newDose]), isEmpty);
  });
  test('Different presentations and registrations remain distinct', () {
    final base = <String, Object?>{'generic_name': 'Prueba', 'presentation': 'Caja 10', 'registration': 'TEST-A'};
    expect(newMedicationRows([base, {...base, 'presentation': 'Caja 20'}, {...base, 'registration': 'TEST-B'}], []), hasLength(3));
  });
}
