import 'clinical_guidance.dart';
import 'clinical_models.dart';

import 'dart:convert';

const nomTables = [
  'consultations',
  'emergencies',
  'hospitalizations',
  'progress_notes',
  'medical_orders',
  'documents',
];

// Assistance for NOM-004 documentation; this is not a certification engine.
const nomLabels = <String, String>{
  'nom_kind': 'Tipo de atención',
  'nom_family': 'Antecedentes heredofamiliares',
  'nom_ethnic': 'Grupo étnico, si aplica',
  'nom_pathological': 'Antecedentes personales patológicos y sustancias',
  'nom_nonpathological': 'Antecedentes personales no patológicos',
  'nom_systems': 'Interrogatorio por aparatos y sistemas',
  'nom_prognosis': 'Pronóstico',
  'nom_exam': 'Exploración física y estado mental',
  'nom_reason': 'Motivo de atención',
  'nom_discharge_plan': 'Plan de manejo al egreso',
  'nom_outpatient': 'Recomendaciones para vigilancia ambulatoria',
  'nom_medication_details': 'Medicamentos: nombre, dosis, vía y periodicidad',
  'nom_measurement_exception': 'Motivo clínico de mediciones no obtenidas',
  'nom_history': 'Resumen del interrogatorio',
  'nom_results': 'Resultados de laboratorio y gabinete',
  'nom_diagnoses': 'Diagnósticos o problemas clínicos',
  'nom_sender': 'Establecimiento que envía',
  'nom_receiver': 'Establecimiento receptor',
  'nom_referral_reason': 'Motivo de referencia o traslado',
  'nom_criteria': 'Criterios diagnósticos',
  'nom_study_plan': 'Plan de estudios',
  'nom_act': 'Acto médico específico autorizado',
  'nom_risks': 'Riesgos explicados',
  'nom_benefits': 'Beneficios esperados',
  'nom_contingencies': 'Autorización para contingencias derivadas del acto',
  'nom_signer': 'Nombre del paciente o representante que firmará',
  'nom_relationship':
      'Parentesco o representación; motivo si no firma el paciente',
  'nom_witness1': 'Nombre completo del primer testigo',
  'nom_witness2': 'Nombre completo del segundo testigo',
  'nom_discharge_reason': 'Motivo del egreso',
  'nom_inpatient_management': 'Manejo durante la estancia hospitalaria',
  'nom_pending': 'Problemas clínicos pendientes',
  'nom_risk_factors': 'Atención de factores de riesgo',
  'nom_death_causes': 'Causas de muerte y necropsia, si aplica',
  'nom_voluntary_consequences':
      'Consecuencias explicadas del egreso voluntario',
};
const nomDocTypes = [
  'Nota libre',
  'Referencia/traslado',
  'Interconsulta',
  'Consentimiento informado',
  'Nota de egreso',
  'Egreso voluntario',
];
const nomProfileLabels = <String, String>{
  'doctor': 'Nombre completo del médico',
  'license': 'Cédula profesional',
  'rfc': 'RFC del médico (opcional)',
  'profession': 'Profesión / especialidad',
  'institution': 'Institución a la que pertenece, si aplica',
  'establishment': 'Nombre del establecimiento',
  'establishment_type': 'Tipo de establecimiento',
  'owner': 'Razón o denominación social, si aplica',
  'address': 'Domicilio del establecimiento',
  'place': 'Ciudad y estado',
  'phone': 'WhatsApp del médico (opcional)',
};

Map<String, dynamic> decodeNom(Object? value) {
  if (value == null || '$value'.isEmpty) return {};
  final decoded = jsonDecode('$value');
  if (decoded is! Map)
    throw const FormatException('Datos de documentación dañados');
  return Map<String, dynamic>.from(decoded);
}

Map<String, String> nomInput(Map<String, Object?>? record) {
  final data = decodeNom(record?['nom_json']);
  final fields = data['fields'];
  return fields is Map
      ? {for (final e in fields.entries) '${e.key}': '${e.value ?? ''}'}
      : {};
}

