import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/clinical_scales.dart';
import '../lib/clinical_scales_screen.dart';
import '../lib/clinical_theme.dart';
void main(){
 final tools=parseScaleCatalog(File('assets/scales/catalog.json').readAsStringSync());
 testWidgets('Scale blocks incomplete input and invalidates result after edit',(tester)async{
  await tester.pumpWidget(MaterialApp(home:ScaleAssessment(tool:tools.singleWhere((t)=>t.id=='pain'))));
  await tester.scrollUntilVisible(find.text('Calcular'),200,scrollable:find.byType(Scrollable).first);
  await tester.tap(find.text('Calcular'));await tester.pump();expect(find.textContaining('Confirma que la población'),findsOneWidget);
  await tester.scrollUntilVisible(find.byType(CheckboxListTile),-200,scrollable:find.byType(Scrollable).first);
  await tester.tap(find.byType(CheckboxListTile));await tester.pump();
  await tester.scrollUntilVisible(find.text('Calcular'),200,scrollable:find.byType(Scrollable).first);await tester.tap(find.text('Calcular'));await tester.pump();expect(find.text('Introduce un dato válido'),findsOneWidget);
  await tester.scrollUntilVisible(find.byType(TextFormField),-100,scrollable:find.byType(Scrollable).first);await tester.enterText(find.byType(TextFormField),'0');
  await tester.scrollUntilVisible(find.text('Calcular'),100,scrollable:find.byType(Scrollable).first);await tester.tap(find.text('Calcular'));await tester.pump();
  await tester.scrollUntilVisible(find.text('Resultado'),100,scrollable:find.byType(Scrollable).first);expect(find.text('Sin dolor referido.'),findsOneWidget);
  await tester.scrollUntilVisible(find.byType(TextFormField),-100,scrollable:find.byType(Scrollable).first);await tester.enterText(find.byType(TextFormField),'3');await tester.pump();expect(find.text('Resultado'),findsNothing);
  expect(tester.takeException(),isNull);
 });
 for(final id in ['sofa','phq9','gad7']){
 for(final brightness in Brightness.values){
  testWidgets('Long scale criteria readable in narrow large-text $id $brightness',(tester)async{
   tester.view.physicalSize=const Size(320,750);tester.view.devicePixelRatio=1;addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
   await tester.pumpWidget(MaterialApp(theme:clinicalTheme(brightness),builder:(ctx,child)=>MediaQuery(data:MediaQuery.of(ctx).copyWith(textScaler:const TextScaler.linear(1.5)),child:child!),home:ScaleAssessment(tool:tools.singleWhere((t)=>t.id==id))));
   await tester.scrollUntilVisible(find.text('Calcular'),200,scrollable:find.byType(Scrollable).first);await tester.pump();expect(tester.takeException(),isNull);
  });
 }
 }
}
