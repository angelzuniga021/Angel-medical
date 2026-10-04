import 'dart:convert';
import 'dart:math' as math;

class ScaleField {
  final String key, label;
  final double? min, max;
  final List<Map<String, dynamic>> options;
  ScaleField(Map<String, dynamic> j) : key=j['key'] as String, label=j['label'] as String,
    min=(j['min'] as num?)?.toDouble(), max=(j['max'] as num?)?.toDouble(),
    options=(j['options'] as List? ?? []).map((v)=>Map<String,dynamic>.from(v as Map)).toList();
  String display(double value) => options.isEmpty ? '$value' : options.firstWhere((o)=>(o['value'] as num).toDouble()==value)['label'] as String;
}
class ClinicalScale {
  final String id, name, area, version, population, limitations, source, formula, unit;
  final List<ScaleField> fields;
  ClinicalScale(Map<String,dynamic> j) : id=j['id'],name=j['name'],area=j['area'],version=j['version'],population=j['population'],limitations=j['limitations'],source=j['source'],formula=j['formula'],unit=j['unit'],fields=(j['fields'] as List).map((v)=>ScaleField(Map<String,dynamic>.from(v as Map))).toList();
  Map<String, double> validate(Map<String, String> input) {
    final out=<String,double>{};
    for(final f in fields) {
      final raw=(input[f.key]??'').trim().replaceAll(',', '.');
      final value=double.tryParse(raw);
      if(value==null || !value.isFinite) throw FormatException('Evaluación incompleta: ${f.label}');
      if(f.options.isNotEmpty && !f.options.any((o)=>(o['value'] as num).toDouble()==value)) throw FormatException('Opción no válida: ${f.label}');
      if(f.min!=null && (value<f.min! || value>f.max!)) throw FormatException('Fuera de rango: ${f.label} (${f.min}–${f.max})');
      if((f.key=='age' || id=='pain') && value!=value.roundToDouble()) throw FormatException('Utiliza un número entero: ${f.label}');
      if(id=='gcs' && value<0) throw const FormatException('Glasgow: componente no evaluable. Registra E/V/M por separado en la nota, sin asignar un total.');
      out[f.key]=value;
    }
    return out;
  }
  double calculate(Map<String,String> input) {
    final v=validate(input);
    double n(String k)=>v[k]!;
    double result;
    switch(formula) {
      case 'sum':result=v.values.fold<double>(0,(a,b)=>a+b);break;
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
  String interpretation(double s) {
    switch(id) {
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
  String summary(Map<String,String> input, double value, DateTime date, String notes) {
    final v=validate(input);
    return '$name · versión $version\nFecha: ${date.toLocal().toIso8601String()}\nResultado: ${formatScaleValue(value)} $unit\n${interpretation(value)}\n\n${fields.map((f)=>'${f.label}: ${f.display(v[f.key]!)}').join('\n')}\n\nObservaciones: ${notes.trim().isEmpty?'Sin observaciones adicionales':notes.trim()}\nAplicación: $population\nLimitaciones: $limitations\nFuente: $source';
  }
}
String formatScaleValue(double value)=>value==value.roundToDouble()?value.toInt().toString():value.toStringAsFixed(2);
List<ClinicalScale> parseScaleCatalog(String raw) {
  final json=jsonDecode(raw) as Map<String,dynamic>;
  if(json['version']!=1) throw const FormatException('Versión de catálogo no admitida.');
  final tools=(json['tools'] as List).map((v)=>ClinicalScale(Map<String,dynamic>.from(v as Map))).toList();
  if(tools.map((t)=>t.id).toSet().length!=tools.length) throw const FormatException('Identificadores duplicados.');
  for(final t in tools) {
    if(t.fields.isEmpty || t.fields.map((f)=>f.key).toSet().length!=t.fields.length || !t.source.startsWith('https://')) throw const FormatException('Definición incompleta.');
  }
  return tools;
}
