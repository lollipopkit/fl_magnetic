import 'dart:math';

import 'package:flutter/material.dart';
import 'package:fl_magnetic/fl_magnetic.dart';

void main() {
  runApp(const MagneticExampleApp());
}

Path starPath({
  int points = 5,
  double outerRadius = 100,
  double innerRadius = 45,
}) {
  final path = Path();
  final step = pi / points;
  for (var i = 0; i < points * 2; i++) {
    final r = i.isEven ? outerRadius : innerRadius;
    final a = -pi / 2 + step * i;
    final p = Offset(cos(a) * r, sin(a) * r);
    if (i == 0) {
      path.moveTo(p.dx, p.dy);
    } else {
      path.lineTo(p.dx, p.dy);
    }
  }
  path.close();
  return path;
}

Path pillPath({
  double width = 220,
  double height = 120,
}) {
  final rect =
      Rect.fromCenter(center: Offset.zero, width: width, height: height);
  return Path()
    ..addRRect(RRect.fromRectXY(rect, height / 2, height / 2));
}

class MagneticExampleApp extends StatelessWidget {
  const MagneticExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Magnetic Example',
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const MagneticExamplePage(),
    );
  }
}

class MagneticExamplePage extends StatefulWidget {
  const MagneticExamplePage({super.key});

  @override
  State<MagneticExamplePage> createState() => _MagneticExamplePageState();
}

class _MagneticExamplePageState extends State<MagneticExamplePage> {
  late final MagneticController controller = MagneticController(nodes: [
    MagneticNode(id: '0', text: 'Rock'),
    MagneticNode(id: '1', text: 'Jazz'),
    MagneticNode(id: '2', text: 'Hip Hop / Alternative / Indie'),
    MagneticNode(id: '3', text: 'Classical'),
    MagneticNode(id: '4', text: 'Pop'),
    MagneticNode(id: '5', text: 'EDM'),
    MagneticNode(
      id: 'star',
      text: 'Star',
      path: starPath(points: 5),
      style: MagneticNodeStyle(
        radius: 46,
        color: Colors.amber.shade100,
        selectedColor: Colors.amber.shade400,
      ),
    ),
    MagneticNode(
      id: 'pill',
      text: 'Pill',
      path: pillPath(),
      style: MagneticNodeStyle(
        radius: 52,
        color: Colors.pink.shade50,
        selectedColor: Colors.pink.shade300,
      ),
    ),
  ]);

  final Random _rng = Random();
  int _counter = 6;
  double _spacingScale = 1.1;

  void _addRandomNode() {
    final id = (_counter++).toString();
    controller.addNode(
      MagneticNode(
        id: id,
        text: 'New $id',
        style: MagneticNodeStyle(
          color: Colors.grey.shade200,
          selectedColor: Colors.primaries[_rng.nextInt(Colors.primaries.length)],
          radius: 36 + _rng.nextDouble() * 14,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Magnetic Example'),
        actions: [
          IconButton(
            tooltip: 'Reset selection',
            onPressed: controller.resetSelection,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Add node',
            onPressed: _addRandomNode,
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Clear nodes',
            onPressed: controller.clearNodes,
            icon: const Icon(Icons.delete_sweep),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Text('Spacing'),
                  Expanded(
                    child: Slider(
                      min: 0.8,
                      max: 1.8,
                      value: _spacingScale,
                      onChanged: (v) => setState(() => _spacingScale = v),
                    ),
                  ),
                  SizedBox(
                    width: 48,
                    child: Text(_spacingScale.toStringAsFixed(2)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                color: Colors.black12,
                child: MagneticView(
                  controller: controller,
                  allowsMultipleSelection: true,
                  enableLongPressToRemove: true,
                  spacingScale: _spacingScale,
                  defaultStyle: const MagneticNodeStyle(
                    radius: 44,
                    color: Color(0xFFECEFF1),
                    selectedColor: Color(0xFF42A5F5),
                    strokeColor: Color(0xFFB0BEC5),
                    marginScale: 1.3,
                  ),
                  onSelect: (n) => debugPrint('selected: ${n.text}'),
                  onDeselect: (n) => debugPrint('deselected: ${n.text}'),
                  onRemove: (n) => debugPrint('removed: ${n.text}'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
