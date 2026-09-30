import 'clinical_certificate.dart';

import 'package:crypto/crypto.dart' show sha256;

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
  Map<String, dynamic>? certificate;
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
      if (saved['certificate_import'] is Map)
        certificate = Map<String, dynamic>.from(saved['certificate_import']);
      for (final e in fields.entries) {
        e.value.text = '${saved[e.key] ?? defaults[e.key] ?? ''}';
      }
      if (mounted) setState(() => ready = true);
    } catch (_) {
      if (mounted)
        setState(() => error = 'No se pudo cargar la configuración.');
    }
  }

  Future<void> importCertificate() async {
    try {
      final pick = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['cer'],
        withData: true,
      );
      if (pick == null) return;
      if (pick.files.single.size > 128 * 1024)
        throw const FormatException('Máximo 128 KB');
      final bytes =
          pick.files.single.bytes ??
          await File(pick.files.single.path!).readAsBytes();
      final parsed = readCertificate(bytes);
      if (!mounted) return;
      final valid = parsed.validAt(DateTime.now());
      final approved = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Confirmar datos del certificado'),
          content: SingleChildScrollView(
            child: Text(
              'Titular: ${parsed.name}\nRFC: ${parsed.rfc.isEmpty ? "No encontrado" : parsed.rfc}\nEmisor: ${parsed.issuer}\nVigencia: ${parsed.notBefore.toLocal().toString().split(" ").first} a ${parsed.notAfter.toLocal().toString().split(" ").first}\n\n${valid ? "Fechas dentro de vigencia según el reloj del teléfono." : "Fuera del periodo de vigencia según el reloj del teléfono."}\n\nSe leerán nombre y RFC. Confirma que corresponden a ti. No se verificó la cadena del SAT ni revocación. Importar este archivo no firma notas ni acredita tu cédula.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Usar estos datos'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
      setState(() {
        fields['doctor']!.text = parsed.name;
        if (parsed.rfc.isNotEmpty) fields['rfc']!.text = parsed.rfc;
        certificate = {
          'name': parsed.name,
          'rfc': parsed.rfc,
          'issuer': parsed.issuer,
          'serial': parsed.serial,
          'not_before': parsed.notBefore.toIso8601String(),
          'not_after': parsed.notAfter.toIso8601String(),
          'sha256': sha256.convert(parsed.bytes).toString(),
          'public_certificate_base64': base64Encode(parsed.bytes),
          'imported_at': DateTime.now().toIso8601String(),
          'trust_verified': false,
        };
      });
      clinicalMessage(
        context,
        'Datos cargados. Revisa el perfil y pulsa Confirmar y guardar.',
      );
    } catch (_) {
      if (mounted)
        clinicalMessage(
          context,
          'No se pudo leer el certificado. Elige solamente el .cer público de tu e.firma, válido y de hasta 128 KB.',
        );
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
      if (certificate != null) 'certificate_import': certificate!,
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
                clinicalPanel(context, 'Certificado de e.firma', [
                  const Text(
                    'Importa exclusivamente el archivo público .cer. Se leen datos para confirmar; no se solicita .key ni contraseña y no se firman documentos en esta versión.',
                  ),
                  OutlinedButton.icon(
                    onPressed: importCertificate,
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('Importar certificado .cer'),
                  ),
                  if (certificate != null) ...[
                    Text('Certificado leído: ${certificate!["name"]}'),
                    const Text(
                      'Identidad criptográfica y revocación no verificadas.',
                    ),
                    TextButton(
                      onPressed: () => setState(() => certificate = null),
                      child: const Text('Quitar certificado del perfil'),
                    ),
                  ],
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
