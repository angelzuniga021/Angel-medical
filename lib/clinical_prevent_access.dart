import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'clinical_ui.dart';

class ClinicalPreventAccess extends StatelessWidget {
  const ClinicalPreventAccess({super.key});
  Future<void> open(BuildContext context,String url)async{
    if(!await launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication)&&context.mounted)clinicalMessage(context,'No se pudo abrir el sitio oficial. Revisa la conexión.');
  }
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('PREVENT · recurso oficial')),body:ListView(padding:const EdgeInsets.all(16),children:[
    clinicalPanel(context,'Riesgo cardiovascular para prevención primaria',[
      const Text('Calculadora oficial en línea de la American Heart Association. Estima riesgo de enfermedad cardiovascular total, enfermedad aterosclerótica e insuficiencia cardiaca.'),
      const SizedBox(height:12),
      const Text('10 años: edades 30–79. 30 años: edades 30–59. Utilizar en personas sin enfermedad cardiovascular conocida. Desarrollada con población estadounidense; valorar su aplicabilidad al paciente.'),
      const SizedBox(height:12),
      const Text('Prepara edad, sexo, presión sistólica, colesterol total, HDL, IMC, eGFR, diabetes, tabaquismo, tratamiento antihipertensivo y estatinas. El sitio oficial explica los datos opcionales.'),
      const SizedBox(height:12),
      FilledButton.icon(onPressed:()=>open(context,'https://professional.heart.org/en/guidelines-and-statements/prevent-calculator'),icon:const Icon(Icons.open_in_new),label:const Text('Abrir calculadora oficial PREVENT')),
    ]),
    clinicalPanel(context,'Uso en Ángel Medical',[
      const Text('Este acceso requiere internet. Ángel Medical no calcula ni valida resultados de PREVENT y no envía datos del expediente al sitio. Si utilizas un resultado en una nota, documenta fecha, horizonte, desenlace, datos utilizados y fuente.'),
      const SizedBox(height:12),
      const Text('El cálculo integrado sin internet está pendiente del acuerdo y acceso al código oficial de la AHA. Este botón no acepta la licencia ni constituye autorización de uso en nombre del médico.'),
      TextButton.icon(onPressed:()=>open(context,'https://form.jotform.com/240774577352161'),icon:const Icon(Icons.description_outlined),label:const Text('Revisar acuerdo oficial de acceso')),
    ]),
  ]));
}
