import 'dart:convert';
import 'dart:math' as math;

class ScaleField {
  final String key, label;
  final double? min, max;
  final bool scored, optional;
  final List<Map<String, dynamic>> options;
  ScaleField(Map<String, dynamic> j) : key=j['key'] as String, label=j['label'] as String,
    scored=j['scored']!=false, optional=j['optional']==true,
    min=(j['min'] as num?)?.toDouble(), max=(j['max'] as num?)?.toDouble(),
    options=(j['options'] as List? ?? []).map((v)=>Map<String,dynamic>.from(v as Map)).toList();
  String display(double value) => options.isEmpty ? '$value' : options.firstWhere((o)=>(o['value'] as num).toDouble()==value)['label'] as String;
}
class ClinicalScale {
  final String id, name, area, version, population, limitations, source, formula, unit;
  final List<ScaleField> fields;
  final String instructions, attribution, translationSource;
  ClinicalScale(Map<String,dynamic> j) : instructions=j['instructions']??'', attribution=j['attribution']??'', translationSource=j['translationSource']??'', id=j['id'],name=j['name'],area=j['area'],version=j['version'],population=j['population'],limitations=j['limitations'],source=j['source'],formula=j['formula'],unit=j['unit'],fields=(j['fields'] as List).map((v)=>ScaleField(Map<String,dynamic>.from(v as Map))).toList();
  Map<String, double> validate(Map<String, String> input) {
    final out=<String,double>{};
    for(final f in fields) {
      final raw=(input[f.key]??'').trim().replaceAll(',', '.');
      if(raw.isEmpty && f.optional) continue;
      final value=double.tryParse(raw);
      if(value==null || !value.isFinite) throw FormatException('Evaluación incompleta: ${f.label}');
      if(f.options.isNotEmpty && !f.options.any((o)=>(o['value'] as num).toDouble()==value)) throw FormatException('Opción no válida: ${f.label}');
      if(f.min!=null && (value<f.min! || value>f.max!)) throw FormatException('Fuera de rango: ${f.label} (${f.min}–${f.max})');
      if((f.key=='age' || id=='pain' || (id=='news2' && ['rr','spo2','sbp','hr'].contains(f.key))) && value!=value.roundToDouble()) throw FormatException('Utiliza un número entero: ${f.label}');
      if(id=='gcs' && value<0) throw const FormatException('Glasgow: componente no evaluable. Registra E/V/M por separado en la nota, sin asignar un total.');
      if(id=='news2' && f.key=='temperature' && (value*10-(value*10).round()).abs()>0.000001) throw const FormatException('Registra temperatura con máximo un decimal.');
      out[f.key]=value;
    }
    return out;
  }
  double calculate(Map<String,String> input) {
    final v=validate(input);
    double n(String k)=>v[k]!;
    double result;
    switch(formula) {
      case 'sum':result=fields.where((f)=>f.scored).fold<double>(0,(a,f)=>a+v[f.key]!);break;
      case 'news2':result=newsComponents(v).values.fold<double>(0,(a,b)=>a+b);break;
      case 'bmi': result=n('weight')/math.pow(n('height')/100,2);break;
      case 'map':
        if(n('dbp')>n('sbp')) throw const FormatException('La PAD no puede superar la PAS.');
        result=(n('sbp')+2*n('dbp'))/3;break;
      case 'shock':result=n('hr')/n('sbp');break;
      case 'bsa':result=math.sqrt(n('weight')*n('height')/3600);break;
      case 'cockcroft':result=(140-n('age'))*n('weight')/(72*n('scr'))*(n('female')==1?0.85:1);break;
      case 'ckdepi':
        final female=n('female')==1, k=female?0.7:0.9, alpha=female?-0.241:-0.302, r=n('scr')/k;
        result=(142*math.pow(math.min(r,1),alpha)*math.pow(math.max(r,1),-1.200)*math.pow(0.9938,n('age'))*(female?1.012:1)).toDouble();break;
      case 'anion':result=n('na')-n('cl')-n('hco3');break;
      case 'osm':result=2*n('na')+n('glucose')/18+n('bun')/2.8;break;
      default:throw const FormatException('Instrumento no disponible.');
    }
    if(!result.isFinite) throw const FormatException('No se pudo calcular un resultado finito.');
    return result;
  }
  Map<String,double> newsComponents(Map<String,double> v) {
    if(v['scale']==2 && v['scale2_confirm']!=1) throw const FormatException('NEWS2: confirma los requisitos clínicos para utilizar la escala SpO2 2.');
    final rr=v['rr']!,sp=v['spo2']!,bp=v['sbp']!,hr=v['hr']!,temp=v['temperature']!;
    final oxygen=v['oxygen']!;
    final saturation=v['scale']==1?(sp<=91?3:sp<=93?2:sp<=95?1:0):(sp<=83?3:sp<=85?2:sp<=87?1:sp<=92||oxygen==0?0:sp<=94?1:sp<=96?2:3);
    return {'Respiración':(rr<=8?3:rr<=11?1:rr<=20?0:rr<=24?2:3).toDouble(),'SpO2':saturation.toDouble(),'Oxígeno':oxygen,'PAS':(bp<=90?3:bp<=100?2:bp<=110?1:bp<=219?0:3).toDouble(),'Pulso':(hr<=40?3:hr<=50?1:hr<=90?0:hr<=110?1:hr<=130?2:3).toDouble(),'Consciencia':v['consciousness']!,'Temperatura':(temp<=35?3:temp<=36?1:temp<=38?0:temp<=39?1:2).toDouble()};
  }
  String interpretation(double s) {
    switch(id) {
      case 'news2':return s>=7?'Riesgo alto: respuesta urgente/emergente y monitorización según protocolo.':s>=5?'Riesgo medio: valoración clínica urgente.':'Total 0–4: revisar también cada componente; un valor individual de 3 activa respuesta urgente.';
      case 'rcri':return s>=3?'Tres o más factores del RCRI. Integrar evaluación perioperatoria y capacidad funcional.':'${s.toInt()} factores del RCRI. Interpretar junto con síntomas, cirugía y capacidad funcional.';
      case 'apgar':return s<=3?'Puntaje bajo. Interpretar según minuto de vida e intervenciones realizadas.':s<=6?'Puntaje intermedio. Interpretar según minuto de vida e intervenciones realizadas.':'Puntaje 7–10. Interpretar según minuto de vida; no excluye otros problemas neonatales.';
      case 'rockall':return 'Rockall completo: $s puntos. Estratificación posterior a endoscopia; no autoriza alta por sí solo.';
      case 'phq9':return s<5?'Síntomas depresivos mínimos.':s<10?'Síntomas depresivos leves.':s<15?'Síntomas depresivos moderados.':s<20?'Síntomas depresivos moderadamente graves.':'Síntomas depresivos graves.';
      case 'gad7':return s<5?'Síntomas de ansiedad mínimos.':s<10?'Síntomas de ansiedad leves.':s<15?'Síntomas de ansiedad moderados.':'Síntomas de ansiedad graves.';
      case 'phq2':return s>=3?'Tamizaje positivo: ampliar entrevista y considerar PHQ-9.':'Tamizaje por debajo del umbral de 3; no excluye depresión.';
      case 'gad2':return s>=3?'Tamizaje positivo: ampliar entrevista y considerar GAD-7.':'Tamizaje por debajo del umbral de 3; no excluye un trastorno de ansiedad.';
      case 'spesi':return s==0?'Estrato pronóstico bajo según sPESI; valorar criterios adicionales antes de decidir manejo.':'Estrato pronóstico elevado según sPESI.';
      case 'geneva':return s<=3?'Probabilidad preprueba baja.':s<=10?'Probabilidad preprueba intermedia.':'Probabilidad preprueba alta.';
      case 'pain':return s==0?'Sin dolor referido.':s<=3?'Intensidad leve.':s<=6?'Intensidad moderada.':'Intensidad elevada.';
      case 'gcs':return 'Total E + V + M. Interpretar los componentes y factores que interfieren.';
      case 'curb65':return s<=1?'Estrato bajo.':s==2?'Estrato intermedio.':'Estrato alto.';
      case 'crb65':return s==0?'Estrato bajo.':s<=2?'Estrato intermedio.':'Estrato alto.';
      case 'wells_pe':return s>4?'TEP probable según modelo de dos niveles.':'TEP improbable según modelo; no significa descartado.';
      case 'wells_dvt':return s>=2?'TVP probable según modelo de dos niveles.':'TVP improbable según modelo; no significa descartada.';
      case 'perc':return s==0?'Sin criterios positivos; solo interpretable si la probabilidad clínica ya era baja.':'Uno o más criterios positivos; PERC no permite exclusión.';
      case 'heart':return s<=3?'Estrato bajo. No equivale a autorización de alta.':s<=6?'Estrato intermedio.':'Estrato alto.';
      case 'qsofa':return s>=2?'≥2 criterios: mayor riesgo de evolución desfavorable en contexto de infección.':'<2 criterios; no excluye sepsis ni deterioro.';
      case 'sirs':return s>=2?'Cumple ≥2 criterios inflamatorios; no identifica causa ni diagnostica sepsis.':'<2 criterios; no excluye infección ni sepsis.';
      case 'padua':return s>=4?'Riesgo trombótico elevado según Padua.':'Estrato bajo según Padua.';
      case 'hasbled':return s>=3?'Riesgo hemorrágico elevado: revisar factores modificables; no negar anticoagulación solo por el puntaje.':'Revisar factores hemorrágicos y contexto clínico.';
      case 'cha_va':case 'cha_vasc':return 'Puntuación tromboembólica. Aplicar umbrales de la guía correspondiente a esta versión.';
      case 'gbs':return 'Estratificación de hemorragia digestiva alta; aplicar protocolo local con valoración clínica.';
      case 'sofa':return 'Total absoluto de disfunción orgánica. No es ΔSOFA ni diagnóstico automático de sepsis.';
      case 'centor':case 'mcisaac':return 'Puntuación de probabilidad preprueba. No confirma etiología ni indica antibiótico automáticamente.';
      case 'alvarado':return 'Puntuación de sospecha de apendicitis; correlacionar con exploración, estudios y evolución.';
      default:return 'Resultado estimado. Ver unidades, fórmula y limitaciones del instrumento.';
    }
  }
  List<String> alerts(Map<String,String> input) {
    if(id=='news2') {
      try {final parts=newsComponents(validate(input));if(parts.values.any((v)=>v==3))return ['NEWS2: uno o más componentes puntúan 3. Requiere respuesta clínica urgente incluso con total <5.'];}on FormatException {return [];}
    }
    if(id=='phq9' && (double.tryParse(input['q9']??'')??0)>0) return ['Ítem 9 positivo: evaluar ahora pensamientos de muerte/autolesión, intención, plan, medios y seguridad. El total no determina el riesgo. Si existe peligro inmediato, activar el protocolo de urgencias y acompañamiento.'];
    return [];
  }
  String summary(Map<String,String> input, double value, DateTime date, String notes) {
    final v=validate(input);
    final d=date.toLocal();
    final when='${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year} ${d.hour.toString().padLeft(2,'0')}:${d.minute.toString().padLeft(2,'0')} (hora local)';
    return '$name · versión $version\nFecha: $when\nResultado: ${formatScaleValue(value)} $unit\n${interpretation(value)}\n${alerts(input).join('\n')}\n${id=='news2'?newsComponents(v).entries.map((e)=>'${e.key}: ${formatScaleValue(e.value)} puntos').join('\n'):''}\n$instructions\n${fields.map((f)=>'${f.label}: ${v.containsKey(f.key)?f.display(v[f.key]!):"Sin respuesta (no puntúa)"}').join('\n')}\n\nObservaciones: ${notes.trim().isEmpty?'Sin observaciones adicionales':notes.trim()}\nAplicación: $population\nLimitaciones: $limitations\nFuente: $source${translationSource.isEmpty?'':'\nVersión en español: $translationSource'}${attribution.isEmpty?'':'\n$attribution'}';
  }
}
String formatScaleValue(double value)=>value==value.roundToDouble()?value.toInt().toString():value.toStringAsFixed(2);
List<ClinicalScale> parseScaleCatalog(String raw) {
  final json=jsonDecode(raw) as Map<String,dynamic>;
  if(json['version']!=1) throw const FormatException('Versión de catálogo no admitida.');
  final tools=(json['tools'] as List).map((v)=>ClinicalScale(Map<String,dynamic>.from(v as Map))).toList();
  if(tools.map((t)=>t.id).toSet().length!=tools.length) throw const FormatException('Identificadores duplicados.');
  for(final t in tools) {
    if(t.fields.any((f)=>f.optional && f.scored)) throw const FormatException('Un componente puntuado no puede ser opcional.');
    if(t.fields.isEmpty || t.fields.map((f)=>f.key).toSet().length!=t.fields.length || !t.source.startsWith('https://')) throw const FormatException('Definición incompleta.');
  }
  return tools;
}
