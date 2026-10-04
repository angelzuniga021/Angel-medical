import 'dart:convert';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

// Standard PDF fonts support Spanish, but not these scientific glyphs.
// Explicit textual equivalents preserve their meaning in an offline PDF.
String scalePdfText(String value){
 const replacements={'₀':'0','₁':'1','₂':'2','₃':'3','₄':'4','₅':'5','₆':'6','₇':'7','₈':'8','₉':'9','≥':'>=','≤':'<=','Δ':'Delta ','−':'-','–':'-','→':'->','×':'x','√':'sqrt','µ':'u'};
 for(final e in replacements.entries){value=value.replaceAll(e.key,e.value);}return value;
}
Future<Uint8List> buildScalePdf(Map<String,Object?> row)async{
 final payload=jsonDecode('${row['payload']}') as Map<String,dynamic>;
 final patient=Map<String,dynamic>.from(payload['patient'] as Map);
 final profile=Map<String,dynamic>.from(payload['profile'] as Map);
 final doc=pw.Document();
 final blue=PdfColors.blue900;
 final text=scalePdfText('${row['summary']}');
 final lines=<String>[];
 for(final line in text.split('\n')){
   if(line.isEmpty){lines.add('');continue;}
   for(var i=0;i<line.length;i+=500){lines.add(line.substring(i,(i+500).clamp(0,line.length)));}
 }
 doc.addPage(pw.MultiPage(pageFormat:PdfPageFormat.a4,maxPages:100,margin:const pw.EdgeInsets.all(32),
  header:(_)=>pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[pw.Text('ÁNGEL MEDICAL · EVALUACIÓN CLÍNICA',style:pw.TextStyle(fontWeight:pw.FontWeight.bold,color:blue,fontSize:16)),pw.SizedBox(height:8),pw.Text(scalePdfText('Paciente: ${patient['first_name']} ${patient['last_name']}')),pw.Text(scalePdfText('Médico: ${profile['doctor']??'Sin autor registrado'} · Cédula: ${profile['license']??''}')),pw.SizedBox(height:10),pw.Divider(color:blue)]),
  footer:(c)=>pw.Text('Registro sin firma electrónica · ${c.pageNumber}/${c.pagesCount}',style:const pw.TextStyle(fontSize:8)),
  build:(_)=>[...lines.map((line)=>pw.Padding(padding:const pw.EdgeInsets.only(bottom:5),child:pw.Text(line,style:const pw.TextStyle(fontSize:10)))),pw.SizedBox(height:12),pw.Text('No sustituye una nota clínica ni certifica cumplimiento normativo.',style:const pw.TextStyle(fontSize:8))],
 ));return doc.save();
}
