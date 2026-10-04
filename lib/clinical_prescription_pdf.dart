import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'clinical_nom.dart';
import 'clinical_signature_data.dart';
import 'clinical_pdf_signature.dart';

String recipeFolio(Map<String, Object?> record) => 'AM-${record['id'] ?? 'BORRADOR'}-${clinicalRecordHash(record).substring(0, 10).toUpperCase()}';
String recipeQr(Map<String,Object?> record, Uint8List certificate) => jsonEncode({'format':'angel-medical-recipe-reference-v1','folio':recipeFolio(record),'record_sha256':clinicalRecordHash(record),'certificate_sha256':sha256.convert(certificate).toString()});

Future<Uint8List> buildRecipePdf({required Map<String,Object?> patient, required Map<String,Object?> record, Map<String,dynamic>? legacyProfile, PdfCmsSigner? signer, String? signerName, Uint8List? certificate, DateTime? signedAt}) async {
  final nom=decodeNom(record['nom_json']);
  final profile=nom['profile'] is Map ? Map<String,dynamic>.from(nom['profile']) : legacyProfile ?? <String,dynamic>{};
  final identity=nom['patient'] is Map ? Map<String,dynamic>.from(nom['patient']) : <String,dynamic>{};
  final name='${identity['name'] ?? '${patient['first_name'] ?? ''} ${patient['last_name'] ?? ''}'}'.trim();
  final dob=DateTime.tryParse('${identity['dob'] ?? patient['dob'] ?? ''}');
  final date=DateTime.tryParse('${nom['encounter_at'] ?? record['date'] ?? ''}')?.toLocal();
  String dateText(DateTime? d)=> d==null ? 'No registrada' : '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';
  final structured=nomInput(record)['nom_rx_data'];
  Map<String,dynamic> rx={};
  if(structured!=null) { try { rx=Map<String,dynamic>.from(jsonDecode(structured)); } catch (_) {} }
  if (rx['content_sha256'] != sha256.convert(utf8.encode('${record['content'] ?? ''}')).toString()) rx={};
  final medications=rx['medications'] is List ? (rx['medications'] as List).whereType<Map>().map((m)=>Map<String,dynamic>.from(m)).toList() : <Map<String,dynamic>>[];
  final doc=pw.Document();
  final signed=signer!=null;
  if(signed) doc.document.sign=PdfSignature(doc.document,value:ClinicalPdfSignature(signer,signerName ?? '',signedAt!),flags:{PdfSigFlags.signaturesExist,PdfSigFlags.appendOnly});
  pw.MemoryImage? image(String key) {final value='${profile[key] ?? ''}'; if(value.isEmpty)return null; try {return pw.MemoryImage(base64Decode(value));} catch(_){return null;} }
  final logo=image('logo_base64'), secondLogo=image('secondary_logo_base64');
  final blue=PdfColors.blue900;
  pw.Widget heading(String label)=>pw.Padding(padding:const pw.EdgeInsets.only(top:14,bottom:6),child:pw.Text(label,style:pw.TextStyle(fontSize:12,fontWeight:pw.FontWeight.bold,color:blue)));
  pw.Widget text(String value,{double size=10})=>pw.Text(value,style:pw.TextStyle(fontSize:size));
  List<pw.Widget> paragraphs(String value)=>[for(final line in const LineSplitter().convert(value)) for(var i=0;i<line.length;i+=500) text(line.substring(i,(i+500).clamp(0,line.length)),size:11)];
  doc.addPage(pw.MultiPage(pageFormat:PdfPageFormat.letter,margin:const pw.EdgeInsets.all(32),maxPages:100,
    header:(c)=>pw.Column(children:[pw.Row(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[if(logo!=null)pw.Container(width:95,height:64,child:pw.Image(logo,fit:pw.BoxFit.contain)),pw.SizedBox(width:12),pw.Expanded(child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[pw.Text('${profile['doctor'] ?? 'Médico: no registrado'}',style:pw.TextStyle(fontSize:15,fontWeight:pw.FontWeight.bold,color:blue)),text('${profile['profession'] ?? ''}'),text('Cédula profesional: ${profile['license'] ?? 'no registrada'}'),text('${profile['establishment'] ?? ''}',size:9),text('${profile['address'] ?? ''}',size:8),text('${profile['place'] ?? ''}  ${profile['phone'] ?? ''}',size:8)])),if(secondLogo!=null)pw.Container(width:70,height:60,child:pw.Image(secondLogo,fit:pw.BoxFit.contain))]),pw.SizedBox(height:10),pw.Container(height:2,color:blue),pw.SizedBox(height:12)]),
    footer:(c)=>pw.Column(children:[pw.Divider(color:PdfColors.blue100),pw.Row(mainAxisAlignment:pw.MainAxisAlignment.spaceBetween,children:[text(recipeFolio(record),size:8),text('${signed?'PDF con firma integrada':'Sin firma electrónica'} · ${c.pageNumber}/${c.pagesCount}',size:8)])]),
    build:(_)=>[
      pw.Text('RECETA MÉDICA',style:pw.TextStyle(fontSize:18,fontWeight:pw.FontWeight.bold,color:blue)),pw.SizedBox(height:12),
      pw.Container(padding:const pw.EdgeInsets.all(12),decoration:pw.BoxDecoration(color:PdfColors.blue50,borderRadius:pw.BorderRadius.circular(6)),child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[pw.Text('Paciente: $name',style:pw.TextStyle(fontSize:12,fontWeight:pw.FontWeight.bold)),pw.SizedBox(height:5),text('Fecha de nacimiento: ${dateText(dob)}'),text('Fecha de emisión: ${dateText(date)}${date==null?'':' · ${date.hour.toString().padLeft(2,'0')}:${date.minute.toString().padLeft(2,'0')}'}')])),
      if('${rx['diagnosis'] ?? ''}'.trim().isNotEmpty)...[heading('Diagnóstico'),...paragraphs('${rx['diagnosis']}')],
      heading('Tratamiento'),
      if(medications.isEmpty)...paragraphs('${record['content'] ?? ''}'),
      for(final entry in medications.asMap().entries)...[
        pw.Text('${entry.key+1}. ${entry.value['name'] ?? ''}',style:pw.TextStyle(fontSize:12,fontWeight:pw.FontWeight.bold)),
        ...paragraphs([for(final pair in {'presentation':'Presentación','dose':'Dosis','route':'Vía','frequency':'Frecuencia','duration':'Duración'}.entries) if('${entry.value[pair.key] ?? ''}'.trim().isNotEmpty)'${pair.value}: ${entry.value[pair.key]}'].join(' · ')),
        if('${entry.value['instructions'] ?? ''}'.trim().isNotEmpty)...paragraphs('${entry.value['instructions']}'),pw.SizedBox(height:12),
      ],
      if('${rx['recommendations'] ?? ''}'.trim().isNotEmpty)...[heading('Indicaciones y recomendaciones'),...paragraphs('${rx['recommendations']}')],
      pw.SizedBox(height:24),
      if(signed) pw.Row(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[pw.Padding(padding:const pw.EdgeInsets.all(8),child:pw.BarcodeWidget(barcode:pw.Barcode.qrCode(),data:recipeQr(record,certificate!),width:88,height:88)),pw.SizedBox(width:14),pw.Expanded(child:pw.Column(crossAxisAlignment:pw.CrossAxisAlignment.start,children:[pw.Text('Firma electrónica integrada',style:pw.TextStyle(fontWeight:pw.FontWeight.bold,color:blue)),text('Firmante: $signerName',size:9),text('Firma realizada: ${dateText(signedAt!.toLocal())} · ${signedAt.toLocal().hour.toString().padLeft(2,'0')}:${signedAt.toLocal().minute.toString().padLeft(2,'0')}',size:9),pw.SizedBox(height:6),text('Verifica la firma digital en un lector compatible. El QR identifica el folio y sus referencias; no es una validación SAT ni un enlace público.',size:8),text('Sin comprobación de revocación ni sello de tiempo confiable.',size:8),pw.Annotation(builder:ClinicalSignatureAnnotation(),child:pw.SizedBox(width:1,height:1))]))])
      else ...[pw.Container(width:220,decoration:const pw.BoxDecoration(border:pw.Border(top:pw.BorderSide()))),pw.SizedBox(height:4),text('Firma del médico',size:9)],
      if(nom['profile'] is! Map)...[pw.SizedBox(height:10),text('Registro previo: datos del perfil actual para presentación; no se atribuye autor retrospectivamente.',size:8)],
    ]));
  return doc.save();
}
