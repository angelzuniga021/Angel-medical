import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import '../lib/clinical_profile.dart';

void main() {
  test('Imported patients remain accessible without attributing a missing doctor', () {
    expect(canOpenClinicalWorkspace({}, 2), true);
    expect(canOpenClinicalWorkspace({}, 0), false);
    expect(profileMissingFields({}), isNotEmpty);
  });
  test('Incomplete saved identity is an existing installation, without weakening required fields', () {
    final profile = <String, dynamic>{'doctor': 'Médico ficticio', 'license': 'TEST', 'logo_base64': 'public-fixture'};
    expect(hasExistingClinicalProfile(profile), true);
    expect(profileMissingFields(profile), isNotEmpty);
    expect(profile['doctor'], 'Médico ficticio');
    expect(hasExistingClinicalProfile({}), false);
    expect(hasExistingClinicalProfile({'doctor': '  '}), false);
  });
  test('Restore without identity preserves local profile exactly, including public certificate and logo', () {
    final local = jsonEncode({'doctor': 'Médico A', 'license': 'TEST-A', 'logo_base64': 'test', 'certificate_import': {'signed': false}});
    expect(localProfileToPreserve(local, null), local);
    expect(localProfileToPreserve(local, '{}'), local);
    expect(localProfileToPreserve(null, '{}'), null);
    final restored = jsonEncode({'doctor': 'Médico B', 'license': 'TEST-B'});
    expect(localProfileToPreserve(local, restored), null);
    expect(() => localProfileToPreserve(local, 'invalid json'), throwsFormatException);
  });
}
