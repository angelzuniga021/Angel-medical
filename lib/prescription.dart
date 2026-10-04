import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'clinical_store.dart';
import 'clinical_record_view.dart';
import 'clinical_nom_settings.dart';

import 'clinical_ui.dart';

import 'package:flutter/material.dart';

import 'db.dart';
import 'services.dart';

class PrescriptionForm extends StatefulWidget {
  final Map<String, Object?> patient;
  final String diagnosis;
  final String initialFreeTreatment;

  const PrescriptionForm({
    super.key,
    required this.patient,
    this.diagnosis = '',
    this.initialFreeTreatment = '',
  });

  @override
  State<PrescriptionForm> createState() => _PrescriptionFormState();
}

class RxMedication {
  final name = TextEditingController();
  final presentation = TextEditingController();
  final dose = TextEditingController();
  final route = TextEditingController();
  final frequency = TextEditingController();
  final duration = TextEditingController();
  final instructions = TextEditingController();

  Map<String, String> toMap() => {
    'name': name.text.trim(),
    'presentation': presentation.text.trim(),
    'dose': dose.text.trim(),
    'route': route.text.trim(),
    'frequency': frequency.text.trim(),
    'duration': duration.text.trim(),
    'instructions': instructions.text.trim(),
  };
}

class _PrescriptionFormState extends State<PrescriptionForm> {
  bool saving = false;
  int? savedId;
  final meds = <RxMedication>[RxMedication()];
  final general = TextEditingController();
  late final TextEditingController diagnosis;
  Map<String, Object?>? latestVitals;

  @override
  void initState() {
    super.initState();
    diagnosis = TextEditingController(text: widget.diagnosis);
    if (widget.initialFreeTreatment.trim().isNotEmpty) {
      general.text = widget.initialFreeTreatment.trim();
    }
    _loadVitals();
  }

  Future<void> _loadVitals() async {
    latestVitals = await AppDb.instance.latestConsultation(
      widget.patient['id'] as int,
    );
    if (mounted) setState(() {});
  }

  void addMedication() => setState(() => meds.add(RxMedication()));

  void removeMedication(int index) {
    if (meds.length == 1) {
      for (final c in [
        meds[0].name,
        meds[0].presentation,
        meds[0].dose,
        meds[0].route,
        meds[0].frequency,
        meds[0].duration,
        meds[0].instructions,
      ]) {
        c.clear();
      }
      setState(() {});
      return;
    }
    setState(() => meds.removeAt(index));
  }

  void applyMedication(RxMedication m, Map<String, Object?> x) {
    final generic = '${x['generic_name'] ?? ''}'.trim();
    final brand = '${x['brand_name'] ?? ''}'.trim();
    m.name.text =
        brand.isNotEmpty && brand.toUpperCase() != generic.toUpperCase()
        ? '$generic ($brand)'
        : generic;
    final presentation = [x['form'], x['strength'], x['presentation']]
        .where((v) => v != null && '$v'.trim().isNotEmpty)
        .map((v) => '$v'.trim())
        .join(' · ');
    if (presentation.isNotEmpty) m.presentation.text = presentation;
    AppDb.instance.markMedicationUsed(x);
    setState(() {});
  }

  Future<void> saveAndPrint({bool review = false}) async {
    if (saving) return;
    if (savedId != null) {
      await openSavedRecipe();
      return;
    }
    setState(() => saving = true);
    try {
      await saveOnceAndPrint(review: review);
    } catch (e) {
      if (mounted)
        clinicalMessage(
          context,
          savedId == null ? 'No se pudo guardar la receta: $e' : 'La receta está guardada; falló la impresión. Puedes abrirla desde el historial.',
        );
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> openSavedRecipe() async {
    final record = await AppDb.instance.one('documents', savedId!);
    if (record == null) throw const FormatException('No se encontró la receta guardada');
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => ClinicalRecordView(patient: widget.patient, record: record, title: 'Receta médica', table: 'documents')));
    if (mounted) Navigator.pop(context);
  }

