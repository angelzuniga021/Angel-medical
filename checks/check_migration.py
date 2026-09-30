from pathlib import Path
import sqlite3, re, json
root=Path(__file__).resolve().parent.parent
old=(root/'checks/legacy_schema.sql').read_text()
new=(root/'lib/clinical_schema.dart').read_text()
sqls=re.findall(r"'([^']+)'",new)
def setup():
 db=sqlite3.connect(':memory:');db.execute('PRAGMA foreign_keys=ON');db.executescript(old)
 for pid in [1,2]:db.execute('INSERT INTO patients(id,first_name,last_name,created_at,updated_at) VALUES(?,?,?,?,?)',(pid,'Ficticio',str(pid),'2026-01-01','2026-01-01'))
 for table in ['consultations','emergencies','documents']:
  extras={'consultations':{},'emergencies':{},'documents':{'type':'Nota libre','title':'Ejemplo','content':'Texto'}}[table]
  data={'patient_id':1,'date':'2026-01-02','created_at':'2026-01-02',**extras}
  db.execute(f'INSERT INTO {table}({",".join(data)}) VALUES({",".join("?" for _ in data)})',list(data.values()))
 db.execute('INSERT INTO hospitalizations(id,patient_id,admitted_at,status,created_at) VALUES(1,1,?,?,?)',('2026-01-01','egresado','2026-01-01'))
 for table in ['progress_notes','medical_orders']:db.execute(f'INSERT INTO {table}(hospitalization_id,date,created_at) VALUES(1,?,?)',('2026-01-02','2026-01-02'))
 db.commit();return db
db=setup();tables=['patients','consultations','emergencies','documents','hospitalizations','progress_notes','medical_orders']
before={t:db.execute(f'SELECT * FROM {t}').fetchall() for t in tables}
with db:
 for sql in sqls:db.execute(sql)
 db.execute('PRAGMA user_version=5')
assert {t:db.execute(f'SELECT * FROM {t}').fetchall() for t in tables}==before
assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
assert db.execute('PRAGMA foreign_key_check').fetchall()==[]
# BLOB is included in database backup; reopening preserves its exact bytes.
blob=bytes(range(256))*128
db.execute('INSERT INTO clinical_attachments(patient_id,name,mime,data,sha256,created_at) VALUES(1,?,?,?,?,?)',('demo.pdf','application/pdf',blob,'test','2026-01-01'))
copy=sqlite3.connect(':memory:');db.commit();db.backup(copy)
assert copy.execute('SELECT data FROM clinical_attachments').fetchone()[0]==blob
# Referential constraints reject attachment placement on a missing patient.
try:db.execute('INSERT INTO clinical_tasks(patient_id,title,created_at,updated_at) VALUES(999,"x","x","x")')
except sqlite3.IntegrityError:pass
else:raise AssertionError('Foreign keys missing')
db.rollback()
# A failure inside the note/revision/draft transaction rolls everything back.
db.execute('INSERT INTO clinical_drafts VALUES("d",1,"consultations",NULL,?,"2026-01-01")',(json.dumps({'illness':'draft'}),));db.commit()
try:
 with db:
  db.execute('UPDATE consultations SET illness="changed" WHERE id=1')
  db.execute('INSERT INTO clinical_revisions(patient_id,table_name,record_id,before_json,after_json,reason,created_at) VALUES(1,"consultations",1,"{}","{}","correction","today")')
  db.execute('DELETE FROM clinical_drafts WHERE draft_key="d"')
  raise RuntimeError('simulated failure')
except RuntimeError:pass
assert db.execute('SELECT illness FROM consultations WHERE id=1').fetchone()[0] is None
assert db.execute('SELECT COUNT(*) FROM clinical_revisions').fetchone()[0]==0
assert db.execute('SELECT COUNT(*) FROM clinical_drafts').fetchone()[0]==1
print('PASS: additive migration preserves all rows; integrity, BLOB backup, patient constraints and transaction rollback.')
