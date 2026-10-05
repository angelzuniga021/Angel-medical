import 'dart:ffi';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:sqflite_common/sqlite_api.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' show createDatabaseFactoryFfi;
import 'package:sqlite3/open.dart' as loader;
export 'package:sqflite_common/sqlite_api.dart';

void loadPcCipher() {
  final override = Platform.environment['ANGEL_SQLCIPHER_DLL'];
  final path = override ?? p.join(p.dirname(Platform.resolvedExecutable), 'sqlcipher.dll');
  if (!File(path).existsSync()) throw StateError('Falta SQLCipher. Reinstala el programa; no borres los datos.');
  loader.open.overrideFor(loader.OperatingSystem.windows, () => DynamicLibrary.open(path));
}
final _factory = createDatabaseFactoryFfi(ffiInit: loadPcCipher, noIsolate: true);

Future<String> getDatabasesPath() async {
  final local = Platform.environment['ANGEL_TEST_DATA_DIR'] ?? Platform.environment['LOCALAPPDATA'];
  if (local == null) throw StateError('No se encontró la carpeta local del usuario.');
  final dir = Directory(p.join(local, 'AngelMedical', 'databases'));
  await dir.create(recursive: true);
  return dir.path;
}

Future<Database> openDatabase(String path, {String? password, int? version,
  OnDatabaseConfigureFn? onConfigure, OnDatabaseCreateFn? onCreate,
  OnDatabaseVersionChangeFn? onUpgrade, OnDatabaseVersionChangeFn? onDowngrade,
  OnDatabaseOpenFn? onOpen, bool readOnly = false, bool singleInstance = true}) async {
  if (password == null || password.isEmpty) throw StateError('No se admite una base sin cifrado.');
  return _factory.openDatabase(path, options: OpenDatabaseOptions(
    version: version, singleInstance: singleInstance,
    // sqflite ignores configure callbacks in native readOnly mode. Use
    // query_only after applying the key, so validation can decrypt safely.
    onConfigure: (db) async {
      await db.execute("PRAGMA key = '${password.replaceAll("'", "''")}'");
      await db.execute('PRAGMA cipher_compatibility = 4');
      final cipher = await db.rawQuery('PRAGMA cipher_version');
      if (cipher.isEmpty || !'${cipher.first.values.first}'.startsWith('4.')) throw StateError('Motor cifrado no compatible.');
      await db.rawQuery('SELECT count(*) FROM sqlite_master');
      if (readOnly) await db.execute('PRAGMA query_only=ON');
      if (onConfigure != null) await onConfigure(db);
    }, onCreate: onCreate, onUpgrade: onUpgrade, onDowngrade: onDowngrade, onOpen: onOpen,
  ));
}
class Sqflite {
  static int? firstIntValue(List<Map<String, Object?>> rows) => rows.isEmpty ? null : (rows.first.values.first as num?)?.toInt();
}
