import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/clinical_catalog.dart';

void main() {
  test('Full supplied catalog retains reference flags and excludes placeholder', () {
    final items = (jsonDecode(File('assets/data/cie10_full.json').readAsStringSync()) as List).cast<Map<String, dynamic>>();
    final rows = validateCatalogRows(items.map((m) => ['${m['code']}', '${m['name']}', '${m['chapter']}']));
    expect(rows.length, 14497);
    expect(items.where((m) => m['valid'] == true).length, 12551);
    expect(items.any((m) => m['code'] == '9999'), false);
    BundledCie.entries = {for (final m in items) '${m['code']}': m};
    expect(BundledCie.entries['U071']!['name'], 'COVID-19, VIRUS IDENTIFICADO');
    expect(BundledCie.displayCode('e11.9'), 'E11.9');
    expect(BundledCie.canonical('E11.9'), 'E119');
    expect(BundledCie.displayCode('I10X'), 'I10X');
    final retired = items.firstWhere((m) => m['valid'] == false);
    expect(BundledCie.selectable('${retired['code']}'), false);
    expect(BundledCie.selectable(BundledCie.displayCode('${retired['code']}')), false);
    expect(normalizeCatalogText('Hipertensión'), 'HIPERTENSION');
  });
}
