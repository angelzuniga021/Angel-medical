import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';
import 'clinical_ui.dart';
import 'services.dart';

class ClinicalExchangeScreen extends StatefulWidget {
  const ClinicalExchangeScreen({super.key});
  @override
  State<ClinicalExchangeScreen> createState() => _ClinicalExchangeScreenState();
}
class _ClinicalExchangeScreenState extends State<ClinicalExchangeScreen> {
  final password = TextEditingController(), confirmation = TextEditingController();
  bool busy = false;
  Future<void> export() async {
    if (password.text != confirmation.text) { clinicalMessage(context, 'Las contraseñas no coinciden.'); return; }
    setState(() => busy = true);
    try {
      final file = await BackupService.createExchange(password.text);
      password.clear(); confirmation.clear();
      await Share.shareXFiles([XFile(file.path)], text: 'Instantánea cifrada Ángel Medical para futura versión PC. No es sincronización.');
    } catch (e) { if (mounted) clinicalMessage(context, e is FormatException ? e.message : 'No se pudo generar el archivo de intercambio.'); }
    finally { if (mounted) setState(() => busy = false); }
  }
  @override
  void dispose() { password.dispose(); confirmation.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Preparar intercambio con PC')), body: ListView(padding: const EdgeInsets.all(20), children: [
    const Text('Puedes guardar una instantánea cifrada en Drive desde el menú Compartir. Incluye registros, perfil, adjuntos y firmas en un formato lógico preparado para un futuro lector de PC.'), const SizedBox(height: 16),
    const Text('La versión PC aún no está incluida. Este archivo .amx no se restaura con el botón de respaldo .ambak y no sincroniza cambios. Sigue utilizando .ambak para recuperación en el teléfono.'), const SizedBox(height: 16),
    const Text('No abras ni edites una base SQLite directamente dentro de una carpeta sincronizada por Drive. La futura sincronización necesita resolver cambios de ambos dispositivos.'), const SizedBox(height: 16),
    TextField(controller: password, obscureText: true, enableSuggestions: false, autocorrect: false, decoration: const InputDecoration(labelText: 'Contraseña del archivo · mínimo 8 caracteres')), const SizedBox(height: 12),
    TextField(controller: confirmation, obscureText: true, enableSuggestions: false, autocorrect: false, decoration: const InputDecoration(labelText: 'Repetir contraseña')), const SizedBox(height: 16),
    if (busy) const LinearProgressIndicator(),
    FilledButton.icon(onPressed: busy ? null : export, icon: const Icon(Icons.computer_outlined), label: const Text('Crear y compartir instantánea cifrada')),
  ]));
}
