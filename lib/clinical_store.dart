import 'dart:convert';

import 'package:sqflite_sqlcipher/sqflite.dart';

import 'db.dart';

import 'clinical_models.dart';
import 'clinical_nom.dart';
export 'clinical_models.dart';

class ClinicalStore {
  static Future<void> verifyOwner(
    DatabaseExecutor db,
    String table,
    Map<String, Object?> record,
    int pid,
  ) async {
    if (!noteFields.containsKey(table)) throw StateError('Tipo no permitido');
    if (table == 'progress_notes' || table == 'medical_orders') {
      final parent = await db.query(
        'hospitalizations',
        where: 'id=? AND patient_id=?',
        whereArgs: [record['hospitalization_id'], pid],
      );
      if (parent.length != 1)
        throw StateError('La hospitalización no pertenece al paciente');
    } else if (record['patient_id'] != pid) {
      throw StateError('El registro no pertenece al paciente');
    }
  }

  static Future<Map<String, Object?>> readEvent(
    Map<String, Object?> event,
    int pid,
  ) async {
    final table = '${event['table']}';
    if (!noteFields.containsKey(table)) throw StateError('Tipo no permitido');
    final db = await AppDb.instance.database;
    final rows = await db.query(table, where: 'id=?', whereArgs: [event['id']]);
    if (rows.length != 1) throw StateError('Registro no encontrado');
    await verifyOwner(db, table, rows.single, pid);
    return rows.single;
  }

