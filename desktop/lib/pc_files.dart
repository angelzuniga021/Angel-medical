import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

/// Windows users choose the destination directly, including their Drive folder.
Future<File?> savePcFile(File source, {String? title}) async {
  final path = await FilePicker.platform.saveFile(dialogTitle: title ?? 'Guardar archivo', fileName: p.basename(source.path));
  if (path == null) return null;
  if (p.equals(source.path, path)) return source;
  return source.copy(path);
}
