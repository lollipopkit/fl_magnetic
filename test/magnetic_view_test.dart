import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fl_magnetic/fl_magnetic.dart';

void main() {
  testWidgets('MagneticView builds with Path nodes', (tester) async {
    final square = Path()
      ..addRect(const Rect.fromLTWH(-50, -50, 100, 100));
    final controller = MagneticController(nodes: [
      MagneticNode(id: 's', text: 'Square', path: square),
    ]);

    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox(
          width: 240,
          height: 240,
          child: MagneticView(controller: controller),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 50));
    expect(find.text('Square'), findsOneWidget);
  });
}

