const guidePlaceholder = '[Completar]';
const communityEdition = bool.fromEnvironment(
  'COMMUNITY_EDITION',
  defaultValue: false,
);

class ClinicalGuide {
  final String question;
  final List<String> prompts;
  const ClinicalGuide(this.question, this.prompts);
  String get outline => prompts.map((x) => '$x: $guidePlaceholder').join('\n');
}

const clinicalGuides = <String, ClinicalGuide>{
  'reason': ClinicalGuide('¿Qué motivó la atención?', [
    'Motivo principal',
    'Objetivo de esta consulta',
  ]),
  'illness': ClinicalGuide('Ordena el padecimiento en una secuencia temporal', [
    'Inicio y tiempo de evolución',
    'Síntomas y características',
    'Evolución y factores modificadores',
    'Síntomas asociados relevantes',
    'Tratamientos previos y respuesta',
  ]),
  'nom_family': ClinicalGuide(
    'Registra lo interrogado, sin asumir antecedentes negados',
    [
      'Familiar y parentesco',
      'Enfermedad o antecedente',
      'Datos relevantes o no disponibles',
    ],
  ),
  'nom_pathological': ClinicalGuide('Documenta antecedentes y exposiciones', [
    'Enfermedades y evolución',
    'Cirugías, hospitalizaciones y traumatismos',
    'Alergias y reacción',
    'Medicamentos habituales',
    'Tabaco, alcohol y otras sustancias',
  ]),
  'nom_nonpathological': ClinicalGuide(
    'Registra antecedentes personales no patológicos',
    [
      'Ocupación y entorno',
      'Hábitos y alimentación',
      'Actividad física y sueño',
      'Vacunación y otros antecedentes pertinentes',
    ],
  ),
  'nom_systems': ClinicalGuide(
    'Registra las respuestas obtenidas por sistemas',
    [
      'Síntomas generales',
      'Respiratorio y cardiovascular',
      'Digestivo y genitourinario',
      'Neurológico y musculoesquelético',
      'Otros sistemas interrogados y datos no disponibles',
    ],
  ),
  'physical_exam': ClinicalGuide(
    'Describe los hallazgos que realmente exploraste',
    [
      'Habitus exterior',
      'Cabeza y cuello',
      'Tórax',
      'Abdomen',
      'Extremidades',
      'Otras regiones exploradas',
      'Exploración no realizada y motivo',
    ],
  ),
  'exam': ClinicalGuide('Describe exploración y estado al ingreso', [
    'Habitus exterior y estado mental',
    'Exploración por regiones',
    'Hallazgos relevantes',
    'Exploración no realizada y motivo',
  ]),
  'subjective': ClinicalGuide('¿Qué cambió desde la atención anterior?', [
    'Síntomas actuales',
    'Cambios y evolución',
    'Adherencia y tolerancia al tratamiento',
  ]),
  'objective': ClinicalGuide('Registra hallazgos de esta valoración', [
    'Exploración actual',
    'Mediciones realizadas',
    'Resultados disponibles',
  ]),
  'assessment': ClinicalGuide('Expresa tu evaluación clínica', [
    'Interpretación de hallazgos',
    'Problemas activos',
    'Respuesta al manejo',
  ]),
  'diagnoses': ClinicalGuide('Documenta tu impresión diagnóstica', [
    'Problema o diagnóstico',
    'Sustento clínico',
    'Diagnósticos diferenciales si aplica',
  ]),
  'nom_diagnoses': ClinicalGuide('Documenta tu impresión diagnóstica', [
    'Problema o diagnóstico',
    'Sustento clínico',
    'Pendientes diagnósticos',
  ]),
  'studies': ClinicalGuide('Separa resultados de lo solicitado', [
    'Resultados disponibles y fecha',
    'Interpretación clínica',
    'Estudios solicitados o motivo de no requerirlos',
  ]),
  'nom_results': ClinicalGuide('Registra los estudios relevantes', [
    'Estudio y fecha',
    'Resultado relevante',
    'Interpretación clínica o ausencia documentada',
  ]),
  'nom_prognosis': ClinicalGuide('Define el pronóstico según tu valoración', [
    'Pronóstico',
    'Factores que lo condicionan',
  ]),
  'nom_medication_details': ClinicalGuide(
    'Prescribe según tu criterio; la app no sugiere fármacos',
    [
      'Nombre del medicamento o ausencia documentada',
      'Dosis',
      'Vía de administración',
      'Periodicidad',
      'Duración y otras instrucciones',
    ],
  ),
  'treatment': ClinicalGuide('Ordena las indicaciones para esta atención', [
    'Manejo indicado',
    'Indicaciones no farmacológicas',
    'Precauciones pertinentes',
    'Seguimiento',
  ]),
  'plan': ClinicalGuide('Define qué debe ocurrir después', [
    'Plan de manejo',
    'Estudios o interconsultas',
    'Seguimiento y pendientes',
    'Indicaciones y datos de alarma explicados',
  ]),
  'nom_pending': ClinicalGuide('¿Qué problemas quedan por resolver?', [
    'Problema pendiente o ausencia documentada',
    'Acción requerida',
    'Responsable y plazo cuando se conozcan',
  ]),
};

class GuideSection {
  final String title;
  final List<String> keys;
  const GuideSection(this.title, this.keys);
}

List<GuideSection> guideSections(Iterable<String> keys) {
  final active = keys.toSet();
  const groups = [
    GuideSection('Antecedentes', [
      'nom_ethnic',
      'nom_family',
      'nom_pathological',
      'nom_nonpathological',
    ]),
    GuideSection('Padecimiento', [
      'reason',
      'illness',
      'brief_history',
      'nom_history',
      'nom_systems',
      'subjective',
    ]),
    GuideSection('Exploración', [
      'physical_exam',
      'exam',
      'objective',
      'triage',
      'pain',
      'glasgow',
      'systolic',
      'diastolic',
      'heart_rate',
      'respiratory_rate',
      'temperature',
      'spo2',
      'weight',
      'height',
      'glucose',
      'nom_measurement_exception',
    ]),
    GuideSection('Evaluación', [
      'studies',
      'nom_results',
      'diagnoses',
      'nom_diagnoses',
      'assessment',
      'nom_prognosis',
    ]),
    GuideSection('Plan', [
      'treatment',
      'plan',
      'nom_medication_details',
      'evolution',
      'disposition',
      'disposition_notes',
    ]),
  ];
  final result = <GuideSection>[];
  for (final g in groups) {
    final selected = g.keys.where(active.contains).toList();
    if (selected.isNotEmpty) {
      result.add(GuideSection(g.title, selected));
      active.removeAll(selected);
    }
  }
  if (active.isNotEmpty)
    result.add(GuideSection('Otros apartados', active.toList()));
  return result;
}

bool hasGuidePlaceholders(Map<String, String> values) =>
    values.values.any((x) => x.contains(guidePlaceholder));
