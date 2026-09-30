import 'dart:convert';

import '../lib/clinical_nom.dart';

void require(bool ok, String message) {
  if (!ok) throw StateError(message);
}

final fixtureDate = DateTime(2026, 9, 29, 10, 30);
const fixturePatient = <String, Object?>{
  'id': 1,
  'first_name': 'Paciente',
  'last_name': 'Ficticio',
  'dob': '1990-09-30',
  'sex': 'Masculino',
  'address': 'Domicilio ficticio',
};
const fixtureProfile = {
  'doctor': 'Médico ficticio',
  'license': '0000000',
  'profession': 'Medicina general',
  'establishment': 'Consultorio ficticio',
  'establishment_type': 'Consultorio',
  'address': 'Domicilio ficticio',
  'place': 'Ciudad ficticia',
};
Map<String, String> initial() => {
  'nom_kind': 'Historia clínica inicial',
  'illness': 'Inicio hace dos días',
  'physical_exam': 'Descripción por regiones',
  'studies': 'No se requieren estudios en esta atención',
  'diagnoses': 'Diagnóstico documentado',
  'treatment': 'Indicaciones no farmacológicas',
  'nom_family': 'Antecedentes interrogados',
  'nom_pathological': 'Antecedentes interrogados',
  'nom_nonpathological': 'Antecedentes interrogados',
  'nom_systems': 'Síntomas interrogados',
  'nom_prognosis': 'Favorable para la vida',
  'nom_medication_details': 'No se prescriben medicamentos',
  'systolic': '120',
  'diastolic': '80',
  'heart_rate': '80',
  'respiratory_rate': '16',
  'temperature': '36.5',
  'weight': '80',
  'height': '175',
};
List<String> missing(
  String table,
  Map<String, String> values, {
  Map<String, Object?> patient = fixturePatient,
  Map<String, String> profile = fixtureProfile,
}) => nomMissing(
  table: table,
  input: values,
  patient: patient,
  profile: profile,
  encounter: fixtureDate,
);
final nomCases = <String, void Function()>{
  'Historia inicial incompleta no pasa y borrador no se confunde con nota': () {
    require(
      missing('consultations', {}).contains('Pronóstico'),
      'Falta pronóstico',
    );
    require(
      missing('consultations', {}).contains('Antecedentes heredofamiliares'),
      'Faltan antecedentes',
    );
    require(
      missing('consultations', initial()).isEmpty,
      'Historia completa bloqueada',
    );
  },
  'Evolución no exige reinterrogar historia inicial pero sí pronóstico': () {
    final values = initial()..['nom_kind'] = 'Evolución ambulatoria';
    for (final key in [
      'nom_family',
      'nom_pathological',
      'nom_nonpathological',
      'nom_systems',
      'weight',
      'height',
    ]) {
      values.remove(key);
    }
    require(
      missing('consultations', values).isEmpty,
      'Evolución exige historia nueva',
    );
    values.remove('nom_prognosis');
    require(
      missing('consultations', values).contains('Pronóstico'),
      'Evolución sin pronóstico',
    );
  },
  'Excepción de mediciones requiere explicación explícita': () {
    final values = initial();
    values.remove('temperature');
    require(
      missing('consultations', values).contains('Temperatura'),
      'Se acepta medición ausente sin explicación',
    );
    values['nom_measurement_exception'] =
        'Termómetro no disponible; pendiente de obtener';
    require(
      missing('consultations', values).isEmpty,
      'No admite motivo explícito',
    );
  },
  'Identificación y establecimiento no se inventan': () {
    require(
      missing(
        'consultations',
        initial(),
        profile: {},
      ).contains('Domicilio del establecimiento'),
      'Acepta perfil vacío',
    );
    final patient = {
      ...fixturePatient,
      'dob': '2030-01-01',
      'sex': '',
      'address': '',
    };
    final issues = missing('consultations', initial(), patient: patient);
    require(
      issues.contains('Sexo del paciente') &&
          issues.contains('Domicilio del paciente') &&
          issues.contains('Fecha de nacimiento válida para calcular edad'),
      'Identificación inválida aceptada',
    );
    require(
      ageAt('1990-09-30', fixtureDate) == 35,
      'Edad calculada en fecha incorrecta',
    );
    require(
      ageAt('1990-09-30', DateTime(2026, 9, 30)) == 36,
      'Edad en cumpleaños',
    );
  },
  'Consentimiento exige acto, riesgos, beneficios y dos testigos': () {
    final values = {
      'type': 'Consentimiento informado',
      'title': 'Consentimiento',
      'content': 'Información explicada',
    };
    final issues = missing('documents', values);
    for (final key in [
      'nom_act',
      'nom_risks',
      'nom_benefits',
      'nom_contingencies',
      'nom_signer',
      'nom_witness1',
      'nom_witness2',
    ]) {
      require(
        issues.contains(nomLabels[key]),
        'Acepta consentimiento sin $key',
      );
      values[key] = 'Dato ficticio de prueba';
    }
    values['nom_signer'] = 'Representante ficticio';
    require(
      missing('documents', values).contains(nomLabels['nom_relationship']),
      'Representante sin parentesco ni explicación',
    );
    values['nom_signer'] = 'Paciente Ficticio';
    require(
      missing('documents', values).isEmpty,
      'Consentimiento preparado completo bloqueado',
    );
  },
  'Egreso exige manejo, pendientes, vigilancia y causas si defunción': () {
    final values = {
      'type': 'Nota de egreso',
      'title': 'Egreso',
      'content': 'Resumen y condición actual',
    };
    for (final key in nomKeys('documents', values)) {
      values[key] = 'Dato ficticio';
    }
    values.remove('nom_pending');
    require(
      missing('documents', values).contains(nomLabels['nom_pending']),
      'Acepta egreso sin pendientes',
    );
    values['nom_pending'] = 'Sin problemas pendientes tras valoración';
    values['nom_discharge_reason'] = 'Defunción';
    values.remove('nom_death_causes');
    require(
      missing('documents', values).contains(nomLabels['nom_death_causes']),
      'Defunción sin causas',
    );
  },
  'Registros previos no reciben autoría ni firma retrospectiva': () {
    final legacy = nomDisplay({'date': '2026-01-01'});
    require(
      legacy.single.value.contains('No se atribuye autor'),
      'Inventa autor de notas antiguas',
    );
    final record = <String, Object?>{
      'nom_json': jsonEncode({
        'fields': {'nom_prognosis': 'Reservado'},
        'profile': {'doctor': 'Autor original'},
        'patient': {'age': 35},
        'signature': 'pending_ink',
        'correction_profile': {
          'doctor': 'Médico corrector',
          'license': '00000',
        },
        'corrected_at': '2026-09-30',
      }),
    };
    final view = Map.fromEntries(nomDisplay(record));
    require(view['Pronóstico'] == 'Reservado', 'No muestra datos NOM');
    require(
      view['Nombre completo del médico'] == 'Autor original',
      'Confunde autor y corrector',
    );
    require(
      view['Responsable de la última corrección']!.contains('Médico corrector'),
      'Corrector no registrado',
    );
    require(
      view['Firma del documento']!.contains('Pendiente'),
      'Simula firma válida',
    );
  },
  'JSON dañado se rechaza en lugar de ocultar documentación': () {
    var threw = false;
    try {
      decodeNom('{invalid');
    } on FormatException {
      threw = true;
    }
    require(threw, 'JSON dañado aceptado');
  },
};
void main() {
  for (final e in nomCases.entries) {
    e.value();
    print('PASS: ${e.key}');
  }
}
