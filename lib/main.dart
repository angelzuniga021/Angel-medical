import 'clinical_birthdate.dart';
import 'clinical_nom_settings.dart';
import 'clinical_nom.dart';

import 'clinical_record.dart';

import 'clinical_ui.dart';
import 'clinical_editor.dart';
import 'clinical_hub.dart';
import 'clinical_home.dart';
import 'clinical_theme.dart';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'db.dart';
import 'services.dart';
import 'quick_consult.dart';
import 'notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await AppDb.instance.database;
    await loadClinicalTheme();
    await CieBootstrap.ensureLoaded();
    try {
      await NotificationService.instance.init();
      await NotificationService.instance.reconcile();
    } catch (_) {
      /* Agenda remains usable when notifications are denied. */
    }
    runApp(const AngelMedicalApp());
  } catch (_) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 48),
                    const SizedBox(height: 16),
                    const Text(
                      'No se pudo abrir Angel Medical. Tus archivos no se han borrado. No desinstales ni borres los datos. Solicita revisión y conserva tu respaldo.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: main,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const blue = Color(0xFF3F7CFF);
const cyan = Color(0xFF2CC8FF);
const bg = Color(0xFF080D14);
const card = Color(0xFF111923);

String fmtDate(Object? value) {
  final s = '${value ?? ''}';
  try {
    return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(s));
  } catch (_) {
    return s;
  }
}

Widget sectionTitle(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.only(top: 8, bottom: 10),
  child: Text(
    text,
    style: Theme.of(context).textTheme.titleLarge
        ?.copyWith(fontWeight: FontWeight.w800),
  ),
);

Widget infoLine(String label, Object? value) {
  final text = '${value ?? ''}'.trim();
  if (text.isEmpty) return const SizedBox.shrink();
  return Padding(
    padding: const EdgeInsets.only(top: 7),
    child: Align(alignment: Alignment.centerLeft, child: Text('$label: $text')),
  );
}

class AngelMedicalApp extends StatelessWidget {
  const AngelMedicalApp({super.key});
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<ThemeMode>(
    valueListenable: clinicalThemeMode,
    builder: (context, mode, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Angel Medical',
      themeMode: mode,
      theme: clinicalTheme(Brightness.light),
      darkTheme: clinicalTheme(Brightness.dark),
      home: const Gate(),
    ),
  );
}

class DoctorSetupGate extends StatefulWidget {
  const DoctorSetupGate({super.key});
  @override
  State<DoctorSetupGate> createState() => _DoctorSetupGateState();
}

