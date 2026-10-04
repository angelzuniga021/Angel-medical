import 'package:flutter/material.dart';
import 'clinical_ui.dart';

String recordedValue(Object? value) => '${value ?? ''}'.trim().isEmpty ? 'Sin registro' : '$value';

IconData clinicalEventIcon(String table) => switch (table) {
  'consultations' => Icons.medical_services_outlined,
  'emergencies' => Icons.emergency_outlined,
  'hospitalizations' => Icons.bed_outlined,
  'progress_notes' => Icons.monitor_heart_outlined,
  'medical_orders' => Icons.medication_outlined,
  _ => Icons.description_outlined,
};

class ClinicalPatientBanner extends StatelessWidget {
  final Map<String, Object?> patient;
  final int events, drafts;
  const ClinicalPatientBanner({super.key, required this.patient, required this.events, required this.drafts});
  @override
  Widget build(BuildContext context) {
    final name = '${patient['first_name'] ?? ''} ${patient['last_name'] ?? ''}'.trim();
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF164A7C), Color(0xFF102838)])),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [CircleAvatar(backgroundColor: const Color(0xFF285C85), foregroundColor: Colors.white, child: Text(initial)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
          Text('$events atenciones · $drafts borradores', style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ]))]),
        const SizedBox(height: 10),
        Text('Alergias: ${recordedValue(patient['allergies'])}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0xFFFFCB8A), fontWeight: FontWeight.w600)),
        if (patient['is_deceased'] == 1 || patient['is_archived'] == 1)
          Text(patient['is_deceased'] == 1 ? 'Paciente fallecido' : 'Expediente archivado', style: const TextStyle(color: Colors.white70)),
      ]),
    );
  }
}

class ClinicalPatientOverview extends StatelessWidget {
  final Map<String, Object?> patient;
  final Map<String, Object?>? lastAssessment;
  final VoidCallback? onOpenAssessment;
  const ClinicalPatientOverview({super.key, required this.patient, this.lastAssessment, this.onOpenAssessment});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('Lo esencial para la consulta', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
    const SizedBox(height: 12),
    for (final entry in const {'allergies': 'Alergias registradas', 'chronic_meds': 'Medicación habitual', 'personal_history': 'Antecedentes personales'}.entries)
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [Icon(entry.key == 'allergies' ? Icons.warning_amber_rounded : entry.key == 'chronic_meds' ? Icons.medication_outlined : Icons.medical_information_outlined, color: entry.key == 'allergies' ? Theme.of(context).colorScheme.tertiary : Theme.of(context).colorScheme.primary), const SizedBox(width: 10), Expanded(child: Text(entry.value, style: const TextStyle(fontWeight: FontWeight.w700)))]),
        const SizedBox(height: 10), SelectableText(recordedValue(patient[entry.key])),
      ]))),
    Card(child: ListTile(
      contentPadding: const EdgeInsets.all(18), leading: const Icon(Icons.history_rounded),
      title: const Text('Última valoración', style: TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(lastAssessment == null ? 'Sin valoración registrada' : '${lastAssessment!['type']} · ${clinicalDate(lastAssessment!['date'])}\n${recordedValue(lastAssessment!['text'])}'),
      trailing: lastAssessment == null ? null : const Icon(Icons.chevron_right), onTap: onOpenAssessment,
    )),
    const Padding(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8), child: Text('La medicación habitual proviene de la ficha del paciente. Las recetas anteriores no se consideran tratamiento activo automáticamente.', style: TextStyle(fontSize: 12))),
  ]);
}

class ClinicalTimelineTile extends StatelessWidget {
  final Map<String, Object?> event;
  final VoidCallback? onTap;
  const ClinicalTimelineTile({super.key, required this.event, this.onTap});
  @override
  Widget build(BuildContext context) => Card(child: InkWell(
    borderRadius: BorderRadius.circular(20), onTap: onTap,
    child: Padding(padding: const EdgeInsets.all(18), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, borderRadius: BorderRadius.circular(14)), child: Icon(clinicalEventIcon('${event['table']}'), color: Theme.of(context).colorScheme.onPrimaryContainer)),
      const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(clinicalDate(event['date']), style: Theme.of(context).textTheme.labelMedium), const SizedBox(height: 5),
        Text('${event['type']}', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8), Text(recordedValue(event['text']), maxLines: 3, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 10), const Text('Registro guardado · Sin firma electrónica', style: TextStyle(fontSize: 11)),
      ])), const Icon(Icons.chevron_right, size: 20),
    ])),
  ));
}