List<String> nomKeys(String table, Map<String, String> input) {
  if (table == 'consultations')
    return [
      if ((input['nom_kind'] ?? 'Historia clínica inicial') ==
          'Historia clínica inicial') ...[
        'nom_ethnic',
        'nom_family',
        'nom_pathological',
        'nom_nonpathological',
        'nom_systems',
      ],
      'nom_prognosis',
      'nom_medication_details',
      'nom_measurement_exception',
    ];
  if (table == 'emergencies')
    return [
      'nom_prognosis',
      'nom_medication_details',
      'nom_measurement_exception',
    ];
  if (table == 'hospitalizations')
    return [
      'nom_history',
      'nom_results',
      'nom_prognosis',
      'nom_medication_details',
      'nom_measurement_exception',
      'systolic',
      'diastolic',
      'heart_rate',
      'respiratory_rate',
      'temperature',
    ];
  if (table == 'progress_notes')
    return [
      'nom_results',
      'nom_diagnoses',
      'nom_prognosis',
      'nom_medication_details',
    ];
  if (table == 'medical_orders') return ['nom_medication_details'];
  switch (input['type']) {
    case 'Referencia/traslado':
      return [
        'nom_sender',
        'nom_receiver',
        'nom_referral_reason',
        'nom_diagnoses',
        'nom_medication_details',
      ];
    case 'Interconsulta':
      return [
        'nom_criteria',
        'nom_study_plan',
        'nom_diagnoses',
        'nom_reason',
        'nom_history',
        'nom_exam',
        'nom_results',
        'nom_prognosis',
        'nom_medication_details',
        'nom_measurement_exception',
        'systolic',
        'diastolic',
        'heart_rate',
        'respiratory_rate',
        'temperature',
      ];
    case 'Consentimiento informado':
      return [
        'nom_act',
        'nom_risks',
        'nom_benefits',
        'nom_contingencies',
        'nom_signer',
        'nom_relationship',
        'nom_witness1',
        'nom_witness2',
      ];
    case 'Nota de egreso':
      return [
        'nom_discharge_reason',
        'nom_diagnoses',
        'nom_inpatient_management',
        'nom_pending',
        'nom_discharge_plan',
        'nom_outpatient',
        'nom_medication_details',
        'nom_risk_factors',
        'nom_prognosis',
        'nom_death_causes',
      ];
    case 'Egreso voluntario':
      return [
        'nom_signer',
        'nom_relationship',
        'nom_diagnoses',
        'nom_medication_details',
        'nom_risk_factors',
        'nom_voluntary_consequences',
        'nom_witness1',
        'nom_witness2',
      ];
    default:
      return [];
  }
}

int? ageAt(Object? birth, DateTime when) {
  final d = DateTime.tryParse('${birth ?? ''}');
  if (d == null || d.isAfter(when)) return null;
  var age = when.year - d.year;
  if (when.month < d.month || (when.month == d.month && when.day < d.day))
    age--;
  return age;
}