class _DoctorSetupGateState extends State<DoctorSetupGate> {
  bool? configured;
  String? error;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final profile = decodeNom(await AppDb.instance.getSetting('nom_profile'));
      final ready = [
        'doctor',
        'license',
        'profession',
        'establishment',
        'establishment_type',
        'address',
        'place',
      ].every((k) => '${profile[k] ?? ''}'.trim().isNotEmpty);
      if (mounted)
        setState(() {
          configured = ready;
          error = null;
        });
    } catch (_) {
      if (mounted) setState(() => error = 'No se pudo leer el perfil.');
    }
  }

  Future<void> setup() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const NomSettings()),
    );
    await load();
  }

  @override
  Widget build(BuildContext context) {
    if (configured == true) return const Shell();
    return Scaffold(
      appBar: AppBar(title: const Text('Bienvenido a Angel Medical')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.medical_information_outlined, size: 60),
              const SizedBox(height: 16),
              const Text(
                'Configura tu nombre, cédula y establecimiento antes de comenzar. Los expedientes se guardan en este dispositivo.',
              ),
              const SizedBox(height: 16),
              if (error != null) Text(error!),
              if (configured == null && error == null)
                const CircularProgressIndicator()
              else
                FilledButton(
                  onPressed: setup,
                  child: const Text('Configurar mi consulta'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class Gate extends StatefulWidget {
  const Gate({super.key});

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  bool? firstSetup;
  final pin = TextEditingController();
  final confirm = TextEditingController();
  String error = '';

  @override
  void initState() {
    super.initState();
    SecurityService.hasPin().then((hasPin) {
      if (mounted) setState(() => firstSetup = !hasPin);
    });
  }

  Future<void> submit() async {
    if (firstSetup == true) {
      if (pin.text.length < 4) {
        setState(() => error = 'Usa al menos 4 dígitos');
        return;
      }
      if (pin.text != confirm.text) {
        setState(() => error = 'Los PIN no coinciden');
        return;
      }
      await SecurityService.setPin(pin.text);
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DoctorSetupGate()),
        );
      }
      return;
    }

    if (await SecurityService.verifyPin(pin.text)) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DoctorSetupGate()),
        );
      }
    } else {
      setState(() => error = 'PIN incorrecto');
    }
  }

  Future<void> biometric() async {
    if (await SecurityService.biometric() && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DoctorSetupGate()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (firstSetup == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.health_and_safety_outlined,
                      size: 62,
                      color: cyan,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Angel Medical',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      firstSetup == true
                          ? 'Configura tu acceso seguro'
                          : 'Expediente clínico cifrado',
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: pin,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: firstSetup == true ? 'Nuevo PIN' : 'PIN',
                      ),
                    ),
                    if (firstSetup == true) ...[
                      const SizedBox(height: 8),
                      TextField(
                        controller: confirm,
                        obscureText: true,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Confirmar PIN',
                        ),
                      ),
                    ],
                    if (error.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        error,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: submit,
                        child: Text(
                          firstSetup == true ? 'Crear PIN' : 'Desbloquear',
                        ),
                      ),
                    ),
                    if (firstSetup == false)
                      TextButton.icon(
                        onPressed: biometric,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Biometría'),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int index = 0;

  final pages = const [
    ClinicalHome(),
    PatientsScreen(),
    EmergencyList(),
    HospitalList(),
    AppointmentsScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 850;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (wide)
              NavigationRail(
                selectedIndex: index,
                onDestinationSelected: (v) => setState(() => index = v),
                labelType: NavigationRailLabelType.all,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.home_outlined),
                    label: Text('Inicio'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.people_outline),
                    label: Text('Pacientes'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.local_hospital_outlined),
                    label: Text('Urgencias'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.bed_outlined),
                    label: Text('Hospital'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.calendar_month_outlined),
                    label: Text('Agenda'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.settings_outlined),
                    label: Text('Ajustes'),
                  ),
                ],
              ),
            Expanded(child: pages[index]),
          ],
        ),
      ),
      floatingActionButton: index == 1
          ? FloatingActionButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const PatientForm()),
                );
                setState(() {});
              },
              child: const Icon(Icons.add),
            )
          : null,
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (v) => setState(() => index = v),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  label: 'Inicio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  label: 'Pacientes',
                ),
                NavigationDestination(
                  icon: Icon(Icons.local_hospital_outlined),
                  label: 'Urgencias',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bed_outlined),
                  label: 'Hospital',
                ),
                NavigationDestination(
                  icon: Icon(Icons.calendar_month_outlined),
                  label: 'Agenda',
                ),
                NavigationDestination(
                  icon: Icon(Icons.settings_outlined),
                  label: 'Ajustes',
                ),
              ],
            ),
    );
  }
}

class Dashboard extends StatefulWidget {
  const Dashboard({super.key});

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  int patients = 0;
  int consults = 0;
  int emergencies = 0;
  int hospitalized = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    patients = await AppDb.instance.count('patients');
    consults = await AppDb.instance.count('consultations');
    emergencies = await AppDb.instance.count('emergencies');
    hospitalized = (await AppDb.instance.all(
      'hospitalizations',
      where: 'status=?',
      args: ['hospitalizado'],
    )).length;
    if (mounted) setState(() {});
  }

  Widget stat(String title, int value, IconData icon) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: cyan),
            const Spacer(),
            Text(
              '$value',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            Text(title),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          const Text(
            'ANGEL MEDICAL',
            style: TextStyle(
              color: cyan,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.4,
            ),
          ),
          Text(
            'Expediente clínico móvil',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const Text('Offline · cifrado · respaldable'),
          const SizedBox(height: 18),
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.55,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              stat('Pacientes', patients, Icons.people_outline),
              stat('Consultas', consults, Icons.description_outlined),
              stat('Urgencias', emergencies, Icons.local_hospital_outlined),
              stat('Hospitalizados', hospitalized, Icons.bed_outlined),
            ],
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<Map<String, Object?>>>(
            future: AppDb.instance.all('appointments', orderBy: 'start_at ASC'),
            builder: (_, snap) {
              final now = DateTime.now();
              final items = (snap.data ?? []).where((x) {
                try {
                  final d = DateTime.parse('${x['start_at']}');
                  return d.year == now.year &&
                      d.month == now.month &&
                      d.day == now.day &&
                      '${x['status']}' == 'programada';
                } catch (_) {
                  return false;
                }
              }).toList();
              if (items.isEmpty) return const SizedBox.shrink();
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Citas de hoy',
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      ...items
                          .take(4)
                          .map(
                            (x) => ListTile(
                              dense: true,
                              leading: const Icon(Icons.schedule, color: cyan),
                              title: Text('${x['reason'] ?? 'Cita'}'),
                              subtitle: Text(fmtDate(x['start_at'])),
                            ),
                          ),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accesos rápidos',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  ListTile(
                    leading: const Icon(Icons.bolt, color: cyan),
                    title: const Text('Consulta rápida'),
                    subtitle: const Text(
                      'Captura breve, automatizada y opcional',
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const QuickConsultPicker(),
                        ),
                      );
                      load();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1),
                    title: const Text('Nuevo paciente'),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PatientForm()),
                      );
                      load();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.medical_information_outlined),
                    title: const Text('Importar catálogo CIE-10'),
                    subtitle: const Text(
                      'XLSX con CATALOG_KEY / NOMBRE / LETRA',
                    ),
                    onTap: () async {
                      try {
                        final n = await CieImporter.importXlsx();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('$n diagnósticos importados'),
                            ),
                          );
                        }
                      } catch (ex) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('$ex')));
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PatientsScreen extends StatefulWidget {
  const PatientsScreen({super.key});

  @override
  State<PatientsScreen> createState() => _PatientsState();
}

