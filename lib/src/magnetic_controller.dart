import 'dart:collection';

import 'package:flutter/widgets.dart';

import 'magnetic_node_style.dart';

@immutable
class MagneticNode {
  static int _idCounter = 0;

  final String id;
  final String text;
  final ImageProvider? image;
  /// Optional custom shape for this node.
  ///
  /// If provided, the path is scaled and centered to fit the node's visual size
  /// (based on [MagneticNodeStyle.radius]). Hit-testing uses this path.
  final Path? path;
  /// Optional behavior object to customize rendering, hit-testing, and physics.
  ///
  /// This is the Flutter equivalent of subclassing `Node` in iOS Magnetic.
  final MagneticNodeBehavior? behavior;
  final MagneticNodeStyle? style;
  final String? semanticsLabel;

  MagneticNode({
    String? id,
    required this.text,
    this.image,
    this.path,
    this.behavior,
    this.style,
    this.semanticsLabel,
  }) : id = id ?? 'magnetic_node_${_idCounter++}';

  /// Convenience constructor for a text-only node (iOS Magnetic: `Node` with label).
  factory MagneticNode.label({
    String? id,
    required String text,
    MagneticNodeStyle? style,
    String? semanticsLabel,
    MagneticNodeBehavior? behavior,
    Path? path,
  }) {
    return MagneticNode(
      id: id,
      text: text,
      style: style,
      semanticsLabel: semanticsLabel,
      behavior: behavior,
      path: path,
    );
  }

  /// Convenience constructor for an image node (iOS Magnetic: `ImageNode`).
  factory MagneticNode.image({
    String? id,
    required ImageProvider image,
    String text = '',
    MagneticNodeStyle? style,
    String? semanticsLabel,
    MagneticNodeBehavior? behavior,
    Path? path,
  }) {
    return MagneticNode(
      id: id,
      text: text,
      image: image,
      style: style,
      semanticsLabel: semanticsLabel,
      behavior: behavior,
      path: path,
    );
  }

  MagneticNode copyWith({
    String? id,
    String? text,
    ImageProvider? image,
    Path? path,
    MagneticNodeBehavior? behavior,
    MagneticNodeStyle? style,
    String? semanticsLabel,
  }) {
    return MagneticNode(
      id: id ?? this.id,
      text: text ?? this.text,
      image: image ?? this.image,
      path: path ?? this.path,
      behavior: behavior ?? this.behavior,
      style: style ?? this.style,
      semanticsLabel: semanticsLabel ?? this.semanticsLabel,
    );
  }
}

/// Text-only convenience node type.
class LabelNode extends MagneticNode {
  LabelNode({
    super.id,
    required super.text,
    super.style,
    super.semanticsLabel,
    super.behavior,
    super.path,
  }) : super(image: null);
}

/// Image convenience node type.
class ImageNode extends MagneticNode {
  ImageNode({
    super.id,
    required super.image,
    super.text = '',
    super.style,
    super.semanticsLabel,
    super.behavior,
    super.path,
  });
}

@immutable
abstract class MagneticNodeBehavior {
  const MagneticNodeBehavior();

  /// Build a custom widget for this node. Return null to use defaults.
  Widget? build(
    BuildContext context,
    MagneticNode node,
    bool selected,
    MagneticNodeStyle style,
    bool anySelected,
  ) =>
      null;

  /// Custom hit-test. Return null to fall back to default hit-testing.
  ///
  /// [localPosition] is relative to the node's visual box (0..size).
  bool? hitTest(
    MagneticNode node,
    Offset localPosition,
    Size size,
    bool selected,
    MagneticNodeStyle style,
  ) =>
      null;

  /// Optional multiplier to adjust collision radius for this node.
  double? collisionRadiusMultiplier(
    MagneticNode node,
    bool selected,
    MagneticNodeStyle style,
  ) =>
      null;

  /// Optional convex hull points for physics collisions.
  ///
  /// Points should be in unit space centered at origin, e.g. a visual box of
  /// size 1x1 maps to coordinates in roughly [-0.5, 0.5]. If null, collisions
  /// fall back to circle (or path-based hull if [MagneticNode.path] is set).
  List<Offset>? convexHull(
    MagneticNode node,
    bool selected,
    MagneticNodeStyle style,
  ) =>
      null;
}

class MagneticController extends ChangeNotifier {
  final List<MagneticNode> _nodes;
  final Set<String> _selectedIds = <String>{};

  MagneticController({
    List<MagneticNode>? nodes,
    Set<String>? selectedIds,
  }) : _nodes = List<MagneticNode>.from(nodes ?? const <MagneticNode>[]) {
    if (selectedIds != null) {
      _selectedIds.addAll(selectedIds);
    }
  }

  UnmodifiableListView<MagneticNode> get nodes =>
      UnmodifiableListView<MagneticNode>(_nodes);

  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);

  UnmodifiableListView<MagneticNode> get selectedNodes =>
      UnmodifiableListView<MagneticNode>(
        _nodes.where((n) => _selectedIds.contains(n.id)).toList(growable: false),
      );

  bool isSelected(String id) => _selectedIds.contains(id);

  void setNodes(List<MagneticNode> nodes) {
    _nodes
      ..clear()
      ..addAll(nodes);
    _selectedIds.removeWhere(
      (id) => !_nodes.any((n) => n.id == id),
    );
    notifyListeners();
  }

  void addNode(MagneticNode node) {
    _nodes.add(node);
    notifyListeners();
  }

  void removeNode(String id) {
    _nodes.removeWhere((n) => n.id == id);
    _selectedIds.remove(id);
    notifyListeners();
  }

  void clearNodes() {
    _nodes.clear();
    _selectedIds.clear();
    notifyListeners();
  }

  void setSelectedIds(Set<String> ids) {
    _selectedIds
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  void resetSelection() {
    _selectedIds.clear();
    notifyListeners();
  }
}
