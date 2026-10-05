import 'dart:convert';
import 'pc_database.dart';
import 'clinical_scales.dart';
import 'clinical_nom.dart';

Future<int> saveClinicalScale(Database db, {required int pid, required ClinicalScale tool, required Map<String,String> input, required String notes, required DateTime evaluatedAt, required bool applicable}) async {
  if(!applicable) throw const FormatException('Confirma la población e indicación antes de guardar.');
  final score=tool.calculate(input);
  if(evaluatedAt.isAfter(DateTime.now().add(const Duration(minutes:1)))) throw const FormatException('La fecha de evaluación no puede ser futura.');
  return db.transaction((tx) async {
    final patients=await tx.query('patients',where:'id=?',whereArgs:[pid]);
    if(patients.length!=1) throw const FormatException('Paciente no encontrado.');
    final dob=DateTime.tryParse('${patients.single['dob']??''}');
    if(dob!=null && evaluatedAt.isBefore(dob)) throw const FormatException('La evaluación no puede ser anterior al nacimiento.');
    final settings=await tx.query('app_settings',where:'setting_key=?',whereArgs:['nom_profile']);
    final raw=settings.isEmpty?<String,dynamic>{}:decodeNom(settings.single['setting_value']);
    if('${raw['doctor']??''}'.trim().isEmpty || '${raw['license']??''}'.trim().isEmpty) throw const FormatException('Completa nombre y cédula del médico.');
    final profile={for(final k in ['doctor','license','profession']) if(raw[k]!=null) k:raw[k]};
    // Entire source definition and labels persist, even after future catalog updates.
    final summary=tool.summary(input,score,evaluatedAt,notes);
    final id=await tx.insert('clinical_scales',{
      'patient_id':pid,'scale_id':tool.id,'scale_name':tool.name,'scale_version':tool.version,
      'date':evaluatedAt.toUtc().toIso8601String(),'score':score,'unit':tool.unit,'summary':summary,
      'payload':jsonEncode({'catalog_version':1,'answers':input,'source':tool.source,'translation_source':tool.translationSource,'attribution':tool.attribution,'instructions':tool.instructions,'alerts':tool.alerts(input),'population':tool.population,'limitations':tool.limitations,'applicable_confirmed':true,'patient':{'first_name':patients.single['first_name'],'last_name':patients.single['last_name'],'dob':patients.single['dob']},'profile':profile,'notes':notes}),
      'created_at':DateTime.now().toUtc().toIso8601String(),
    });
    await tx.insert('audit',{'action':'ADD_SCALE','detail':'Paciente $pid · ${tool.id} · registro $id','date':DateTime.now().toUtc().toIso8601String()});
    return id;
  });
}
