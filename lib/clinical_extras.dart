import 'clinical_nom.dart';

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart' show sha256;
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'db.dart';
import 'clinical_record.dart';
import 'clinical_store.dart';
import 'clinical_ui.dart';

class PatientAttachments extends StatefulWidget {
  final int pid;
  const PatientAttachments({super.key, required this.pid});
  @override
  State<PatientAttachments> createState() => _PatientAttachmentsState();
}

class _PatientAttachmentsState extends State<PatientAttachments> {
  List<Map<String, Object?>> rows = [];
  bool loading = true, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final db = await AppDb.instance.database;
      final data = await db.query(
        'clinical_attachments',
        columns: ['id', 'name', 'description', 'mime', 'created_at'],
        where: 'patient_id=?',
        whereArgs: [widget.pid],
        orderBy: 'created_at DESC',
      );
      if (mounted)
        setState(() {
          rows = data;
          loading = false;
          error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          error = 'No se pudieron cargar los adjuntos.';
          loading = false;
        });
    }
  }

  Future<void> add() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final pick = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp'],
        withData: false,
      );
      if (pick == null) return;
      final file = pick.files.single;
      if (file.size > 8 * 1024 * 1024)
        throw const FormatException('Máximo 8 MB por archivo.');
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      if (bytes.length > 8 * 1024 * 1024)
        throw const FormatException('Máximo 8 MB por archivo.');
      final ext = file.name.split('.').last.toLowerCase();
      final pdf =
          bytes.length > 4 &&
          ascii.decode(bytes.take(4).toList(), allowInvalid: true) == '%PDF';
      final png =
          bytes.length > 8 &&
          bytes[0] == 137 &&
          bytes[1] == 80 &&
          bytes[2] == 78 &&
          bytes[3] == 71;
      final jpg =
          bytes.length > 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255;
      final webp =
          bytes.length > 12 &&
          ascii.decode(bytes.sublist(0, 4), allowInvalid: true) == 'RIFF' &&
          ascii.decode(bytes.sublist(8, 12), allowInvalid: true) == 'WEBP';
      if (!(pdf && ext == 'pdf' ||
          png && ext == 'png' ||
          jpg && {'jpg', 'jpeg'}.contains(ext) ||
          webp && ext == 'webp'))
        throw const FormatException(
          'El contenido no corresponde a un PDF o imagen admitida.',
        );
      if (!mounted) return;
      final description = await askClinicalText(
        context,
        'Descripción del estudio o fotografía',
      );
      if (description == null) return;
      final db = await AppDb.instance.database;
      await db.transaction((tx) async {
        final total =
            (await tx.rawQuery(
                  'SELECT COALESCE(SUM(length(data)),0) AS n FROM clinical_attachments',
                )).first['n']
                as int;
        if (total + bytes.length > 100 * 1024 * 1024)
          throw const FormatException(
            'Límite de adjuntos: 100 MB para mantener los respaldos manejables.',
          );
        final digest = sha256.convert(bytes).toString();
        final same = await tx.query(
          'clinical_attachments',
          columns: ['id'],
          where: 'patient_id=? AND sha256=?',
          whereArgs: [widget.pid, digest],
        );
        if (same.isNotEmpty)
          throw const FormatException('Este archivo ya está en el expediente.');
        await tx.insert('clinical_attachments', {
          'patient_id': widget.pid,
          'name': file.name,
          'description': description,
          'mime': pdf
              ? 'application/pdf'
              : png
              ? 'image/png'
              : jpg
              ? 'image/jpeg'
              : 'image/webp',
          'data': bytes,
          'sha256': digest,
          'created_at': DateTime.now().toIso8601String(),
        });
      });
      await load();
    } catch (e) {
      if (mounted) clinicalMessage(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> open(Map<String, Object?> meta) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final db = await AppDb.instance.database;
      final records = await db.query(
        'clinical_attachments',
        where: 'id=? AND patient_id=?',
        whereArgs: [meta['id'], widget.pid],
      );
      if (records.isEmpty) throw StateError('Adjunto no encontrado');
      final data = Uint8List.fromList(records.single['data'] as List<int>);
      if (sha256.convert(data).toString() != records.single['sha256'])
        throw StateError('El archivo no pasó la verificación de integridad.');
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: Text('${meta['name']}')),
            body: meta['mime'] == 'application/pdf'
                ? PdfPreview(
                    build: (_) => data,
                    allowSharing: false,
                    canChangeOrientation: false,
                    canChangePageFormat: false,
                  )
                : Center(
                    child: InteractiveViewer(
                      maxScale: 6,
                      child: Image.memory(
                        data,
                        errorBuilder: (_, __, ___) =>
                            const Text('No se pudo mostrar la imagen.'),
                      ),
                    ),
                  ),
          ),
        ),
      );
    } catch (e) {
      if (mounted) clinicalMessage(context, e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      FilledButton.icon(
        onPressed: busy ? null : add,
        icon: const Icon(Icons.attach_file),
        label: const Text('Agregar estudio o fotografía'),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'PDF e imágenes · Hasta 8 MB por archivo. Incluidos en el respaldo cifrado.',
        ),
      ),
      if (loading || busy) const LinearProgressIndicator(),
      if (error != null) Text(error!),
      if (!loading && rows.isEmpty)
        const ListTile(title: Text('Todavía no hay adjuntos')),
      for (final r in rows)
        Card(
          child: ListTile(
            leading: Icon(
              r['mime'] == 'application/pdf'
                  ? Icons.picture_as_pdf_outlined
                  : Icons.image_outlined,
            ),
            title: Text('${r['name']}'),
            subtitle: Text(
              '${r['description']}\n${clinicalDate(r['created_at'])}',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_right),
            onTap: () => open(r),
          ),
        ),
    ],
  );
}

