import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'clinical_exchange_reader.dart';

void main() => runApp(const AngelPc());
Future<ClinicalSnapshot> decryptSnapshot(List<String> args) => readClinicalExchange(args[0], args[1]);

const sections = <String, String>{
  'patients': 'Datos del paciente', 'consultations': 'Consultas',
  'emergencies': 'Urgencias', 'hospitalizations': 'Hospitalizaciones',
  'progress_notes': 'Evoluciones hospitalarias', 'medical_orders': 'Indicaciones hospitalarias',
  'documents': 'Recetas y documentos', 'clinical_scales': 'Escalas registradas',
  'clinical_measurements': 'Mediciones', 'appointments': 'Agenda',
  'clinical_attachments': 'Adjuntos y firmas', 'clinical_tasks': 'Pendientes',
  'clinical_drafts': 'Borradores', 'clinical_revisions': 'Historial de cambios',
};
const labels = <String, String>{
  'first_name': 'Nombre', 'last_name': 'Apellidos', 'dob': 'Fecha de nacimiento',
  'sex': 'Sexo', 'phone': 'Teléfono', 'allergies': 'Alergias',
  'personal_history': 'Antecedentes personales', 'family_history': 'Antecedentes familiares',
  'surgical_history': 'Antecedentes quirúrgicos', 'chronic_meds': 'Medicación habitual',
  'reason': 'Motivo', 'illness': 'Padecimiento actual', 'physical_exam': 'Exploración física',
  'diagnoses': 'Diagnósticos', 'treatment': 'Tratamiento', 'studies': 'Estudios',
  'plan': 'Plan', 'date': 'Fecha', 'content': 'Contenido', 'title': 'Título',
  'subjective': 'Subjetivo', 'objective': 'Objetivo', 'assessment': 'Análisis',
  'summary': 'Resumen', 'score': 'Puntaje', 'scale_name': 'Escala',
  'scale_version': 'Versión de escala', 'payload': 'Datos y contexto registrados',
  'nom_payload': 'Documentación clínica', 'notes': 'Observaciones',
  'systolic': 'TA sistólica', 'diastolic': 'TA diastólica', 'heart_rate': 'Frecuencia cardiaca',
  'respiratory_rate': 'Frecuencia respiratoria', 'temperature': 'Temperatura',
  'spo2': 'SpO₂', 'weight': 'Peso', 'height': 'Talla', 'glucose': 'Glucosa',
  'created_at': 'Registro', 'updated_at': 'Actualización', 'description': 'Descripción',
  'admitted_at': 'Ingreso', 'discharged_at': 'Egreso', 'start_at': 'Fecha de cita',
  'doctor': 'Médico', 'license': 'Cédula', 'establishment': 'Establecimiento',
};

class AngelPc extends StatelessWidget {
  const AngelPc({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'Ángel Medical PC',
    theme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff13548a)), scaffoldBackgroundColor: const Color(0xfff1f5fa)),
    darkTheme: ThemeData(useMaterial3: true, colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff71b8f1), brightness: Brightness.dark)),
    home: const DesktopHome(),
  );
}

