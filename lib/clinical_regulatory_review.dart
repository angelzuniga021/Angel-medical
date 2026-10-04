import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'clinical_nom.dart';
import 'clinical_profile.dart';
import 'clinical_signature_data.dart';
import 'clinical_ui.dart';
import 'db.dart';

class ClinicalRegulatoryReview extends StatefulWidget {
  const ClinicalRegulatoryReview({super.key});
  @override
  State<ClinicalRegulatoryReview> createState() => _ClinicalRegulatoryReviewState();
}
class _ClinicalRegulatoryReviewState extends State<ClinicalRegulatoryReview> {
  List<String> missing = [];
  int legacy = 0, signatures = 0, catalog = 0;
  bool loading = true;
  String? backup, error;
  @override
  void initState() { super.initState(); load(); }
  Future<void> load() async {
    try {
      final db = await AppDb.instance.database;
      missing = profileMissingFields(decodeNom(await AppDb.instance.getSetting('nom_profile')));
      backup = await AppDb.instance.getSetting('last_backup_at');
      legacy = 0;
      for (final table in nomTables) { legacy += (await db.rawQuery("SELECT COUNT(*) n FROM $table WHERE nom_json IS NULL OR TRIM(nom_json)='' ")).first['n'] as int; }
      signatures = (await db.rawQuery('SELECT COUNT(*) n FROM clinical_attachments WHERE mime=?', [signedNoteMime])).first['n'] as int;
      catalog = await AppDb.instance.count('cie10');
      if (mounted) setState(() => loading = false);
    } catch (_) { if (mounted) setState(() { loading = false; error = 'No se pudo revisar la base. No se modificó información.'; }); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Revisión de documentación')), body: ListView(padding: const EdgeInsets.all(18), children: [
    clinicalPanel(context, 'Alcance de esta revisión', [const Text('Es una revisión técnica de funciones y datos; no es dictamen jurídico ni certificación NOM-024. No mide por sí sola la calidad clínica de las notas.')]),
    if (loading) const LinearProgressIndicator(), if (error != null) Text(error!),
    clinicalPanel(context, 'Identificación y documentación · NOM-004', [
      Text(missing.isEmpty ? 'Campos de perfil requeridos registrados. No se verifica aquí la cédula ante el registro profesional.' : 'Campos del perfil pendientes: ${missing.join(', ')}'),
      Text('$legacy registros anteriores sin metadatos documentales. Se conservan sin atribuir autor ni firma retrospectivamente.'),
      const Text('Las notas nuevas validan los apartados requeridos por tipo de atención. Guardar y firmar son acciones distintas.'),
    ]),
    clinicalPanel(context, 'Conservación y trazabilidad', [
      const Text('Correcciones con motivo y copia previa; expedientes archivados conservados. No se programa borrado automático por antigüedad.'),
      Text(backup == null ? 'Sin respaldo registrado. Genera y conserva una copia externa.' : 'Último respaldo creado: ${clinicalDate(backup)}. Comprueba la copia externa y la restauración.'),
      const Text('La conservación, disponibilidad y confidencialidad también dependen de los procedimientos del consultorio.'),
    ]),
    clinicalPanel(context, 'Firma y seguridad', [
      Text('$signatures paquetes de firma almacenados; este conteo no valida sus firmas. Abre cada nota para verificar integridad y versión.'),
      const Text('SQLCipher y acceso local con PIN/biometría. Firma CMS del PDF y del manifiesto. Clave privada y contraseña no se guardan en la base.'),
      const Text('Pendiente: validación de cadena SAT y revocación, sello de tiempo confiable, controles completos por roles y pruebas integrales de seguridad.'),
    ]),
    clinicalPanel(context, 'Intercambio · NOM-024', [
      Text('$catalog entradas en el catálogo CIE-10. Los códigos no vigentes del recurso se excluyen de nuevas selecciones.'),
      const Text('Pendiente: alcance de guías DGIS, interoperabilidad formal, consentimientos de intercambio, validación de catálogos requeridos y evaluación externa. Compartir un respaldo por Drive no equivale a cumplir esos requisitos.'),
    ]),
    Wrap(spacing: 8, children: [for (final code in ['5272787','5280847']) TextButton(onPressed: () async { final ok = await launchUrl(Uri.parse('https://sidof.segob.gob.mx/notas/docFuente/$code'), mode: LaunchMode.externalApplication); if (!ok && context.mounted) clinicalMessage(context, 'No se pudo abrir la fuente oficial.'); }, child: Text(code == '5272787' ? 'Fuente NOM-004' : 'Fuente NOM-024'))]),
  ]));
}
