import 'package:flutter_test/flutter_test.dart';

import 'catalog_cases.dart';

void main() {
  for (final c in catalogCases.entries) {
    test(c.key, c.value);
  }
}
