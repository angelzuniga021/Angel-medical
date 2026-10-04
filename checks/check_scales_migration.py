from pathlib import Path
import sqlite3,re,json
p=Path(__file__).resolve().parent.parent
sqls=re.findall(r"'([^']+)'",(p/'lib/clinical_schema.dart').read_text())
db=sqlite3.connect(':memory:');db.execute('PRAGMA foreign_keys=ON');db.executescript((p/'checks/legacy_schema.sql').read_text())
db.execute('INSERT INTO patients(id,first_name,last_name,created_at,updated_at) VALUES(1,"Paciente","Ficticio","now","now")')
for sql in sqls:
 if 'clinical_scales' not in sql:db.execute(sql)
for table in ['consultations','emergencies','documents','hospitalizations','progress_notes','medical_orders']:db.execute(f'ALTER TABLE {table} ADD COLUMN nom_json TEXT')
db.execute('INSERT INTO documents(patient_id,date,type,title,content,created_at,nom_json) VALUES(1,"now","Receta","Título","Indicación previa","now",?)',(json.dumps({'signature':'previous'}),))
db.execute('INSERT INTO clinical_attachments(patient_id,name,mime,data,sha256,created_at) VALUES(1,"prev.amfirma","application/octet-stream",?,"hash","now")',(bytes(range(256)),))
db.execute('PRAGMA user_version=6');db.commit()
names=[r[0] for r in db.execute("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")]
before={t:db.execute(f'SELECT * FROM {t}').fetchall() for t in names}
with db:
 for sql in sqls:db.execute(sql)
 db.execute('PRAGMA user_version=7')
assert {t:db.execute(f'SELECT * FROM {t}').fetchall() for t in names}==before
assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
assert not db.execute('PRAGMA foreign_key_check').fetchall()
row=(1,'gcs','Glasgow','1.0','2026-10-04',15,'puntos','Respuestas y resultado',json.dumps({'answers':{'eye':4,'verbal':5,'motor':6},'profile':{'doctor':'Ficticio'}}),'now')
with db:db.execute('INSERT INTO clinical_scales(patient_id,scale_id,scale_name,scale_version,date,score,unit,summary,payload,created_at) VALUES(?,?,?,?,?,?,?,?,?,?)',row)
copy=sqlite3.connect(':memory:');db.backup(copy)
assert copy.execute('SELECT payload FROM clinical_scales').fetchone()[0]==row[8]
try:
 with db:db.execute('INSERT INTO clinical_scales(patient_id,scale_id,scale_name,scale_version,date,score,unit,summary,payload,created_at) VALUES(?,?,?,?,?,?,?,?,?,?)',(999,*row[1:]))
except sqlite3.IntegrityError:pass
else:raise AssertionError('Missing patient must be rejected')
try:
 with db:
  db.execute('INSERT INTO clinical_scales(patient_id,scale_id,scale_name,scale_version,date,score,unit,summary,payload,created_at) VALUES(?,?,?,?,?,?,?,?,?,?)',row)
  raise RuntimeError('audit failed')
except RuntimeError:pass
assert db.execute('SELECT COUNT(*) FROM clinical_scales').fetchone()[0]==1
print('PASS: 6→7 preserves patients, notes and signature bytes; scale backup, patient constraint and rollback')
