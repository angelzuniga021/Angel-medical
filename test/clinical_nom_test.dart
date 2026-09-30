import 'package:flutter_test/flutter_test.dart';

import 'nom_cases.dart';

void main() {
  for (final e in nomCases.entries) {
    test(e.key, e.value);
  }
}
