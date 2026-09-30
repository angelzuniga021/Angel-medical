import 'clinical_nom_settings.dart';
import 'services.dart';

import 'package:flutter/material.dart';

import 'db.dart';
import 'main.dart' as app;
import 'clinical_extras.dart';
import 'clinical_ui.dart';
import 'clinical_theme.dart';
import 'clinical_store.dart';

class ClinicalHome extends StatefulWidget {
  const ClinicalHome({super.key});
  @override
  State<ClinicalHome> createState() => _ClinicalHomeState();
}

class _ClinicalHomeState extends State<ClinicalHome> {
  int patients = 0, notes = 0, admissions = 0, drafts = 0, catalogCount = 0;
  String? backup, error;
  List<Map<String, Object?>> appointments = [], pending = [];
  bool loading = true;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final db = await AppDb.instance.database;
      patients = await AppDb.instance.count('patients');
      catalogCount = await AppDb.instance.count('cie10');
      notes = await AppDb.instance.count('consultations');
      drafts = await AppDb.instance.count('clinical_drafts');
      admissions =
          ((await db.rawQuery(
                'SELECT COUNT(*) AS n FROM hospitalizations WHERE status=?',
                ['hospitalizado'],
              )).first['n']
              as int);
      backup = await AppDb.instance.getSetting('last_backup_at');
      final now = DateTime.now();
      final start = DateTime(now.year, now.month, now.day).toIso8601String();
      appointments = await db.rawQuery(
        'SELECT a.*,p.first_name,p.last_name FROM appointments a JOIN patients p ON p.id=a.patient_id WHERE a.start_at>=? AND a.status=? ORDER BY a.start_at LIMIT 8',
        [start, 'programada'],
      );
      pending = await db.rawQuery(
        'SELECT t.*,p.first_name,p.last_name FROM clinical_tasks t JOIN patients p ON p.id=t.patient_id WHERE t.status=? ORDER BY COALESCE(t.due_at,t.created_at) LIMIT 8',
        ['pendiente'],
      );
      if (mounted)
        setState(() {
          loading = false;
          error = null;
        });
    } catch (_) {
      if (mounted)
        setState(() {
          loading = false;
          error = 'No se pudo actualizar Inicio.';
        });
    }
  }

  Future<void> route(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    await load();
  }

  @override
  Widget build(BuildContext context) {
    final b = DateTime.tryParse(backup ?? '');
    final old = b == null || DateTime.now().difference(b).inDays >= 7;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Angel Medical'),
        actions: [
          IconButton(
            tooltip: 'Herramientas',
            onPressed: () => route(const ClinicalTools()),
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            tooltip: 'Actualizar',
            onPressed: load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: load,
        child: ListView(
          padding: const EdgeInsets.all(18),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: [Color(0xFF174B82), Color(0xFF123246)],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Tu consulta, organizada.',
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Expedientes · Seguimiento · Continuidad de la atención',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      FilledButton.icon(
                        onPressed: () => route(const app.PatientsScreen()),
                        icon: const Icon(Icons.person_search_outlined),
                        label: const Text('Buscar paciente'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => route(const app.PatientForm()),
                        icon: const Icon(Icons.person_add_alt_1),
                        label: const Text('Nuevo paciente'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (loading) const LinearProgressIndicator(),
            if (error != null) Text(error!),
            LayoutBuilder(
              builder: (context, c) => Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final e in {
                    'Pacientes': patients,
                    'Consultas': notes,
                    'Hospitalizados': admissions,
                    'Borradores': drafts,
                  }.entries)
                    SizedBox(
                      width:
                          (c.maxWidth - (c.maxWidth > 650 ? 30 : 10)) /
                          (c.maxWidth > 650 ? 4 : 2),
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${e.value}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(e.key),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            clinicalPanel(context, 'Catálogo CIE-10', [
              ListTile(
                leading: Icon(
                  catalogCount == 0
                      ? Icons.info_outline
                      : Icons.library_books_outlined,
                ),
                title: Text(
                  catalogCount == 0
                      ? 'Catálogo pendiente de incorporar'
                      : '$catalogCount diagnósticos disponibles',
                ),
                subtitle: const Text(
                  'Importa un catálogo verificado en XLSX con CATALOG_KEY, NOMBRE y LETRA opcional. No se generan códigos automáticamente.',
                ),
                trailing: const Icon(Icons.upload_file),
                onTap: () async {
                  try {
                    final count = await CieImporter.importXlsx();
                    if (mounted && count > 0)
                      clinicalMessage(
                        context,
                        '$count diagnósticos importados.',
                      );
                    await load();
                  } catch (e) {
                    if (mounted)
                      clinicalMessage(context, 'No se importó el catálogo: $e');
                  }
                },
              ),
            ]),
            clinicalPanel(context, 'Respaldo cifrado', [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  old ? Icons.backup_outlined : Icons.verified_user_outlined,
                  color: old ? Colors.orange : null,
                ),
                title: Text(
                  b == null
                      ? 'Sin respaldo registrado'
                      : 'Última copia creada: ${clinicalDate(backup)}',
                ),
                subtitle: Text(
                  old
                      ? 'Conviene generar una copia y guardarla fuera del teléfono.'
                      : 'La fecha indica creación local; comprueba que guardaste una copia externa.',
                ),
                onTap: () => route(const app.SettingsScreen()),
                trailing: const Icon(Icons.chevron_right),
              ),
            ]),
            clinicalPanel(context, 'Próximas citas', [
              if (appointments.isEmpty)
                const Text('Sin citas programadas próximas.'),
              for (final a in appointments)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.event_available_outlined),
                  title: Text('${a['first_name']} ${a['last_name']}'),
                  subtitle: Text(
                    '${clinicalDate(a['start_at'])} · ${a['reason']}',
                  ),
                  onTap: () =>
                      route(app.PatientDetail(pid: a['patient_id'] as int)),
                ),
              TextButton(
                onPressed: () => route(const app.AppointmentsScreen()),
                child: const Text('Ver agenda completa'),
              ),
            ]),
            clinicalPanel(context, 'Pendientes de seguimiento', [
              if (pending.isEmpty) const Text('No hay pendientes abiertos.'),
              for (final t in pending)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.task_alt),
                  title: Text('${t['title']}'),
                  subtitle: Text(
                    '${t['first_name']} ${t['last_name']} · ${clinicalDate(t['due_at']).split(' ').first}',
                  ),
                  onTap: () =>
                      route(app.PatientDetail(pid: t['patient_id'] as int)),
                ),
              TextButton(
                onPressed: () => route(
                  Scaffold(
                    appBar: AppBar(title: const Text('Todos los pendientes')),
                    body: const ClinicalTasks(),
                  ),
                ),
                child: const Text('Ver todos los pendientes'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class ClinicalTools extends StatefulWidget {
  const ClinicalTools({super.key});
  @override
  State<ClinicalTools> createState() => _ClinicalToolsState();
}

class _ClinicalToolsState extends State<ClinicalTools> {
  List<Map<String, Object?>> templates = [], drafts = [];
  bool busy = false;
  String? result;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final db = await AppDb.instance.database;
      final t = await db.query('clinical_templates', orderBy: 'name');
      final d = await db.rawQuery(
        'SELECT d.*,p.first_name,p.last_name FROM clinical_drafts d JOIN patients p ON p.id=d.patient_id ORDER BY d.updated_at DESC',
      );
      if (mounted)
        setState(() {
          templates = t;
          drafts = d;
        });
    } catch (_) {
      if (mounted)
        clinicalMessage(context, 'No se pudieron cargar las herramientas.');
    }
  }

  Future<void> verify() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final db = await AppDb.instance.database;
      final check = await db.rawQuery('PRAGMA integrity_check');
      final foreign = await db.rawQuery('PRAGMA foreign_key_check');
      final good =
          check.length == 1 &&
          check.first.values.first == 'ok' &&
          foreign.isEmpty;
      if (mounted)
        setState(
          () => result = good
              ? 'Integridad y relaciones: correctas. Esta revisión no sustituye un respaldo.'
              : 'Se detectaron inconsistencias. Conserva tus respaldos y solicita revisión; no borres datos.',
        );
    } catch (_) {
      if (mounted) setState(() => result = 'No fue posible verificar la base.');
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> removeTemplate(Map<String, Object?> t) async {
    if (!await clinicalConfirm(
      context,
      'Eliminar plantilla',
      'Se eliminará solo la plantilla. Las notas ya guardadas no cambian.',
    ))
      return;
    try {
      final db = await AppDb.instance.database;
      await db.delete(
        'clinical_templates',
        where: 'id=?',
        whereArgs: [t['id']],
      );
      await load();
    } catch (_) {
      if (mounted) clinicalMessage(context, 'No se pudo eliminar.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Herramientas y apariencia')),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        clinicalPanel(context, 'Documentación clínica NOM-004', [
          const Text(
            'Configura autor y establecimiento. Las notas muestran campos faltantes y se imprimen para firma autógrafa. La revisión asistida no es una certificación NOM-024.',
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NomSettings()),
            ),
            icon: const Icon(Icons.badge_outlined),
            label: const Text('Médico y establecimiento'),
          ),
        ]),
        clinicalPanel(context, 'Apariencia', [
          ValueListenableBuilder<ThemeMode>(
            valueListenable: clinicalThemeMode,
            builder: (context, mode, _) => DropdownButtonFormField<ThemeMode>(
              value: mode,
              items: const [
                DropdownMenuItem(value: ThemeMode.dark, child: Text('Oscuro')),
                DropdownMenuItem(value: ThemeMode.light, child: Text('Claro')),
                DropdownMenuItem(
                  value: ThemeMode.system,
                  child: Text('Según el teléfono'),
                ),
              ],
              onChanged: (v) async {
                if (v == null) return;
                try {
                  await AppDb.instance.setSetting('theme_mode', v.name);
                  clinicalThemeMode.value = v;
                } catch (_) {
                  if (context.mounted)
                    clinicalMessage(
                      context,
                      'No se pudo guardar la apariencia.',
                    );
                }
              },
            ),
          ),
        ]),
        clinicalPanel(context, 'Datos y respaldo', [
          OutlinedButton.icon(
            onPressed: busy ? null : verify,
            icon: const Icon(Icons.verified_user_outlined),
            label: const Text('Verificar integridad'),
          ),
          if (busy) const LinearProgressIndicator(),
          if (result != null) Text(result!),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const app.SettingsScreen()),
            ),
            child: const Text('Abrir respaldos, seguridad y catálogos'),
          ),
        ]),
        clinicalPanel(context, 'Borradores recuperables', [
          if (drafts.isEmpty) const Text('No hay borradores pendientes.'),
          for (final d in drafts)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${d['first_name']} ${d['last_name']}'),
              subtitle: Text(
                '${noteNames[d['table_name']]} · ${clinicalDate(d['updated_at'])}',
              ),
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        app.PatientDetail(pid: d['patient_id'] as int),
                  ),
                );
                await load();
              },
            ),
        ]),
        clinicalPanel(context, 'Plantillas personales', [
          const Text(
            'Se crean desde el menú de una nota. Al utilizarlas eliges qué campos copiar.',
          ),
          for (final t in templates)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${t['name']}'),
              subtitle: Text(noteNames[t['table_name']] ?? 'Plantilla'),
              trailing: IconButton(
                tooltip: 'Eliminar plantilla',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => removeTemplate(t),
              ),
            ),
        ]),
        const ListTile(
          title: Text('Angel Medical 2.5.0'),
          subtitle: Text(
            'Uso local · Expediente cifrado · Sincronización entre dispositivos no incluida',
          ),
        ),
      ],
    ),
  );
}
