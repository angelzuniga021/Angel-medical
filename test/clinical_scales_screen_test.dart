import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/clinical_scales.dart';
import '../lib/clinical_scales_screen.dart';
import '../lib/clinical_theme.dart';
import '../lib/clinical_prevent_access.dart';
void main(){
 final tools=parseScaleCatalog(File('assets/scales/catalog.json').readAsStringSync());
 testWidgets('Scale blocks incomplete input and invalidates result after edit',(tester)async{
  await tester.pumpWidget(MaterialApp(home:ScaleAssessment(tool:tools.singleWhere((t)=>t.id=='pain'))));
  await tester.scrollUntilVisible(find.text('Calcular'),200,scrollable:find.byType(Scrollable).first);
  await tester.tap(find.text('Calcular'));await tester.pump();expect(find.textContaining('Confirma que la población'),findsOneWidget);
  tester.state<ScrollableState>(find.byType(Scrollable).first).position.jumpTo(0);await tester.pumpAndSettle();
  await tester.tap(find.byType(CheckboxListTile));await tester.pump();
  await tester.scrollUntilVisible(find.text('Calcular'),200,scrollable:find.byType(Scrollable).first);await tester.tap(find.text('Calcular'));await tester.pump();await tester.scrollUntilVisible(find.textContaining('Evaluación incompleta:'),100,scrollable:find.byType(Scrollable).first);expect(find.textContaining('Evaluación incompleta:'),findsOneWidget);
  await tester.scrollUntilVisible(find.byType(TextFormField),-100,scrollable:find.byType(Scrollable).first);await tester.enterText(find.byType(TextFormField),'0');
  await tester.scrollUntilVisible(find.text('Calcular'),100,scrollable:find.byType(Scrollable).first);await tester.tap(find.text('Calcular'));await tester.pump();
  await tester.scrollUntilVisible(find.text('Resultado'),100,scrollable:find.byType(Scrollable).first);expect(find.text('Sin dolor referido.'),findsOneWidget);
  await tester.scrollUntilVisible(find.byType(TextFormField),-100,scrollable:find.byType(Scrollable).first);expect(tester.widget<EditableText>(find.descendant(of:find.byType(TextFormField),matching:find.byType(EditableText))).controller.text,'0');await tester.enterText(find.byType(TextFormField),'3');await tester.pump();expect(find.text('Resultado'),findsNothing);
  expect(tester.takeException(),isNull);
 });
 testWidgets('PHQ alert appears before calculation and optional question cannot alter total',(tester)async{
  await tester.pumpWidget(MaterialApp(home:ScaleAssessment(tool:tools.singleWhere((t)=>t.id=='phq9'))));
  await tester.scrollUntilVisible(find.byType(CheckboxListTile),100,scrollable:find.byType(Scrollable).first);
  await tester.tap(find.byType(CheckboxListTile));await tester.pump();
  for(var i=1;i<=9;i++){
   final field=find.byKey(ValueKey('q$i'));
   await tester.scrollUntilVisible(field,150,scrollable:find.byType(Scrollable).first);
   tester.widget<DropdownButtonFormField<String>>(field).onChanged!(i==9?'1':'0');await tester.pump();
  }
  await tester.scrollUntilVisible(find.textContaining('Ítem 9 positivo:'),100,scrollable:find.byType(Scrollable).first);
  expect(find.textContaining('Ítem 9 positivo:'),findsOneWidget);expect(find.text('Resultado'),findsNothing);
  final functional=find.byKey(const ValueKey('function'));
  await tester.scrollUntilVisible(functional,-100,scrollable:find.byType(Scrollable).first);
  tester.widget<DropdownButtonFormField<String>>(functional).onChanged!('3');await tester.pump();
  await tester.scrollUntilVisible(find.text('Calcular'),100,scrollable:find.byType(Scrollable).first);await tester.tap(find.text('Calcular'));await tester.pump();
  await tester.scrollUntilVisible(find.text('Resultado'),100,scrollable:find.byType(Scrollable).first);
  expect(find.text('1 puntos'),findsOneWidget);expect(find.text('Síntomas depresivos mínimos.'),findsOneWidget);expect(tester.takeException(),isNull);
 });
 testWidgets('PREVENT resource discloses online access without claiming an integrated calculation',(tester)async{
  tester.view.physicalSize=const Size(320,750);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(builder:(ctx,child)=>MediaQuery(data:MediaQuery.of(ctx).copyWith(textScaler:const TextScaler.linear(1.5)),child:child!),home:const ClinicalPreventAccess()));
  await tester.scrollUntilVisible(find.text('Revisar acuerdo oficial de acceso'),150,scrollable:find.byType(Scrollable).first);
  expect(find.textContaining('Este acceso requiere internet.'),findsOneWidget);expect(find.text('Calcular'),findsNothing);expect(tester.takeException(),isNull);
 });
 for(final id in ['sofa','phq9','gad7','news2']){
 for(final brightness in Brightness.values){
  testWidgets('Long scale criteria readable in narrow large-text $id $brightness',(tester)async{
   tester.view.physicalSize=const Size(320,750);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
   await tester.pumpWidget(MaterialApp(theme:clinicalTheme(brightness),builder:(ctx,child)=>MediaQuery(data:MediaQuery.of(ctx).copyWith(textScaler:const TextScaler.linear(1.5)),child:child!),home:ScaleAssessment(tool:tools.singleWhere((t)=>t.id==id))));
   await tester.scrollUntilVisible(find.text('Calcular'),200,scrollable:find.byType(Scrollable).first);await tester.pump();expect(tester.takeException(),isNull);
  });
 }
 }
}
