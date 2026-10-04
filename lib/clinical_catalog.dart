String normalizeCatalogText(String text) {
  const from = 'ÁÉÍÓÚÜÑáéíóúüñ';
  const to = 'AEIOUUNAEIOUUN';
  for (var i = 0; i < from.length; i++) {
    text = text.replaceAll(from[i], to[i]);
  }
  return text.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
}

class CatalogEntry {
  final String code, name, chapter;
  const CatalogEntry(this.code, this.name, this.chapter);
  String get searchText => normalizeCatalogText('$code $name');
}

List<CatalogEntry> validateCatalogRows(Iterable<List<String>> rows) {
  final entries = <CatalogEntry>[];
  final seen = <String>{};
  var rowNumber = 1;
  for (final row in rows) {
    rowNumber++;
    final code = row[0].trim().toUpperCase();
    final name = row[1].trim();
    final chapter = row.length > 2 ? row[2].trim() : '';
    if (code.isEmpty && name.isEmpty) continue;
    if (!RegExp(r'^[A-Z][0-9]{2}(?:\.?[0-9A-Z]{1,4})?$').hasMatch(code) ||
        name.isEmpty) {
      throw FormatException(
        'Fila $rowNumber: código o descripción incompletos/ inválidos.',
      );
    }
    if (!seen.add(code))
      throw FormatException('Código duplicado $code en fila $rowNumber.');
    entries.add(CatalogEntry(code, name, chapter));
  }
  if (entries.isEmpty)
    throw const FormatException(
      'El catálogo no contiene diagnósticos válidos.',
    );
  return entries;
}

/// Reference flags from the bundled catalog; historic notes are never rewritten.
class BundledCie {
  static Map<String, Map<String, dynamic>> entries = {};
  static String canonical(String code) => code.toUpperCase().replaceAll('.', '').trim();
  static bool selectable(String code) => entries[canonical(code)]?['valid'] != false;
  static bool complementary(String code) => entries[canonical(code)]?['complementary'] == true;
  static String displayCode(String code) {
    final c = canonical(code);
    return c.length == 4 ? '${c.substring(0, 3)}.${c.substring(3)}' : c;
  }
}
