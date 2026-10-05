import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

String withSourceExtension(String selected, String source) {
  final extension = p.extension(source);
  return extension.isEmpty || selected.toLowerCase().endsWith(extension.toLowerCase()) ? selected : '$selected$extension';
}

Future<File?> savePcFile(File source, {String? title}) async {
  final root = Platform.environment['LOCALAPPDATA'];
  final prefs = root == null ? null : File(p.join(root, 'AngelMedical', 'save-folder.json'));
  String? folder;
  try { if (prefs != null && await prefs.exists()) { folder = jsonDecode(await prefs.readAsString())['folder'] as String?; if (folder != null && !await Directory(folder).exists()) folder = null; } } catch (_) {}
  final extension = p.extension(source.path).replaceFirst('.', '');
  final selected = await FilePicker.platform.saveFile(dialogTitle: title ?? 'Guardar archivo', fileName: p.basename(source.path), initialDirectory: folder, type: extension.isEmpty ? FileType.any : FileType.custom, allowedExtensions: extension.isEmpty ? null : [extension]);
  if (selected == null) return null;
  var destination = withSourceExtension(selected, source.path);
  if (destination != selected && await File(destination).exists()) {
    // The native dialog has not confirmed replacement of the appended path.
    // Keep the existing backup and choose a unique timestamped filename.
    destination = p.join(p.dirname(destination), '${p.basenameWithoutExtension(destination)}_${DateTime.now().microsecondsSinceEpoch}${p.extension(destination)}');
  }
  final result = p.equals(source.path, destination) ? source : await source.copy(destination);
  try { if (prefs != null) { await prefs.parent.create(recursive: true); await prefs.writeAsString(jsonEncode({'folder': p.dirname(destination)}), flush: true); } } catch (_) {}
  return result;
}
