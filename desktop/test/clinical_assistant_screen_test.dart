import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/clinical_assistant_screen.dart';

void main(){
  testWidgets('Manual capture requires field selection and review before applying', (tester)async{
    tester.view.physicalSize=const Size(1200,2400);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home:ClinicalAssistantScreen(patient:const {'id':1},current:const {'illness':''},table:'consultations',encounter:'2026-10-19T12:00:00',recentConsultations:const [])));
    await tester.enterText(find.byType(TextField).first,'Niega fiebre. Tos de tres días.');
    await tester.tap(find.text('Usar texto sin IA'));await tester.pumpAndSettle();
    await tester.tap(find.text('Padecimiento actual').last);await tester.pumpAndSettle();
    final apply=find.widgetWithText(FilledButton,'Aplicar al borrador');
    expect(tester.widget<FilledButton>(apply).onPressed,isNull);
    final selection=find.widgetWithText(CheckboxListTile,'Padecimiento actual');
    await tester.ensureVisible(selection);await tester.tap(selection);await tester.pump();
    expect(tester.widget<FilledButton>(apply).onPressed,isNull);
    final review=find.text('Revisé el contenido y confirmo que corresponde a esta atención.');
    await tester.ensureVisible(review);await tester.tap(review);await tester.pump();
    expect(tester.widget<FilledButton>(apply).onPressed,isNotNull);
    await tester.enterText(find.byType(TextField).last,'Texto corregido');await tester.pump();
    expect(tester.widget<FilledButton>(apply).onPressed,isNull);
  });
}
