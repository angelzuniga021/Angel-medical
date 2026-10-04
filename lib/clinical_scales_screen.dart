import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'clinical_scale_pdf.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'db.dart';
import 'clinical_scales.dart';
import 'clinical_scale_store.dart';
import 'clinical_ui.dart';

class ClinicalScalesScreen extends StatefulWidget {
  final Map<String,Object?>? patient;
  final bool selectForNote;
  const ClinicalScalesScreen({super.key,this.patient,this.selectForNote=false});
  @override State<ClinicalScalesScreen> createState()=>_ClinicalScalesScreenState();
}
class _ClinicalScalesScreenState extends State<ClinicalScalesScreen> {
  List<ClinicalScale>? tools;
  Set<String> favorites={};
  String query='',area='Todas';
  bool favoritesOnly=false;
  String? error;
  @override void initState(){super.initState();load();}
  Future<void> load() async {
    try {
      final list=parseScaleCatalog(await rootBundle.loadString('assets/scales/catalog.json'));
      final raw=await AppDb.instance.getSetting('scale_favorites');
      final fav=raw==null?<String>{}:(jsonDecode(raw) as List).cast<String>().toSet();
      if(mounted)setState((){tools=list;favorites=fav;error=null;});
    } catch(_) {if(mounted)setState(()=>error='No se pudo abrir el catálogo. Pulsa actualizar.');}
  }
  Future<void> favorite(ClinicalScale t) async {
    final next={...favorites};if(!next.add(t.id))next.remove(t.id);
    try{await AppDb.instance.setSetting('scale_favorites',jsonEncode(next.toList()));if(mounted)setState(()=>favorites=next);}catch(_){if(mounted)clinicalMessage(context,'No se pudo guardar el favorito.');}
  }
  Future<void> open(ClinicalScale t) async {
    final text=await Navigator.push<String>(context,MaterialPageRoute(builder:(_)=>ScaleAssessment(tool:t,patient:widget.patient,selectForNote:widget.selectForNote)));
    if(text!=null && widget.selectForNote && mounted)Navigator.pop(context,text);
  }
  @override Widget build(BuildContext context){
    final visible=(tools??[]).where((t)=>(area=='Todas'||t.area==area)&&(!favoritesOnly||favorites.contains(t.id))&&('${t.name} ${t.area} ${t.id}'.toLowerCase().contains(query.toLowerCase()))).toList();
    return Scaffold(appBar:AppBar(title:const Text('Escalas y calculadoras'),actions:[
      if(widget.patient!=null)IconButton(tooltip:'Historial del paciente',icon:const Icon(Icons.history),onPressed:()async{final text=await Navigator.push<String>(context,MaterialPageRoute(builder:(_)=>ScaleHistory(patient:widget.patient!,selectForNote:widget.selectForNote)));if(text!=null&&widget.selectForNote&&mounted)Navigator.pop(context,text);}),
      IconButton(tooltip:'Actualizar',onPressed:load,icon:const Icon(Icons.refresh)),
    ]),body:error!=null?Center(child:Text(error!)):tools==null?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
      Text(widget.patient==null?'Cálculo rápido · selecciona un paciente para guardar en su expediente':'Expediente de ${widget.patient!['first_name']} ${widget.patient!['last_name']}',style:Theme.of(context).textTheme.titleMedium),
      const SizedBox(height:12),TextField(decoration:const InputDecoration(labelText:'Buscar escala o calculadora',prefixIcon:Icon(Icons.search)),onChanged:(v)=>setState(()=>query=v)),
      const SizedBox(height:12),DropdownButtonFormField<String>(value:area,isExpanded:true,decoration:const InputDecoration(labelText:'Área'),items:['Todas',...tools!.map((t)=>t.area).toSet()].map((a)=>DropdownMenuItem(value:a,child:Text(a))).toList(),onChanged:(v)=>setState(()=>area=v??'Todas')),
      FilterChip(label:Text('Favoritos · ${favorites.length}'),selected:favoritesOnly,onSelected:(v)=>setState(()=>favoritesOnly=v)),
      Text('${visible.length} herramientas · cálculo local sin internet'),
      if(visible.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('No hay coincidencias. Cambia el filtro.')),
      for(final t in visible)Card(child:ListTile(isThreeLine:true,leading:Icon(t.area=='Calculadoras'?Icons.calculate_outlined:Icons.assignment_outlined),title:Text(t.name),subtitle:Text('${t.area}\nVersión ${t.version} · ver indicación y fuente'),onTap:()=>open(t),trailing:IconButton(tooltip:'Favorito',icon:Icon(favorites.contains(t.id)?Icons.star:Icons.star_border),onPressed:()=>favorite(t)))),
    ]));
  }
}
class ScaleAssessment extends StatefulWidget {
  final ClinicalScale tool;
  final Map<String,Object?>? patient;
  final bool selectForNote;
  const ScaleAssessment({super.key,required this.tool,this.patient,this.selectForNote=false});
  @override State<ScaleAssessment> createState()=>_ScaleAssessmentState();
}
class _ScaleAssessmentState extends State<ScaleAssessment> {
  final form=GlobalKey<FormState>();
  final input=<String,String>{};
  final notes=TextEditingController();
  double? score;
  bool applicable=false,busy=false,saved=false;
  DateTime evaluatedAt=DateTime.now();
  String? failure;
  @override void initState(){super.initState();notes.addListener(invalidate);}
  @override void dispose(){notes.removeListener(invalidate);notes.dispose();super.dispose();}
  void invalidate(){if(mounted)setState((){score=null;saved=false;failure=null;});}
  String get summary=>widget.tool.summary(input,score!,evaluatedAt,notes.text);
  void calculate(){
    if(!applicable){setState(()=>failure='Confirma que la población e indicación corresponden.');return;}
    if(!form.currentState!.validate())return;
    try{final s=widget.tool.calculate(input);setState((){score=s;failure=null;});}catch(e){setState(()=>failure=e.toString().replaceFirst('FormatException: ',''));}
  }
  Future<void> save()async{
    if(score==null||busy||saved||widget.patient==null)return;
    setState(()=>busy=true);
    try{
      final db=await AppDb.instance.database;
      await saveClinicalScale(db,pid:widget.patient!['id'] as int,tool:widget.tool,input:Map.of(input),notes:notes.text,evaluatedAt:evaluatedAt,applicable:applicable);
      if(mounted){setState(()=>saved=true);clinicalMessage(context,'Evaluación guardada en el expediente.');}
    }catch(_){if(mounted)clinicalMessage(context,'No se pudo guardar la evaluación. El resultado permanece disponible; verifica los datos del médico y vuelve a intentar.');}
    finally{if(mounted)setState(()=>busy=false);}
  }
  Future<void> date()async{
    final now=DateTime.now();
    final d=await showDatePicker(context:context,initialDate:evaluatedAt,firstDate:DateTime(1900),lastDate:now);
    if(d==null||!mounted)return;
    final time=await showTimePicker(context:context,initialTime:TimeOfDay.fromDateTime(evaluatedAt));
    if(time==null||!mounted)return;
    final next=DateTime(d.year,d.month,d.day,time.hour,time.minute);
    if(next.isAfter(now)){clinicalMessage(context,'No uses una fecha futura.');return;}
    setState((){evaluatedAt=next;score=null;saved=false;});
  }
  @override Widget build(BuildContext context){final t=widget.tool;
    return PopScope(canPop:!busy,child:Scaffold(appBar:AppBar(title:Text(t.name)),body:AbsorbPointer(absorbing:busy,child:Form(key:form,child:ListView(padding:const EdgeInsets.all(16),children:[
      clinicalPanel(context,'Aplicación y límites',[
        Text(t.population),const SizedBox(height:8),Text(t.limitations),
        CheckboxListTile(contentPadding:EdgeInsets.zero,value:applicable,title:const Text('Confirmo que esta herramienta corresponde al paciente y al contexto'),onChanged:(v){setState(()=>applicable=v??false);invalidate();}),
        TextButton.icon(onPressed:()async{if(!await launchUrl(Uri.parse(t.source),mode:LaunchMode.externalApplication)&&mounted)clinicalMessage(context,'No se pudo abrir la fuente.');},icon:const Icon(Icons.open_in_new),label:const Text('Fuente original / guía')),
        Text('Versión ${t.version} · catálogo 2026-10-04'),
      ]),
      ListTile(contentPadding:EdgeInsets.zero,title:const Text('Fecha y hora de la evaluación'),subtitle:Text(clinicalDate(evaluatedAt.toIso8601String())),trailing:const Icon(Icons.event),onTap:date),
      for(final f in t.fields)Padding(padding:const EdgeInsets.only(bottom:16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(f.label,style:Theme.of(context).textTheme.titleSmall),const SizedBox(height:8),f.options.isNotEmpty?
        DropdownButtonFormField<String>(isExpanded:true,itemHeight:null,decoration:const InputDecoration(labelText:'Respuesta'),items:f.options.map((o)=>DropdownMenuItem<String>(value:'${o['value']}',child:Text('${o['label']}',))).toList(),selectedItemBuilder:(context)=>f.options.map((o)=>Text('${o['label']}',overflow:TextOverflow.ellipsis)).toList(),validator:(v)=>v==null?'Selecciona una respuesta':null,onChanged:(v){input[f.key]=v??'';invalidate();}):
        TextFormField(key:ValueKey(f.key),keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:InputDecoration(labelText:'Valor',helperText:'Rango de captura: ${f.min}–${f.max}'),validator:(v){final n=double.tryParse((v??'').trim().replaceAll(',','.'));return n==null||!n.isFinite?'Introduce un dato válido':n<f.min!||n>f.max!?'Fuera de rango':null;},onChanged:(v){input[f.key]=v;invalidate();})])),
      TextField(controller:notes,maxLines:3,decoration:const InputDecoration(labelText:'Observaciones / contexto / peso elegido')),
      const SizedBox(height:16),FilledButton.icon(onPressed:calculate,icon:const Icon(Icons.calculate),label:const Text('Calcular')),
      if(failure!=null)Padding(padding:const EdgeInsets.all(12),child:Text(failure!,style:TextStyle(color:Theme.of(context).colorScheme.error))),
      if(score!=null)clinicalPanel(context,'Resultado',[
        Text('${formatScaleValue(score!)} ${t.unit}',style:Theme.of(context).textTheme.headlineMedium),Text(t.interpretation(score!)),const SizedBox(height:12),
        if(widget.patient!=null)FilledButton.icon(onPressed:saved?null:save,icon:Icon(saved?Icons.check:Icons.save_outlined),label:Text(saved?'Guardado en el expediente':'Guardar evaluación')),
        OutlinedButton.icon(onPressed:()async{await Clipboard.setData(ClipboardData(text:summary));if(mounted)clinicalMessage(context,'Resultado y respuestas copiados.');},icon:const Icon(Icons.copy),label:const Text('Copiar para una nota')),
        if(widget.selectForNote)OutlinedButton.icon(onPressed:()=>Navigator.pop(context,summary),icon:const Icon(Icons.note_add_outlined),label:const Text('Agregar al borrador de la nota')),
      ]),
      if(busy)const Center(child:CircularProgressIndicator()),
    ])))));
  }
}
class ScaleHistory extends StatefulWidget {
  final Map<String,Object?> patient;
  final bool selectForNote;
  const ScaleHistory({super.key,required this.patient,this.selectForNote=false});
  @override State<ScaleHistory> createState()=>_ScaleHistoryState();
}
class _ScaleHistoryState extends State<ScaleHistory>{
  List<Map<String,Object?>>? rows;
  String filter='Todas';
  String? error;
  @override void initState(){super.initState();load();}
  Future<void> load()async{try{final r=await AppDb.instance.all('clinical_scales',where:'patient_id=?',args:[widget.patient['id']],orderBy:'date DESC,id DESC');if(mounted)setState(()=>rows=r);}catch(_){if(mounted)setState(()=>error='No se pudo cargar el historial.');}}
  Future<void> printRow(Map<String,Object?> row)async{
    try{
      final bytes=await buildScalePdf(row);await Printing.layoutPdf(name:'Evaluacion_clinica.pdf',onLayout:(_)async=>bytes);
    }catch(_){if(mounted)clinicalMessage(context,'No se pudo generar el PDF.');}
  }
  @override Widget build(BuildContext context){
    final list=(rows??[]).where((r)=>filter=='Todas'||r['scale_id']==filter).toList();
    return Scaffold(appBar:AppBar(title:const Text('Historial de evaluaciones')),body:error!=null?Center(child:Text(error!)):rows==null?const Center(child:CircularProgressIndicator()):ListView(padding:const EdgeInsets.all(16),children:[
      Text('${widget.patient['first_name']} ${widget.patient['last_name']}',style:Theme.of(context).textTheme.titleLarge),
      const Text('Los registros se conservan. Para una corrección o reevaluación, guarda una nueva evaluación y documenta el motivo.'),
      DropdownButtonFormField<String>(value:filter,isExpanded:true,items:[const DropdownMenuItem(value:'Todas',child:Text('Todas')),for(final id in rows!.map((r)=>'${r['scale_id']}').toSet())DropdownMenuItem(value:id,child:Text('${rows!.firstWhere((r)=>r['scale_id']==id)['scale_name']}',overflow:TextOverflow.ellipsis))],onChanged:(v)=>setState(()=>filter=v??'Todas')),
      if(filter!='Todas'&&list.isNotEmpty)clinicalPanel(context,'Evolución · más reciente primero',[
        const Text('Compara fechas, respuestas y contexto; los resultados no son intercambiables entre versiones.'),
        for(final r in list.take(12))ListTile(title:Text('${formatScaleValue((r['score'] as num).toDouble())} ${r['unit']}'),subtitle:Text('${clinicalDate(r['date'])} · v${r['scale_version']}')),
      ]),
      if(list.isEmpty)const Padding(padding:EdgeInsets.all(20),child:Text('Todavía no hay evaluaciones guardadas.')),
      for(final r in list)Card(child:ExpansionTile(title:Text('${r['scale_name']} · ${formatScaleValue((r['score'] as num).toDouble())} ${r['unit']}'),subtitle:Text(clinicalDate(r['date'])),children:[Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        SelectableText('${r['summary']}'),
        TextButton.icon(onPressed:()=>printRow(r),icon:const Icon(Icons.print_outlined),label:const Text('Imprimir / PDF')),
        TextButton.icon(onPressed:()async{await Clipboard.setData(ClipboardData(text:'${r['summary']}'));if(mounted)clinicalMessage(context,'Evaluación copiada.');},icon:const Icon(Icons.copy),label:const Text('Copiar')),
        if(widget.selectForNote)TextButton.icon(onPressed:()=>Navigator.pop(context,'${r['summary']}'),icon:const Icon(Icons.note_add),label:const Text('Agregar al borrador')),
      ]))])),
    ]));
  }
}