class _PatientsState extends State<PatientsScreen> {
  final q = TextEditingController();
  List<Map<String, Object?>> rows = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load([String text = '']) async {
    rows = await AppDb.instance.searchPatients(text);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Pacientes'),
        automaticallyImplyLeading: Navigator.canPop(context),
      ),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            TextField(
              controller: q,
              onChanged: load,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Nombre, CURP o teléfono',
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('Sin pacientes'))
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 7),
                      itemBuilder: (_, i) {
                        final r = rows[i];
                        final fn = '${r['first_name'] ?? ''}';
                        final ln = '${r['last_name'] ?? ''}';
                        final subtitle = [r['phone'], r['blood_type']]
                            .where((x) => x != null && '$x'.isNotEmpty)
                            .join(' · ');
                        return Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: const Color(0xFF17305A),
                              child: Text(
                                '${fn.isNotEmpty ? fn[0] : ''}${ln.isNotEmpty ? ln[0] : ''}',
                              ),
                            ),
                            title: Text(
                              '$fn $ln',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text(subtitle),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      PatientDetail(pid: r['id'] as int),
                                ),
                              );
                              load(q.text);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class PatientForm extends StatefulWidget {
  final Map<String, Object?>? patient;

  const PatientForm({super.key, this.patient});

  @override
  State<PatientForm> createState() => _PatientFormState();
}

class _PatientFormState extends State<PatientForm> {
  late final Map<String, TextEditingController> c;
  String sex = '';
  String blood = '';

  @override
  void initState() {
    super.initState();
    String value(String key) => '${widget.patient?[key] ?? ''}';
    c = {
      for (final key in [
        'first_name',
        'last_name',
        'dob',
        'phone',
        'curp',
        'occupation',
        'marital_status',
        'address',
        'emergency_contact',
        'emergency_phone',
        'allergies',
        'personal_history',
        'family_history',
        'surgical_history',
        'chronic_meds',
        'notes',
      ])
        key: TextEditingController(text: value(key)),
    };
    final existingDob = parseBirthDate(c['dob']!.text);
    if (existingDob != null) c['dob']!.text = birthDateDisplay(existingDob);
    sex = value('sex');
    blood = value('blood_type');
  }

