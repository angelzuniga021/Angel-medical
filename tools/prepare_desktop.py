"""Generate the Windows edition from the same clinical source, no DB shipped."""
from pathlib import Path
import shutil

root = Path(__file__).resolve().parents[1]
pc = root / 'desktop'
lib = pc / 'lib'
lib.mkdir(exist_ok=True)
for file in lib.glob('*.dart'):
    file.unlink()
for file in (root / 'lib').glob('*.dart'):
    content = file.read_text(encoding='utf-8')
    content = content.replace("'package:sqflite_sqlcipher/sqflite.dart'", "'pc_database.dart'").replace('package:angel_medical_mobile/', 'package:angel_medical_pc/')
    (lib / file.name).write_text(content, encoding='utf-8')
for file in (pc / 'platform').glob('*.dart'):
    shutil.copyfile(file, lib / file.name)

# Same dependencies, replacing only the database backend. Pin sqlite3 v2 for
# a deliberate SQLCipher DLL loader instead of native plain-SQLite build hooks.
pub = (root / 'pubspec.yaml').read_text(encoding='utf-8').replace('name: angel_medical_mobile', 'name: angel_medical_pc').replace('version: 3.2.2+122', 'version: 1.0.0+10')
pub = pub.replace('  sqflite_sqlcipher: ^3.4.1', '  sqflite_common: ^2.5.6\n  sqflite_common_ffi: 2.3.7\n  sqlite3: 2.9.4')
(pc / 'pubspec.yaml').write_text(pub, encoding='utf-8')
shutil.copytree(root / 'assets', pc / 'assets', dirs_exist_ok=True)

def edit(name, fn):
    path = lib / name
    path.write_text(fn(path.read_text(encoding='utf-8')), encoding='utf-8')

edit('clinical_signature.dart', lambda s: s.replace("import 'clinical_pdf_signature.dart';", "import 'clinical_pdf_signature.dart';\nimport 'pc_signature.dart';\nimport 'pc_files.dart';").replace("const signatureChannel = MethodChannel('angel_medical/signature');", 'const signatureChannel = PcSignatureChannel();').replace("await Share.shareXFiles([XFile(file.path)], text: 'Receta con firma digital integrada.');", "await savePcFile(file, title: 'Guardar receta firmada');").replace("await Share.shareXFiles([XFile(file.path)], text: 'PDF y firma separada. Confianza y revocación SAT pendientes de verificar.');", "await savePcFile(file, title: 'Guardar paquete de firma');"))

edit('services.dart', lambda s: s.replace("import 'clinical_prescription_pdf.dart';", "import 'clinical_prescription_pdf.dart';\nimport 'pc_files.dart';").replace("    await Share.shareXFiles(\n      [XFile(file.path)],\n      subject: 'Respaldo Angel Medical',\n      text: 'Respaldo cifrado de Angel Medical. Guarda este archivo en Google Drive, OneDrive u otra nube segura.',\n    );", "    final saved = await savePcFile(file, title: 'Guardar respaldo .ambak · puedes elegir tu carpeta Drive');\n    if (saved == null) throw const FormatException('Guardado cancelado. La base local sigue intacta.');\n    await AppDb.instance.setSetting('last_backup_file', saved.path);"))

# Unified version, direct save/restore language, standalone initial setup.
edit('main.dart', lambda s: s.replace("import 'clinical_profile.dart';", "import 'clinical_profile.dart';\nimport 'dart:io';").replace("'Angel Medical',", "'Angel Medical PC',").replace('En el menú de Android selecciona Google Drive para guardarlo.', 'Elige la carpeta donde guardar el .ambak; puedes seleccionar tu carpeta de Drive.').replace("child: const Text('Configurar mi consulta'),", "child: const Text('Comenzar desde cero'),").replace("                  child: const Text('Comenzar desde cero'),\n                ),", "                  child: const Text('Comenzar desde cero'),\n                ),\n              if (configured != null) TextButton.icon(onPressed: () async { await const SettingsScreen().restoreBackup(context); await load(); }, icon: const Icon(Icons.restore), label: const Text('Importar respaldo .ambak del teléfono')),\n              const Padding(padding: EdgeInsets.only(top: 12), child: Text('Los cambios se guardan en esta PC. No necesitas importar un respaldo para comenzar.')),"))
edit('clinical_home.dart', lambda s: s.replace('Angel Medical 3.2.2', 'Angel Medical PC 1.0').replace('Sincronización entre dispositivos no incluida.', 'Base local de esta PC · Respaldos .ambak compatibles con Android.').replace("        clinicalPanel(context, 'PC y Drive · preparación', [", "        clinicalPanel(context, 'Intercambio avanzado · .amx', ["))

# Windows notifications are in-process timers, never install services silently.
shutil.copyfile(pc / 'platform' / 'pc_notifications.dart', lib / 'notification_service.dart')

tests = pc / 'test'
tests.mkdir(exist_ok=True)
shutil.copytree(root / 'test' / 'fixtures', tests / 'fixtures', dirs_exist_ok=True)
for f in tests.glob('*.dart'):
    f.unlink()
for f in (root / 'test').glob('*.dart'):
    (tests / f.name).write_text(f.read_text(encoding='utf-8').replace('package:angel_medical_mobile/', 'package:angel_medical_pc/'), encoding='utf-8')
for f in (pc / 'checks').glob('*_test.dart'):
    shutil.copyfile(f, tests / f.name)
print('Windows: módulos compartidos, SQLCipher, firma, respaldo y pruebas preparados.')

edit('main.dart', lambda s: s.replace('      home: const Gate(),', "      builder: (context, child) => ValueListenableBuilder<String?>(valueListenable: pcReminder, builder: (context, reminder, _) => Column(children: [if (reminder != null) Material(color: Theme.of(context).colorScheme.primaryContainer, child: SafeArea(bottom: false, child: Row(children: [const SizedBox(width: 16), Expanded(child: Text(reminder)), IconButton(onPressed: () => pcReminder.value = null, icon: const Icon(Icons.close))]))), Expanded(child: child!)])),\n      home: const Gate(),"))
