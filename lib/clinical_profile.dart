import 'clinical_nom.dart';

const profileRequiredKeys = ['doctor', 'license', 'profession', 'establishment', 'establishment_type', 'address', 'place'];

/// Existing identity is not a new installation merely because fields are missing.
bool hasExistingClinicalProfile(Map<String, dynamic> profile) =>
    ['doctor', 'license'].any((k) => '${profile[k] ?? ''}'.trim().isNotEmpty);

List<String> profileMissingFields(Map<String, dynamic> profile) =>
    profileRequiredKeys.where((k) => '${profile[k] ?? ''}'.trim().isEmpty)
        .map((k) => nomProfileLabels[k] ?? k).toList();

/// Never overwrite a profile supplied by the restored database.
String? localProfileToPreserve(String? local, String? restored) =>
    !hasExistingClinicalProfile(decodeNom(restored)) && hasExistingClinicalProfile(decodeNom(local)) ? local : null;
