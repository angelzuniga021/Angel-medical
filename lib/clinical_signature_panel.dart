import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'clinical_signature.dart';
import 'clinical_signature_data.dart';
import 'clinical_ui.dart';
import 'db.dart';

class ClinicalSignaturePanel extends StatefulWidget {
  final String table, title;
  final Map<String, Object?> patient, record;
  const ClinicalSignaturePanel({super.key, required this.table, required this.title, required this.patient, required this.record});
  @override
  State<ClinicalSignaturePanel> createState() => _ClinicalSignaturePanelState();
}
class _ClinicalSignaturePanelState extends State<ClinicalSignaturePanel> {
  bool busy = false;
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
      if (mounted) setState(() { signatures = next; error = null; });
    } catch (_) { if (mounted) setState(() => error = 'No se pudo verificar alguna firma. No se muestra como válida.'); }
  }
  Future<void> sign() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      await ClinicalSignatureService.sign(context, table: widget.table, patient: widget.patient, record: widget.record, title: widget.title);
      await load();
    } catch (e) { if (mounted) clinicalMessage(context, e is FormatException ? e.message : 'No se pudo firmar. Comprueba los archivos, contraseña y vigencia.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  Future<void> export(Map<String, dynamic> payload) async {
    setState(() => busy = true);
    try { await ClinicalSignatureService.export(payload); }
    catch (_) { if (mounted) clinicalMessage(context, 'No se pudo verificar o exportar la firma.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  Widget build(BuildContext context) => clinicalPanel(context, 'Firma electrónica del PDF', [
    const Text('Firma local con .cer y .key cifrada. No se guardan la clave privada ni su contraseña en la base.'),
    const SizedBox(height: 8),
    const Text('Verificación de integridad disponible. Confianza SAT, revocación y sello de tiempo confiable pendientes.', style: TextStyle(fontSize: 12)),
    if (error != null) Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
    if (busy) const LinearProgressIndicator(),
    for (final payload in signatures) ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(payload['record_sha256'] == clinicalRecordHash(widget.record) ? Icons.fact_check_outlined : Icons.history),
      title: Text(payload['record_sha256'] == clinicalRecordHash(widget.record) ? 'Integridad verificada · versión actual' : 'Firma de una versión anterior'),
      subtitle: Text('${payload['signer_name']} · ${payload['signer_rfc']}\n${clinicalDate(payload['signed_at_device'])} · fecha del dispositivo'),
      trailing: IconButton(tooltip: 'Exportar PDF y firmas', onPressed: busy ? null : () => export(payload), icon: const Icon(Icons.ios_share)),
    ),
    FilledButton.tonalIcon(onPressed: busy ? null : sign, icon: const Icon(Icons.draw_outlined), label: const Text('Firmar esta versión')),
  ]);
}
