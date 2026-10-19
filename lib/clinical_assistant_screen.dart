import 'dart:io';
import 'package:flutter/material.dart';
import 'clinical_assistant_data.dart';
import 'clinical_assistant_service.dart';
import 'clinical_dictation.dart';
import 'clinical_record.dart';
import 'clinical_nom.dart';
import 'clinical_body_map.dart';
import 'clinical_body_data.dart';
import 'clinical_cie_screen.dart';
import 'clinical_ui.dart';
import 'db.dart';

class ClinicalAssistantScreen extends StatefulWidget {
  final Map<String,Object?> patient;
  final Map<String,String> current;
  final String table;
  final String encounter;
  final int? recordId;
  final List<Map<String,Object?>>? recentConsultations;
  const ClinicalAssistantScreen({super.key,required this.patient,required this.current,required this.table,required this.encounter,this.recordId,this.recentConsultations});
  @override
  State<ClinicalAssistantScreen> createState()=>_ClinicalAssistantState();
}
class _ClinicalAssistantState extends State<ClinicalAssistantScreen> with WidgetsBindingObserver {
  final text=TextEditingController();
  final result=<String,TextEditingController>{};
  final selected=<String>{};
  late Map<String,String> current;
  bool busy=false, reviewed=false, loading=true, recording=false, allowLeave=false;
  String? error;
  String historyError='';
  String origin='Captura manual';
  List<Map<String,Object?>> history=[];
  AssistantService? service;
  Set<String> get allowed=>current.keys.where(assistantTextKeys.contains).toSet();
  @override
  void initState(){super.initState();current=Map.of(widget.current);WidgetsBinding.instance.addObserver(this);loadHistory();}
  Future<void> loadHistory() async {
    if(widget.recentConsultations!=null){history=widget.recentConsultations!;loading=false;return;}
    try {
      final db=await AppDb.instance.database;
      final rows=await db.query('consultations',where:'patient_id=? AND date<=?${widget.table=='consultations' && widget.recordId!=null ? ' AND id!=?' : ''}',whereArgs:[widget.patient['id'],widget.encounter,if(widget.table=='consultations' && widget.recordId!=null) widget.recordId],orderBy:'date DESC, id DESC',limit:20);
      if(mounted)setState((){history=rows;loading=false;});
    }catch(_){if(mounted)setState((){loading=false;historyError='No se pudo leer el historial. No significa que esté vacío.';});}
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){if(state!=AppLifecycleState.resumed){ClinicalDictation.stop();if(mounted)setState(()=>recording=false);}}
  @override
  void dispose(){WidgetsBinding.instance.removeObserver(this);ClinicalDictation.dispose();service?.close();text.dispose();for(final c in result.values){c.dispose();}super.dispose();}
  void message(String value){if(mounted)clinicalMessage(context,value);}
  Future<void> dictate() async {
    if(recording){await ClinicalDictation.stop();if(mounted)setState(()=>recording=false);return;}
    if(Platform.isWindows){
      message('Haz clic en el campo de texto y pulsa Windows + H. Requiere el dictado y el micrófono habilitados en Windows.');return;
    }
    final accepted=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Dictar un resumen clínico'),content:const Text('El reconocimiento lo realiza el sistema del dispositivo y puede usar servicios en línea. Dicta un resumen sin nombres ni identificadores. Ángel Medical no guarda el audio. Puedes detenerlo en cualquier momento.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Iniciar dictado'))]));
    if(accepted!=true || !mounted)return;
    final prefix=text.text.trim();
    try {
      setState(()=>recording=true);
      final ok=await ClinicalDictation.start((words){if(mounted){text.text=[prefix,words].where((s)=>s.isNotEmpty).join('\n');text.selection=TextSelection.collapsed(offset:text.text.length);}},(status){if(mounted && (status=='done'||status=='notListening'))setState(()=>recording=false);},(e){if(mounted)setState(()=>recording=false);message(e);});
      if(!ok && mounted){setState(()=>recording=false);message('Dictado en español no disponible. Usa el micrófono del teclado o escribe.');}
    }catch(_){if(mounted)setState(()=>recording=false);message('No se pudo iniciar el micrófono. Puedes escribir el resumen.');}
  }
  void setDraft(Map<String,String> values,String source){
    for(final c in result.values){c.dispose();}
    result.clear();selected.clear();
    for(final e in values.entries){result[e.key]=TextEditingController(text:e.value);}
    setState((){origin=source;reviewed=false;error=null;});
  }
  Future<void> manual() async {
    if(text.text.trim().isEmpty){message('Primero escribe o dicta el resumen.');return;}
    final key=await showDialog<String>(context:context,builder:(ctx)=>SimpleDialog(title:const Text('Agregar texto sin IA a…'),children:[for(final k in allowed)SimpleDialogOption(onPressed:()=>Navigator.pop(ctx,k),child:Text(clinicalLabels[k]??k))]));
    if(key!=null && mounted)setDraft({key:text.text.trim()},'Texto dictado o escrito · sin IA');
  }
  Future<void> generate() async {
    if(recording){await ClinicalDictation.stop();if(!mounted)return;setState(()=>recording=false);}
    setState(()=>error=null);
    try {
      final config=await AssistantConfig.load();
      if(!mounted)return;
      if(config.endpoint.isEmpty){await configure();return;}
      final endpoint=assistantEndpoint(config.endpoint);
      final source=TextEditingController(text:assistantSource(current,text.text,allowed));
      String? payload;
      try {
        payload=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Revisar antes de enviar'),content:SizedBox(width:640,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('Destino: ${endpoint.origin}\nModelo: ${config.model}\nSe enviará únicamente el texto de abajo. Elimina nombres o identificadores que hayas escrito. No se incluye automáticamente el historial ni el perfil del paciente.'),const SizedBox(height:12),TextField(controller:source,minLines:6,maxLines:12,maxLength:40000,decoration:const InputDecoration(labelText:'Contenido editable para el servicio de IA')),const Text('El servicio puede cobrar por uso y aplicar sus políticas de almacenamiento. La salida será un borrador para revisar.')]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(ctx,source.text),child:const Text('Enviar y generar'))]));
      }finally{source.dispose();}
      if(payload==null || !mounted)return;
      if(payload.trim().isEmpty)throw const FormatException('No hay texto para procesar.');
      setState(()=>busy=true);
      service=AssistantService();
      final values=await service!.generate(config,payload,allowed);
      if(mounted)setDraft(values,'Borrador de IA · ${config.model} · ${DateTime.now().toIso8601String()}');
    }on FormatException catch(e){if(mounted)setState(()=>error=e.message);}
    catch(_){if(mounted)setState(()=>error='No se pudo generar el borrador. La nota original sigue intacta.');}
    finally{service?.close();service=null;if(mounted)setState(()=>busy=false);}
  }
  Future<void> configure() async {
    try {
      final c=await AssistantConfig.load();if(!mounted)return;
      await Navigator.push(context,MaterialPageRoute(builder:(_)=>AssistantSettings(config:c)));
    }catch(_){message('No se pudo abrir la configuración segura.');}
  }
  Future<void> body() async {
    final value=await Navigator.push<String>(context,MaterialPageRoute(builder:(_)=>ClinicalBodyMap(initial:current['nom_body_map']??'')));
    if(value!=null && mounted){setState(()=>current['nom_body_map']=value);message('Mapa preparado. Se aplicará al volver con “Aplicar al borrador”.');}
  }
  Future<void> cie() async {
    final row=await Navigator.push<Map<String,Object?>>(context,MaterialPageRoute(builder:(_)=>ClinicalCieScreen(select:true,initialQuery:(result['diagnoses']?.text ?? current['diagnoses'] ?? '').split('\n').first)));
    if(row==null || !mounted)return;
    final key=allowed.contains('diagnoses')?'diagnoses':allowed.contains('assessment')?'assessment':null;
    if(key==null)return;
    final old=result[key]?.text ?? current[key] ?? '';
    final value='$old${old.trim().isEmpty?'':'\n'}${row['code']} · ${row['name']}';
    if(result.containsKey(key)){result[key]!.text=value;}else{result[key]=TextEditingController(text:value);}
    setState(()=>reviewed=false);
  }
  Future<void> apply() async {
    final changes=<String,String>{for(final k in selected)k:result[k]!.text};
    if(current['nom_body_map']!=widget.current['nom_body_map'])changes['nom_body_map']=current['nom_body_map']??'';
    if(changes.isEmpty){message('Selecciona al menos un campo o modifica el mapa.');return;}
    final overwrite=changes.keys.where((k)=>(widget.current[k]??'').trim().isNotEmpty).toList();
    if(overwrite.isNotEmpty){
      final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Reemplazar campos del borrador'),content:Text('Se reemplazará el contenido actual de:\n${overwrite.map((k)=>clinicalLabels[k]??nomLabels[k]??k).join('\n')}\n\nLos registros firmados no se modifican desde el asistente.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Aplicar cambios revisados'))]));
      if(ok!=true || !mounted)return;
    }
    finish(changes);
  }
  void finish(Map<String,String>? changes){
    setState(()=>allowLeave=true);
    WidgetsBinding.instance.addPostFrameCallback((_){if(mounted)Navigator.pop(context,changes);});
  }
  Future<void> leave() async {
    if(busy)return;
    if(text.text.trim().isEmpty && result.isEmpty && current['nom_body_map']==widget.current['nom_body_map']){finish(null);return;}
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>AlertDialog(title:const Text('¿Salir sin aplicar?'),content:const Text('El texto y las propuestas de este asistente no se han aplicado al borrador. Si sales, se descartarán. La nota original se conserva.'),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Seguir revisando')),TextButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Descartar y salir'))]));
    if(ok==true && mounted)finish(null);
  }
  Widget panel(String title,List<Widget> children)=>Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Text(title,style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:12),...children])));
  @override
  Widget build(BuildContext context)=>PopScope(canPop:allowLeave,onPopInvokedWithResult:(didPop,result){if(!didPop)leave();},child:DefaultTabController(length:3,child:Scaffold(
    appBar:AppBar(title:const Text('Asistente de consulta'),actions:[IconButton(tooltip:'Configurar IA',onPressed:busy?null:configure,icon:const Icon(Icons.settings_outlined))],bottom:const TabBar(tabs:[Tab(text:'Redactar'),Tab(text:'Expediente'),Tab(text:'Comparar')])),
    body:TabBarView(children:[
      ListView(padding:const EdgeInsets.all(16),children:[
        panel('De tus hallazgos a una nota revisada',[
          const Text('Escribe o dicta un resumen. La IA organiza el texto; tú validas cada dato. Los campos sin información permanecen pendientes.'),const SizedBox(height:12),
          TextField(controller:text,enabled:!busy && !recording,minLines:5,maxLines:12,maxLength:20000,decoration:const InputDecoration(labelText:'Resumen de esta consulta',hintText:'Motivo, evolución, hallazgos, impresión y plan que tú estableciste…')),
          Wrap(spacing:8,runSpacing:8,children:[OutlinedButton.icon(onPressed:busy?null:dictate,icon:Icon(recording?Icons.stop:Icons.mic_none),label:Text(recording?'Detener':Platform.isWindows?'Dictar · Windows + H':'Dictar')),OutlinedButton(onPressed:busy||recording?null:manual,child:const Text('Usar texto sin IA')),FilledButton.icon(onPressed:busy||recording?null:generate,icon:const Icon(Icons.auto_awesome),label:const Text('Preparar con IA'))]),
          if(recording)const Text('Micrófono activo · dicta por frases cortas.'),
          if(busy)...[const SizedBox(height:12),const LinearProgressIndicator(),TextButton(onPressed:(){service?.close();},child:const Text('Cancelar solicitud'))],
          if(error!=null)Padding(padding:const EdgeInsets.only(top:12),child:Text(error!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
        ]),
        panel('Pendientes de captura',[
          const Text('Lista de apoyo, no certificación normativa. Los signos vitales se capturan en sus campos de la nota y no se rellenan con IA.'),
          for(final k in allowed.where((k)=>(current[k]??'').trim().isEmpty)) Text('• ${clinicalLabels[k]??k}: sin registrar'),
        ]),
        panel('Herramientas de la atención',[
          Wrap(spacing:8,runSpacing:8,children:[if(current.containsKey('nom_body_map'))OutlinedButton.icon(onPressed:busy?null:body,icon:const Icon(Icons.accessibility_new),label:const Text('Mapa corporal')),if(allowed.contains('diagnoses')||allowed.contains('assessment'))OutlinedButton.icon(onPressed:busy?null:cie,icon:const Icon(Icons.search),label:const Text('Sugerencias CIE-10'))]),
          const Text('Elige códigos para diagnósticos que hayas documentado; el buscador no establece diagnósticos.'),
          if((current['nom_body_map']??'').isNotEmpty)Text(describeBodyMap(current['nom_body_map']!)),
        ]),
        if(result.isNotEmpty)panel('Revisar propuesta',[
          Text(origin),const Text('Selecciona solo los campos que deseas aplicar. Revisa negaciones, lateralidad, nombres de medicamentos, dosis y unidades.'),
          for(final e in result.entries)...[
            CheckboxListTile(contentPadding:EdgeInsets.zero,title:Text(clinicalLabels[e.key]??e.key),value:selected.contains(e.key),onChanged:busy?null:(v)=>setState((){v==true?selected.add(e.key):selected.remove(e.key);reviewed=false;})),
            if((widget.current[e.key]??'').isNotEmpty)ExpansionTile(title:const Text('Ver texto actual'),children:[Padding(padding:const EdgeInsets.all(12),child:SelectableText(widget.current[e.key]!))]),
            TextField(controller:e.value,minLines:2,maxLines:8,onChanged:(_)=>setState(()=>reviewed=false)),
          ],
        ]),
        if(result.isNotEmpty || current['nom_body_map']!=widget.current['nom_body_map'])panel('Aplicar al borrador',[
          CheckboxListTile(contentPadding:EdgeInsets.zero,value:reviewed,onChanged:busy?null:(v)=>setState(()=>reviewed=v??false),title:const Text('Revisé el contenido y confirmo que corresponde a esta atención.')),
          FilledButton.icon(onPressed:reviewed&&!busy?apply:null,icon:const Icon(Icons.check),label:const Text('Aplicar al borrador')),
          const Text('Esto no finaliza ni firma la nota. Al regresar podrás revisar los campos pendientes y guardarla.'),
        ]),
      ]),
      ListView(padding:const EdgeInsets.all(16),children:[
        panel('Resumen documental local',[
          const Text('Datos del perfil y hasta 20 consultas anteriores a esta atención. No incluye hospitalizaciones, documentos ni adjuntos. No se envía a la IA.'),
          for(final e in assistantHistoryKeys.entries)ListTile(contentPadding:EdgeInsets.zero,title:Text(e.value),subtitle:Text('${widget.patient[e.key]??''}'.trim().isEmpty?'Sin registro':'${widget.patient[e.key]}')),
          Text('Fuente: perfil del paciente · actualización ${widget.patient['updated_at']??'sin fecha'}'),
        ]),
        if(loading)const LinearProgressIndicator(),if(historyError.isNotEmpty)Text(historyError),
        if(!loading && historyError.isEmpty && history.isEmpty)const Text('No hay consultas previas registradas para esta fecha.'),
        for(final row in history)panel('Consulta #${row['id']} · ${clinicalDate(row['date'])}',[
          for(final k in ['reason','illness','diagnoses','treatment','plan'])if('${row[k]??''}'.trim().isNotEmpty)Padding(padding:const EdgeInsets.only(bottom:10),child:SelectableText('${clinicalLabels[k]}: ${row[k]}')),
        ]),
      ]),
      ListView(padding:const EdgeInsets.all(16),children:[
        if(loading)const LinearProgressIndicator(),if(historyError.isNotEmpty)Text(historyError),
        if(history.isNotEmpty)panel('Actual frente a consulta #${history.first['id']}',[
          Text('Anterior: ${clinicalDate(history.first['date'])}\nActual: ${clinicalDate(widget.encounter)}\nLos campos vacíos significan “sin registro”, no mejoría. Las propuestas aún no aplicadas no se incluyen.'),
          for(final row in compareConsultations(history.first,current))Padding(padding:const EdgeInsets.symmetric(vertical:10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(row['label']!,style:const TextStyle(fontWeight:FontWeight.bold)),Text('Anterior: ${row['before']!.isEmpty?'Sin registro':row['before']}'),Text('Actual: ${row['after']!.isEmpty?'Sin registro':row['after']}'),if(row['delta']!.isNotEmpty)Text('Cambio: ${row['delta']} (misma unidad del campo)')])),
          const Divider(),const Text('Mapa corporal anterior',style:TextStyle(fontWeight:FontWeight.bold)),
          Text((nomInput(history.first)['nom_body_map']??'').isEmpty?'Sin registro':describeBodyMap(nomInput(history.first)['nom_body_map']!)),
          const Text('Mapa corporal actual',style:TextStyle(fontWeight:FontWeight.bold)),Text((current['nom_body_map']??'').isEmpty?'Sin registro':describeBodyMap(current['nom_body_map']!)),
        ])else if(!loading && historyError.isEmpty)const Text('Hace falta una consulta previa para comparar.'),
      ]),
    ]),
  )));
}

