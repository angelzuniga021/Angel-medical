import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String clinicalDate(Object? raw) {
  final value = DateTime.tryParse('$raw');
  return value == null
      ? '${raw ?? ''}'
      : DateFormat('dd/MM/yyyy HH:mm').format(value.toLocal());
}

void clinicalMessage(BuildContext context, Object text) {
  if (context.mounted)
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$text')));
}

Future<String?> askClinicalText(
  BuildContext context,
  String title, {
  String initial = '',
  int lines = 3,
}) async {
  final c = TextEditingController(text: initial);
  final value = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: c,
        autofocus: true,
        minLines: 1,
        maxLines: lines,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, c.text.trim()),
          child: const Text('Guardar'),
        ),
      ],
    ),
  );
  // Controller lifetime includes the closing animation.
  await Future<void>.delayed(const Duration(milliseconds: 250));
  c.dispose();
  return value;
}

Future<bool> clinicalConfirm(
  BuildContext context,
  String title,
  String text,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Continuar'),
          ),
        ],
      ),
    ) ??
    false;

Widget clinicalPanel(
  BuildContext context,
  String title,
  List<Widget> children,
) => Card(
  child: Padding(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    ),
  ),
);

Future<T> clinicalBlocking<T>(
  BuildContext context,
  String label,
  Future<T> Function() action,
) async {
  final nav = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    ),
  );
  await Future<void>.delayed(Duration.zero);
  try {
    return await action();
  } finally {
    if (nav.mounted) nav.pop();
  }
}
