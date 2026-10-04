import 'dart:convert';
import 'package:flutter/material.dart';
import 'clinical_body_data.dart';

Map<String, Offset> bodyPositions(bool back) {
  final right = back ? 0.70 : 0.30, left = 1-right;
  return {
    'head': const Offset(.5,.09), 'neck': const Offset(.5,.20),
    if (!back) 'chest': const Offset(.5,.30), if (!back) 'abdomen': const Offset(.5,.42), if (!back) 'pelvis': const Offset(.5,.53),
    if (back) 'upper_back': const Offset(.5,.32), if (back) 'lower_back': const Offset(.5,.46),
    'right_shoulder': Offset(right,.25), 'left_shoulder': Offset(left,.25),
    'right_arm': Offset(back ? .78 : .22,.38), 'left_arm': Offset(back ? .22 : .78,.38),
    'right_hand': Offset(back ? .82 : .18,.53), 'left_hand': Offset(back ? .18 : .82,.53),
    'right_hip': Offset(back ? .60 : .40,.56), 'left_hip': Offset(back ? .40 : .60,.56),
    'right_knee': Offset(back ? .61 : .39,.72), 'left_knee': Offset(back ? .39 : .61,.72),
    'right_foot': Offset(back ? .63 : .37,.91), 'left_foot': Offset(back ? .37 : .63,.91),
  };
}

class ClinicalBodyMap extends StatefulWidget {
  final String initial;
  final bool readOnly;
  const ClinicalBodyMap({super.key, this.initial = '', this.readOnly = false});
  @override
  State<ClinicalBodyMap> createState() => _ClinicalBodyMapState();
}
class _ClinicalBodyMapState extends State<ClinicalBodyMap> {
  late List<Map<String, dynamic>> points;
  bool back = false;
  @override
  void initState() { super.initState(); points = (parseBodyMap(widget.initial)['points'] as List).map((p) => Map<String, dynamic>.from(p as Map)).toList(); }
  String get view => back ? 'back' : 'front';
  bool selected(String region) => points.any((p) => p['view'] == view && p['region'] == region);
  void toggle(String region) {
    if (widget.readOnly) return;
    setState(() { if (selected(region)) { points.removeWhere((p) => p['view'] == view && p['region'] == region); } else { points.add({'region': region, 'view': view, 'severity': null, 'notes': ''}); } });
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Mapa corporal del dolor')),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      const Text('Marca las regiones referidas por el paciente. La derecha e izquierda corresponden al paciente, no al observador.'), const SizedBox(height: 12),
      Wrap(spacing: 8, children: [ChoiceChip(label: const Text('Vista anterior'), selected: !back, onSelected: (_) => setState(() => back = false)), ChoiceChip(label: const Text('Vista posterior'), selected: back, onSelected: (_) => setState(() => back = true))]),
      const SizedBox(height: 12),
      Center(child: SizedBox(width: 300, height: 400, child: LayoutBuilder(builder: (ctx, constraints) => GestureDetector(
        onTapUp: widget.readOnly ? null : (details) {
          final positions = bodyPositions(back); String? hit; double distance = 28;
          for (final e in positions.entries) { final d = (Offset(e.value.dx * constraints.maxWidth, e.value.dy * constraints.maxHeight) - details.localPosition).distance; if (d < distance) { hit = e.key; distance = d; } }
          if (hit != null) toggle(hit);
        },
        child: CustomPaint(painter: BodyPainter(back: back, selected: {for (final p in points.where((p) => p['view'] == view)) '${p['region']}'}, color: Theme.of(context).colorScheme.primary, surface: Theme.of(context).colorScheme.surfaceContainerHighest)),
      )))),
      const Text('También puedes seleccionar por nombre:', style: TextStyle(fontWeight: FontWeight.w700)), const SizedBox(height: 8),
      Wrap(spacing: 6, runSpacing: 6, children: [for (final region in bodyPositions(back).keys) FilterChip(label: Text(bodyRegions[region]!), selected: selected(region), onSelected: widget.readOnly ? null : (_) => toggle(region))]),
      const SizedBox(height: 18),
      for (final point in points) Card(key: ValueKey('${point['view']}:${point['region']}'), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${bodyRegions[point['region']]} · ${point['view'] == 'front' ? 'anterior' : 'posterior'}', style: const TextStyle(fontWeight: FontWeight.w700)),
        Text(point['severity'] == null ? 'Intensidad sin registrar' : 'Intensidad: ${point['severity']}/10'),
        if (!widget.readOnly) Slider(value: (point['severity'] as int? ?? 5).toDouble(), min: 0, max: 10, divisions: 10, label: point['severity'] == null ? 'Sin registrar' : '${point['severity']}/10', onChanged: (v) => setState(() => point['severity'] = v.round())),
        if (!widget.readOnly) TextFormField(initialValue: '${point['notes']}', maxLength: 2000, maxLines: 3, decoration: const InputDecoration(labelText: 'Inicio, irradiación, características o limitación'), onChanged: (v) => point['notes'] = v)
        else if ('${point['notes']}'.isNotEmpty) Text('${point['notes']}'),
      ]))),
      if (points.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('No hay regiones registradas. No equivale a dolor negado.')),
      if (!widget.readOnly) FilledButton.icon(onPressed: () => Navigator.pop(context, points.isEmpty ? '' : jsonEncode({'schema': 1, 'points': points})), icon: const Icon(Icons.check), label: const Text('Usar este mapa en la nota')),
    ]),
  );
}
class BodyPainter extends CustomPainter {
  final bool back; final Set<String> selected; final Color color, surface;
  BodyPainter({required this.back, required this.selected, required this.color, required this.surface});
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save(); canvas.scale(size.width, size.height);
    final fill = Paint()..color = surface; final stroke = Paint()..color = color.withValues(alpha: .7)..style = PaintingStyle.stroke..strokeWidth = .009;
    final head = Rect.fromCenter(center: const Offset(.5,.09), width: .19, height: .15); canvas.drawOval(head, fill); canvas.drawOval(head, stroke);
    final body = Path()..moveTo(.44,.17)..lineTo(.44,.21)..lineTo(.30,.24)..lineTo(.15,.54)..lineTo(.21,.57)..lineTo(.36,.34)..lineTo(.35,.55)..lineTo(.31,.92)..lineTo(.44,.94)..lineTo(.50,.61)..lineTo(.56,.94)..lineTo(.69,.92)..lineTo(.65,.55)..lineTo(.64,.34)..lineTo(.79,.57)..lineTo(.85,.54)..lineTo(.70,.24)..lineTo(.56,.21)..lineTo(.56,.17)..close();
    canvas.drawPath(body, fill); canvas.drawPath(body, stroke);
    canvas.restore();
    for (final e in bodyPositions(back).entries) {
      final position = Offset(e.value.dx*size.width, e.value.dy*size.height);
      canvas.drawCircle(position, selected.contains(e.key) ? 10 : 5, Paint()..color = selected.contains(e.key) ? Colors.orange : color.withValues(alpha: .6));
      if (selected.contains(e.key)) canvas.drawCircle(position, 15, Paint()..color = Colors.orange.withValues(alpha: .3)..style = PaintingStyle.stroke..strokeWidth = 3);
    }
  }
  @override
  bool shouldRepaint(covariant BodyPainter old) => old.back != back || old.color != color || old.surface != surface || old.selected.toString() != selected.toString();
}
