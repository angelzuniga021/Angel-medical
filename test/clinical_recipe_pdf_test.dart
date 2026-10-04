import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:angel_medical_mobile/clinical_prescription_pdf.dart';
import 'package:angel_medical_mobile/clinical_pdf_signature.dart';

void main() {
  final patient=<String,Object?>{'id':1,'first_name':'Paciente','last_name':'Prueba','dob':'2000-01-02'};
  Map<String,Object?> record({int count=2}) {
    const content='Tratamiento de prueba';
    return {'id':44,'type':'Receta','date':'2026-10-04T12:00:00','content':content,'nom_json':jsonEncode({'profile':{'doctor':'Medico Ficticio','license':'PRUEBA','profession':'Medicina General','establishment':'Consultorio de prueba','phone':'0000000000'},'patient':{'name':'Paciente Prueba','dob':'2000-01-02'},'fields':{'nom_rx_data':jsonEncode({'content_sha256':sha256.convert(utf8.encode(content)).toString(),'medications':[for(var i=0;i<count;i++){'name':'Medicamento de prueba ${i+1}','dose':'Una unidad','route':'VO','frequency':'8 horas','duration':'3 dias','instructions':'Texto de prueba sin validez clínica.'}],'recommendations':'Recomendaciones de prueba.'})}})};
  }
  test('QR excludes patient identity and clinical content',(){
    final qr=recipeQr(record(),Uint8List.fromList([1,2,3]));
    expect(qr, isNot(contains('Paciente')));expect(qr,isNot(contains('Medicamento')));
    expect(jsonDecode(qr)['record_sha256'],hasLength(64));
  });
  test('unsigned, long and corrected recipes render without clipping failure',()async{
    final short=await buildRecipePdf(patient:patient,record:record());
    final long=await buildRecipePdf(patient:patient,record:record(count:30));
    final corrected=record();corrected['content']='Contenido corregido que debe prevalecer';
    final updated=await buildRecipePdf(patient:patient,record:corrected);
    expect(latin1.decode(short),isNot(contains('/ByteRange')));expect(long.length,greaterThan(short.length));expect(updated,isNotEmpty);
    Directory('recipe-fixture').createSync();File('recipe-fixture/unsigned.pdf').writeAsBytesSync(short);File('recipe-fixture/long.pdf').writeAsBytesSync(long);
  });
  test('embedded PDF CMS verifies independently and rejects tampering',()async{
    final dir=Directory.systemTemp.createTempSync('angel_recipe_test');
    try {
      final key='${dir.path}/key.pem',cert='${dir.path}/cert.pem';
      var proc=await Process.run('openssl',['req','-x509','-newkey','rsa:2048','-nodes','-keyout',key,'-out',cert,'-days','2','-subj','/CN=Test Only']);expect(proc.exitCode,0);
      proc=await Process.run('openssl',['x509','-in',cert,'-outform','DER','-out','${dir.path}/cert.der']);expect(proc.exitCode,0);
      final pdf=await buildRecipePdf(patient:patient,record:record(),certificate:File('${dir.path}/cert.der').readAsBytesSync(),signerName:'Medico Ficticio',signedAt:DateTime.utc(2026,10,4,17),signer:(data)async{
        File('${dir.path}/data').writeAsBytesSync(data);
        final result=await Process.run('openssl',['cms','-sign','-binary','-in','${dir.path}/data','-signer',cert,'-inkey',key,'-outform','DER','-out','${dir.path}/cms','-md','sha256']);expect(result.exitCode,0);return File('${dir.path}/cms').readAsBytesSync();
      });
      final parts=embeddedPdfParts(pdf);
      File('${dir.path}/data').writeAsBytesSync(parts.data);File('${dir.path}/cms').writeAsBytesSync(parts.cms);
      proc=await Process.run('openssl',['cms','-verify','-binary','-inform','DER','-in','${dir.path}/cms','-content','${dir.path}/data','-noverify','-out','${dir.path}/verified']);expect(proc.exitCode,0,reason:'${proc.stderr}');
      final altered=Uint8List.fromList(parts.data);altered[10]^=1;File('${dir.path}/data').writeAsBytesSync(altered);
      proc=await Process.run('openssl',['cms','-verify','-binary','-inform','DER','-in','${dir.path}/cms','-content','${dir.path}/data','-noverify','-out','${dir.path}/verified']);expect(proc.exitCode,isNot(0));
      expect(()=>embeddedPdfParts(Uint8List.fromList([...pdf,32])),throwsFormatException);
      Directory('recipe-fixture').createSync();File('recipe-fixture/signed.pdf').writeAsBytesSync(pdf);
    } finally {dir.deleteSync(recursive:true);}
  });
}
