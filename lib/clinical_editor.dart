import 'clinical_note_review.dart';
import 'clinical_cie_screen.dart';
import 'clinical_catalog.dart';
import 'clinical_guidance.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import 'db.dart';
import 'clinical_store.dart';
import 'clinical_record.dart';
import 'clinical_ui.dart';
import 'clinical_nom.dart';
import 'clinical_nom_settings.dart';

class ClinicalEditor extends StatefulWidget {
  final Map<String, Object?> patient;
  final String table;
  final int? parentId;
  final Map<String, Object?>? original;
  final String? documentType;
  const ClinicalEditor({
    super.key,
    required this.patient,
    required this.table,
    this.parentId,
    this.original,
    this.documentType,
  });
  @override
  State<ClinicalEditor> createState() => _ClinicalEditorState();
}

class _ClinicalEditorState extends State<ClinicalEditor>
    with WidgetsBindingObserver {
  late final Map<String, TextEditingController> fields;
  final reason = TextEditingController();
  Timer? timer;
  Future<void> queue = Future.value();
  bool ready = false,
      busy = false,
      completed = false,
      allowPop = false,
      leaving = false;
  bool guided = true;
  int guideStep = 0;
  DateTime encounter = DateTime.now();
  Map<String, String> profile = {};
  List<String> missing = [];
  String status = 'Cargando borrador…';
  String? failure;
  Map<String, Object?>? previous;
  int get pid => widget.patient['id'] as int;
  String get draftKey =>
      '${widget.table}:$pid:${widget.parentId ?? 0}:${widget.original?['id'] ?? 0}';
  Map<String, String> get input => {
    for (final e in fields.entries) e.key: e.value.text,
    '_revision_reason': reason.text,
    '_encounter_at': encounter.toIso8601String(),
  };
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    guided = widget.original == null && widget.table == 'consultations';
    final oldExtra = nomInput(widget.original);
    encounter =
        DateTime.tryParse(
          '${widget.original?[widget.table == 'hospitalizations' ? 'admitted_at' : 'date'] ?? ''}',
        ) ??
        DateTime.now();
    fields = {
      for (final k in noteFields[widget.table]!.where(
        (k) =>
            widget.table != 'hospitalizations' ||
            widget.original != null ||
            !k.startsWith('discharge_'),
      ))
        k: TextEditingController(text: '${widget.original?[k] ?? ''}'),
    };
    for (final key in nomLabels.keys) {
      fields.putIfAbsent(
        key,
        () => TextEditingController(text: oldExtra[key] ?? ''),
      );
    }
    for (final key in [
      'systolic',
      'diastolic',
      'heart_rate',
      'respiratory_rate',
      'temperature',
    ]) {
      if (widget.table == 'hospitalizations' || widget.table == 'documents') {
        fields.putIfAbsent(
          key,
          () => TextEditingController(text: oldExtra[key] ?? ''),
        );
      }
    }
    if (fields['nom_kind']!.text.isEmpty)
      fields['nom_kind']!.text = 'Historia clínica inicial';
    if (widget.original == null && widget.table == 'documents') {
      fields['type']!.text = widget.documentType ?? 'Nota libre';
      fields['title']!.text = widget.documentType ?? 'Documento médico';
    }
    initialize();
  }

  Future<void> initialize() async {
    try {
      await reloadProfile();
      final db = await AppDb.instance.database;
      final drafts = await db.query(
        'clinical_drafts',
        where: 'draft_key=? AND patient_id=?',
        whereArgs: [draftKey, pid],
      );
      if (!mounted) return;
      if (drafts.isNotEmpty) {
        final data =
            jsonDecode('${drafts.first['payload']}') as Map<String, dynamic>;
        for (final e in fields.entries) {
          if (data.containsKey(e.key)) e.value.text = '${data[e.key] ?? ''}';
        }
        reason.text = '${data['_revision_reason'] ?? ''}';
        if (widget.original == null)
          encounter =
              DateTime.tryParse('${data['_encounter_at'] ?? ''}') ?? encounter;
        status =
            'Borrador recuperado · ${clinicalDate(drafts.first['updated_at'])}';
      } else {
        status = 'Borrador automático · aún sin cambios';
      }
      if (widget.table == 'consultations' && widget.original == null)
        previous = await AppDb.instance.latestConsultation(pid);
      if (!mounted) return;
      for (final c in [...fields.values, reason]) {
        c.addListener(changed);
      }
      setState(() => ready = true);
    } catch (e) {
      if (mounted)
        setState(
          () => failure =
              'No se pudo cargar el borrador. Vuelve a abrir la pantalla.',
        );
    }
  }

  Future<void> reloadProfile() async {
    final value = decodeNom(await AppDb.instance.getSetting('nom_profile'));
    profile = {for (final e in value.entries) e.key: '${e.value ?? ''}'};
  }

  Future<void> configureProfile() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NomSettings()),
    );
    try {
      await reloadProfile();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) clinicalMessage(context, 'No se pudo actualizar el perfil.');
    }
  }

  Future<void> pickEncounter() async {
    final d = await showDatePicker(
      context: context,
      initialDate: encounter,
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(encounter),
    );
    if (t == null || !mounted) return;
    setState(
      () => encounter = DateTime(d.year, d.month, d.day, t.hour, t.minute),
    );
    changed();
  }

  Set<String> get visibleKeys => {
    ...noteFields[widget.table]!.where(
      (k) => widget.table != 'hospitalizations' || !k.startsWith('discharge_'),
    ),
    ...nomKeys(widget.table, input),
  };
  List<GuideSection> get sections => guideSections(visibleKeys);
  bool showField(String key) =>
      !guided ||
      sections[guideStep.clamp(0, sections.length - 1)].keys.contains(key);
  Future<void> showGuide(String key) async {
    final guide = clinicalGuides[key];
    if (guide == null) return;
    final insert = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(guide.question, style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              for (final prompt in guide.prompts) Text('• $prompt'),
              const SizedBox(height: 12),
              const Text(
                'Son preguntas de documentación. No afirman hallazgos ni indican diagnósticos o tratamientos.',
              ),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Insertar estructura para completar'),
              ),
            ],
          ),
        ),
      ),
    );
    if (insert == true && mounted) {
      final c = fields[key]!;
      c.text = [
        c.text.trim(),
        guide.outline,
      ].where((x) => x.isNotEmpty).join('\n');
    }
  }

  void selectKind(String key, String value) {
    guideStep = 0;
    fields[key]!.text = value;
    if (key == 'type' && widget.original == null) fields['title']!.text = value;
    setState(() {});
  }

  void changed() {
    if (!ready || completed) return;
    timer?.cancel();
    setState(() => status = 'Guardando borrador…');
    timer = Timer(const Duration(milliseconds: 400), () => persist());
  }

  Future<void> persist() {
    timer?.cancel();
    if (!ready || completed) return queue;
    final snapshot = input;
    queue = queue.then((_) async {
      if (completed) return;
      try {
        await ClinicalStore.saveDraft(
          draftKey,
          pid,
          widget.table,
          widget.parentId,
          snapshot,
        );
        failure = null;
        if (mounted)
          setState(
            () => status =
                'Borrador guardado · ${clinicalDate(DateTime.now().toIso8601String())}',
          );
      } catch (_) {
        failure = 'No se pudo guardar el borrador. Mantén esta pantalla abierta y reintenta.';
        if (mounted) setState(() => status = failure!);
      }
    });
    return queue;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) unawaited(persist());
  }

  Future<void> leave() async {
    if (leaving || busy) return;
    leaving = true;
    await persist();
    if (!mounted) return;
    if (failure != null && ready) {
      clinicalMessage(context, failure!);
      leaving = false;
      return;
    }
    setState(() => allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context);
  }

  Future<void> finish() async {
    if (busy || !ready) return;
    try {
      await reloadProfile();
      final freshPatient = await AppDb.instance.one('patients', pid);
      if (!mounted) return;
      final issues = nomMissing(
        table: widget.table,
        input: input,
        patient: freshPatient ?? widget.patient,
        profile: profile,
        encounter: encounter,
      );
      setState(() => missing = issues);
      if (issues.isNotEmpty) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Apartados por completar'),
            content: SizedBox(
              width: 420,
              child: SingleChildScrollView(
                child: Text(issues.map((x) => '• $x').join('\n')),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Volver a la nota'),
              ),
            ],
          ),
        );
        return;
      }
    } catch (e) {
      if (mounted) clinicalMessage(context, 'No se pudo revisar la nota: $e');
      return;
    }
    if (!mounted) return;
    final approved = await showDialog<bool>(context: context,
      builder: (_) => ClinicalNoteReview(patientName: '${widget.patient['first_name']} ${widget.patient['last_name']}',
        input: {for (final key in visibleKeys) key: fields[key]?.text ?? '', 'encounter_date': clinicalDate(encounter.toIso8601String())}));
    if (approved != true || !mounted) return;
    setState(() => busy = true);
    try {
      await persist();
      final id = await ClinicalStore.finalize(
        table: widget.table,
        pid: pid,
        input: input,
        draftKey: draftKey,
        parentId: widget.parentId,
        original: widget.original,
        reason: reason.text,
      );
      completed = true;
      timer?.cancel();
      if (!mounted) return;
      setState(() => allowPop = true);
      clinicalMessage(context, 'Nota guardada correctamente');
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context, id);
    } catch (e) {
      if (mounted)
        clinicalMessage(
          context,
          e.toString().replaceFirst('FormatException: ', ''),
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> discard() async {
    if (busy ||
        !await clinicalConfirm(
          context,
          'Descartar borrador',
          'Se eliminará solo este borrador. Las notas finalizadas permanecen intactas.',
        ))
      return;
    if (!mounted) return;
    setState(() => busy = true);
    timer?.cancel();
    await queue;
    try {
      final db = await AppDb.instance.database;
      await db.delete(
        'clinical_drafts',
        where: 'draft_key=? AND patient_id=?',
        whereArgs: [draftKey, pid],
      );
      completed = true;
      if (!mounted) return;
      setState(() => allowPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) clinicalMessage(context, 'No se pudo descartar.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> copySelected(Map<String, Object?> data) async {
    data = {...data, ...nomInput(data)};
    final choices = {
      for (final k in fields.keys.where(
        (k) =>
            visibleKeys.contains(k) &&
            !numericFields.contains(k) &&
            !{
              'type',
              'title',
              'nom_kind',
              'nom_signer',
              'nom_relationship',
              'nom_witness1',
              'nom_witness2',
            }.contains(k) &&
            '${data[k] ?? ''}'.isNotEmpty,
      ))
        k: false,
    };
    final selected = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Selecciona qué reutilizar'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Verifica cada dato para esta atención. Los signos vitales anteriores no se copian.',
                  ),
                  for (final key in choices.keys)
                    CheckboxListTile(
                      value: choices[key],
                      title: Text(clinicalLabels[key] ?? key),
                      subtitle: Text(
                        '${data[key]}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onChanged: (v) =>
                          setDialog(() => choices[key] = v ?? false),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Usar seleccionados'),
            ),
          ],
        ),
      ),
    );
    if (selected == true && mounted) {
      for (final key in choices.keys) {
        if (choices[key]!) fields[key]!.text = '${data[key]}';
      }
    }
  }

  Future<void> templates() async {
    try {
      final rows = await AppDb.instance.all(
        'clinical_templates',
        where: 'table_name=?',
        args: [widget.table],
        orderBy: 'name',
      );
      if (!mounted) return;
      if (rows.isEmpty) {
        clinicalMessage(
          context,
          'No hay plantillas. Usa “Guardar como plantilla” para crear una.',
        );
        return;
      }
      final row = await showModalBottomSheet<Map<String, Object?>>(
        context: context,
        builder: (ctx) => SafeArea(
          child: ListView(
            children: [
              const ListTile(title: Text('Plantillas personales')),
              for (final r in rows)
                ListTile(
                  title: Text('${r['name']}'),
                  onTap: () => Navigator.pop(ctx, r),
                ),
            ],
          ),
        ),
      );
      if (row != null && mounted)
        await copySelected(
          Map<String, Object?>.from(jsonDecode('${row['payload']}') as Map),
        );
    } catch (_) {
      if (mounted)
        clinicalMessage(context, 'No se pudieron abrir las plantillas.');
    }
  }

  Future<void> saveTemplate() async {
    final name = await askClinicalText(context, 'Nombre de la plantilla');
    if (name == null || name.isEmpty) return;
    try {
      final data = {
        for (final e in fields.entries)
          if (visibleKeys.contains(e.key) &&
              !numericFields.contains(e.key) &&
              !{
                'type',
                'title',
                'nom_kind',
                'nom_signer',
                'nom_relationship',
                'nom_witness1',
                'nom_witness2',
              }.contains(e.key))
            e.key: e.value.text,
      };
      await AppDb.instance.insert('clinical_templates', {
        'name': name,
        'table_name': widget.table,
        'payload': jsonEncode(data),
        'created_at': DateTime.now().toIso8601String(),
      });
      if (mounted)
        clinicalMessage(
          context,
          'Plantilla guardada. No incluyas datos personales en plantillas reutilizables.',
        );
    } catch (_) {
      if (mounted) clinicalMessage(context, 'No se pudo guardar la plantilla.');
    }
  }

  Future<void> cie() async {
    final row = await Navigator.push<Map<String, Object?>>(context,
      MaterialPageRoute(builder: (_) => const ClinicalCieScreen(select: true)));
    if (row != null && mounted) {
      final c = fields['diagnoses']!;
      c.text = [c.text, '${BundledCie.displayCode('${row['code']}')} · ${row['name']}']
          .where((x) => x.isNotEmpty).join('\n');
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    for (final c in [...fields.values, reason]) {
      c.removeListener(changed);
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allergies = '${widget.patient['allergies'] ?? ''}'.trim();
    return PopScope(
      canPop: allowPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) leave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            '${widget.original == null ? 'Nueva atención' : 'Corregir nota'} · ${noteNames[widget.table]}',
          ),
          actions: [
            PopupMenuButton<String>(
              enabled: ready && !busy,
              onSelected: (v) {
                if (v == 'template') saveTemplate();
                if (v == 'discard') discard();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'template',
                  child: Text('Guardar como plantilla'),
                ),
                const PopupMenuItem(
                  value: 'discard',
                  child: Text('Descartar borrador'),
                ),
              ],
            ),
          ],
        ),
        body: !ready
            ? Center(
                child: failure == null
                    ? const CircularProgressIndicator()
                    : Text(failure!),
              )
            : AbsorbPointer(
                absorbing: busy,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      '${widget.patient['first_name']} ${widget.patient['last_name']}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    clinicalPanel(context, 'Documentación clínica · NOM-004', [
                      Text(
                        'Responsable: ${profile['doctor'] ?? 'Configura el perfil'}',
                      ),
                      Text(
                        'Establecimiento: ${profile['establishment'] ?? 'Pendiente'}',
                      ),
                      TextButton(
                        onPressed: configureProfile,
                        child: const Text(
                          'Configurar médico y establecimiento',
                        ),
                      ),
                      Text(
                        'Atención: ${clinicalDate(encounter.toIso8601String())}',
                      ),
                      if (widget.original == null)
                        TextButton(
                          onPressed: pickEncounter,
                          child: const Text('Cambiar fecha y hora de atención'),
                        ),
                      const Text(
                        'Registra hallazgos reales en lenguaje médico y sin abreviaturas. Si no hay estudios o medicamentos, documenta esa situación; no se rellenan datos automáticamente.',
                      ),
                      const Text(
                        'Firma autógrafa pendiente: imprime y firma. Guardar la nota no la firma.',
                      ),
                      if (missing.isNotEmpty)
                        Text(
                          'Pendientes: ${missing.join(', ')}',
                          style: const TextStyle(color: Colors.orange),
                        ),
                    ]),
                    if (widget.table == 'consultations')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: DropdownButtonFormField<String>(
                          value: fields['nom_kind']!.text,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de atención',
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Historia clínica inicial',
                              child: Text('Historia clínica inicial'),
                            ),
                            DropdownMenuItem(
                              value: 'Evolución ambulatoria',
                              child: Text('Evolución ambulatoria'),
                            ),
                          ],
                          onChanged:
                              widget.original != null &&
                                  nomInput(widget.original)['nom_kind'] != null
                              ? null
                              : (v) {
                                  if (v != null) selectKind('nom_kind', v);
                                },
                        ),
                      ),
                    if (widget.table == 'documents')
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: DropdownButtonFormField<String>(
                          value: fields['type']!.text,
                          decoration: const InputDecoration(
                            labelText: 'Tipo de documento',
                          ),
                          items: [
                            for (final type in {
                              ...nomDocTypes.where(
                                (x) =>
                                    x != 'Nota de egreso' ||
                                    widget.parentId != null ||
                                    widget.documentType == 'Nota de egreso',
                              ),
                              fields['type']!.text,
                            })
                              DropdownMenuItem(value: type, child: Text(type)),
                          ],
                          onChanged:
                              widget.original != null ||
                                  widget.documentType != null
                              ? null
                              : (v) {
                                  if (v != null) selectKind('type', v);
                                },
                        ),
                      ),
                    if (widget.table == 'documents' &&
                        [
                          'Consentimiento informado',
                          'Egreso voluntario',
                        ].contains(fields['type']!.text))
                      clinicalPanel(context, 'Documento para recabar firmas', [
                        const Text(
                          'Este formato registra la información explicada. Imprime y recaba las firmas del paciente o representante, médico y dos testigos. Adjunta el documento firmado en Estudios. El formato sin firmas no acredita el consentimiento.',
                        ),
                      ]),
                    if (allergies.isNotEmpty)
                      clinicalPanel(context, 'Alergias', [
                        Text(
                          allergies,
                          style: const TextStyle(color: Colors.orange),
                        ),
                      ]),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        failure == null
                            ? Icons.cloud_done_outlined
                            : Icons.warning_amber,
                      ),
                      title: Text(status),
                      subtitle: const Text(
                        'El borrador no es una nota finalizada.',
                      ),
                      trailing: IconButton(
                        tooltip: 'Guardar borrador ahora',
                        onPressed: persist,
                        icon: const Icon(Icons.save_outlined),
                      ),
                    ),
                    if (widget.original != null)
                      clinicalPanel(context, 'Corrección con trazabilidad', [
                        const Text(
                          'Se conserva la versión anterior. La fecha original de la atención no cambia.',
                        ),
                        TextField(
                          controller: reason,
                          decoration: const InputDecoration(
                            labelText: 'Motivo de la corrección *',
                          ),
                          minLines: 1,
                          maxLines: 3,
                        ),
                      ]),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('Plantillas'),
                          avatar: const Icon(Icons.library_books_outlined),
                          onPressed: templates,
                        ),
                        if (fields.containsKey('diagnoses'))
                          ActionChip(
                            label: const Text('CIE-10'),
                            onPressed: cie,
                          ),
                        if (previous != null)
                          ActionChip(
                            label: const Text('Reutilizar datos seleccionados'),
                            onPressed: () => copySelected(previous!),
                          ),
                      ],
                    ),
                    if (previous != null)
                      ExpansionTile(
                        title: Text(
                          'Consulta anterior · ${clinicalDate(previous!['date'])}',
                        ),
                        children: [
                          for (final field in clinicalFields(previous!))
                            ListTile(
                              title: Text(field.key),
                              subtitle: Text(field.value),
                            ),
                        ],
                      ),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Llenado guiado'),
                      subtitle: const Text(
                        'Un apartado a la vez; las sugerencias no completan hallazgos.',
                      ),
                      value: guided,
                      onChanged: (v) => setState(() {
                        guided = v;
                        guideStep = 0;
                      }),
                    ),
                    if (guided) ...[
                      Text('Paso ${guideStep + 1} de ${sections.length}', style: Theme.of(context).textTheme.labelLarge),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(value: (guideStep + 1) / sections.length),
                      const SizedBox(height: 12),
                    ],
                    if (guided)
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (var i = 0; i < sections.length; i++)
                            ChoiceChip(
                              label: Text('${i + 1}. ${sections[i].title}'),
                              selected: guideStep == i,
                              onSelected: (_) => setState(() => guideStep = i),
                            ),
                        ],
                      ),
                    const SizedBox(height: 16),
                    for (final e in fields.entries.where(
                      (e) =>
                          visibleKeys.contains(e.key) &&
                          showField(e.key) &&
                          !numericFields.contains(e.key) &&
                          !{'type', 'nom_kind'}.contains(e.key),
                    ))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: TextField(
                          controller: e.value,
                          minLines: 1,
                          maxLines: e.key == 'content' ? 14 : 6,
                          decoration: InputDecoration(
                            labelText:
                                nomLabels[e.key] ??
                                clinicalLabels[e.key] ??
                                e.key,
                            helperText:
                                e.key == 'physical_exam' || e.key == 'exam'
                                ? 'Incluye habitus exterior y exploración por regiones; documenta lo no explorado y el motivo.'
                                : e.key == 'nom_pathological'
                                ? 'Incluye tabaco, alcohol, otras sustancias y tratamientos previos.'
                                : null,
                            suffixIcon: clinicalGuides.containsKey(e.key)
                                ? IconButton(
                                    tooltip: 'Preguntas y estructura',
                                    onPressed: () => showGuide(e.key),
                                    icon: const Icon(Icons.lightbulb_outline),
                                  )
                                : null,
                            alignLabelWithHint: true,
                          ),
                        ),
                      ),
                    if (visibleKeys.any(
                      (k) => numericFields.contains(k) && showField(k),
                    ))
                      clinicalPanel(context, 'Mediciones de esta atención', [
                        LayoutBuilder(
                          builder: (context, constraints) => Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              for (final e in fields.entries.where(
                                (e) =>
                                    visibleKeys.contains(e.key) &&
                                    showField(e.key) &&
                                    numericFields.contains(e.key),
                              ))
                                SizedBox(
                                  width: constraints.maxWidth > 580
                                      ? (constraints.maxWidth - 24) / 3
                                      : (constraints.maxWidth - 12) / 2,
                                  child: TextField(
                                    controller: e.value,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: InputDecoration(
                                      labelText:
                                          nomLabels[e.key] ??
                                          clinicalLabels[e.key] ??
                                          e.key,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ]),
                    const SizedBox(height: 24),
                    if (guided)
                      Row(
                        children: [
                          if (guideStep > 0)
                            TextButton(
                              onPressed: () => setState(() => guideStep--),
                              child: const Text('Anterior'),
                            ),
                          const Spacer(),
                          if (guideStep < sections.length - 1)
                            FilledButton(
                              onPressed: () => setState(() => guideStep++),
                              child: const Text('Continuar'),
                            ),
                        ],
                      ),
                    if (!guided || guideStep == sections.length - 1)
                      FilledButton.icon(
                        onPressed: busy ? null : finish,
                        icon: const Icon(Icons.check_circle_outline),
                        label: Text(
                          busy ? 'Guardando…' : 'Finalizar y guardar nota',
                        ),
                      ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
      ),
    );
  }
}

class HospitalNoteEditor extends StatelessWidget {
  final int hid;
  final String table;
  const HospitalNoteEditor({super.key, required this.hid, required this.table});
  Future<Map<String, Object?>?> patient() async {
    final h = await AppDb.instance.one('hospitalizations', hid);
    if (h == null) return null;
    return AppDb.instance.one('patients', h['patient_id'] as int);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, Object?>?>(
    future: patient(),
    builder: (context, s) {
      if (s.connectionState != ConnectionState.done)
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (s.hasError || s.data == null)
        return Scaffold(
          appBar: AppBar(),
          body: const Center(
            child: Text('No se pudo abrir la hospitalización.'),
          ),
        );
      return ClinicalEditor(patient: s.data!, table: table, parentId: hid);
    },
  );
}
