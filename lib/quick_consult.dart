import 'package:flutter/material.dart';

import 'db.dart';
import 'clinical_editor.dart';

class QuickConsultPicker extends StatefulWidget {
  const QuickConsultPicker({super.key});

  @override
  State<QuickConsultPicker> createState() => _QuickConsultPickerState();
}

class _QuickConsultPickerState extends State<QuickConsultPicker> {
  final search = TextEditingController();
  List<Map<String, Object?>> rows = [];

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load([String q = '']) async {
    rows = await AppDb.instance.searchPatients(q);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Consulta rápida')),
      body: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Selecciona al paciente',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: search,
              onChanged: load,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Nombre, CURP o teléfono',
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: rows.isEmpty
                  ? const Center(child: Text('No se encontraron pacientes'))
                  : ListView.separated(
                      itemCount: rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 6),
                      itemBuilder: (_, i) {
                        final p = rows[i];
                        return Card(
                          child: ListTile(
                            leading: const Icon(
                              Icons.bolt,
                              color: Color(0xFF2CC8FF),
                            ),
                            title: Text(
                              '${p['first_name']} ${p['last_name']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            subtitle: Text('${p['phone'] ?? ''}'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QuickConsultForm(patient: p),
                              ),
                            ),
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

class QuickConsultForm extends StatelessWidget {
  final Map<String, Object?> patient;
  const QuickConsultForm({super.key, required this.patient});
  @override
  Widget build(BuildContext context) =>
      ClinicalEditor(patient: patient, table: 'consultations');
}
