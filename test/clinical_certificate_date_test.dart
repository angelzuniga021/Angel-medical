import 'package:flutter_test/flutter_test.dart';

import 'certificate_date_cases.dart';

void main() {
  for (final c in certificateDateCases.entries) {
    test(c.key, c.value);
  }
}
