import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import '../lib/clinical_assistant_data.dart';
import '../lib/clinical_assistant_service.dart';

void main(){
  test('Reject non-TLS remote endpoints, embedded credentials and query secrets',(){
    for(final url in ['http://example.com/v1/chat/completions','https://a:b@example.com/v1','file:///tmp/model','https://example.com/?token=secret']){
      expect(()=>assistantEndpoint(url),throwsFormatException);
    }
    expect(assistantEndpoint('http://localhost:11434/v1/chat/completions').host,'localhost');
    expect(assistantEndpoint('https://example.com/v1/chat/completions').scheme,'https');
  });
  test('Model cannot write identifiers, measurements, signatures or arbitrary fields',(){
    for(final key in ['patient_id','systolic','signature','nom_body_map']){
      expect(()=>parseAssistantDraft(jsonEncode({'fields':{key:'invented'}}),{key,'illness'}),throwsFormatException);
    }
    expect(()=>parseAssistantDraft('{"fields":{"illness":null}}',{'illness'}),throwsFormatException);
    expect(()=>parseAssistantDraft('{"fields":{}}',{'illness'}),throwsFormatException);
    expect(parseAssistantDraft('{"fields":{"illness":"Niega fiebre; tos de 3 días."}}',{'illness'}),{'illness':'Niega fiebre; tos de 3 días.'});
  });
  test('Only allowed current text is included, not patient or historical identity',(){
    final source=assistantSource({'illness':'Tos','first_name':'PRIVATE','allergies':'PRIVATE','nom_body_map':'PRIVATE'},'Niega fiebre',{'illness'});
    expect(source,contains('Tos'));expect(source,contains('Niega fiebre'));expect(source, isNot(contains('PRIVATE')));
  });
  test('Comparison preserves zero, does not treat missing as improvement',(){
    final rows=compareConsultations({'glucose':100,'weight':80,'pain':0},{'glucose':'','weight':'79,5'});
    expect(rows.firstWhere((r)=>r['key']=='glucose')['delta'],'');
    expect(rows.firstWhere((r)=>r['key']=='weight')['delta'],'-0.5');
    final zero=compareConsultations({'glucose':0},{'glucose':'0'});
    expect(zero.single['before'],'0');expect(zero.single['delta'],'0.0');
  });
  test('Compatible service receives minimal payload and returns only a draft',() async {
    final server=await HttpServer.bind(InternetAddress.loopbackIPv4,0);
    final received=server.first.then((request)async{
      expect(request.headers.value('authorization'),'Bearer fixture-token');
      final data=jsonDecode(await utf8.decoder.bind(request).join());
      expect(data['messages'][1]['content'],'fictional-source');
      request.response.headers.contentType=ContentType.json;
      request.response.write(jsonEncode({'choices':[{'message':{'content':'{"fields":{"illness":"Dato ficticio"}}'}}]}));
      await request.response.close();
    });
    final service=AssistantService();
    try{
      final draft=await service.generate(AssistantConfig('http://127.0.0.1:${server.port}/v1/chat/completions','fixture','fixture-token'),'fictional-source',{'illness'});
      expect(draft,{'illness':'Dato ficticio'});await received;
    }finally{service.close();await server.close(force:true);}
  });
  test('HTTP failures do not expose service content or credentials',() async {
    final server=await HttpServer.bind(InternetAddress.loopbackIPv4,0);
    final received=server.first.then((r)async{r.response.statusCode=401;r.response.write('SECRET');await r.response.close();});
    final service=AssistantService();
    try{await expectLater(service.generate(AssistantConfig('http://127.0.0.1:${server.port}/v1/chat/completions','fixture','fixture-token'),'fake',{'illness'}),throwsA(isA<FormatException>().having((e)=>e.message,'message',isNot(contains('SECRET')))));await received;}
    finally{service.close();await server.close(force:true);}
  });
}
