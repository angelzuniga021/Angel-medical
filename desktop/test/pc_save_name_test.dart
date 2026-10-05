import 'package:flutter_test/flutter_test.dart';
import '../lib/pc_files.dart';
void main() {
  test('Save names retain backup and signed PDF extensions', () {
    expect(withSourceExtension('respaldo', 'original.ambak'), 'respaldo.ambak');
    expect(withSourceExtension('respaldo.AMBAK', 'original.ambak'), 'respaldo.AMBAK');
    expect(withSourceExtension('receta', 'firmada.pdf'), 'receta.pdf');
  });
}
