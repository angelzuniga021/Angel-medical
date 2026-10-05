import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/main.dart';

void main() {
  testWidgets('Desktop explains encryption and read-only scope', (tester) async {
    await tester.pumpWidget(const AngelPc());
    expect(find.text('Abrir expediente cifrado'), findsOneWidget);
    expect(find.textContaining('No se guarda una copia descifrada'), findsOneWidget);
    expect(find.text('Ángel Medical PC · 0.1 · Consulta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('Opening page works at narrow width and enlarged text', (tester) async {
    tester.view.physicalSize = const Size(680, 900); tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(builder: (ctx, child) => MediaQuery(data: MediaQuery.of(ctx).copyWith(textScaler: const TextScaler.linear(1.3)), child: child!), home: const DesktopHome()));
    expect(tester.takeException(), isNull);
  });
}
