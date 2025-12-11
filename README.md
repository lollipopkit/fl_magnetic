English | [中文](README_zh.md)

# Magnetic

A Flutter UI component inspired by the iOS SpriteKit library **Magnetic**: a floating “bubble picker” with physics, selection, and customization.

## Features

- Bubbles float, collide, bounce, and gently attract to center.
- Drag individual items and drag the background (pan all bubbles with inertia).
- Tap to select/deselect, with single or multiple selection.
- Per-node customization: text, image, colors, border, radius, scale, spacing, etc.
- Custom `Path` shaped bubbles (hit-test by path; collisions/spacing approximated by convex hull).
- Optional long-press to remove nodes (with animation).

## Getting started

```yaml
dependencies:
  magnetic:
    path: ../magnetic.dart
```

## Usage

```dart
import 'package:flutter/material.dart';
import 'package:magnetic/magnetic.dart';

class Demo extends StatefulWidget {
  const Demo({super.key});
  @override
  State<Demo> createState() => _DemoState();
}

class _DemoState extends State<Demo> {
  late final MagneticController controller = MagneticController(nodes: [
    MagneticNode(id: '0', text: 'Rock'),
    MagneticNode(id: '1', text: 'Jazz'),
    MagneticNode(id: '2', text: 'Hip Hop'),
    MagneticNode(id: '3', text: 'Classical'),
  ]);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: MagneticView(
          controller: controller,
          allowsMultipleSelection: true,
          enableItemDrag: true,
          enableBackgroundDrag: true,
          enableLongPressToRemove: true,
          // Global spacing multiplier (collision radius multiplier).
          spacingScale: 1.2,
          onSelect: (n) => debugPrint('selected: ${n.text}'),
          onDeselect: (n) => debugPrint('deselected: ${n.text}'),
          onRemove: (n) => debugPrint('removed: ${n.text}'),
          defaultStyle: const MagneticNodeStyle(
            radius: 44,
            color: Color(0xFFECEFF1),
            selectedColor: Color(0xFF42A5F5),
            // Per-node spacing multiplier (multiplies with spacingScale).
            marginScale: 1.3,
          ),
        ),
      ),
    );
  }
}
```

## API overview

- `MagneticView`: the scene widget (physics + gestures).
- `MagneticController`: manages nodes and selection (supports dynamic add/remove and `resetSelection`).
- `MagneticController.selectedNodes`: selected nodes in `nodes` order.
- `MagneticNode`: node model (text/image/style/etc).
  - `path` (optional): custom non-circular shape.
  - `behavior` (optional): custom render/hit-test/physics (similar to subclassing `Node` on iOS).
- `LabelNode` / `ImageNode`: convenience node types; also `MagneticNode.label(...)` / `MagneticNode.image(...)` factories.
- `MagneticNodeStyle`: visual style.
  - `marginScale`: per-node collision/spacing multiplier.
  - `textMaxLines` / `minFontSize`: default label multiline + adaptive font size.
- `MagneticView.spacingScale`: global spacing multiplier (multiplies with `marginScale`).
- `MagneticView.animationBuilder`: select/deselect/remove animation hook.

### Custom shape example

```dart
Path starPath(int points) {
  final path = Path();
  const outerR = 100.0;
  const innerR = 45.0;
  final step = pi / points;
  for (var i = 0; i < points * 2; i++) {
    final r = i.isEven ? outerR : innerR;
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

final node = MagneticNode(
  text: 'Star',
  path: starPath(5),
  style: const MagneticNodeStyle(radius: 46),
);
```

`path` is automatically scaled and centered to the bubble size (driven by `radius`).

### Custom node behavior example

```dart
class HexagonBehavior extends MagneticNodeBehavior {
  const HexagonBehavior();

  Path _hexPath(Size size) {
    final w = size.width, h = size.height;
    return Path()
      ..moveTo(w * 0.5, 0)
      ..lineTo(w, h * 0.25)
      ..lineTo(w, h * 0.75)
      ..lineTo(w * 0.5, h)
      ..lineTo(0, h * 0.75)
      ..lineTo(0, h * 0.25)
      ..close();
  }

  @override
  Widget build(context, node, selected, style, anySelected) {
    final bg = selected ? style.selectedColor : style.color;
    final fg = selected ? style.selectedTextColor : style.textColor;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final hex = _hexPath(size);
        return CustomPaint(
          painter: _HexPainter(hex, bg, style.strokeColor, style.strokeWidth),
          child: Center(
            child: Text(node.text, style: TextStyle(color: fg)),
          ),
        );
      },
    );
  }

  @override
  double collisionRadiusMultiplier(node, selected, style) => 1.15;

  @override
  bool hitTest(node, local, size, selected, style) {
    return _hexPath(size).contains(local);
  }
}

class _HexPainter extends CustomPainter {
  final Path path;
  final Color fill, stroke;
  final double strokeWidth;
  _HexPainter(this.path, this.fill, this.stroke, this.strokeWidth);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(path, Paint()..color = fill);
    if (strokeWidth > 0) {
      canvas.drawPath(
        path,
        Paint()
          ..color = stroke
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _HexPainter old) =>
      old.path != path || old.fill != fill || old.stroke != stroke;
}

final node = MagneticNode(
  text: 'Hex',
  behavior: const HexagonBehavior(),
);
```

In this example, `behavior.build/hitTest/collisionRadiusMultiplier` control the node UI, hit region, and collision spacing.

### Custom animation example

```dart
MagneticView(
  controller: controller,
  animationBuilder: (context, node, type, selected, animation, child) {
    switch (type) {
      case MagneticNodeAnimationType.select:
        return ScaleTransition(
          scale: Tween(begin: 1.0, end: 1.35).animate(
            CurvedAnimation(parent: animation, curve: Curves.elasticOut),
          ),
          child: child,
        );
      case MagneticNodeAnimationType.deselect:
        return FadeTransition(
          opacity: Tween(begin: 1.0, end: 0.6).animate(animation),
          child: child,
        );
      case MagneticNodeAnimationType.remove:
        return ScaleTransition(
          scale: Tween(begin: 1.0, end: 0.0).animate(animation),
          child: child,
        );
    }
  },
)
```
