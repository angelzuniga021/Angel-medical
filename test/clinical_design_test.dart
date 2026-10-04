import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/clinical_theme.dart';
import '../lib/clinical_cie_screen.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('Catalog fits narrow screen with large text ($brightness)', (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(theme: clinicalTheme(brightness), home: const ClinicalCieScreen(), builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.5)), child: child!)));
      await tester.pump();
      await tester.scrollUntilVisible(find.text('Busca por nombre o código'), 200, scrollable: find.byType(Scrollable).last);
      expect(find.text('Busca por nombre o código'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