class AssistantSettings extends StatefulWidget {
  final AssistantConfig config;
  const AssistantSettings({super.key,required this.config});
  @override
  State<AssistantSettings> createState()=>_AssistantSettingsState();
}
class _AssistantSettingsState extends State<AssistantSettings>{
  late final endpoint=TextEditingController(text:widget.config.endpoint);
  late final model=TextEditingController(text:widget.config.model);
  late final token=TextEditingController(text:widget.config.token);
  bool saving=false;String? error;
  @override
  void dispose(){endpoint.dispose();model.dispose();token.dispose();super.dispose();}
  Future<void> save()async{
    setState(()=>saving=true);
    try{await AssistantConfig(endpoint.text,model.text,token.text).save();if(mounted)Navigator.pop(context);}
    on FormatException catch(e){if(mounted)setState(()=>error=e.message);}
    catch(_){if(mounted)setState(()=>error='No se pudo guardar en el almacenamiento seguro.');}
    finally{if(mounted)setState(()=>saving=false);}
  }
  @override
  Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('IA opcional · este equipo')),body:ListView(padding:const EdgeInsets.all(20),children:[
    const Text('Conecta un servicio compatible con Chat Completions o un servidor local en esta PC. La aplicación no incluye una suscripción ni un modelo descargado. El expediente funciona sin configurarlos.'),const SizedBox(height:16),
    TextField(controller:endpoint,decoration:const InputDecoration(labelText:'URL completa de chat/completions',hintText:'https://tu-servicio/v1/chat/completions'),autocorrect:false),const SizedBox(height:12),
    TextField(controller:model,decoration:const InputDecoration(labelText:'Identificador del modelo'),autocorrect:false),const SizedBox(height:12),
    TextField(controller:token,obscureText:true,enableSuggestions:false,autocorrect:false,decoration:const InputDecoration(labelText:'Clave del servicio (si la requiere)')),const SizedBox(height:16),
    const Text('La clave se guarda en el almacenamiento seguro de este equipo y no se incluye en los respaldos .ambak. Cada equipo necesita su configuración. Nunca uses aquí tu contraseña o archivos de e.firma.'),
    if(Platform.isWindows)TextButton(onPressed:()=>endpoint.text='http://localhost:11434/v1/chat/completions',child:const Text('Usar dirección local de Ollama')),
    const Text('Local requiere instalar y ejecutar previamente un motor y un modelo compatible. HTTPS es obligatorio para servicios externos. No se envía nada al guardar esta configuración.'),const SizedBox(height:12),
    if(error!=null)Text(error!),FilledButton(onPressed:saving?null:save,child:const Text('Guardar configuración')),
    TextButton(onPressed:saving?null:()async{try{await AssistantConfig.clear();if(context.mounted)Navigator.pop(context);}catch(_){if(mounted)setState(()=>error='No se pudo eliminar la configuración.');}},child:const Text('Desconectar y borrar credenciales')),
  ]));
}
