import 'clinical_scales_screen.dart';
import 'clinical_patient_design.dart';
import 'package:flutter/material.dart';

import 'db.dart';
import 'main.dart' as app;
import 'prescription.dart';
import 'clinical_store.dart';
import 'clinical_record.dart';
import 'clinical_record_view.dart';
import 'clinical_editor.dart';
import 'clinical_extras.dart';
import 'clinical_ui.dart';

class ModernPatientHub extends StatefulWidget {
  final int pid;
  const ModernPatientHub({super.key, required this.pid});
  @override
  State<ModernPatientHub> createState() => _ModernPatientHubState();
}

class _ModernPatientHubState extends State<ModernPatientHub> {
  Map<String, Object?>? patient;
  List<Map<String, Object?>> events = [], drafts = [], appointments = [];
  String query = '', kind = 'Todos';
  String? error;
  bool busy = false;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final p = await AppDb.instance.one('patients', widget.pid);
      if (p == null) throw StateError('No se encontró el paciente.');
      final e = await AppDb.instance.timeline(widget.pid);
      final d = await AppDb.instance.all(
        'clinical_drafts',
        where: 'patient_id=?',
        args: [widget.pid],
        orderBy: 'updated_at DESC',
      );
      final a = await AppDb.instance.all(
        'appointments',
        where: 'patient_id=?',
        args: [widget.pid],
        orderBy: 'start_at DESC',
      );
      if (mounted)
        setState(() {
          patient = p;
          events = e;
          drafts = d;
          appointments = a;
          error = null;
          generation++;
        });
    } catch (_) {
      if (mounted)
        setState(
          () => error = 'No se pudo cargar el expediente. Pulsa actualizar.',
        );
    }
  }

  Future<void> route(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await load();
  }

  Future<void> open(Map<String, Object?> e) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final r = await ClinicalStore.readEvent(e, widget.pid);
      if (!mounted) return;
      await route(
        ClinicalRecordView(
          patient: patient!,
          record: r,
          title: '${e['type']}',
          table: '${e['table']}',
        ),
      );
    } catch (_) {
      if (mounted)
        clinicalMessage(
          context,
          'No se pudo abrir la nota. Actualiza el expediente.',
        );
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> resume(Map<String, Object?> d) async {
    try {
      final parts = '${d['draft_key']}'.split(':');
      final id = int.tryParse(parts.last) ?? 0;
      Map<String, Object?>? original;
      if (id != 0)
        original = await ClinicalStore.readEvent({
          'table': d['table_name'],
          'id': id,
        }, widget.pid);
      if (!mounted) return;
      await route(
        ClinicalEditor(
          patient: patient!,
          table: '${d['table_name']}',
          parentId: d['parent_id'] as int?,
          original: original,
        ),
      );
    } catch (_) {
      if (mounted)
        clinicalMessage(context, 'No se pudo recuperar el borrador.');
    }
  }

  Widget actions() => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: [
      OutlinedButton.icon(
        onPressed: () => route(ClinicalScalesScreen(patient: patient!)),
        icon: const Icon(Icons.calculate_outlined), label: const Text('Escalas'),
      ),
      FilledButton.icon(
        onPressed: () =>
            route(ClinicalEditor(patient: patient!, table: 'consultations')),
        icon: const Icon(Icons.add),
        label: const Text('Consulta'),
      ),
      OutlinedButton.icon(
        onPressed: () => route(PrescriptionForm(patient: patient!)),
        icon: const Icon(Icons.medication_outlined),
        label: const Text('Receta'),
      ),
      OutlinedButton.icon(
        onPressed: () => route(app.AppointmentForm(patient: patient!)),
        icon: const Icon(Icons.event_available_outlined),
        label: const Text('Agendar'),
      ),
      OutlinedButton.icon(
        onPressed: () =>
            route(ClinicalEditor(patient: patient!, table: 'emergencies')),
        icon: const Icon(Icons.emergency_outlined),
        label: const Text('Urgencias'),
      ),
      OutlinedButton.icon(
        onPressed: () =>
            route(ClinicalEditor(patient: patient!, table: 'hospitalizations')),
        icon: const Icon(Icons.bed_outlined),
        label: const Text('Ingresar'),
      ),
      OutlinedButton.icon(
        onPressed: () =>
            route(ClinicalEditor(patient: patient!, table: 'documents')),
        icon: const Icon(Icons.description_outlined),
        label: const Text('Documento'),
      ),
    ],
  );
  Widget summary() {
    final p = patient!;
    final assessments = events.where((e) => {'consultations', 'emergencies', 'hospitalizations', 'progress_notes'}.contains(e['table'])).toList();
    final lastAssessment = assessments.isEmpty ? null : assessments.first;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        actions(),
        const SizedBox(height: 20),
        ClinicalPatientOverview(patient: p, lastAssessment: lastAssessment,
          onOpenAssessment: lastAssessment == null ? null : () => open(lastAssessment)),
        const SizedBox(height: 12),
        if (drafts.isNotEmpty)
          clinicalPanel(context, 'Borradores pendientes · ${drafts.length}', [
            for (final d in drafts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.edit_note),
                title: Text(noteNames[d['table_name']] ?? 'Borrador'),
                subtitle: Text(clinicalDate(d['updated_at'])),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => resume(d),
              ),
          ]),
        clinicalPanel(context, 'Resumen clínico', [
          for (final e in const {
            'dob': 'Nacimiento',
            'sex': 'Sexo',
            'blood_type': 'Grupo sanguíneo',
            
            'family_history': 'Antecedentes familiares',
            'surgical_history': 'Antecedentes quirúrgicos',
            
            'notes': 'Notas generales',
          }.entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(e.value),
              subtitle: SelectableText(
                '${p[e.key] ?? ''}'.trim().isEmpty
                    ? 'Sin registro'
                    : '${p[e.key]}',
              ),
            ),
        ]),
        clinicalPanel(context, 'Contacto e identificación', [
          for (final e in const {
            'phone': 'Teléfono',
            'curp': 'CURP',
            'address': 'Dirección',
            'occupation': 'Ocupación',
            'emergency_contact': 'Contacto de emergencia',
            'emergency_phone': 'Teléfono de emergencia',
          }.entries)
            if ('${p[e.key] ?? ''}'.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(e.value),
                subtitle: SelectableText('${p[e.key]}'),
              ),
        ]),
        if (events.isNotEmpty)
          clinicalPanel(context, 'Última atención', [
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${events.first['type']} · ${clinicalDate(events.first['date'])}',
              ),
              subtitle: Text('${events.first['text'] ?? ''}'),
              onTap: () => open(events.first),
              trailing: const Icon(Icons.chevron_right),
            ),
          ]),
      ],
    );
  }

  Widget history() {
    final visible = events
        .where(
          (e) =>
              (kind == 'Todos' || e['table'] == kind) &&
              matchesClinical({
                ...e,
                'search': '${e['search']} ${clinicalDate(e['date'])}',
              }, query),
        )
        .toList();
    return CustomScrollView(slivers: [
      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        TextField(decoration: const InputDecoration(labelText: 'Buscar en todo el expediente', prefixIcon: Icon(Icons.search)), onChanged: (v) => setState(() => query = v)),
        const SizedBox(height: 12),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          for (final entry in {'Todos': 'Todos', ...noteNames}.entries)
            Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(entry.value), selected: kind == entry.key, onSelected: (_) => setState(() => kind = entry.key))),
        ])),
        Row(children: [Expanded(child: Text('${visible.length} de ${events.length} registros')),
          IconButton(tooltip: 'Exportar selección', onPressed: () => route(ClinicalExport(patient: patient!, events: events)), icon: const Icon(Icons.picture_as_pdf_outlined)),
        ]),
        if (busy) const LinearProgressIndicator(),
      ]))),
      if (visible.isEmpty) const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(24), child: Text('Sin registros para esta búsqueda')))
      else SliverPadding(padding: const EdgeInsets.symmetric(horizontal: 12), sliver: SliverList.builder(itemCount: visible.length, itemBuilder: (context, i) => ClinicalTimelineTile(event: visible[i], onTap: busy ? null : () => open(visible[i])))),
    ]);
  }

  Widget treatment() => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      clinicalPanel(context, 'Medicación habitual', [
        SelectableText('${patient!['chronic_meds'] ?? 'Sin registro'}'),
        TextButton.icon(
          onPressed: () => route(app.PatientForm(patient: patient!)),
          icon: const Icon(Icons.edit_outlined),
          label: const Text('Actualizar medicación habitual'),
        ),
      ]),
      FilledButton.icon(
        onPressed: () => route(PrescriptionForm(patient: patient!)),
        icon: const Icon(Icons.add),
        label: const Text('Crear receta'),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Text(
          'Prescripciones anteriores. No implican que el tratamiento siga vigente.',
        ),
      ),
      for (final e in events.where(
        (e) => e['type'] == 'Receta' || e['table'] == 'medical_orders',
      ))
        Card(
          child: ListTile(
            title: Text('${e['type']} · ${clinicalDate(e['date'])}'),
            subtitle: Text('${e['text'] ?? ''}', maxLines: 2),
            onTap: () => open(e),
            trailing: const Icon(Icons.chevron_right),
          ),
        ),
      clinicalPanel(context, 'Citas de este paciente', [
        for (final a in appointments.take(20))
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(clinicalDate(a['start_at'])),
            subtitle: Text('${a['reason']} · ${a['status']}'),
          ),
        TextButton(
          onPressed: () => route(const app.AppointmentsScreen()),
          child: const Text('Abrir agenda para gestionar citas'),
        ),
      ]),
    ],
  );
  @override
  Widget build(BuildContext context) {
    if (patient == null)
      return Scaffold(
        appBar: AppBar(title: const Text('Expediente')),
        body: Center(
          child: error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(error!),
                    TextButton(
                      onPressed: load,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
        ),
      );
    final p = patient!;
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Expediente clínico'),
          actions: [
            IconButton(
              tooltip: 'Editar paciente',
              onPressed: () => route(app.PatientForm(patient: p)),
              icon: const Icon(Icons.manage_accounts_outlined),
            ),
            IconButton(
              tooltip: 'Exportar atenciones',
              onPressed: () =>
                  route(ClinicalExport(patient: p, events: events)),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
            IconButton(
              tooltip: 'Actualizar',
              onPressed: load,
              icon: const Icon(Icons.refresh),
            ),
            PopupMenuButton<String>(
              onSelected: (_) async {
                await showModalBottomSheet(
                  context: context,
                  builder: (_) => app.PatientStatusSheet(patient: p),
                );
                await load();
              },
              itemBuilder: (_) => [
                const PopupMenuItem(
                  value: 'status',
                  child: Text('Estado del paciente'),
                ),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            ClinicalPatientBanner(patient: p, events: events.length, drafts: drafts.length),
            if (error != null)
              Text(error!, style: const TextStyle(color: Colors.orange)),
            const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Resumen'),
                Tab(text: 'Atenciones'),
                Tab(text: 'Estudios'),
                Tab(text: 'Tratamiento'),
                Tab(text: 'Seguimiento'),
                Tab(text: 'Pendientes'),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  summary(),
                  history(),
                  PatientAttachments(
                    key: ValueKey('a$generation'),
                    pid: widget.pid,
                  ),
                  treatment(),
                  PatientTrends(key: ValueKey('m$generation'), pid: widget.pid),
                  ClinicalTasks(key: ValueKey('t$generation'), pid: widget.pid),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