  Widget field(
    String key,
    String label, {
    int lines = 1,
    TextInputType? keyboardType,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c[key],
        maxLines: lines,
        keyboardType: keyboardType,
        decoration: InputDecoration(labelText: label),
      ),
    );
  }

  Widget two(Widget a, Widget b) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: a),
        const SizedBox(width: 8),
        Expanded(child: b),
      ],
    );
  }

  Future<void> chooseBirthDate() async {
    final now = DateTime.now();
    final chosen = await showDatePicker(
      context: context,
      initialDate:
          parseBirthDate(c['dob']!.text) ??
          DateTime(now.year - 30, now.month, now.day),
      firstDate: DateTime(1850),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Selecciona año, mes y día de nacimiento',
      fieldLabelText: 'Fecha de nacimiento',
      cancelText: 'Cancelar',
      confirmText: 'Elegir',
    );
    if (chosen != null && mounted)
      setState(() => c['dob']!.text = birthDateDisplay(chosen));
  }

  @override
  void dispose() {
    for (final controller in c.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (c['first_name']!.text.trim().isEmpty ||
        c['last_name']!.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nombre y apellidos son obligatorios')),
      );
      return;
    }

    final dobText = c['dob']!.text.trim();
    final birth = parseBirthDate(dobText);
    if (dobText.isNotEmpty && birth == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Escribe una fecha válida DD/MM/AAAA, anterior o igual a hoy.',
          ),
        ),
      );
      return;
    }
    final normalizedDob = birth == null ? '' : birthDateIso(birth);

    final duplicates = await AppDb.instance.findDuplicatePatients(
      firstName: c['first_name']!.text,
      lastName: c['last_name']!.text,
      dob: normalizedDob,
      phone: c['phone']!.text,
      curp: c['curp']!.text,
      excludeId: widget.patient?['id'] as int?,
    );

    if (duplicates.isNotEmpty && mounted) {
      final names = duplicates
          .map(
            (x) =>
                '${x['first_name']} ${x['last_name']} · ${x['dob'] ?? ''} · ${x['phone'] ?? ''}',
          )
          .join('\n');
      final proceed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Posible paciente duplicado'),
          content: Text(
            'Ya existe un registro que podría corresponder al mismo paciente:\n\n$names\n\n¿Deseas guardar de todos modos?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Guardar de todos modos'),
            ),
          ],
        ),
      );
      if (proceed != true) return;
    }

    final now = DateTime.now().toIso8601String();
    final data = <String, Object?>{
      for (final e in c.entries) e.key: e.value.text.trim(),
      'dob': normalizedDob,
      'sex': sex,
      'blood_type': blood,
      'updated_at': now,
    };

    if (widget.patient == null) {
      data['created_at'] = now;
      final id = await AppDb.instance.insert('patients', data);
      await AppDb.instance.audit('CREATE_PATIENT', '$id');
    } else {
      final id = widget.patient!['id'] as int;
      await AppDb.instance.update('patients', data, id);
      await AppDb.instance.audit('UPDATE_PATIENT', '$id');
    }

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.patient == null ? 'Nuevo paciente' : 'Editar paciente',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          sectionTitle(context, 'Datos generales'),
          two(
            field('first_name', 'Nombre *'),
            field('last_name', 'Apellidos *'),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextField(
              controller: c['dob'],
              keyboardType: TextInputType.datetime,
              decoration: InputDecoration(
                labelText: 'Fecha de nacimiento',
                hintText: 'DD/MM/AAAA',
                helperText:
                    'Escribe la fecha o toca el calendario para elegir el año.',
                suffixIcon: IconButton(
                  tooltip: 'Elegir fecha de nacimiento',
                  onPressed: chooseBirthDate,
                  icon: const Icon(Icons.calendar_month),
                ),
              ),
            ),
          ),
          two(
            DropdownButtonFormField<String>(
              value: sex.isEmpty ? null : sex,
              decoration: const InputDecoration(labelText: 'Sexo'),
              items: [
                'Masculino',
                'Femenino',
                'Otro',
              ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
              onChanged: (v) => setState(() => sex = v ?? ''),
            ),
            DropdownButtonFormField<String>(
              value: blood.isEmpty ? null : blood,
              decoration: const InputDecoration(labelText: 'Sangre'),
              items: [
                'A+',
                'A-',
                'B+',
                'B-',
                'AB+',
                'AB-',
                'O+',
                'O-',
                'Desconocido',
              ].map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(),
              onChanged: (v) => setState(() => blood = v ?? ''),
            ),
          ),
          const SizedBox(height: 8),
          field('phone', 'Teléfono', keyboardType: TextInputType.phone),
          field('curp', 'CURP'),
          field('occupation', 'Ocupación'),
          field('marital_status', 'Estado civil'),
          field('address', 'Dirección', lines: 2),
          sectionTitle(context, 'Contacto de emergencia'),
          two(
            field('emergency_contact', 'Nombre'),
            field('emergency_phone', 'Teléfono'),
          ),
          sectionTitle(context, 'Antecedentes'),
          field('allergies', 'Alergias', lines: 2),
          field('personal_history', 'Personales / patológicos', lines: 3),
          field('family_history', 'Familiares', lines: 3),
          field('surgical_history', 'Quirúrgicos', lines: 3),
          field('chronic_meds', 'Medicación habitual', lines: 3),
          field('notes', 'Notas', lines: 3),
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Guardar paciente'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class PatientDetail extends StatelessWidget {
  final int pid;
  const PatientDetail({super.key, required this.pid});
  @override
  Widget build(BuildContext context) => ModernPatientHub(pid: pid);
}

class ConsultationForm extends StatelessWidget {
  final Map<String, Object?> patient;
  const ConsultationForm({super.key, required this.patient});
  @override
  Widget build(BuildContext context) =>
      ClinicalEditor(patient: patient, table: 'consultations');
}

class EmergencyList extends StatefulWidget {
  const EmergencyList({super.key});

  @override
  State<EmergencyList> createState() => _EmergencyListState();
}