List<String> nomMissing({
  required String table,
  required Map<String, String> input,
  required Map<String, Object?> patient,
  required Map<String, String> profile,
  required DateTime encounter,
}) {
  final out = <String>[];
  final active = {...noteFields[table] ?? <String>[], ...nomKeys(table, input)};
  if (hasGuidePlaceholders({
    for (final e in input.entries)
      if (active.contains(e.key)) e.key: e.value,
  }))
    out.add('Completa o retira los marcadores [Completar] de las guías');
  void need(String key, String label) {
    if ((input[key] ?? '').trim().isEmpty) out.add(label);
  }

  for (final k in [
    'doctor',
    'license',
    'profession',
    'establishment',
    'establishment_type',
    'address',
    'place',
  ]) {
    if ((profile[k] ?? '').trim().isEmpty) out.add(nomProfileLabels[k]!);
  }
  if ('${patient['first_name'] ?? ''}'.trim().isEmpty ||
      '${patient['last_name'] ?? ''}'.trim().isEmpty)
    out.add('Nombre completo del paciente');
  if ('${patient['sex'] ?? ''}'.trim().isEmpty) out.add('Sexo del paciente');
  if (ageAt(patient['dob'], encounter) == null)
    out.add('Fecha de nacimiento válida para calcular edad');
  if ('${patient['address'] ?? ''}'.trim().isEmpty)
    out.add('Domicilio del paciente');
  final required = <String>[];
  if (table == 'consultations') {
    required.addAll([
      'illness',
      'physical_exam',
      'studies',
      'diagnoses',
      'nom_prognosis',
      'treatment',
    ]);
    if ((input['nom_kind'] ?? 'Historia clínica inicial') ==
        'Historia clínica inicial') {
      required.addAll([
        'nom_family',
        'nom_pathological',
        'nom_nonpathological',
        'nom_systems',
      ]);
    }
  } else if (table == 'emergencies') {
    required.addAll([
      'reason',
      'brief_history',
      'physical_exam',
      'diagnoses',
      'nom_prognosis',
      'treatment',
      'studies',
    ]);
  } else if (table == 'hospitalizations') {
    required.addAll([
      'nom_history',
      'exam',
      'nom_results',
      'diagnoses',
      'nom_prognosis',
      'plan',
    ]);
  } else if (table == 'progress_notes') {
    required.addAll([
      'subjective',
      'objective',
      'nom_results',
      'nom_diagnoses',
      'nom_prognosis',
      'plan',
    ]);
  } else if (table == 'medical_orders') {
    required.addAll(['medications', 'nom_medication_details']);
  } else if (table == 'documents') {
    required.addAll(['title', 'content']);
    required.addAll(
      nomKeys(table, input).where(
        (k) => ![
          'nom_relationship',
          'nom_death_causes',
          'nom_measurement_exception',
          'systolic',
          'diastolic',
          'heart_rate',
          'respiratory_rate',
          'temperature',
        ].contains(k),
      ),
    );
  }
  for (final k in required) {
    need(k, nomLabels[k] ?? nomBaseLabels[k] ?? k);
  }
  // Explicit documentation is required even if no medication is prescribed.
  if ([
    'consultations',
    'emergencies',
    'hospitalizations',
    'progress_notes',
  ].contains(table))
    need('nom_medication_details', nomLabels['nom_medication_details']!);
  final needVitals =
      table == 'emergencies' ||
      table == 'hospitalizations' ||
      (table == 'documents' && input['type'] == 'Interconsulta') ||
      (table == 'consultations' &&
          (input['nom_kind'] ?? 'Historia clínica inicial') ==
              'Historia clínica inicial');
  if (needVitals && (input['nom_measurement_exception'] ?? '').trim().isEmpty) {
    for (final k in [
      'systolic',
      'diastolic',
      'heart_rate',
      'respiratory_rate',
      'temperature',
      if (table == 'consultations') ...['weight', 'height'],
    ]) {
      need(k, nomBaseLabels[k] ?? k);
    }
  }
  if (table == 'documents' &&
      [
        'Consentimiento informado',
        'Egreso voluntario',
      ].contains(input['type'])) {
    final patientName =
        '${patient['first_name'] ?? ''} ${patient['last_name'] ?? ''}'
            .trim()
            .toLowerCase();
    final signer = (input['nom_signer'] ?? '').trim().toLowerCase();
    if (signer.isNotEmpty && signer != patientName)
      need('nom_relationship', nomLabels['nom_relationship']!);
  }
  if (table == 'consultations' &&
      ![
        'Historia clínica inicial',
        'Evolución ambulatoria',
      ].contains(input['nom_kind'] ?? 'Historia clínica inicial')) {
    out.add('Selecciona un tipo de atención válido');
  }
  if (input['type'] == 'Nota de egreso' &&
      (input['nom_discharge_reason'] ?? '').toLowerCase().contains('defunci')) {
    need('nom_death_causes', nomLabels['nom_death_causes']!);
  }
  if (encounter.isAfter(DateTime.now().add(const Duration(minutes: 5))))
    out.add('Fecha de atención: no puede ser futura');
  return out;
}

