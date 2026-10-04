import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'clinical_signature.dart';
import 'clinical_signature_flow.dart';
import 'clinical_signature_data.dart';
import 'clinical_ui.dart';
import 'db.dart';

class ClinicalSignaturePanel extends StatefulWidget {
  final String table, title;
  final Map<String, Object?> patient, record;
  final ValueChanged<Map<String, dynamic>?>? onCurrentSignature;
  const ClinicalSignaturePanel({super.key, required this.table, required this.title, required this.patient, required this.record, this.onCurrentSignature});
  @override
  State<ClinicalSignaturePanel> createState() => _ClinicalSignaturePanelState();
}
class _ClinicalSignaturePanelState extends State<ClinicalSignaturePanel> {
  bool busy = false, loading = true;
  List<Map<String, dynamic>> signatures = [];
  String? error;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final db = await AppDb.instance.database;
      final rows = await db.query('clinical_attachments', where: 'patient_id=? AND mime=? AND description=?', whereArgs: [widget.patient['id'], signedNoteMime, 'firma:${widget.table}:${widget.record['id']}'], orderBy: 'created_at DESC', limit: 20);
      final next = <Map<String, dynamic>>[];
      for (final row in rows) {
        final bytes = Uint8List.fromList(row['data'] as List<int>);
        if (sha256.convert(bytes).toString() != row['sha256']) throw const FormatException('Paquete de firma modificado.');
        final payload = Map<String, dynamic>.from(jsonDecode(utf8.decode(bytes)) as Map);
        await ClinicalSignatureService.verify(payload);
        if (payload['table'] != widget.table || payload['record_id'] != widget.record['id'] || payload['patient_id'] != widget.patient['id']) throw const FormatException('Firma vinculada a otro registro.');
        next.add(payload);
      }
      if (mounted) {
        setState(() { signatures = next; error = null; loading = false; });
        widget.onCurrentSignature?.call(current);
      }
    } catch (_) { if (mounted) {
      setState(() { signatures = []; loading = false; error = 'No se pudo verificar alguna firma. No se muestra como válida.'; });
      widget.onCurrentSignature?.call(null);
    } }
  }
  Future<void> sign() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final created = await ClinicalSignatureService.sign(context, table: widget.table, patient: widget.patient, record: widget.record, title: widget.title);
      await load();
      if (created != null && mounted && error == null && signatures.any((p) => p['record_sha256'] == clinicalRecordHash(widget.record))) clinicalMessage(context, 'Firma guardada y verificada. Puedes exportar el PDF con su firma.');
    } catch (e) {
      await load();
      if (mounted) clinicalMessage(context, e is ClinicalSignatureFailure ? e.message : e is FormatException ? e.message : 'No se completó el proceso de firma. Código: PANEL_FAILURE. Las firmas anteriores se conservan.');
    }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> inspect() async {
    if (busy) return;
    setState(() => busy = true);
    try { await ClinicalSignatureService.inspectCertificate(context); }
    catch (e) { if (mounted) clinicalMessage(context, e is FormatException ? e.message : 'No se pudo leer el .cer. Selecciona el certificado público, no la clave privada.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> export(Map<String, dynamic> payload) async {
    setState(() => busy = true);
    try { await ClinicalSignatureService.export(payload); }
    catch (_) { if (mounted) clinicalMessage(context, 'No se pudo verificar o exportar la firma.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Map<String, dynamic>? get current {
    for (final payload in signatures) { if (payload['record_sha256'] == clinicalRecordHash(widget.record)) return payload; }
    return null;
  }
  @override
  Widget build(BuildContext context) => clinicalPanel(context, 'Firma electrónica del PDF', [
    const Text('Firma local con .cer y .key cifrada. No se guardan la clave privada ni su contraseña en la base.'),
    const SizedBox(height: 8),
    const Text('Verificación de integridad disponible. Confianza SAT, revocación y sello de tiempo confiable pendientes.', style: TextStyle(fontSize: 12)),
    if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    if (busy || loading) const LinearProgressIndicator(),
    if (current != null) const Text('Esta versión ya tiene una firma verificada. Puedes exportarla sin introducir otra vez la clave.'),
    for (final payload in signatures) ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(payload['record_sha256'] == clinicalRecordHash(widget.record) ? Icons.fact_check_outlined : Icons.history),
      title: Text(payload['record_sha256'] == clinicalRecordHash(widget.record) ? 'Integridad verificada · versión actual' : 'Firma de una versión anterior'),
      subtitle: Text('${payload['signer_name']} · ${payload['signer_rfc']}\n${clinicalDate(payload['signed_at_device'])} · fecha del dispositivo'),
      trailing: IconButton(tooltip: 'Exportar PDF y firmas', onPressed: busy ? null : () => export(payload), icon: const Icon(Icons.ios_share)),
    ),
    FilledButton.tonalIcon(onPressed: busy || loading ? null : current == null ? sign : () => export(current!), icon: Icon(current == null ? Icons.draw_outlined : Icons.ios_share), label: Text(current == null ? 'Firmar esta versión' : 'Exportar versión firmada')),
    if (current != null) ExpansionTile(title: const Text('Añadir otra firma a esta versión'), children: [TextButton(onPressed: busy || loading ? null : sign, child: const Text('Firmar nuevamente'))]),
    OutlinedButton.icon(onPressed: busy ? null : inspect, icon: const Icon(Icons.event_available_outlined), label: const Text('Revisar vigencia del .cer')),
  ]);
}