  static Future<int> finalize({
    required String table,
    required int pid,
    required Map<String, String> input,
    required String draftKey,
    int? parentId,
    Map<String, Object?>? original,
    String reason = '',
  }) async {
    if (!noteFields.containsKey(table)) throw StateError('Tipo no permitido');
    final values = parseClinicalInput(table, input);
    if (!noteFields[table]!.any(
      (key) =>
          !numericFields.contains(key) &&
          !{'type', 'title'}.contains(key) &&
          (input[key] ?? '').trim().isNotEmpty,
    )) {
      throw const FormatException(
        'Escribe el contenido clínico antes de finalizar.',
      );
    }
    final encounter = DateTime.tryParse(input['_encounter_at'] ?? '');
    if (encounter == null)
      throw const FormatException('Selecciona fecha y hora de la atención');
    final db = await AppDb.instance.database;
    return db.transaction((tx) async {
      final patients = await tx.query(
        'patients',
        where: 'id=?',
        whereArgs: [pid],
      );
      if (patients.length != 1) throw StateError('Paciente no encontrado');
      final patient = patients.single;
      final settings = await tx.query(
        'app_settings',
        where: 'setting_key=?',
        whereArgs: ['nom_profile'],
      );
      final rawProfile = settings.isEmpty
          ? <String, dynamic>{}
          : decodeNom(settings.single['setting_value']);
      final profile = {
        for (final e in rawProfile.entries) e.key: '${e.value ?? ''}',
      };
      final issues = nomMissing(
        table: table,
        input: input,
        patient: patient,
        profile: profile,
        encounter: encounter,
      );
      if (issues.isNotEmpty)
        throw FormatException('Falta completar:\n${issues.join('\n')}');
      // Validate extra numeric fields with the same parser used for consultations.
      parseClinicalInput('consultations', {
        for (final key in nomKeys(table, input).where(numericFields.contains))
          key: input[key] ?? '',
      });
      if (original != null &&
          table == 'documents' &&
          input['type'] != original['type']) {
        throw const FormatException(
          'El tipo de un documento finalizado no se cambia. Crea otro documento.',
        );
      }
      if (original != null) {
        final dateKey = table == 'hospitalizations' ? 'admitted_at' : 'date';
        if (DateTime.tryParse('${original[dateKey]}') != encounter) {
          throw const FormatException(
            'La fecha de una nota finalizada no puede cambiar',
          );
        }
      }
      if (table == 'progress_notes' || table == 'medical_orders') {
        final hid = original?['hospitalization_id'] ?? parentId;
        final h = await tx.query(
          'hospitalizations',
          where: 'id=? AND patient_id=?',
          whereArgs: [hid, pid],
        );
        if (h.length != 1)
          throw StateError('Hospitalización ajena o inexistente');
        if (encounter.isBefore(DateTime.parse('${h.single['admitted_at']}')))
          throw const FormatException(
            'La atención no puede ser anterior al ingreso',
          );
      }
      final oldNom = decodeNom(original?['nom_json']);
      final extras = {
        for (final key in nomKeys(table, input)) key: (input[key] ?? '').trim(),
        if (table == 'consultations')
          'nom_kind': input['nom_kind'] ?? 'Historia clínica inicial',
      };
      if (original != null && oldNom.isNotEmpty) {
        final oldFields = nomInput(original);
        final baseChanged = values.entries.any(
          (e) => original[e.key] != e.value,
        );
        final extrasChanged =
            extras.length != oldFields.length ||
            extras.entries.any((e) => oldFields[e.key] != e.value);
        if (!baseChanged && !extrasChanged)
          throw const FormatException('No hay cambios clínicos para guardar');
        if (table == 'consultations' &&
            oldFields['nom_kind'] != null &&
            input['nom_kind'] != oldFields['nom_kind']) {
          throw const FormatException(
            'El tipo de una atención finalizada no puede cambiar',
          );
        }
      }
      final stamp = <String, dynamic>{
        'schema': 1,
        'reference': 'NOM-004-SSA3-2012',
        'fields': extras,
        'signature': 'pending_ink',
        'patient':
            oldNom['patient'] ??
            {
              'id': pid,
              'name': '${patient['first_name']} ${patient['last_name']}',
              'age': ageAt(patient['dob'], encounter),
              'dob': patient['dob'],
              'sex': patient['sex'],
              'address': patient['address'],
            },
        if (original == null) 'profile': profile,
        if (original != null) ...{
          if (oldNom['profile'] != null) 'profile': oldNom['profile'],
          'legacy': oldNom.isEmpty || oldNom['legacy'] == true,
          'correction_profile': profile,
          'corrected_at': DateTime.now().toIso8601String(),
        },
        if (oldNom['hospitalization_id'] != null) ...{
          'hospitalization_id': oldNom['hospitalization_id'],
          'hospital_admitted_at': oldNom['hospital_admitted_at'],
        },
      };
      if (table == 'documents' && input['type'] == 'Nota de egreso') {
        final hid = original == null ? parentId : oldNom['hospitalization_id'];
        final hospitals = await tx.query(
          'hospitalizations',
          where: 'id=? AND patient_id=?',
          whereArgs: [hid, pid],
        );
        if (hospitals.length != 1)
          throw StateError(
            'Abre el egreso desde la hospitalización del paciente',
          );
        final h = hospitals.single;
        if (original == null && h['status'] != 'hospitalizado')
          throw StateError('La hospitalización ya tiene egreso registrado');
        if (encounter.isBefore(DateTime.parse('${h['admitted_at']}')))
          throw const FormatException(
            'El egreso no puede ser anterior al ingreso',
          );
        stamp['hospitalization_id'] = hid;
        stamp['hospital_admitted_at'] = h['admitted_at'];
        if (original == null) {
          await tx.update(
            'hospitalizations',
            {
              'discharged_at': encounter.toIso8601String(),
              'status': 'egresado',
              'discharge_diagnoses': input['nom_diagnoses'],
              'discharge_summary': input['content'],
              'discharge_treatment': input['nom_medication_details'],
              'discharge_recommendations': [
                input['nom_discharge_plan'],
                input['nom_outpatient'],
                input['nom_risk_factors'],
              ].where((x) => x != null && x.isNotEmpty).join('\n'),
            },
            where: 'id=? AND patient_id=?',
            whereArgs: [hid, pid],
          );
        } else {
          // Synchronize the summary while preserving the original discharge timestamp.
          await tx.update(
            'hospitalizations',
            {
              'discharge_diagnoses': input['nom_diagnoses'],
              'discharge_summary': input['content'],
              'discharge_treatment': input['nom_medication_details'],
              'discharge_recommendations': [
                input['nom_discharge_plan'],
                input['nom_outpatient'],
                input['nom_risk_factors'],
              ].where((x) => x != null && x.isNotEmpty).join('\n'),
            },
            where: 'id=? AND patient_id=?',
            whereArgs: [hid, pid],
          );
        }
      }
      values['nom_json'] = jsonEncode(stamp);
      final now = DateTime.now().toIso8601String();
      int id;
      if (original != null) {
        if (reason.trim().isEmpty)
          throw const FormatException('Indica el motivo de la corrección.');
        id = original['id'] as int;
        final rows = await tx.query(table, where: 'id=?', whereArgs: [id]);
        if (rows.length != 1) throw StateError('Registro no encontrado');
        final current = rows.single;
        await verifyOwner(tx, table, current, pid);
        if (current.length != original.length ||
            original.entries.any((e) => current[e.key] != e.value)) {
          throw StateError(
            'La nota cambió mientras la editabas. Sal, vuelve a abrirla y revisa la versión actual.',
          );
        }
        final changed = values.entries.any((e) => current[e.key] != e.value);
        if (!changed)
          throw const FormatException('No hay cambios para guardar.');
        await tx.insert('clinical_revisions', {
          'patient_id': pid,
          'table_name': table,
          'record_id': id,
          'before_json': jsonEncode(current),
          'after_json': jsonEncode({...current, ...values}),
          'reason': reason.trim(),
          'created_at': now,
        });
        await tx.update(table, values, where: 'id=?', whereArgs: [id]);
      } else {
        values['created_at'] = now;
        if (table == 'progress_notes' || table == 'medical_orders') {
          values['hospitalization_id'] = parentId;
          await verifyOwner(tx, table, values, pid);
        } else {
          values['patient_id'] = pid;
        }
        if (table == 'hospitalizations') {
          values['admitted_at'] = encounter.toIso8601String();
          values['status'] = 'hospitalizado';
        } else {
          values['date'] = encounter.toIso8601String();
        }
        id = await tx.insert(table, values);
      }
      await tx.delete(
        'clinical_drafts',
        where: 'draft_key=? AND patient_id=?',
        whereArgs: [draftKey, pid],
      );
      await tx.insert('audit', {
        'date': now,
        'action': original == null
            ? 'CREATE_CLINICAL_NOTE'
            : 'REVISE_CLINICAL_NOTE',
        'detail': '$table:$id; paciente:$pid',
      });
      return id;
    });
  }

  static Future<void> saveDraft(
    String key,
    int pid,
    String table,
    int? parent,
    Map<String, String> input,
  ) async {
    final db = await AppDb.instance.database;
    await db.insert('clinical_drafts', {
      'draft_key': key,
      'patient_id': pid,
      'table_name': table,
      'parent_id': parent,
      'payload': jsonEncode(input),
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }
}
