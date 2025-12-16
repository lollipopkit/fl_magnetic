中文 | [English](README.md)

# Magnetic

仿照 iOS SpriteKit 库 **Magnetic** 的“漂浮气泡选择器”效果实现的 Flutter UI 组件。

[演示视频](https://cdn.lpkt.cn/misc/video/fl_magnetic.webm)

## 特性

- 气泡自动漂浮、碰撞、回弹并向中心轻微吸附。
- 支持拖动单个气泡与拖动背景（平移所有气泡并可甩出惯性）。
- 点击气泡选择 / 取消选择，支持单选或多选。
- 每个气泡可自定义文字、图片、颜色、边框、半径、缩放、气泡间距等。
- 支持自定义 `Path` 形状气泡（命中检测按 Path；碰撞/间距按凸包近似）。
- 可选长按删除气泡（带缩小动画）。

## 快速开始

```yaml
dependencies:
  magnetic:
    path: ../magnetic.dart
```

## 用法

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
          // 全局气泡间距（碰撞半径倍率）
          spacingScale: 1.2,
          onSelect: (n) => debugPrint('selected: ${n.text}'),
          onDeselect: (n) => debugPrint('deselected: ${n.text}'),
          onRemove: (n) => debugPrint('removed: ${n.text}'),
          defaultStyle: const MagneticNodeStyle(
            radius: 44,
            color: Color(0xFFECEFF1),
            selectedColor: Color(0xFF42A5F5),
            // 单个气泡的间距倍率（与 spacingScale 相乘）
            marginScale: 1.3,
          ),
        ),
      ),
    );
  }
}
```

## API 概览

- `MagneticView`：容器/场景，负责物理模拟和交互。
- `MagneticController`：管理节点列表与选中状态（支持动态增删、resetSelection）。
- `MagneticController.selectedNodes`：按 nodes 顺序返回已选中节点列表。
- `MagneticNode`：气泡数据模型（text/image/style 等）。
  - `path` 可选，用于非圆形自定义形状。
  - `behavior` 可选，用于自定义渲染/命中/物理（等价于 iOS 的 Node 子类化）。
- `LabelNode` / `ImageNode`：快捷节点类型；也可用 `MagneticNode.label(...)` / `MagneticNode.image(...)` 工厂快速创建。
- `MagneticNodeStyle`：气泡外观参数。
  - `marginScale` 影响单个气泡的碰撞/间距倍率。
  - `textMaxLines/minFontSize` 影响默认文字的多行与自适应缩放。
- `MagneticView.spacingScale`：全局间距倍率（与每个节点 marginScale 相乘）。
- `MagneticView.animationBuilder`：选中/取消/移除动画 hook。

### 自定义形状示例

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

`path` 会被自动缩放/居中到气泡尺寸（由 `radius` 决定）。

### 自定义节点行为示例

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

上面示例里 `behavior.build/hitTest/collisionRadiusMultiplier` 分别对应自定义外观、命中区域和碰撞间距。

### 自定义动画示例

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

