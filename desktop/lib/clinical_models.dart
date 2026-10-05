const noteFields = <String, List<String>>{
  'consultations': [
    'reason',
    'illness',
    'physical_exam',
    'diagnoses',
    'treatment',
    'studies',
    'plan',
    'systolic',
    'diastolic',
    'heart_rate',
    'respiratory_rate',
    'temperature',
    'spo2',
    'weight',
    'height',
    'glucose',
  ],
  'emergencies': [
    'reason',
    'brief_history',
    'physical_exam',
    'diagnoses',
    'treatment',
    'studies',
    'evolution',
    'disposition',
    'disposition_notes',
    'triage',
    'pain',
    'glasgow',
    'systolic',
    'diastolic',
    'heart_rate',
    'respiratory_rate',
    'temperature',
    'spo2',
    'glucose',
  ],
  'hospitalizations': [
    'room',
    'bed',
    'reason',
    'diagnoses',
    'exam',
    'plan',
    'discharge_diagnoses',
    'discharge_summary',
    'discharge_treatment',
    'discharge_recommendations',
  ],
  'progress_notes': [
    'subjective',
    'objective',
    'assessment',
    'plan',
    'systolic',
    'diastolic',
    'heart_rate',
    'respiratory_rate',
    'temperature',
    'spo2',
    'glucose',
  ],
  'medical_orders': [
    'diet',
    'activity',
    'fluids',
    'oxygen',
    'medications',
    'monitoring',
    'studies',
    'nursing',
    'other',
  ],
  'documents': ['type', 'title', 'content'],
};
const numericFields = {
  'systolic',
  'diastolic',
  'heart_rate',
  'respiratory_rate',
  'temperature',
  'spo2',
  'weight',
  'height',
  'glucose',
  'pain',
  'glasgow',
};
const noteNames = {
  'consultations': 'Consulta',
  'emergencies': 'Urgencias',
  'hospitalizations': 'Hospitalización',
  'progress_notes': 'Evolución SOAP',
  'medical_orders': 'Indicaciones',
  'documents': 'Documento',
};

Map<String, Object?> parseClinicalInput(
  String table,
  Map<String, String> input,
) {
  final out = <String, Object?>{};
  for (final key in noteFields[table] ?? <String>[]) {
    final value = (input[key] ?? '').trim();
    if (!numericFields.contains(key)) {
      out[key] = value;
      continue;
    }
    if (value.isEmpty) {
      out[key] = null;
      continue;
    }
    final number = double.tryParse(value.replaceAll(',', '.'));
    if (number == null || !number.isFinite || number < 0)
      throw FormatException('Revisa el campo $key');
    if (key == 'spo2' && number > 100)
      throw const FormatException('SpO₂ debe estar entre 0 y 100');
    if (key == 'pain' && number > 10)
      throw const FormatException('EVA debe estar entre 0 y 10');
    if (key == 'glasgow' &&
        (number < 3 || number > 15 || number != number.roundToDouble()))
      throw const FormatException('Glasgow debe ser un entero entre 3 y 15');
    if ((key == 'height' || key == 'weight') && number == 0)
      throw const FormatException('Peso y talla deben ser mayores de cero');
    out[key] = number;
  }
  if (table == 'consultations') {
    final w = out['weight'] as double?;
    final h = out['height'] as double?;
    out['bmi'] = w != null && h != null && h > 0
        ? w / ((h / 100) * (h / 100))
        : null;
  }
  return out;
}
