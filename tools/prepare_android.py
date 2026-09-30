"""Generate missing Flutter Android scaffolding, then apply reviewed configuration."""
from pathlib import Path
import shutil, subprocess, tempfile, os
root = Path(__file__).resolve().parents[1]
if (root / 'android').exists():
    raise SystemExit('android already exists; refusing to replace it')
with tempfile.TemporaryDirectory() as tmp:
    scaffold = Path(tmp) / 'scaffold'
    subprocess.run(['flutter', 'create', '--platforms=android', '--project-name',
                    'angel_medical_mobile', '--org', 'com.drangelzuniga',
                    '--no-pub', str(scaffold)], check=True)
    shutil.copytree(scaffold / 'android', root / 'android')
for source in (root / 'android_overlay').rglob('*'):
    if not source.is_file() or source.name == 'GeneratedPluginRegistrant.java':
        continue
    destination = root / 'android' / source.relative_to(root / 'android_overlay')
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)
manifest = root / 'android/app/src/main/AndroidManifest.xml'
manifest.write_text(manifest.read_text().replace('android:label="Angel Medical"',
                                               'android:label="Angel Medical Beta"' if os.environ.get('ANGEL_MODE') == 'pruebas' else 'android:label="Angel Medical"'))
