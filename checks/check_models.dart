import '../lib/clinical_models.dart';
import '../lib/clinical_record.dart';
void check(bool ok,String message){if(!ok)throw StateError(message);}
void invalid(String table,Map<String,String> input){
  var rejected=false;try{parseClinicalInput(table,input);}on FormatException{rejected=true;}
  check(rejected,'Invalid input accepted: $input');
}
void main(){
  final parsed=parseClinicalInput('consultations',{'weight':'80,5','height':'175','reason':'Seguimiento','patient_id':'999','date':'2000'});
  check(parsed['weight']==80.5,'Decimal parsing');
  check(((parsed['bmi'] as double)-80.5/(1.75*1.75)).abs()<0.00001,'BMI');
  check(!parsed.containsKey('patient_id')&&!parsed.containsKey('date'),'Patient/date injection');
  check(parsed['systolic']==null,'Missing measurements');
  for(final s in ['abc','NaN','Infinity','-1']){invalid('consultations',{'weight':s});}
  invalid('consultations',{'spo2':'101'});invalid('emergencies',{'glasgow':'14.5'});invalid('emergencies',{'pain':'11'});
  final long=List.filled(2000,'Historia clínica extensa.').join('\n');
  final fields=Map.fromEntries(clinicalFields({'illness':long,'pain':0,'patient_id':1}));
  check(fields['Padecimiento actual']==long,'Long note truncation');check(fields['Dolor (EVA)']=='0','Zero value missing');
  check(matchesClinical({'type':'Consulta','search':'Exploración completa sin dolor'},'EXPLORACION dolor'),'Accent insensitive search');
  check(!matchesClinical({'search':'Normal'},'fractura'),'False search match');
  print('PASS: numerical validation, BMI, missing values, immutable identifiers, long text, and search.');
}
