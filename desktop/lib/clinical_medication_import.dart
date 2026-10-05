import 'dart:convert';
import 'clinical_catalog.dart';

String medicationIdentity(Map<String, Object?> row) => jsonEncode([
  for (final key in ['generic_name', 'brand_name', 'form', 'strength', 'presentation', 'registration'])
    normalizeCatalogText('${row[key] ?? ''}').replaceAll(RegExp(r'\s+'), ' ').trim(),
]);

List<Map<String, Object?>> newMedicationRows(List<Map<String, Object?>> incoming, List<Map<String, Object?>> existing) {
  final seen = existing.map(medicationIdentity).toSet();
  return incoming.where((row) => seen.add(medicationIdentity(row))).toList();
}
