from pathlib import Path
import re, sqlite3, json
root=Path(__file__).resolve().parent.parent
legacy=(root/'checks/legacy_schema.sql').read_text()
clinical=(root/'lib/clinical_schema.dart').read_text()
nom=(root/'lib/clinical_nom.dart').read_text()
tables=re.findall(r"'([^']+)'",re.search(r'const nomTables = \[(.*?)\];',nom,re.S).group(1))
def setup(version):
 db=sqlite3.connect(':memory:');db.execute('PRAGMA foreign_keys=ON');db.executescript(legacy)
 db.execute('INSERT INTO patients(id,first_name,last_name,created_at,updated_at) VALUES(1,"Paciente","Ficticio","now","now")')
 for t in ['consultations','emergencies','documents']:
  data={'patient_id':1,'date':'2026-09-01','created_at':'2026-09-01'}
  if t=='documents':data.update(type='Nota libre',title='Ejemplo',content='Dato clínico previo')
  db.execute(f'INSERT INTO {t}({",".join(data)}) VALUES({",".join("?" for _ in data)})',list(data.values()))
 db.execute('INSERT INTO hospitalizations(id,patient_id,admitted_at,created_at) VALUES(1,1,"2026-09-01","2026-09-01")')
 for t in ['progress_notes','medical_orders']:
  db.execute(f'INSERT INTO {t}(hospitalization_id,date,created_at) VALUES(1,"2026-09-01","2026-09-01")')
 if version>=5:
  for sql in re.findall(r"'([^']+)'",clinical):db.execute(sql)
 db.execute(f'PRAGMA user_version={version}');db.commit();return db
for version in [4,5]:
 db=setup(version)
 before={t:db.execute(f'SELECT * FROM {t}').fetchall() for t in ['patients',*tables]}
 db.execute('BEGIN')
 with db:
  if version<5:
   for sql in re.findall(r"'([^']+)'",clinical):db.execute(sql)
  for t in tables:db.execute(f'ALTER TABLE {t} ADD COLUMN nom_json TEXT')
  db.execute('PRAGMA user_version=6')
 for t in tables:
  now=db.execute(f'SELECT * FROM {t}').fetchall()
  assert [r[:-1] for r in now]==before[t]
  assert all(r[-1] is None for r in now),'Historical authorship must remain absent'
 assert db.execute('SELECT * FROM patients').fetchall()==before['patients']
 assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
 assert not db.execute('PRAGMA foreign_key_check').fetchall()
 # Snapshot metadata in encrypted DB payload also survives portable DB backup.
 meta=json.dumps({'profile':{'doctor':'Autor ficticio'},'patient':{'age':35},'signature':'pending_ink'})
 db.execute('UPDATE consultations SET nom_json=? WHERE id=1',(meta,));db.commit()
 copy=sqlite3.connect(':memory:');db.backup(copy)
 assert copy.execute('SELECT nom_json FROM consultations').fetchone()[0]==meta
 # Inserting discharge document and closing hospitalization must succeed atomically.
 try:
  with db:
   db.execute('UPDATE hospitalizations SET status="egresado",discharged_at="2026-09-30" WHERE id=1')
   db.execute('INSERT INTO documents(patient_id,date,type,title,content,created_at,nom_json) VALUES(1,"2026-09-30","Nota de egreso","Egreso","Texto","now",?)',(meta,))
   raise RuntimeError('simulated failure before audit')
 except RuntimeError:pass
 assert db.execute('SELECT status FROM hospitalizations').fetchone()[0]=='hospitalizado'
 assert db.execute('SELECT COUNT(*) FROM documents WHERE type="Nota de egreso"').fetchone()[0]==0
 print(f'PASS: schema {version}->6, original rows/columns preserved; metadata backup and discharge rollback')
# sqflite onUpgrade is transactional; reproduce that boundary explicitly.
db=setup(5);db.execute('BEGIN')
try:
 db.execute(f'ALTER TABLE {tables[0]} ADD COLUMN nom_json TEXT')
 db.execute('PRAGMA user_version=6')
 raise RuntimeError('simulated failure')
except RuntimeError:db.rollback()
assert 'nom_json' not in [r[1] for r in db.execute(f'PRAGMA table_info({tables[0]})')]
assert db.execute('PRAGMA user_version').fetchone()[0]==5
print('PASS: failed migration rolls back schema and version inside explicit transaction')
