import 'clinical_nom.dart';

// Read-only presentation helpers, including separately stored documentation.
const clinicalLabels = <String, String>{
  'date': 'Fecha y hora',
  'admitted_at': 'Ingreso',
  'discharged_at': 'Egreso',
  'status': 'Estado',
  'room': 'Habitación',
  'bed': 'Cama',
  'reason': 'Motivo de atención',
  'illness': 'Padecimiento actual',
  'brief_history': 'Historia clínica',
  'physical_exam': 'Exploración física',
  'exam': 'Exploración / condición',
  'subjective': 'Subjetivo',
  'objective': 'Objetivo',
  'assessment': 'Análisis',
  'diagnoses': 'Diagnósticos',
  'treatment': 'Tratamiento',
  'studies': 'Resultados de estudios',
  'plan': 'Plan',
  'evolution': 'Evolución',
  'triage': 'Triage',
  'pain': 'Dolor (EVA)',
  'glasgow': 'Glasgow',
  'systolic': 'Presión arterial sistólica (mmHg)',
  'diastolic': 'Presión arterial diastólica (mmHg)',
  'heart_rate': 'Frecuencia cardiaca (latidos/minuto)',
  'respiratory_rate': 'Frecuencia respiratoria (respiraciones/minuto)',
  'temperature': 'Temperatura (°C)',
  'spo2': 'Saturación periférica de oxígeno (%)',
  'glucose': 'Glucosa (mg/dL)',
  'weight': 'Peso (kg)',
  'height': 'Talla (cm)',
  'bmi': 'Índice de masa corporal',
  'disposition': 'Destino',
  'disposition_notes': 'Notas de destino',
  'discharge_diagnoses': 'Diagnósticos de egreso',
  'discharge_summary': 'Resumen de egreso',
  'discharge_treatment': 'Tratamiento al egreso',
  'discharge_recommendations': 'Recomendaciones de egreso',
  'diet': 'Dieta',
  'activity': 'Actividad',
  'fluids': 'Soluciones',
  'oxygen': 'Oxígeno',
  'medications': 'Medicamentos',
  'monitoring': 'Vigilancia',
  'nursing': 'Enfermería',
  'other': 'Otras indicaciones',
  'title': 'Título',
  'type': 'Tipo de documento',
  'content': 'Contenido',
  'created_at': 'Fecha de registro',
};

List<MapEntry<String, String>> clinicalFields(Map<String, Object?> record) {
  final all = <MapEntry<String, String>>[
    for (final entry in clinicalLabels.entries)
      if ('${record[entry.key] ?? ''}'.trim().isNotEmpty)
        MapEntry(entry.value, '${record[entry.key]}'),
    ...nomDisplay(record),
  ];
  if (decodeNom(record['nom_json']).isEmpty) return all;
  final preferred = <String>[
    'Fecha y hora',
    'Ingreso',
    'Egreso',
    'Número de expediente',
    'Paciente en la atención',
    'Edad en la atención',
    'Sexo',
    'Fecha de nacimiento',
    'Domicilio del paciente',
    ...nomProfileLabels.values,
    'Habitación',
    'Cama',
    'Título',
    'Tipo de documento',
    'Tipo de atención',
    'Grupo étnico, si aplica',
    'Antecedentes heredofamiliares',
    'Antecedentes personales patológicos y sustancias',
    'Antecedentes personales no patológicos',
    'Motivo de atención',
    'Padecimiento actual',
    'Historia clínica',
    'Resumen del interrogatorio',
    'Interrogatorio por aparatos y sistemas',
    'Exploración física',
    'Exploración / condición',
    'Exploración física y estado mental',
    'Subjetivo',
    'Objetivo',
    'Análisis',
    'Presión arterial sistólica (mmHg)',
    'Presión arterial diastólica (mmHg)',
    'Frecuencia cardiaca (latidos/minuto)',
    'Frecuencia respiratoria (respiraciones/minuto)',
    'Temperatura (°C)',
    'Peso (kg)',
    'Talla (cm)',
    'Índice de masa corporal',
    'Saturación periférica de oxígeno (%)',
    'Glucosa (mg/dL)',
    'Resultados de estudios',
    'Resultados de laboratorio y gabinete',
    'Diagnósticos',
    'Diagnósticos o problemas clínicos',
    'Pronóstico',
    'Tratamiento',
    'Medicamentos: nombre, dosis, vía y periodicidad',
    'Plan',
  ];
  // Stable sort preserves the remaining content and all long-text fields.
  return [
    for (final label in preferred.toSet()) ...all.where((e) => e.key == label),
    ...all.where((e) => !preferred.contains(e.key)),
  ];
}

String normalizeClinical(String text) {
  var value = text.toLowerCase();
  const accents = {'á': 'a', 'é': 'e', 'í': 'i', 'ó': 'o', 'ú': 'u', 'ü': 'u'};
  for (final entry in accents.entries) {
    value = value.replaceAll(entry.key, entry.value);
  }
  return value;
}

bool matchesClinical(Map<String, Object?> event, String query) {
  final text = normalizeClinical(
    '${event['type']} ${event['date']} ${event['search'] ?? event['text'] ?? ''}',
  );
  return normalizeClinical(query)
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .every(text.contains);
}
