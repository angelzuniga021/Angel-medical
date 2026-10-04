import 'dart:async';
import 'package:flutter/material.dart';
import 'clinical_catalog.dart';
import 'clinical_ui.dart';
import 'db.dart';

class ClinicalCieScreen extends StatefulWidget {
  final bool select;
  const ClinicalCieScreen({super.key, this.select = false});
  @override
  State<ClinicalCieScreen> createState() => _ClinicalCieScreenState();
}

class _ClinicalCieScreenState extends State<ClinicalCieScreen> {
  final query = TextEditingController();
  Timer? timer;
  int request = 0;
  bool favorites = false, loading = false;
  String? error;
  List<Map<String, Object?>> rows = [];
  @override
  void initState() { super.initState(); query.addListener(changed); }
  void changed() {
    timer?.cancel();
    timer = Timer(const Duration(milliseconds: 250), search);
  }
  Future<void> search() async {
    final token = ++request;
    setState(() { loading = true; error = null; });
    try {
      final result = await AppDb.instance.searchCie(query.text, favoritesOnly: favorites);
      if (mounted && token == request) setState(() { rows = result; loading = false; });
    } catch (_) {
      if (mounted && token == request) setState(() { loading = false; error = 'No se pudo consultar el catálogo.'; });
    }
  }
  Future<void> favorite(Map<String, Object?> row) async {
    try {
      final db = await AppDb.instance.database;
      await db.update('cie10', {'favorite': row['favorite'] == 1 ? 0 : 1}, where: "REPLACE(code,'.','')=?", whereArgs: [BundledCie.canonical('${row['code']}')]);
      if (mounted) await search();
    } catch (_) { if (mounted) clinicalMessage(context, 'No se pudo actualizar el favorito.'); }
  }
  @override
  void dispose() { timer?.cancel(); query.removeListener(changed); query.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.select ? 'Elegir diagnóstico' : 'Biblioteca CIE-10')),
    body: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(18, 12, 18, 0), child: TextField(
        controller: query, autofocus: widget.select,
        decoration: InputDecoration(hintText: 'Código o diagnóstico · E11.9, diabetes…', prefixIcon: const Icon(Icons.search), suffixIcon: IconButton(tooltip: 'Limpiar búsqueda', onPressed: query.clear, icon: const Icon(Icons.close))),
      )),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10), child: Row(children: [
        FilterChip(label: const Text('Favoritos'), avatar: const Icon(Icons.star_outline, size: 18), selected: favorites, onSelected: (v) { setState(() => favorites = v); search(); }),
        const SizedBox(width: 12), const Expanded(child: Text('Disponible sin conexión', style: TextStyle(fontSize: 12))),
      ])),
      if (loading) const LinearProgressIndicator(),
      Expanded(child: error != null ? Center(child: Text(error!)) : rows.isEmpty
        ? Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.manage_search_rounded, size: 56, color: Theme.of(context).colorScheme.primary), const SizedBox(height: 16),
          Text(query.text.trim().length < 2 && !favorites ? 'Busca por nombre o código' : 'Sin coincidencias', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8), const Text('Usa al menos dos caracteres. Marca tus diagnósticos frecuentes con la estrella.', textAlign: TextAlign.center),
        ])))
        : ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 14), itemCount: rows.length, itemBuilder: (ctx, i) {
          final row = rows[i]; final code = '${row['code']}';
          return Card(child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Text('${BundledCie.displayCode(code)} · ${row['name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Capítulo ${row['chapter'] ?? ''}${BundledCie.complementary(code) ? ' · Código complementario: requiere diagnóstico principal' : ''}'),
            trailing: IconButton(tooltip: row['favorite'] == 1 ? 'Quitar favorito' : 'Guardar favorito', onPressed: () => favorite(row), icon: Icon(row['favorite'] == 1 ? Icons.star_rounded : Icons.star_outline_rounded, color: row['favorite'] == 1 ? Colors.orange : null)),
            onTap: widget.select ? () => Navigator.pop(context, row) : null,
          ));
        })),
      const Padding(padding: EdgeInsets.all(14), child: Text('Referencia: catálogo y diccionario importados. Códigos no vigentes excluidos de nuevas selecciones. Hasta 100 resultados por búsqueda.', style: TextStyle(fontSize: 11), textAlign: TextAlign.center)),
    ]),
  );
}
