import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silicon_simulator/main.dart';

void main() {
  testWidgets('workbench shows the default simulator shell', (tester) async {
    _setDesktopSurface(tester);
    await tester.pumpWidget(const SiliconSimulatorApp());

    expect(find.text('Silicon Simulator'), findsOneWidget);
    expect(find.text('Project Controls'), findsOneWidget);
    expect(find.text('Assembly'), findsOneWidget);
    expect(find.text('Machine Setup'), findsOneWidget);
    expect(find.text('Machine State'), findsOneWidget);
    expect(
      find.text('Phase 1 RV64I backend + Phase 1.5 workbench'),
      findsOneWidget,
    );
  });

  testWidgets('step executes one instruction and updates registers', (
    tester,
  ) async {
    _setDesktopSurface(tester);
    await tester.pumpWidget(const SiliconSimulatorApp());

    await tester.tap(find.widgetWithText(FilledButton, 'Step'));
    await tester.pump();

    expect(find.textContaining('Executed addi'), findsOneWidget);
    expect(find.text('0x0000000000000005'), findsOneWidget);
  });
}

void _setDesktopSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}