class ClinicalTasks extends StatefulWidget {
  final int? pid;
  const ClinicalTasks({super.key, this.pid});
  @override
  State<ClinicalTasks> createState() => _ClinicalTasksState();
}

class _ClinicalTasksState extends State<ClinicalTasks> {
  List<Map<String, Object?>> rows = [];
  bool busy = false, showDone = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final db = await AppDb.instance.database;
      final data = await db.rawQuery(
        'SELECT t.*, p.first_name, p.last_name FROM clinical_tasks t JOIN patients p ON p.id=t.patient_id ${widget.pid == null ? '' : 'WHERE t.patient_id=?'} ORDER BY t.status, COALESCE(t.due_at,t.created_at)',
        widget.pid == null ? [] : [widget.pid],
      );
      if (mounted)
        setState(() {
          rows = data;
          error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() => error = 'No se pudieron cargar los pendientes.');
    }
  }

  Future<void> add() async {
    if (busy || widget.pid == null) return;
    final title = await askClinicalText(
      context,
      'Pendiente: estudio, resultado o seguimiento',
    );
    if (title == null || title.isEmpty || !mounted) return;
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) return;
    final notes = await askClinicalText(context, 'Observaciones (opcional)');
    if (notes == null || !mounted) return;
    setState(() => busy = true);
    try {
      final now = DateTime.now().toIso8601String();
      await AppDb.instance.insert('clinical_tasks', {
        'patient_id': widget.pid,
        'title': title,
        'notes': notes,
        'due_at': date.toIso8601String(),
        'status': 'pendiente',
        'created_at': now,
        'updated_at': now,
      });
      await load();
    } catch (_) {
      if (mounted) clinicalMessage(context, 'No se pudo guardar el pendiente.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> toggle(Map<String, Object?> row) async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await AppDb.instance.update('clinical_tasks', {
        'status': row['status'] == 'pendiente' ? 'resuelto' : 'pendiente',
        'updated_at': DateTime.now().toIso8601String(),
      }, row['id'] as int);
      await load();
    } catch (_) {
      if (mounted) clinicalMessage(context, 'No se pudo cambiar el estado.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final visible = rows
        .where((r) => showDone || r['status'] == 'pendiente')
        .toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.pid != null)
          FilledButton.icon(
            onPressed: busy ? null : add,
            icon: const Icon(Icons.add_task),
            label: const Text('Agregar pendiente'),
          ),
        SwitchListTile(
          title: const Text('Mostrar resueltos'),
          value: showDone,
          onChanged: (v) => setState(() => showDone = v),
        ),
        const Text(
          'Los pendientes se consultan aquí y en Inicio. Las notificaciones corresponden a las citas de la agenda.',
        ),
        if (error != null) Text(error!),
        if (busy) const LinearProgressIndicator(),
        if (visible.isEmpty)
          const ListTile(
            leading: Icon(Icons.check_circle_outline),
            title: Text('Sin pendientes en esta vista'),
          ),
        for (final r in visible)
          Card(
            child: CheckboxListTile(
              value: r['status'] == 'resuelto',
              onChanged: busy ? null : (_) => toggle(r),
              title: Text('${r['title']}'),
              subtitle: Text(
                '${widget.pid == null ? '${r['first_name']} ${r['last_name']}\n' : ''}${clinicalDate(r['due_at']).split(' ').first}\n${r['notes']}',
              ),
              isThreeLine: true,
            ),
          ),
      ],
    );
  }
}

