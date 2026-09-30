import '../lib/clinical_catalog.dart';

void check(bool ok) {
  if (!ok) throw StateError('Catalog check failed');
}

final catalogCases = <String, void Function()>{
  'Normaliza acentos y espacios para búsquedas': () {
    check(
      normalizeCatalogText('  diagnóstico   clínico ') == 'DIAGNOSTICO CLINICO',
    );
  },
  'Conserva códigos sin inventar equivalencias': () {
    final x = validateCatalogRows([
      ['A00.0', 'Ejemplo ficticio'],
      ['B001', 'Otro ejemplo ficticio'],
    ]);
    check(x.length == 2 && x[1].code == 'B001');
  },
  'Rechaza vacío, duplicados y descripción faltante': () {
    for (final rows in <List<List<String>>>[
      [],
      [
        ['A00', ''],
      ],
      [
        ['A00', 'Uno'],
        ['a00', 'Dos'],
      ],
    ]) {
      var failed = false;
      try {
        validateCatalogRows(rows);
      } on FormatException {
        failed = true;
      }
      check(failed);
    }
  },
};
void main() {
  for (final c in catalogCases.entries) {
    c.value();
    print('PASS: ${c.key}');
  }
}
