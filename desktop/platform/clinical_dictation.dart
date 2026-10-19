// Windows uses its system dictation (Win+H), avoiding the beta speech plugin.
class ClinicalDictation {
  static bool get listening => false;
  static Future<bool> start(void Function(String) words,void Function(String) status,void Function(String) error) async => false;
  static Future<void> stop() async {}
  static void dispose() {}
}
