import 'dart:convert';

const bodyRegions = <String, String>{
  'head': 'Cabeza', 'neck': 'Cuello', 'chest': 'Tórax', 'abdomen': 'Abdomen', 'pelvis': 'Pelvis',
  'right_shoulder': 'Hombro derecho', 'left_shoulder': 'Hombro izquierdo',
  'right_arm': 'Brazo derecho', 'left_arm': 'Brazo izquierdo',
  'right_hand': 'Mano derecha', 'left_hand': 'Mano izquierda',
  'right_hip': 'Cadera derecha', 'left_hip': 'Cadera izquierda',
  'right_knee': 'Rodilla derecha', 'left_knee': 'Rodilla izquierda',
  'right_foot': 'Pie derecho', 'left_foot': 'Pie izquierdo',
  'upper_back': 'Espalda superior', 'lower_back': 'Región lumbar',
};
Map<String, dynamic> parseBodyMap(String raw) {
  if (raw.trim().isEmpty) return {'schema': 1, 'points': <dynamic>[]};
  final value = jsonDecode(raw);
  if (value is! Map || value['schema'] != 1 || value['points'] is! List || (value['points'] as List).length > 40) throw const FormatException('Mapa corporal inválido.');
  final seen = <String>{};
  for (final point in value['points'] as List) {
    if (point is! Map || !bodyRegions.containsKey(point['region']) || !['front', 'back'].contains(point['view']) ||
        !seen.add('${point['view']}:${point['region']}') || point['notes'] is! String || (point['notes'] as String).length > 2000 ||
        (point['severity'] != null && (point['severity'] is! int || point['severity'] < 0 || point['severity'] > 10))) throw const FormatException('Punto del mapa corporal inválido.');
  }
  return Map<String, dynamic>.from(value);
}
String describeBodyMap(String raw) {
  final points = parseBodyMap(raw)['points'] as List;
  return points.map((p) => '${bodyRegions[p['region']]} · vista ${p['view'] == 'front' ? 'anterior' : 'posterior'} · intensidad ${p['severity'] == null ? 'sin registro' : '${p['severity']}/10'}${'${p['notes']}'.trim().isEmpty ? '' : '\n${p['notes']}'}').join('\n\n');
}