class DesktopHome extends StatefulWidget {
  final ClinicalSnapshot? initialSnapshot;
  const DesktopHome({super.key, this.initialSnapshot});
  @override
  State<DesktopHome> createState() => _DesktopHomeState();
}
class _DesktopHomeState extends State<DesktopHome> {
  ClinicalSnapshot? snapshot;
  Map<String, dynamic>? patient;
  String query = '', section = 'patients';
  bool busy = false;
  @override
  void initState() { super.initState(); snapshot = widget.initialSnapshot; }
  void message(String text) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text))); }
  Future<void> open() async {
    if (busy) return;
    final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['amx']);
    if (picked == null || picked.files.single.path == null || !mounted) return;
    final password = TextEditingController();
    final accepted = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Abrir expediente cifrado'),
      content: TextField(controller: password, obscureText: true, autofocus: true, enableSuggestions: false, autocorrect: false,
        onSubmitted: (_) => Navigator.pop(ctx, true), decoration: const InputDecoration(labelText: 'Contraseña elegida al exportar en Android')),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Abrir'))],
    ));
    final secret = password.text;
    // Dispose after the dialog's closing animation releases its TextField.
    Future<void>.delayed(const Duration(milliseconds: 400), password.dispose);
    if (accepted != true || !mounted) return;
    setState(() => busy = true);
    try {
      final file = File(picked.files.single.path!);
      if (await file.length() > 512 * 1024 * 1024) throw const FormatException('El archivo excede el límite de lectura de 512 MB.');
      final result = await compute(decryptSnapshot, [await file.readAsString(), secret]);
      if (!mounted) return;
      setState(() { snapshot = result; patient = null; section = 'patients'; query = ''; });
      message('Instantánea abierta. Adjuntos y relaciones comprobados.');
    } catch (e) {
      message(e is FormatException ? e.message : 'No se pudo abrir el archivo. No se modificó el expediente abierto.');
    } finally { if (mounted) setState(() => busy = false); }
  }

  Future<void> saveAttachment(Map<String, dynamic> row, {bool pdf = false}) async {
    try {
      var bytes = row['data'] as Uint8List;
      var name = '${row['name']}';
      if (pdf) {
        bytes = originalSignedPdf(bytes);
        name = '${p.basenameWithoutExtension(name)}.pdf';
      }
      final safeName = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final dest = await FilePicker.platform.saveFile(dialogTitle: 'Guardar archivo original sin modificar', fileName: safeName);
      if (dest == null) return;
      await File(dest).writeAsBytes(bytes, flush: true);
      message('Archivo original guardado. La huella de integridad no equivale a validar confianza SAT.');
    } catch (e) { message(e is FormatException ? e.message : 'No se pudo guardar el archivo.'); }
  }

  String valueText(dynamic value) {
    if (value is Uint8List) return 'Archivo binario · ${value.length} bytes';
    if (value is String && (value.startsWith('{') || value.startsWith('['))) {
      try { return const JsonEncoder.withIndent('  ').convert(jsonDecode(value)); } catch (_) { /* Preserve original text. */ }
    }
    return '$value';
  }
  Widget fields(Map<String, dynamic> row) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    for (final e in row.entries.where((e) => e.value != null && '${e.value}'.isNotEmpty && e.value is! Uint8List))
      Padding(padding: const EdgeInsets.only(bottom: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(labels[e.key] ?? e.key.replaceAll('_', ' '), style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 3), SelectableText(valueText(e.value)),
      ])),
  ]);
  Widget patientList() {
    final rows = snapshot!.rows('patients').where((r) => '${r['first_name']} ${r['last_name']} ${r['curp'] ?? ''} ${r['id']}'.toLowerCase().contains(query.toLowerCase())).toList()
      ..sort((a, b) => '${a['last_name']} ${a['first_name']}'.compareTo('${b['last_name']} ${b['first_name']}'));
    return Column(children: [
      Padding(padding: const EdgeInsets.all(12), child: TextField(onChanged: (v) => setState(() => query = v), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), labelText: 'Paciente, CURP o expediente'))),
      Expanded(child: rows.isEmpty ? const Center(child: Text('Sin pacientes para esta búsqueda.')) : ListView.builder(itemCount: rows.length, itemBuilder: (ctx, i) {
        final r = rows[i];
        return ListTile(selected: patient?['id'] == r['id'], leading: const Icon(Icons.person_outline), title: Text('${r['first_name']} ${r['last_name']}'),
          subtitle: Text('Exp. ${r['id']} · ${r['dob'] ?? 'Nacimiento sin registrar'}'), onTap: () => setState(() { patient = r; section = 'patients'; }));
      })),
    ]);
  }
  Widget details() {
    if (patient == null) return ListView(padding: const EdgeInsets.all(24), children: [
      const Text('Expediente abierto', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12), const Text('Selecciona un paciente para consultar sus registros. Esta edición de PC es de consulta; los cambios se realizan en Android.'),
      const SizedBox(height: 20), fields(snapshot!.profile),
      const Text('Contenido recibido', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12), SelectableText('Fecha de exportación: ${snapshot!.metadata['created_at']}\nOrigen: Ángel Medical ${snapshot!.metadata['app_version']}\nIdentidad: ${snapshot!.metadata['database_uuid']}'),
      const SizedBox(height: 12), for (final e in snapshot!.tables.entries) Text('${sections[e.key] ?? e.key}: ${e.value.length} registros'),
    ]);
    final rows = section == 'patients' ? [patient!] : snapshot!.patientRows(section, patient!['id'] as int);
    rows.sort((a, b) => '${b['date'] ?? b['created_at'] ?? b['start_at'] ?? ''}'.compareTo('${a['date'] ?? a['created_at'] ?? a['start_at'] ?? ''}'));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Padding(padding: const EdgeInsets.all(16), child: Text('${patient!['first_name']} ${patient!['last_name']}', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: DropdownButtonFormField<String>(initialValue: section, key: ValueKey('${patient!['id']}:$section'), isExpanded: true,
        items: [for (final e in sections.entries) DropdownMenuItem(value: e.key, child: Text(e.value))], onChanged: (v) => setState(() => section = v!))),
      const SizedBox(height: 12),
      Expanded(child: rows.isEmpty ? const Center(child: Text('Sin registros en esta sección.')) : ListView.builder(padding: const EdgeInsets.all(16), itemCount: rows.length, itemBuilder: (ctx, i) {
        final row = rows[i];
        return Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${row['title'] ?? row['scale_name'] ?? row['name'] ?? sections[section]} · ${row['date'] ?? row['created_at'] ?? ''}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const Divider(), fields(row),
          if (section == 'clinical_attachments') Wrap(spacing: 12, runSpacing: 8, children: [
            OutlinedButton.icon(onPressed: () => saveAttachment(row), icon: const Icon(Icons.save_alt), label: const Text('Guardar adjunto original')),
            if ('${row['name']}'.endsWith('.amfirma')) FilledButton.icon(onPressed: () => saveAttachment(row, pdf: true), icon: const Icon(Icons.picture_as_pdf), label: const Text('Guardar PDF firmado original')),
          ]),
        ])));
      })),
    ]);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Ángel Medical PC · 0.1 · Consulta'), actions: [
      TextButton.icon(onPressed: busy ? null : open, icon: const Icon(Icons.folder_open), label: const Text('Abrir .amx')),
      if (snapshot != null) IconButton(tooltip: 'Cerrar expediente', onPressed: busy ? null : () => setState(() { snapshot = null; patient = null; query = ''; }), icon: const Icon(Icons.lock_outline)),
    ]),
    body: Column(children: [
      if (busy) const LinearProgressIndicator(),
      Expanded(child: snapshot == null ? Center(child: SingleChildScrollView(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.medical_information_outlined, size: 70), const SizedBox(height: 20),
        const Text('Tus expedientes, también en PC', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)), const SizedBox(height: 16),
        const Text('En Android abre Preparar intercambio con PC, crea un archivo .amx y guárdalo en Drive. Después ábrelo aquí con la misma contraseña.', textAlign: TextAlign.center), const SizedBox(height: 16),
        const Text('El archivo se consulta en memoria. No se guarda una copia descifrada, no modifica Android ni sincroniza cambios. Los archivos que guardes manualmente salen sin el cifrado de .amx.', textAlign: TextAlign.center), const SizedBox(height: 24),
        FilledButton.icon(onPressed: busy ? null : open, icon: const Icon(Icons.folder_open), label: const Text('Abrir expediente cifrado')),
      ]))))) : LayoutBuilder(builder: (ctx, constraints) {
        if (constraints.maxWidth < 760) return patient == null ? patientList() : Column(children: [TextButton.icon(onPressed: () => setState(() => patient = null), icon: const Icon(Icons.arrow_back), label: const Text('Volver a pacientes')), Expanded(child: details())]);
        return Row(children: [SizedBox(width: 310, child: patientList()), const VerticalDivider(width: 1), Expanded(child: details())]);
      })),
      const Padding(padding: EdgeInsets.all(8), child: Text('Drive: respaldo e intercambio · No hay sincronización automática · Cierra el expediente al terminar.')),
    ]),
  );
}
