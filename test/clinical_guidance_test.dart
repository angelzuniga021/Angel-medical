import 'package:flutter_test/flutter_test.dart';

import 'guidance_cases.dart';

void main() {
  for (final item in guidanceCases.entries) {
    test(item.key, item.value);
  }
}