const nomBaseLabels = {
  'illness': 'Padecimiento actual',
  'physical_exam': 'Exploración física',
  'studies': 'Resultados de estudios / ausencia documentada',
  'diagnoses': 'Diagnósticos',
  'treatment': 'Tratamiento e indicaciones',
  'reason': 'Motivo de atención',
  'brief_history': 'Interrogatorio y antecedentes',
  'exam': 'Exploración física y estado mental',
  'plan': 'Tratamiento / plan',
  'subjective': 'Evolución clínica',
  'objective': 'Exploración y estado actual',
  'medications': 'Medicamentos o ausencia documentada',
  'title': 'Título',
  'content': 'Contenido / resumen clínico',
  'systolic': 'Presión sistólica',
  'diastolic': 'Presión diastólica',
  'heart_rate': 'Frecuencia cardiaca',
  'respiratory_rate': 'Frecuencia respiratoria',
  'temperature': 'Temperatura',
  'weight': 'Peso',
  'height': 'Talla',
};
List<MapEntry<String, String>> nomDisplay(Map<String, Object?> record) {
  final data = decodeNom(record['nom_json']);
  if (data.isEmpty)
    return [
      const MapEntry(
        'Documentación',
        'Registro previo sin verificación de apartados NOM ni firma registrada. No se atribuye autor retrospectivamente.',
      ),
    ];
  final out = <MapEntry<String, String>>[];
  for (final group in ['patient', 'profile']) {
    final values = data[group];
    if (values is Map) {
      for (final e in values.entries) {
        if ('${e.value ?? ''}'.trim().isNotEmpty &&
            (group != 'profile' || nomProfileLabels.containsKey('${e.key}')))
          out.add(
            MapEntry(
              group == 'profile'
                  ? nomProfileLabels['${e.key}'] ?? '${e.key}'
                  : {
                          'name': 'Paciente en la atención',
                          'age': 'Edad en la atención',
                          'sex': 'Sexo',
                          'address': 'Domicilio del paciente',
                          'dob': 'Fecha de nacimiento',
                          'id': 'Número de expediente',
                        }['${e.key}'] ??
                        '${e.key}',
              '${e.value}',
            ),
          );
      }
    }
  }
  final f = data['fields'];
  if (f is Map)
    for (final e in f.entries) {
      if ('${e.value ?? ''}'.trim().isNotEmpty)
        out.add(
          MapEntry(
            nomLabels['${e.key}'] ?? nomBaseLabels['${e.key}'] ?? '${e.key}',
            '${e.value}',
          ),
        );
    }
  out.add(
    MapEntry(
      'Firma del documento',
      'Pendiente de firma autógrafa en el impreso. Guardar o imprimir no firma el documento.',
    ),
  );
  if (data['legacy'] == true)
    out.add(
      const MapEntry(
        'Autoría original',
        'No registrada. Los datos actuales corresponden a la corrección, no certifican la autoría de la nota previa.',
      ),
    );
  if (data['correction_profile'] is Map) {
    final c = data['correction_profile'] as Map;
    out.add(
      MapEntry(
        'Responsable de la última corrección',
        '${c['doctor']} · Cédula ${c['license']} · ${data['corrected_at']}',
      ),
    );
  }
  if (data['hospital_admitted_at'] != null)
    out.add(
      MapEntry(
        'Ingreso relacionado',
        '${data['hospital_admitted_at']} · Hospitalización ${data['hospitalization_id']}',
      ),
    );
  return out;
}
