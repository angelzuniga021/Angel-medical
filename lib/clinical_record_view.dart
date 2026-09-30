import 'dart:convert';

import 'package:flutter/material.dart';

import 'db.dart';
import 'clinical_record.dart';
import 'clinical_editor.dart';
import 'clinical_store.dart';
import 'clinical_ui.dart';
import 'clinical_nom.dart';
import 'services.dart';

class ClinicalRecordView extends StatefulWidget {
  final Map<String, Object?> patient, record;
  final String title;
  final String? table;
  const ClinicalRecordView({
    super.key,
    required this.patient,
    required this.record,
    required this.title,
    this.table,
  });
  @override
  State<ClinicalRecordView> createState() => _ClinicalRecordViewState();
}

class _ClinicalRecordViewState extends State<ClinicalRecordView> {
  late Map<String, Object?> record;
  List<Map<String, Object?>> revisions = [];
  bool printing = false;
  @override
  void initState() {
    super.initState();
    record = widget.record;
    loadRevisions();
  }

  Future<void> loadRevisions() async {
    if (widget.table == null) return;
    try {
      final rows = await AppDb.instance.all(
        'clinical_revisions',
        where: 'table_name=? AND record_id=? AND patient_id=?',
        args: [widget.table, record['id'], widget.patient['id']],
        orderBy: 'created_at DESC',
      );
      if (mounted) setState(() => revisions = rows);
    } catch (_) {
      if (mounted)
        clinicalMessage(context, 'No se pudo cargar el historial de cambios.');
    }
  }

  Future<void> edit() async {
    if (widget.table == null) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ClinicalEditor(
          patient: widget.patient,
          table: widget.table!,
          original: record,
          parentId:
              (record['hospitalization_id'] ??
                      decodeNom(record['nom_json'])['hospitalization_id'])
                  as int?,
        ),
      ),
    );
    try {
      final next = await ClinicalStore.readEvent({
        'table': widget.table,
        'id': record['id'],
      }, widget.patient['id'] as int);
      if (mounted) setState(() => record = next);
      await loadRevisions();
    } catch (_) {
      if (mounted)
        clinicalMessage(
          context,
          'No se pudo actualizar la nota. Vuelve al expediente.',
        );
    }
  }

  Future<void> printRecord() async {
    setState(() => printing = true);
    try {
      await PdfService.printClinical(
        title: widget.title,
        patient: widget.patient,
        record: record,
        fields: [
          ...clinicalFields(record),
          if (revisions.isNotEmpty)
            MapEntry(
              'Correcciones',
              '${revisions.length}; última: ${clinicalDate(revisions.first['created_at'])}. Esta impresión muestra la versión actual.',
            ),
        ],
      );
    } catch (_) {
      if (mounted)
        clinicalMessage(
          context,
          'No se pudo generar el PDF. La nota sigue guardada.',
        );
    } finally {
      if (mounted) setState(() => printing = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title),
      actions: [
        if (widget.table != null)
          IconButton(
            tooltip: 'Corregir con historial',
            onPressed: printing ? null : edit,
            icon: const Icon(Icons.edit_note),
          ),
        IconButton(
          tooltip: 'Imprimir / PDF',
          onPressed: printing ? null : printRecord,
          icon: const Icon(Icons.print_outlined),
        ),
      ],
    ),
    body: SelectionArea(
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            '${widget.patient['first_name']} ${widget.patient['last_name']}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          if (printing) const LinearProgressIndicator(),
          if (revisions.isNotEmpty)
            clinicalPanel(context, 'Historial de correcciones', [
              for (final r in revisions)
                ExpansionTile(
                  title: Text(clinicalDate(r['created_at'])),
                  subtitle: Text('${r['reason']}'),
                  children: [
                    for (final field in clinicalFields(
                      Map<String, Object?>.from(
                        jsonDecode('${r['before_json']}') as Map,
                      ),
                    ))
                      ListTile(
                        title: Text('${field.key} · antes'),
                        subtitle: Text(field.value),
                      ),
                    const Divider(),
                    for (final field in clinicalFields(
                      Map<String, Object?>.from(
                        jsonDecode('${r['after_json']}') as Map,
                      ),
                    ))
                      ListTile(
                        title: Text('${field.key} · después'),
                        subtitle: Text(field.value),
                      ),
                  ],
                ),
            ]),
          for (final f in clinicalFields(record))
            clinicalPanel(context, f.key, [Text(f.value)]),
        ],
      ),
    ),
  );
}
