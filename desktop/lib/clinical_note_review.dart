import 'clinical_body_data.dart';
import 'package:flutter/material.dart';
import 'clinical_record.dart';
import 'clinical_nom.dart';

class ClinicalNoteReview extends StatelessWidget {
  final Map<String, String> input;
  final String patientName;
  const ClinicalNoteReview({super.key, required this.input, required this.patientName});
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Revisar antes de finalizar'),
    content: SizedBox(width: 480, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
      Text(patientName, style: const TextStyle(fontWeight: FontWeight.w700)),
      const SizedBox(height: 12),
      const Text('Guardar finaliza la nota. No aplica una firma electrónica. Revisa que los hallazgos y las indicaciones correspondan a esta atención.'),
      const Divider(),
      for (final entry in input.entries.where((e) => e.value.trim().isNotEmpty)) ...[
        Text(entry.key == 'encounter_date' ? 'Fecha y hora de atención' : nomLabels[entry.key] ?? clinicalLabels[entry.key] ?? entry.key, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4), SelectableText(entry.key == 'nom_body_map' ? describeBodyMap(entry.value) : entry.value), const SizedBox(height: 16),
      ],
    ]))),
    actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Seguir editando')), FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Finalizar nota'))],
  );
}
