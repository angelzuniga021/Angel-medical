import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'clinical_guidance.dart';

import 'dart:convert';

import 'package:flutter/material.dart';

import 'db.dart';
import 'clinical_nom.dart';
import 'clinical_ui.dart';

class NomSettings extends StatefulWidget {
  const NomSettings({super.key});
  @override
  State<NomSettings> createState() => _NomSettingsState();
}

class _NomSettingsState extends State<NomSettings> {
  final fields = {
    for (final k in nomProfileLabels.keys) k: TextEditingController(),
  };
  String? logoBase64;
  bool ready = false, busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final saved = decodeNom(await AppDb.instance.getSetting('nom_profile'));
      final defaults = {
        'doctor': communityEdition ? '' : 'Angel Eleuterio Zuniga Guillen',
        'license': communityEdition ? '' : '12548010',
        'profession': 'Medicina General',
        'establishment_type': 'Consultorio médico',
      };
      logoBase64 = saved['logo_base64'] as String?;
      for (final e in fields.entries) {
        e.value.text = '${saved[e.key] ?? defaults[e.key] ?? ''}';
      }
      if (mounted) setState(() => ready = true);
    } catch (_) {
      if (mounted)
        setState(() => error = 'No se pudo cargar la configuración.');
    }
  }

  Future<void> chooseLogo() async {
    try {
      final pick = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (pick == null) return;
      final file = pick.files.single;
      if (file.size > 256 * 1024)
        throw const FormatException('Usa un logo PNG/JPG de hasta 256 KB');
      final bytes = file.bytes ?? await File(file.path!).readAsBytes();
      final png =
          bytes.length > 8 &&
          bytes.take(8).join(',') == '137,80,78,71,13,10,26,10';
      final jpg =
          bytes.length > 3 &&
          bytes[0] == 255 &&
          bytes[1] == 216 &&
          bytes[2] == 255;
      if (!png && !jpg)
        throw const FormatException('El archivo no es PNG/JPG válido');
      if (mounted) setState(() => logoBase64 = base64Encode(bytes));
    } catch (e) {
      if (mounted) clinicalMessage(context, 'No se pudo cargar el logo: $e');
    }
  }

  Future<void> save() async {
    if (busy) return;
    final data = {
      for (final e in fields.entries) e.key: e.value.text.trim(),
      if (logoBase64 != null) 'logo_base64': logoBase64!,
    };
    final missing = [
      'doctor',
      'license',
      'profession',
      'establishment',
      'establishment_type',
      'address',
      'place',
    ].where((k) => data[k]!.isEmpty).map((k) => nomProfileLabels[k]).join(', ');
    if (missing.isNotEmpty) {
      clinicalMessage(context, 'Completa: $missing');
      return;
    }
    setState(() => busy = true);
    try {
      final db = await AppDb.instance.database;
      await db.transaction((tx) async {
        // Uses SQL upsert without deleting the existing configuration row.
        await tx.rawInsert(
          'INSERT INTO app_settings(setting_key,setting_value) VALUES(?,?) ON CONFLICT(setting_key) DO UPDATE SET setting_value=excluded.setting_value',
          ['nom_profile', jsonEncode(data)],
        );
        await tx.insert('audit', {
          'date': DateTime.now().toIso8601String(),
          'action': 'UPDATE_NOM_PROFILE',
          'detail': 'Configuración de autor y establecimiento',
        });
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted)
        clinicalMessage(context, 'No se pudo guardar la configuración.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Médico y establecimiento')),
    body: !ready
        ? Center(
            child: error == null
                ? const CircularProgressIndicator()
                : Text(error!),
          )
        : AbsorbPointer(
            absorbing: busy,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                clinicalPanel(context, 'Datos por atención', [
                  const Text(
                    'Confirma tus datos y el establecimiento donde atiendes. Cada nota nueva conserva una copia de estos datos. Cambiar este perfil no cambia la autoría de notas anteriores.',
                  ),
                ]),
                if (logoBase64 != null)
                  Image.memory(
                    Uint8List.fromList(base64Decode(logoBase64!)),
                    height: 90,
                    errorBuilder: (_, error, stack) =>
                        const Text('Imagen no legible: cambia el logo'),
                  ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: chooseLogo,
                      icon: const Icon(Icons.image_outlined),
                      label: const Text('Elegir mi logo'),
                    ),
                    if (logoBase64 != null)
                      TextButton(
                        onPressed: () => setState(() => logoBase64 = null),
                        child: const Text('Quitar logo'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                for (final e in fields.entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: TextField(
                      controller: e.value,
                      minLines: 1,
                      maxLines: e.key == 'address' ? 3 : 1,
                      decoration: InputDecoration(
                        labelText: nomProfileLabels[e.key],
                      ),
                    ),
                  ),
                const Text(
                  'Las notas se imprimen para firma autógrafa. No se incluye firma electrónica ni certificación NOM-024.',
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: busy ? null : save,
                  child: Text(
                    busy ? 'Guardando…' : 'Confirmar y guardar datos',
                  ),
                ),
              ],
            ),
          ),
  );
}
