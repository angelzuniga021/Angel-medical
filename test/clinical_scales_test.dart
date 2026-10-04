import 'dart:io';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import '../lib/clinical_scales.dart';

void main(){
 final tools=parseScaleCatalog(File('assets/scales/catalog.json').readAsStringSync());
 ClinicalScale t(String id)=>tools.singleWhere((t)=>t.id==id);
 Map<String,String> zeros(ClinicalScale t)=>{for(final f in t.fields)f.key:f.options.isNotEmpty?'${f.options.reduce((a,b)=>(a['value'] as num)<(b['value'] as num)?a:b)['value']}':'${f.min}'};
 test('Catalog identities, provenance and supported formulas',(){
   expect(tools.length,33);expect(tools.map((t)=>t.id).toSet().length,33);
   for(final tool in tools){expect(tool.source,startsWith('https://'));expect(tool.population,isNotEmpty);expect(tool.limitations,isNotEmpty);expect(tool.version,'1.0');}
 });
 for(final tool in tools){
  test('${tool.id}: missing, nonfinite, invalid choice and ranges rejected',(){
   expect(()=>tool.calculate({}),throwsFormatException);
   final data=zeros(tool);if(tool.id=='gcs'){data.addAll({'eye':'4','verbal':'5','motor':'6'});}
   for(final f in tool.fields){
     if(!f.optional)expect(()=>tool.calculate({...data,f.key:''}),throwsFormatException);
     expect(()=>tool.calculate({...data,f.key:'NaN'}),throwsFormatException);
     expect(()=>tool.calculate({...data,f.key:'Infinity'}),throwsFormatException);
     if(f.options.isNotEmpty){expect(()=>tool.calculate({...data,f.key:'999'}),throwsFormatException);}else{expect(()=>tool.calculate({...data,f.key:'${f.min!-1}'}),throwsFormatException);expect(()=>tool.calculate({...data,f.key:'${f.max!+1}'}),throwsFormatException);}
   }
  });
 }
 test('Version-specific clinical definitions remain explicit',(){
   expect(t('cha_va').fields.singleWhere((f)=>f.key=='vascular').label,contains('angina'));
   expect(t('cha_va').fields.singleWhere((f)=>f.key=='hf').label,contains('FEVI ≤40%'));
   expect(t('perc').fields.singleWhere((f)=>f.key=='surgery').label,contains('hospitalización'));
   expect(t('perc').source,contains('18318689'));
 });
 test('Published ranges and negative weighted criteria',(){
   const maxima={'gcs':15,'curb65':5,'crb65':4,'qsofa':3,'sirs':4,'wells_pe':12.5,'wells_dvt':9,'perc':8,'heart':10,'cha_va':8,'cha_vasc':9,'hasbled':9,'centor':4,'mcisaac':5,'alvarado':10,'padua':20,'gbs':23,'sofa':24,'phq9':27,'phq2':6,'gad7':21,'gad2':6,'spesi':6,'geneva':22};
   for(final e in maxima.entries){final tool=t(e.key);final input={for(final f in tool.fields.where((f)=>f.scored))f.key:'${f.options.map((o)=>(o['value'] as num).toDouble()).reduce(math.max)}'};expect(tool.calculate(input),e.value,reason:e.key);}
   final dvt=zeros(t('wells_dvt'));expect(t('wells_dvt').calculate(dvt),-2);
   final mc=zeros(t('mcisaac'));expect(t('mcisaac').calculate(mc),-1);
   expect(t('gcs').calculate({'eye':'1','verbal':'1','motor':'1'}),3);
   expect(()=>t('gcs').calculate({'eye':'4','verbal':'-1','motor':'6'}),throwsFormatException);
 });
 test('Clinical examples and interpretation boundaries',(){
   expect(t('curb65').calculate({'confusion':'1','rr':'1','bp':'0','age':'1','urea':'1'}),4);
   expect(t('heart').calculate({'history':'1','ecg':'0','age':'1','risk':'2','troponin':'0'}),4);
   expect(t('wells_pe').interpretation(4),contains('improbable'));expect(t('wells_pe').interpretation(4.5),contains('probable'));
   expect(t('wells_dvt').interpretation(1),contains('improbable'));expect(t('wells_dvt').interpretation(2),startsWith('TVP probable'));
   expect(t('perc').interpretation(0),contains('probabilidad clínica ya era baja'));
   expect(t('qsofa').interpretation(0),contains('no excluye'));
   expect(t('hasbled').interpretation(3),contains('no negar anticoagulación'));
 });
 test('Equations, units, decimals and physiological consistency',(){
   expect(t('bmi').calculate({'weight':'80','height':'200'}),20);
   expect(t('map').calculate({'sbp':'120','dbp':'60'}),80);
   expect(()=>t('map').calculate({'sbp':'60','dbp':'120'}),throwsFormatException);
   expect(t('shock').calculate({'hr':'100','sbp':'80'}),1.25);
   expect(t('bsa').calculate({'weight':'80','height':'180'}),2);
   expect(t('cockcroft').calculate({'age':'68','weight':'72','scr':'1','female':'0'}),72);
   expect(t('cockcroft').calculate({'age':'68','weight':'72','scr':'1','female':'1'}),closeTo(61.2,1e-10));
   expect(t('ckdepi').calculate({'age':'50','scr':'1','female':'0'}),closeTo(91.6914786,0.0001));
   expect(t('ckdepi').calculate({'age':'50','scr':'1','female':'1'}),closeTo(68.6335,0.001));
   expect(t('anion').calculate({'na':'140','cl':'104','hco3':'24'}),12);
   expect(t('osm').calculate({'na':'140','glucose':'180','bun':'28'}),300);
   expect(t('bmi').calculate({'weight':'80,5','height':'200'}),20.125);
   expect(()=>t('pain').calculate({'pain':'3.5'}),throwsFormatException);
 });
 test('Mental health thresholds, optional functional question and independent safety alert',(){
   final phq=t('phq9');final data=zeros(phq)..remove('function');
   expect(phq.calculate(data),0);expect(phq.calculate({...data,'function':'3'}),0);
   expect(phq.calculate({...data,'q9':'1'}),1);expect(phq.alerts({...data,'q9':'1'}).single,contains('evaluar ahora'));expect(phq.alerts(data),isEmpty);
   expect(phq.summary(data,0,DateTime(2026,10,4),''),contains('Sin respuesta (no puntúa)'));
   for(final e in {4:'mínimos',5:'leves',10:'moderados',15:'moderadamente graves',20:'graves'}.entries){expect(phq.interpretation(e.key.toDouble()),contains(e.value));}
   for(final e in {4:'mínimos',5:'leves',10:'moderados',15:'graves'}.entries){expect(t('gad7').interpretation(e.key.toDouble()),contains(e.value));}
   for(final id in ['phq2','gad2']){expect(t(id).interpretation(2),contains('debajo'));expect(t(id).interpretation(3),contains('positivo'));}
   expect(t('geneva').interpretation(3),contains('baja'));expect(t('geneva').interpretation(4),contains('intermedia'));expect(t('geneva').interpretation(10),contains('intermedia'));expect(t('geneva').interpretation(11),contains('alta'));
   expect(t('spesi').interpretation(0),contains('bajo'));expect(t('spesi').interpretation(1),contains('elevado'));
   for(final id in ['phq9','phq2','gad7','gad2']){expect(t(id).instructions,contains('2 semanas'));expect(t(id).translationSource,startsWith('https://depts.washington.edu/'));expect(t(id).attribution,contains('Pfizer'));}
 });
 test('Summary preserves zero answers, limitations and version',(){
   final tool=t('perc');final input=zeros(tool);final text=tool.summary(input,tool.calculate(input),DateTime(2026,10,4),'Contexto ficticio');
   expect(text,contains('Resultado: 0'));expect(text,contains('Edad ≥50 años: No'));expect(text,contains('versión 1.0'));expect(text,contains(tool.source));expect(text,contains('Contexto ficticio'));
 });
}
