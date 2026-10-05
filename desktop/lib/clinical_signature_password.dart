import 'package:flutter/material.dart';

class ClinicalSignaturePassword extends StatefulWidget {
  const ClinicalSignaturePassword({super.key});
  @override
  State<ClinicalSignaturePassword> createState() => _ClinicalSignaturePasswordState();
}
class _ClinicalSignaturePasswordState extends State<ClinicalSignaturePassword> {
  final password = TextEditingController();
  @override
  void dispose() { password.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Contraseña de la clave privada'),
    content: TextField(controller: password, obscureText: true, autocorrect: false, enableSuggestions: false, decoration: const InputDecoration(labelText: 'Contraseña .key')),
    actions: [
      TextButton(onPressed: () { password.clear(); Navigator.pop(context); }, child: const Text('Cancelar')),
      FilledButton(onPressed: () { final value = password.text; password.clear(); Navigator.pop(context, value); }, child: const Text('Firmar')),
    ],
  );
}