  Future<void> saveOnceAndPrint({bool review = false}) async {
    final validMeds = meds
        .map((m) => m.toMap())
        .where((m) => (m['name'] ?? '').trim().isNotEmpty)
        .toList();

    if (validMeds.isEmpty && general.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Agrega al menos un medicamento o indicación'),
        ),
      );
      return;
    }

    for (final m in validMeds) {
      await AppDb.instance.upsertFreeMedication(m['name'] ?? '');
    }

    final lines = validMeds.map((m) {
      final parts = <String>[
        m['name'] ?? '',
        if ((m['presentation'] ?? '').isNotEmpty) m['presentation']!,
        if ((m['dose'] ?? '').isNotEmpty) 'Dosis ${m['dose']}',
        if ((m['route'] ?? '').isNotEmpty) 'Vía ${m['route']}',
        if ((m['frequency'] ?? '').isNotEmpty) 'Cada ${m['frequency']}',
        if ((m['duration'] ?? '').isNotEmpty) 'por ${m['duration']}',
        if ((m['instructions'] ?? '').isNotEmpty) m['instructions']!,
      ];
      return parts.where((x) => x.trim().isNotEmpty).join(' · ');
    }).toList();

    final content = [
      if (diagnosis.text.trim().isNotEmpty)
        'Diagnóstico: ${diagnosis.text.trim()}',
      ...lines,
      if (general.text.trim().isNotEmpty)
        'Indicaciones generales: ${general.text.trim()}',
    ].join('\n');

    final now = DateTime.now().toIso8601String();
    for (final m in validMeds) {
      if ([
        'dose',
        'route',
        'frequency',
        'duration',
      ].any((k) => (m[k] ?? '').trim().isEmpty)) {
        throw const FormatException(
          'Cada medicamento requiere dosis, vía, periodicidad y duración',
        );
      }
    }
    savedId ??= await ClinicalStore.finalize(
      table: 'documents',
      pid: widget.patient['id'] as int,
      input: {
        'type': 'Receta',
        'title': 'Receta médica',
        'content': content,
        'nom_rx_data': jsonEncode({'medications': validMeds, 'diagnosis': diagnosis.text.trim(), 'recommendations': general.text.trim(), 'content_sha256': sha256.convert(utf8.encode(content)).toString()}),
        '_encounter_at': now,
      },
      draftKey: 'prescription:${widget.patient['id']}:$now',
    );
    if (review) { await openSavedRecipe(); return; }
    final saved = await AppDb.instance.one('documents', savedId!);
    await AppDb.instance.audit('PRINT_PRESCRIPTION', '$savedId');

    await PdfService.printPrescription(
      patient: widget.patient,
      medications: validMeds,
      generalInstructions: general.text.trim(),
      diagnosis: diagnosis.text.trim(),
      vitals: latestVitals,
      record: saved,
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final dob = '${widget.patient['dob'] ?? ''}'.trim();
    final age = PdfService.ageFromDob(dob);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receta médica'),
        actions: [
          IconButton(
            tooltip: 'Médico y establecimiento',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NomSettings()),
            ),
            icon: const Icon(Icons.badge_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text(
            '${widget.patient['first_name']} ${widget.patient['last_name']}',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          Text(
            [
              if (dob.isNotEmpty) 'F.N. $dob',
              if (age != null) '$age años',
              if ('${widget.patient['sex'] ?? ''}'.trim().isNotEmpty)
                '${widget.patient['sex']}',
            ].join(' · '),
          ),
          const SizedBox(height: 4),
          Text(
            latestVitals == null
                ? 'Sin signos vitales previos cargados'
                : 'Los signos vitales permanecen en la consulta; la receta muestra los datos esenciales.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: diagnosis,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Diagnóstico (opcional)',
            ),
          ),
          const SizedBox(height: 14),
          ...meds.asMap().entries.map((entry) {
            final i = entry.key;
            final m = entry.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Medicamento ${i + 1}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => removeMedication(i),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                      MedicationSearchField(
                        controller: m.name,
                        onSelected: (x) => applyMedication(m, x),
                      ),
                      const SizedBox(height: 7),
                      TextField(
                        controller: m.presentation,
                        decoration: const InputDecoration(
                          labelText: 'Presentación (opcional)',
                          hintText: 'Ej. tabletas 500 mg',
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: m.dose,
                              decoration: const InputDecoration(
                                labelText: 'Dosis',
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              decoration: const InputDecoration(
                                labelText: 'Vía',
                              ),
                              items:
                                  const [
                                        'VO',
                                        'IV',
                                        'IM',
                                        'SC',
                                        'SL',
                                        'Inhalada',
                                        'Tópica',
                                        'Oftálmica',
                                        'Ótica',
                                        'Rectal',
                                      ]
                                      .map(
                                        (x) => DropdownMenuItem(
                                          value: x,
                                          child: Text(x),
                                        ),
                                      )
                                      .toList(),
                              onChanged: (v) => m.route.text = v ?? '',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: m.frequency,
                              decoration: const InputDecoration(
                                labelText: 'Frecuencia',
                                hintText: '8 horas',
                              ),
                            ),
                          ),
                          const SizedBox(width: 7),
                          Expanded(
                            child: TextField(
                              controller: m.duration,
                              decoration: const InputDecoration(
                                labelText: 'Duración',
                                hintText: '5 días',
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      TextField(
                        controller: m.instructions,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: 'Indicaciones adicionales',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: addMedication,
            icon: const Icon(Icons.add),
            label: const Text('Agregar medicamento'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: general,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Indicaciones generales (opcional)',
              hintText: 'Reposo, hidratación, signos de alarma u otras recomendaciones',
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: saving ? null : saveAndPrint,
            icon: const Icon(Icons.print_outlined),
            label: const Text('Guardar e imprimir / PDF'),
          ),
          const SizedBox(height: 10),
          FilledButton.tonalIcon(
            onPressed: saving ? null : () => saveAndPrint(review: true),
            icon: const Icon(Icons.draw_outlined),
            label: const Text('Guardar y revisar / firmar'),
          ),
          const SizedBox(height: 25),
        ],
      ),
    );
  }
}

class MedicationSearchField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<Map<String, Object?>> onSelected;

  const MedicationSearchField({
    super.key,
    required this.controller,
    required this.onSelected,
  });

  @override
  State<MedicationSearchField> createState() => _MedicationSearchFieldState();
}

class _MedicationSearchFieldState extends State<MedicationSearchField> {
  List<Map<String, Object?>> results = [];
  bool showResults = false;

  Future<void> search(String q) async {
    results = await AppDb.instance.searchMedications(q);
    if (mounted) {
      setState(() => showResults = results.isNotEmpty);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: widget.controller,
          onChanged: search,
          decoration: InputDecoration(
            labelText: 'Medicamento *',
            hintText: 'Genérico, comercial o captura libre',
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => search(widget.controller.text),
            ),
          ),
        ),
        if (showResults)
          Container(
            constraints: const BoxConstraints(maxHeight: 190),
            margin: const EdgeInsets.only(top: 5),
            child: Card(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: results.length,
                itemBuilder: (_, i) {
                  final x = results[i];
                  final generic = '${x['generic_name'] ?? ''}';
                  final brand = '${x['brand_name'] ?? ''}';
                  final extra = [x['form'], x['strength'], x['presentation']]
                      .where((v) => v != null && '$v'.trim().isNotEmpty)
                      .join(' · ');
                  return ListTile(
                    dense: true,
                    title: Text(
                      brand.trim().isEmpty ? generic : '$generic · $brand',
                    ),
                    subtitle: extra.trim().isEmpty ? null : Text(extra),
                    onTap: () {
                      widget.onSelected(x);
                      setState(() => showResults = false);
                    },
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}
