import '../lib/clinical_guidance.dart';
import 'nom_cases.dart' as fixtures;

final guidanceCases = <String, void Function()>{
  'Cada campo pertenece a un solo paso y ninguno desaparece': () {
    final keys = [...fixtures.initial().keys, 'extra_custom'];
    final result = guideSections(keys).expand((s) => s.keys).toList();
    fixtures.require(
      result.length == keys.length && result.toSet().containsAll(keys),
      'Campos omitidos o duplicados',
    );
  },
  'Estructuras requieren completar y bloquean finalización': () {
    for (final guide in clinicalGuides.values) {
      fixtures.require(
        guide.outline.contains(guidePlaceholder),
        'Guía sin marcador',
      );
    }
    final input = fixtures.initial()
      ..['illness'] = clinicalGuides['illness']!.outline;
    fixtures.require(
      fixtures
          .missing('consultations', input)
          .any((s) => s.contains('[Completar]')),
      'Marcador aceptado',
    );
  },
  'Marcadores de campos inactivos no bloquean la nota': () {
    final input = fixtures.initial()..['nom_death'] = guidePlaceholder;
    fixtures.require(
      !fixtures
          .missing('consultations', input)
          .any((s) => s.contains('[Completar]')),
      'Campo inactivo bloquea',
    );
  },
};
void main() {
  for (final item in guidanceCases.entries) {
    item.value();
    print('PASS: ${item.key}');
  }
}
