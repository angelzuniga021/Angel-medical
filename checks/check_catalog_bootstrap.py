"""Check packaged catalog and additive import against legacy IDs/favorites/history."""
import hashlib,json,sqlite3
from pathlib import Path
root=Path(__file__).resolve().parents[1]
raw=(root/'assets/data/cie10_full.json').read_bytes()
items=json.loads(raw)
meta=json.loads((root/'assets/data/cie10_source.json').read_text())
assert hashlib.sha256(raw).hexdigest()==meta['asset_sha256']
assert len(items)==14497 and sum(x['valid'] for x in items)==12551
source=(root/'lib/services.dart').read_text()
assert 'INSERT OR IGNORE INTO cie10' in source
assert 'bundled_cie_version' in source
con=sqlite3.connect(':memory:')
con.executescript('CREATE TABLE cie10(id INTEGER PRIMARY KEY AUTOINCREMENT,code TEXT UNIQUE,name TEXT,chapter TEXT,search_text TEXT,favorite INTEGER DEFAULT 0); CREATE TABLE notes(content TEXT);')
con.execute("INSERT INTO cie10 VALUES(42,'E119','Descripción importada','IV','DIABETES',1)")
con.execute("INSERT INTO notes VALUES('E11.9 · Nota original intacta')")
stmt='INSERT OR IGNORE INTO cie10(code,name,chapter,search_text,favorite) VALUES(?,?,?,?,0)'
active=[(r['code'],r['name'],r['chapter'],r['name']) for r in items if r['valid']]
for _ in range(2):
 with con: con.executemany(stmt,active)
assert con.execute("SELECT id,name,favorite FROM cie10 WHERE code='E119'").fetchone()==(42,'Descripción importada',1)
assert con.execute('SELECT COUNT(*) FROM cie10').fetchone()[0]==12551
assert con.execute('SELECT content FROM notes').fetchone()[0]=='E11.9 · Nota original intacta'
try:
 with con:
  con.execute(stmt,('TEST','test','',''))
  raise RuntimeError('simulated failure')
except RuntimeError: pass
assert con.execute("SELECT COUNT(*) FROM cie10 WHERE code='TEST'").fetchone()[0]==0
print('Catalog validated; existing IDs/favorites/notes preserved; repeat import and rollback passed.')