class PatientTrends extends StatefulWidget {
  final int pid;
  const PatientTrends({super.key, required this.pid});
  @override
  State<PatientTrends> createState() => _PatientTrendsState();
}

class _PatientTrendsState extends State<PatientTrends> {
  List<Map<String, Object?>> rows = [];
  String metric = 'weight';
  bool busy = false;
  String? error;
  static const metrics = {
    'weight': 'Peso (kg)',
    'systolic': 'TA sistólica (mmHg)',
    'diastolic': 'TA diastólica (mmHg)',
    'glucose': 'Glucosa (mg/dL)',
    'heart_rate': 'FC (lpm)',
    'spo2': 'SpO₂ (%)',
  };
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final db = await AppDb.instance.database;
      final all = <Map<String, Object?>>[];
      for (final table in [
        'consultations',
        'emergencies',
        'clinical_measurements',
      ]) {
        for (final r in await db.query(
          table,
          where: 'patient_id=?',
          whereArgs: [widget.pid],
        )) {
          all.add({
            ...r,
            'origin': table == 'clinical_measurements'
                ? 'Medición'
                : table == 'consultations'
                ? 'Consulta'
                : 'Urgencias',
          });
        }
      }
      for (final r in await db.rawQuery(
        'SELECT n.* FROM progress_notes n JOIN hospitalizations h ON h.id=n.hospitalization_id WHERE h.patient_id=?',
        [widget.pid],
      )) {
        all.add({...r, 'origin': 'Evolución'});
      }
      all.sort((a, b) => '${a['date']}'.compareTo('${b['date']}'));
      if (mounted)
        setState(() {
          rows = all;
          error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() => error = 'No se pudieron cargar las mediciones.');
    }
  }

  Future<void> add() async {
    final input = await askClinicalText(context, metrics[metric]!, lines: 1);
    if (input == null || input.isEmpty || !mounted) return;
    final value = double.tryParse(input.replaceAll(',', '.'));
    if (value == null ||
        !value.isFinite ||
        value <= 0 ||
        (metric == 'spo2' && value > 100)) {
      clinicalMessage(context, 'Revisa el valor y sus unidades.');
      return;
    }
    final day = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (day == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time == null || !mounted) return;
    final when = DateTime(day.year, day.month, day.day, time.hour, time.minute);
    final notes = await askClinicalText(
      context,
      'Contexto: ayuno, domicilio, etc. (opcional)',
    );
    if (notes == null || !mounted) return;
    setState(() => busy = true);
    try {
      await AppDb.instance.insert('clinical_measurements', {
        'patient_id': widget.pid,
        'date': when.toIso8601String(),
        metric: value,
        'notes': notes,
        'created_at': DateTime.now().toIso8601String(),
      });
      await load();
    } catch (_) {
      if (mounted) clinicalMessage(context, 'No se pudo guardar.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = rows
        .where(
          (r) => r[metric] is num && DateTime.tryParse('${r['date']}') != null,
        )
        .toList();
    final values = points.map((r) => (r[metric] as num).toDouble()).toList();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<String>(
          value: metric,
          decoration: const InputDecoration(labelText: 'Variable'),
          items: [
            for (final e in metrics.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) => setState(() => metric = v!),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy ? null : add,
          icon: const Icon(Icons.add_chart),
          label: const Text('Registrar medición'),
        ),
        if (error != null) Text(error!),
        if (busy) const LinearProgressIndicator(),
        if (points.isEmpty)
          const ListTile(title: Text('Sin mediciones para esta variable')),
        if (points.isNotEmpty)
          clinicalPanel(
            context,
            '${metrics[metric]} · ${points.length} registros',
            [
              Text(
                'Último: ${values.last}  ·  Mín: ${values.reduce(math.min)}  ·  Máx: ${values.reduce(math.max)}',
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 180,
                width: double.infinity,
                child: CustomPaint(
                  painter: _TrendPainter(
                    values,
                    points
                        .map(
                          (p) =>
                              DateTime.parse('${p['date']}')
                                  .millisecondsSinceEpoch
                                  .toDouble(),
                        )
                        .toList(),
                  ),
                ),
              ),
              Text(
                '${clinicalDate(points.first['date'])} → ${clinicalDate(points.last['date'])}',
              ),
              const Text(
                'Eje horizontal: fecha y hora. Eje vertical: rango observado, no parte necesariamente de cero.',
              ),
            ],
          ),
        for (final r in points.reversed)
          Card(
            child: ListTile(
              title: Text('${r[metric]} · ${metrics[metric]}'),
              subtitle: Text(
                '${clinicalDate(r['date'])} · ${r['origin']}\n${r['notes'] ?? ''}',
              ),
            ),
          ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  final List<double> y, x;
  _TrendPainter(this.y, this.x);
  @override
  void paint(Canvas canvas, Size size) {
    if (y.isEmpty) return;
    final low = y.reduce(math.min),
        high = y.reduce(math.max),
        first = x.reduce(math.min),
        last = x.reduce(math.max);
    final line = Paint()
      ..color = const Color(0xFF2CC8FF)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final grid = Paint()
      ..color = const Color(0xFF607080)
      ..strokeWidth = .5;
    for (var i = 0; i < 4; i++) {
      final yy = 12 + (size.height - 24) * i / 3;
      canvas.drawLine(Offset(8, yy), Offset(size.width - 8, yy), grid);
    }
    final path = Path();
    for (var i = 0; i < y.length; i++) {
      final px = last == first
          ? size.width / 2
          : 8 + (x[i] - first) / (last - first) * (size.width - 16);
      final py = high == low
          ? size.height / 2
          : 12 + (high - y[i]) / (high - low) * (size.height - 24);
      if (i == 0)
        path.moveTo(px, py);
      else
        path.lineTo(px, py);
      canvas.drawCircle(
        Offset(px, py),
        3,
        Paint()..color = const Color(0xFF2CC8FF),
      );
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) => true;
}

class ClinicalExport extends StatefulWidget {
  final Map<String, Object?> patient;
  final List<Map<String, Object?>> events;
  const ClinicalExport({
    super.key,
    required this.patient,
    required this.events,
  });
  @override
  State<ClinicalExport> createState() => _ClinicalExportState();
}

class _ClinicalExportState extends State<ClinicalExport> {
  final selected = <String>{};
  bool busy = false;
  DateTimeRange? range;
  String key(Map<String, Object?> e) => '${e['table']}:${e['id']}';
  List<Map<String, Object?>> get visible => widget.events.where((e) {
    if (range == null) return true;
    final d = DateTime.tryParse('${e['date']}');
    return d != null &&
        !d.isBefore(range!.start) &&
        d.isBefore(range!.end.add(const Duration(days: 1)));
  }).toList();
  Future<void> printSelected() async {
    if (busy || selected.isEmpty) return;
    if (selected.length > 100) {
      clinicalMessage(context, 'Selecciona hasta 100 atenciones por PDF.');
      return;
    }
    setState(() => busy = true);
    try {
      final sections = <pw.Widget>[];
      void paragraph(String text) {
        // Bounded chunks permit very long clinical text to flow across pages.
        for (var i = 0; i < text.length; i += 1200) {
          sections.add(
            pw.Text(
              text.substring(i, math.min(i + 1200, text.length)),
              style: const pw.TextStyle(fontSize: 10),
            ),
          );
        }
      }

      sections.add(
        pw.Text(
          'ANGEL MEDICAL · EXPEDIENTE SELECCIONADO',
          style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold),
        ),
      );
      paragraph(
        '${widget.patient['first_name']} ${widget.patient['last_name']}',
      );
      paragraph(
        'Nacimiento: ${widget.patient['dob'] ?? ''} · Alergias: ${widget.patient['allergies'] ?? 'Sin registro'}',
      );
      paragraph(
        'Copia de las atenciones seleccionadas. Datos y autoría registrados en cada nota; firmas autógrafas pendientes.',
      );
      paragraph(
        'Generado: ${clinicalDate(DateTime.now().toIso8601String())} · ${selected.length} atenciones seleccionadas. No incluye archivos adjuntos ni borradores.',
      );
      for (final e in widget.events.reversed.where(
        (e) => selected.contains(key(e)),
      )) {
        final record = await ClinicalStore.readEvent(
          e,
          widget.patient['id'] as int,
        );
        sections.add(pw.SizedBox(height: 16));
        sections.add(
          pw.Text(
            '${e['type']} · ${clinicalDate(e['date'])}',
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
        );
        for (final f in clinicalFields(record)) {
          sections.add(pw.SizedBox(height: 6));
          sections.add(
            pw.Text(f.key, style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          );
          paragraph(f.value);
        }
        final nom = decodeNom(record['nom_json']);
        final authorData = nom['correction_profile'] ?? nom['profile'];
        final author = authorData is Map ? authorData : <String, dynamic>{};
        paragraph(
          'Firma autógrafa del médico: ${author['doctor'] ?? 'autor original sin registrar'}',
        );
        sections.add(pw.SizedBox(height: 30));
        sections.add(
          pw.Container(
            width: 220,
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide()),
            ),
          ),
        );
        if ([
          'Consentimiento informado',
          'Egreso voluntario',
        ].contains(record['type'])) {
          final extras = nomInput(record);
          for (final key in ['nom_signer', 'nom_witness1', 'nom_witness2']) {
            paragraph('${nomLabels[key]}: ${extras[key] ?? ''}');
            sections.add(pw.SizedBox(height: 30));
            sections.add(
              pw.Container(
                width: 220,
                decoration: const pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide()),
                ),
              ),
            );
          }
        }
      }
      final doc = pw.Document();
      doc.addPage(
        pw.MultiPage(
          maxPages: 500,
          pageFormat: PdfPageFormat.letter,
          margin: const pw.EdgeInsets.all(28),
          footer: (c) => pw.Text(
            '${c.pageNumber}/${c.pagesCount}',
            style: const pw.TextStyle(fontSize: 9),
          ),
          build: (_) => sections,
        ),
      );
      await Printing.layoutPdf(onLayout: (_) => doc.save());
    } catch (e) {
      if (mounted) clinicalMessage(context, 'No se pudo generar el PDF: $e');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Exportar atenciones')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Elige qué atenciones incluir. Revisa el PDF antes de compartirlo.',
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: busy
                  ? null
                  : () async {
                      final r = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100),
                      );
                      if (r != null && mounted)
                        setState(() {
                          range = r;
                          selected.clear();
                        });
                    },
              icon: const Icon(Icons.date_range),
              label: const Text('Filtrar fechas'),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      range = null;
                      selected.clear();
                    }),
              child: const Text('Quitar filtro'),
            ),
            TextButton(
              onPressed: busy
                  ? null
                  : () => setState(() {
                      selected.clear();
                      selected.addAll(visible.map(key));
                    }),
              child: const Text('Seleccionar visibles'),
            ),
          ],
        ),
        Text('${selected.length} seleccionadas'),
        FilledButton.icon(
          onPressed: busy || selected.isEmpty ? null : printSelected,
          icon: const Icon(Icons.picture_as_pdf_outlined),
          label: Text(busy ? 'Preparando…' : 'Generar PDF'),
        ),
        for (final e in visible)
          CheckboxListTile(
            value: selected.contains(key(e)),
            onChanged: busy
                ? null
                : (v) => setState(() {
                    if (v == true)
                      selected.add(key(e));
                    else
                      selected.remove(key(e));
                  }),
            title: Text('${e['type']} · ${clinicalDate(e['date'])}'),
            subtitle: Text(
              '${e['text'] ?? ''}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
    ),
  );
}
