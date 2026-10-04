import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/clinical_scales.dart';
import '../lib/clinical_scale_pdf.dart';
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 test('Scale PDF preserves scientific symbols as offline textual equivalents',()async{
   final tool=parseScaleCatalog(File('assets/scales/catalog.json').readAsStringSync()).singleWhere((t)=>t.id=='cha_vasc');
   final input={'hf':'0','htn':'1','age':'2','dm':'1','stroke':'0','vascular':'0','female':'0'};
   final summary=tool.summary(input,tool.calculate(input),DateTime(2026,10,4),'Evaluación ficticia, sin validez clínica.');
   final bytes=await buildScalePdf({'summary':summary,'payload':jsonEncode({'patient':{'first_name':'Paciente','last_name':'Ficticio'},'profile':{'doctor':'Médico Ficticio','license':'PRUEBA'}})});
   expect(bytes.sublist(0,4),[37,80,68,70]);
   final dir=Directory('scale-fixture')..createSync();File('${dir.path}/scale.pdf').writeAsBytesSync(bytes);
   expect(scalePdfText('CHA₂DS₂-VASc · Edad ≥75'), 'CHA2DS2-VASc · Edad >=75');
 });
 test('PHQ PDF retains all items, functional response, provenance and safety alert',()async{
   final tool=parseScaleCatalog(File('assets/scales/catalog.json').readAsStringSync()).singleWhere((t)=>t.id=='phq9');
   final input={for(var i=1;i<=9;i++)'q$i':i==9?'1':'0','function':'3'};
   final summary=tool.summary(input,tool.calculate(input),DateTime(2026,10,4),'Evaluación ficticia para comprobar un PDF largo.');
   final bytes=await buildScalePdf({'summary':summary,'payload':jsonEncode({'patient':{'first_name':'Paciente','last_name':'Ficticio'},'profile':{'doctor':'Médico Ficticio','license':'PRUEBA'}})});
   expect(bytes.sublist(0,4),[37,80,68,70]);expect(summary,contains('Ítem 9 positivo'));expect(summary,contains('Extremadamente difícil'));expect(summary,contains('Resultado: 1 puntos'));
   final dir=Directory('scale-fixture')..createSync();File('${dir.path}/phq9.pdf').writeAsBytesSync(bytes);
 });

}