class _EmergencyListState extends State<EmergencyList> {
  List<Map<String, Object?>> rows = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    rows = await AppDb.instance.all('emergencies', orderBy: 'date DESC');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Urgencias')),
      body: rows.isEmpty
          ? const Center(
              child: Text(
                'Sin atenciones de urgencias.\nInicia una desde el expediente del paciente.',
                textAlign: TextAlign.center,
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: rows.length,
              itemBuilder: (_, i) {
                final r = rows[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(
                      Icons.local_hospital_outlined,
                      color: cyan,
                    ),
                    title: Text('${r['diagnoses'] ?? r['reason'] ?? ''}'),
                    subtitle: Text(
                      '${fmtDate(r['date'])} · ${r['triage'] ?? ''}',
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class EmergencyForm extends StatelessWidget {
  final Map<String, Object?> patient;
  const EmergencyForm({super.key, required this.patient});
  @override
  Widget build(BuildContext context) =>
      ClinicalEditor(patient: patient, table: 'emergencies');
}

class HospitalList extends StatefulWidget {
  const HospitalList({super.key});

  @override
  State<HospitalList> createState() => _HospitalListState();
}

class _HospitalListState extends State<HospitalList> {
  List<Map<String, Object?>> rows = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    rows = await AppDb.instance.all(
      'hospitalizations',
      orderBy: 'admitted_at DESC',
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Hospitalización')),
      body: rows.isEmpty
          ? const Center(child: Text('Sin hospitalizaciones'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: rows.length,
              itemBuilder: (_, i) {
                final r = rows[i];
                return Card(
                  child: ListTile(
                    leading: const Icon(Icons.bed_outlined, color: cyan),
                    title: Text('${r['diagnoses'] ?? 'Hospitalización'}'),
                    subtitle: Text(
                      'Hab ${r['room'] ?? '—'} / Cama ${r['bed'] ?? '—'} · ${r['status'] ?? ''}',
                    ),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => HospitalDetail(hid: r['id'] as int),
                        ),
                      );
                      load();
                    },
                  ),
                );
              },
            ),
    );
  }
}

class HospitalForm extends StatelessWidget {
  final Map<String, Object?> patient;
  const HospitalForm({super.key, required this.patient});
  @override
  Widget build(BuildContext context) =>
      ClinicalEditor(patient: patient, table: 'hospitalizations');
}

class HospitalDetail extends StatefulWidget {
  final int hid;

  const HospitalDetail({super.key, required this.hid});

  @override
  State<HospitalDetail> createState() => _HospitalDetailState();
}

class _HospitalDetailState extends State<HospitalDetail> {
  Map<String, Object?>? h;
  Map<String, Object?>? p;
  List<Map<String, Object?>> notes = [];
  List<Map<String, Object?>> orders = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    h = await AppDb.instance.one('hospitalizations', widget.hid);
    if (h != null) {
      p = await AppDb.instance.one('patients', h!['patient_id'] as int);
    }
    notes = await AppDb.instance.all(
      'progress_notes',
      where: 'hospitalization_id=?',
      args: [widget.hid],
      orderBy: 'date DESC',
    );
    orders = await AppDb.instance.all(
      'medical_orders',
      where: 'hospitalization_id=?',
      args: [widget.hid],
      orderBy: 'date DESC',
    );
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (h == null || p == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text('${p!['first_name']} ${p!['last_name']}')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Habitación ${h!['room'] ?? '—'} · Cama ${h!['bed'] ?? '—'}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text('${h!['diagnoses'] ?? ''}'),
                  Text('Estado: ${h!['status']}'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              ActionChip(
                label: const Text('+ Evolución'),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProgressForm(hid: widget.hid),
                    ),
                  );
                  load();
                },
              ),
              ActionChip(
                label: const Text('+ Indicaciones'),
                onPressed: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OrdersForm(hid: widget.hid),
                    ),
                  );
                  load();
                },
              ),
              if (h!['status'] == 'hospitalizado')
                ActionChip(
                  label: const Text('Egreso'),
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => DischargeForm(h: h!)),
                    );
                    load();
                  },
                ),
            ],
          ),
          sectionTitle(context, 'Evoluciones'),
          if (notes.isEmpty) const Text('Sin evoluciones.'),
          ...notes.map(
            (x) => Card(
              child: ExpansionTile(
                title: Text(fmtDate(x['date'])),
                subtitle: Text('${x['assessment'] ?? ''}'),
                childrenPadding: const EdgeInsets.all(12),
                children: [
                  for (final field in clinicalFields(x))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text('${field.key}: ${field.value}'),
                    ),
                  OutlinedButton.icon(
                    onPressed: () => PdfService.printClinical(
                      title: 'Evolución hospitalaria',
                      patient: p!,
                      fields: clinicalFields(x),
                      record: x,
                    ),
                    icon: const Icon(Icons.print_outlined),
                    label: const Text('Imprimir nota completa'),
                  ),
                ],
              ),
            ),
          ),
          sectionTitle(context, 'Indicaciones'),
          if (orders.isEmpty) const Text('Sin indicaciones.'),
          ...orders.map(
            (x) => Card(
              child: ListTile(
                title: Text(fmtDate(x['date'])),
                subtitle: Text(
                  'Dieta: ${x['diet'] ?? ''}\n'
                  'Medicamentos: ${x['medications'] ?? ''}',
                  maxLines: 3,
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.print_outlined),
                  onPressed: () => PdfService.printClinical(
                    title: 'INDICACIONES MÉDICAS',
                    patient: p!,
                    fields: clinicalFields(x),
                    record: x,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProgressForm extends StatelessWidget {
  final int hid;
  const ProgressForm({super.key, required this.hid});
  @override
  Widget build(BuildContext context) =>
      HospitalNoteEditor(hid: hid, table: 'progress_notes');
}

class OrdersForm extends StatelessWidget {
  final int hid;
  const OrdersForm({super.key, required this.hid});
  @override
  Widget build(BuildContext context) =>
      HospitalNoteEditor(hid: hid, table: 'medical_orders');
}

class DischargeForm extends StatelessWidget {
  final Map<String, Object?> h;
  const DischargeForm({super.key, required this.h});
  @override
  Widget build(BuildContext context) => FutureBuilder<Map<String, Object?>?>(
    future: AppDb.instance.one('patients', h['patient_id'] as int),
    builder: (context, s) {
      if (s.connectionState != ConnectionState.done)
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (s.hasError || s.data == null)
        return Scaffold(
          appBar: AppBar(),
          body: const Center(child: Text('No se pudo abrir el paciente')),
        );
      return ClinicalEditor(
        patient: s.data!,
        table: 'documents',
        parentId: h['id'] as int,
        documentType: 'Nota de egreso',
      );
    },
  );
}

class DocumentForm extends StatelessWidget {
  final Map<String, Object?> patient;
  const DocumentForm({super.key, required this.patient});
  @override
  Widget build(BuildContext context) =>
      ClinicalEditor(patient: patient, table: 'documents');
}

class AppointmentForm extends StatefulWidget {
  final Map<String, Object?> patient;

  const AppointmentForm({super.key, required this.patient});

  @override
  State<AppointmentForm> createState() => _AppointmentFormState();
}

class _AppointmentFormState extends State<AppointmentForm> {
  DateTime when = DateTime.now().add(const Duration(hours: 1));
  final reason = TextEditingController(text: 'Consulta');
  final notes = TextEditingController();
  int minutesBefore = 30;

  Future<void> pickDateTime() async {
    final d = await showDatePicker(
      context: context,
      initialDate: when,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 730)),
    );
    if (d == null || !mounted) return;

    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(when),
    );
    if (t == null) return;

    setState(() {
      when = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    });
  }

  Future<void> save() async {
    final now = DateTime.now().toIso8601String();
    final id = await AppDb.instance.insert('appointments', {
      'patient_id': widget.patient['id'],
      'start_at': when.toIso8601String(),
      'reason': reason.text.trim(),
      'notes': notes.text.trim(),
      'status': 'programada',
      'notify_minutes_before': minutesBefore,
      'created_at': now,
      'updated_at': now,
    });

    final patientName =
        '${widget.patient['first_name']} ${widget.patient['last_name']}';

    await NotificationService.instance.scheduleAppointment(
      id: 500000 + id,
      patientName: patientName,
      when: when,
      minutesBefore: minutesBefore,
    );

    final current = DateTime.now();
    if (when.year == current.year &&
        when.month == current.month &&
        when.day == current.day) {
      await NotificationService.instance.showTodayReminder(
        id: 700000 + id,
        patientName: patientName,
        when: when,
      );
    }

    await AppDb.instance.audit('CREATE_APPOINTMENT', '$id');

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Agendar cita')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Text(
            '${widget.patient['first_name']} ${widget.patient['last_name']}',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: const Icon(Icons.event, color: cyan),
              title: const Text('Fecha y hora'),
              subtitle: Text(fmtDate(when.toIso8601String())),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: pickDateTime,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: reason,
            decoration: const InputDecoration(labelText: 'Motivo'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notas'),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: minutesBefore,
            decoration: const InputDecoration(labelText: 'Avisarme antes'),
            items: const [
              DropdownMenuItem(value: 0, child: Text('A la hora')),
              DropdownMenuItem(value: 15, child: Text('15 minutos antes')),
              DropdownMenuItem(value: 30, child: Text('30 minutos antes')),
              DropdownMenuItem(value: 60, child: Text('1 hora antes')),
              DropdownMenuItem(value: 120, child: Text('2 horas antes')),
            ],
            onChanged: (v) => setState(() => minutesBefore = v ?? 30),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: save,
            icon: const Icon(Icons.notifications_active_outlined),
            label: const Text('Guardar cita y programar aviso'),
          ),
        ],
      ),
    );
  }
}

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  List<Map<String, Object?>> rows = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    rows = await AppDb.instance.all('appointments', orderBy: 'start_at ASC');
    if (mounted) setState(() {});
  }

  Future<String> patientName(int pid) async {
    final p = await AppDb.instance.one('patients', pid);
    if (p == null) return 'Paciente';
    return '${p['first_name']} ${p['last_name']}';
  }

  @override
  Widget build(BuildContext context) {
    final upcoming = rows.where((x) {
      if ('${x['status']}' != 'programada') return false;
      try {
        return DateTime.parse('${x['start_at']}')
            .isAfter(DateTime.now().subtract(const Duration(hours: 12)));
      } catch (_) {
        return false;
      }
    }).toList();

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Agenda')),
      body: upcoming.isEmpty
          ? const Center(child: Text('No hay citas próximas'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: upcoming.length,
              itemBuilder: (_, i) {
                final x = upcoming[i];
                return FutureBuilder<String>(
                  future: patientName(x['patient_id'] as int),
                  builder: (_, snap) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.calendar_month, color: cyan),
                      title: Text(snap.data ?? 'Paciente'),
                      subtitle: Text(
                        '${fmtDate(x['start_at'])}\n${x['reason'] ?? ''}',
                      ),
                      isThreeLine: true,
                      trailing: PopupMenuButton<String>(
                        onSelected: (value) async {
                          if (value == 'done') {
                            await AppDb.instance.update('appointments', {
                              'status': 'atendida',
                              'updated_at': DateTime.now().toIso8601String(),
                            }, x['id'] as int);
                          } else if (value == 'cancel') {
                            await AppDb.instance.update('appointments', {
                              'status': 'cancelada',
                              'updated_at': DateTime.now().toIso8601String(),
                            }, x['id'] as int);
                            await NotificationService.instance.cancel(
                              500000 + (x['id'] as int),
                            );
                          }
                          load();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'done',
                            child: Text('Marcar atendida'),
                          ),
                          PopupMenuItem(
                            value: 'cancel',
                            child: Text('Cancelar cita'),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}

class PatientStatusSheet extends StatelessWidget {
  final Map<String, Object?> patient;

  const PatientStatusSheet({super.key, required this.patient});

  Future<void> markDeceased(BuildContext context) async {
    final notes = TextEditingController();
    DateTime date = DateTime.now();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Marcar paciente como fallecido'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.event),
                title: const Text('Fecha'),
                subtitle: Text(
                  '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                ),
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: date,
                    firstDate: DateTime(1900),
                    lastDate: DateTime.now(),
                  );
                  if (d != null) setDialogState(() => date = d);
                },
              ),
              TextField(
                controller: notes,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Observaciones / causa (opcional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Confirmar'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    await AppDb.instance.update('patients', {
      'is_deceased': 1,
      'deceased_at': date.toIso8601String(),
      'death_notes': notes.text.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }, patient['id'] as int);

    await AppDb.instance.audit('MARK_DECEASED', '${patient['id']}');

    if (context.mounted) Navigator.pop(context);
  }

  Future<void> archive(BuildContext context) async {
    await AppDb.instance.update('patients', {
      'is_archived': 1,
      'updated_at': DateTime.now().toIso8601String(),
    }, patient['id'] as int);
    await AppDb.instance.audit('ARCHIVE_PATIENT', '${patient['id']}');
    if (context.mounted) Navigator.pop(context);
  }

  Future<void> delete(BuildContext context) async {
    final ok = await clinicalConfirm(
      context,
      'Conservar el expediente',
      'Los expedientes deben conservarse como mínimo cinco años desde el último acto médico. Puedes archivarlo para ocultarlo de la lista sin borrar notas ni adjuntos. ¿Archivar este paciente?',
    );
    if (ok && context.mounted) await archive(context);
  }

  @override
  Widget build(BuildContext context) {
    final deceased = (patient['is_deceased'] ?? 0) == 1;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Modificar paciente'),
              subtitle: const Text('Usa el botón editar del expediente'),
              onTap: () => Navigator.pop(context),
            ),
            if (!deceased)
              ListTile(
                leading: const Icon(Icons.heart_broken_outlined),
                title: const Text('Marcar como fallecido'),
                subtitle: const Text(
                  'Conserva el expediente y registra la fecha',
                ),
                onTap: () => markDeceased(context),
              ),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: const Text('Archivar paciente'),
              subtitle: const Text(
                'Oculta de la lista sin borrar el expediente',
              ),
              onTap: () => archive(context),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_forever,
                color: Colors.redAccent,
              ),
              title: const Text(
                'Conservar y archivar',
                style: TextStyle(color: Colors.redAccent),
              ),
              subtitle: const Text(
                'Conserva notas y adjuntos; evita el borrado irreversible',
              ),
              onTap: () => delete(context),
            ),
          ],
        ),
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<String?> askPassword(
    BuildContext context,
    String title, {
    String subtitle = 'Esta contraseña protege el respaldo cifrado.',
  }) async {
    final c = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(subtitle),
            const SizedBox(height: 10),
            TextField(
              controller: c,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Contraseña del respaldo',
                hintText: 'Mínimo 6 caracteres',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text.trim()),
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }

  Future<void> cloudBackup(BuildContext context) async {
    final pass = await askPassword(
      context,
      'Respaldar en la nube',
      subtitle: 'Angel Medical generará un archivo cifrado. En el menú de Android selecciona Google Drive para guardarlo.',
    );

    if (pass == null || pass.isEmpty) return;

    try {
      final file = await clinicalBlocking(
        context,
        'Creando respaldo cifrado…',
        () => BackupService.createAndShareToCloud(pass),
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Respaldo creado: ${file.path.split(RegExp(r'[\\/]')).last}',
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No se pudo crear el respaldo: $e')),
        );
      }
    }
  }

  Future<void> restoreBackup(BuildContext context) async {
    final pass = await askPassword(
      context,
      'Restaurar desde Drive / archivo',
      subtitle: 'Selecciona el archivo .ambak desde Google Drive, Descargas u otro proveedor. La base actual será sustituida.',
    );

    if (pass == null || pass.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Restaurar respaldo?'),
        content: const Text(
          'Antes de reemplazar la base actual, Angel Medical guardará una copia de seguridad local de emergencia. Después restaurará el archivo seleccionado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Seleccionar respaldo'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final ok = await clinicalBlocking(
      context,
      'Validando y restaurando…',
      () => BackupService.restoreFromCloudOrFile(pass),
    );
    if (ok) {
      try {
        await NotificationService.instance.reconcile();
      } catch (_) {}
      await loadClinicalTheme();
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Respaldo restaurado correctamente'
                : 'No se pudo restaurar. Verifica archivo y contraseña.',
          ),
        ),
      );
    }
  }

  Future<void> verifyBackup(BuildContext context) async {
    final pass = await askPassword(
      context,
      'Verificar respaldo',
      subtitle: 'Selecciona un .ambak. Se comprobará la contraseña y el contenido sin modificar tu base actual.',
    );

    if (pass == null || pass.isEmpty) return;

    try {
      final info = await clinicalBlocking(
        context,
        'Verificando respaldo…',
        () => BackupService.inspect(pass),
      );
      if (info == null || !context.mounted) return;

      final mb = ((info['sizeBytes'] as int) / (1024 * 1024)).toStringAsFixed(
        1,
      );

      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Respaldo válido'),
          content: Text(
            'Archivo: ${info['fileName']}\n'
            'Creado: ${info['createdAt']}\n'
            'Base de datos: $mb MB\n\n'
            'El archivo pudo descifrarse y su base pasó la verificación de integridad. No se modificó la base actual.',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo verificar: contraseña incorrecta o archivo dañado.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Column(
              children: [
                FutureBuilder<String?>(
                  future: AppDb.instance.getSetting('last_backup_at'),
                  builder: (_, snap) => ListTile(
                    leading: const Icon(Icons.cloud_done_outlined, color: cyan),
                    title: const Text('Último respaldo creado'),
                    subtitle: Text(
                      snap.data == null
                          ? 'Aún no registrado'
                          : fmtDate(snap.data),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.add_to_drive_outlined, color: cyan),
                  title: const Text('Guardar respaldo en Google Drive'),
                  subtitle: const Text(
                    'Crea un .ambak cifrado y abre el menú para elegir Drive',
                  ),
                  onTap: () => cloudBackup(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.verified_user_outlined),
                  title: const Text('Verificar un respaldo'),
                  subtitle: const Text(
                    'Comprueba contraseña e integridad sin restaurarlo',
                  ),
                  onTap: () => verifyBackup(context),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.cloud_download_outlined),
                  title: const Text('Restaurar desde Drive / archivo'),
                  subtitle: const Text(
                    'Puedes seleccionar el .ambak desde Google Drive',
                  ),
                  onTap: () => restoreBackup(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.medication_outlined),
                  title: const Text('Importar catálogo de medicamentos'),
                  subtitle: const Text(
                    'XLSX de COFEPRIS u otro catálogo compatible',
                  ),
                  onTap: () async {
                    try {
                      final n = await MedicationImporter.importXlsx();
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('$n medicamentos importados')),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text('$e')));
                      }
                    }
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'El respaldo en Drive sirve para recuperar la misma base en otro teléfono o tablet. No es sincronización en tiempo real: evita editar simultáneamente la misma base en dos dispositivos.',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
