import 'dart:collection';

import 'package:flutter/widgets.dart';

import 'magnetic_node_style.dart';

/// Represents a single node in the magnetic view.
///
/// A node can contain text, an image, or both, along with optional
/// custom styling and behavior. Nodes are attracted to the center
/// of the view and collide with each other using physics simulation.
@immutable
class MagneticNode {
  static int _idCounter = 0;

  /// Unique identifier for this node.
  final String id;

  /// Text label displayed on the node.
  final String text;

  /// Optional image to display on the node.
  final ImageProvider? image;

  /// Optional custom shape for this node.
  ///
  /// If provided, the path is scaled and centered to fit the node's visual size
  /// (based on [MagneticNodeStyle.radius]). Hit-testing uses this path.
  final Path? path;

  /// Optional behavior object to customize rendering, hit-testing, and physics.
  final MagneticNodeBehavior? behavior;

  /// Optional style overrides for this node.
  final MagneticNodeStyle? style;

  /// Optional semantic label for accessibility.
  final String? semanticsLabel;

  /// Creates a new magnetic node.
  ///
  /// [id] - Optional unique identifier (auto-generated if not provided)
  /// [text] - Text label to display
  /// [image] - Optional image to display
  /// [path] - Optional custom shape path
  /// [behavior] - Optional custom behavior
  /// [style] - Optional style overrides
  /// [semanticsLabel] - Optional accessibility label
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
  ///
  /// Creates a node that displays only text without an image.
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
  ///
  /// Creates a node that displays an image, optionally with text.
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

  /// Creates a copy of this node with the given fields replaced.
  ///
  /// Any parameter that is not provided will keep its current value.
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
///
/// A specialized [MagneticNode] that only displays text without an image.
/// This is a convenience class that extends [MagneticNode] with the image
/// field fixed to null.
class LabelNode extends MagneticNode {
  /// Creates a text-only node.
  ///
  /// All parameters are passed through to the superclass constructor
  /// with [image] fixed to null.
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
///
/// A specialized [MagneticNode] that requires an image and optionally
/// displays text. This is a convenience class that extends [MagneticNode]
/// with the image field as required.
class ImageNode extends MagneticNode {
  /// Creates an image node.
  ///
  /// [image] is required and will be displayed on the node.
  /// [text] defaults to an empty string if not provided.
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

/// Abstract class for customizing node behavior.
///
/// This class allows customization of node rendering, hit-testing, and physics
/// interactions. It's the Flutter equivalent of subclassing `Node` in iOS Magnetic.
///
/// Implement this class to:
/// - Provide custom widget rendering for nodes
/// - Customize hit-testing behavior
/// - Adjust collision radius for physics
/// - Define custom convex hull shapes for collisions
@immutable
abstract class MagneticNodeBehavior {
  /// Creates a new node behavior.
  const MagneticNodeBehavior();

  /// Build a custom widget for this node. Return null to use defaults.
  ///
  /// Parameters:
  /// - [context] - The build context
  /// - [node] - The node being rendered
  /// - [selected] - Whether the node is currently selected
  /// - [style] - The style to apply to the node
  /// - [anySelected] - Whether any nodes in the view are selected
  Widget? build(
    BuildContext context,
    MagneticNode node,
    bool selected,
    MagneticNodeStyle style,
    bool anySelected,
  ) => null;

  /// Custom hit-test. Return null to fall back to default hit-testing.
  ///
  /// Parameters:
  /// - [node] - The node to test
  /// - [localPosition] - Position relative to the node's visual box (0..size)
  /// - [size] - The visual size of the node
  /// - [selected] - Whether the node is currently selected
  /// - [style] - The style applied to the node
  ///
  /// Return true if the position hits the node, false if it doesn't,
  /// or null to use the default hit-testing logic.
  bool? hitTest(
    MagneticNode node,
    Offset localPosition,
    Size size,
    bool selected,
    MagneticNodeStyle style,
  ) => null;

  /// Optional multiplier to adjust collision radius for this node.
  ///
  /// Return a multiplier value > 0 to scale the collision radius,
  /// or null to use the default radius calculation.
  double? collisionRadiusMultiplier(
    MagneticNode node,
    bool selected,
    MagneticNodeStyle style,
  ) => null;

  /// Optional convex hull points for physics collisions.
  ///
  /// Points should be in unit space centered at origin, e.g. a visual box of
  /// size 1x1 maps to coordinates in roughly [-0.5, 0.5]. If null, collisions
  /// fall back to circle (or path-based hull if [MagneticNode.path] is set).
  ///
  /// Return a list of points defining the convex hull shape,
  /// or null to use the default collision shape.
  List<Offset>? convexHull(
    MagneticNode node,
    bool selected,
    MagneticNodeStyle style,
  ) => null;
}

/// Controller for managing a collection of magnetic nodes.
///
/// This controller maintains the state of magnetic nodes including their
/// selection state and provides methods to modify the node collection.
/// It extends [ChangeNotifier] to notify listeners when the state changes.
///
/// Typical usage:
/// ```dart
/// final controller = MagneticController(
///   nodes: [MagneticNode.label(text: 'Hello')],
/// );
///
/// // Add a node
/// controller.addNode(MagneticNode.label(text: 'World'));
///
/// // Listen for changes
/// controller.addListener(() {
///   print('Nodes updated: ${controller.nodes.length}');
/// });
/// ```
class MagneticController extends ChangeNotifier {
  final List<MagneticNode> _nodes;
  final Set<String> _selectedIds = <String>{};

  /// Creates a new magnetic controller.
  ///
  /// [nodes] - Initial list of magnetic nodes
  /// [selectedIds] - Initial set of selected node IDs
  MagneticController({List<MagneticNode>? nodes, Set<String>? selectedIds})
    : _nodes = List<MagneticNode>.from(nodes ?? const <MagneticNode>[]) {
    if (selectedIds != null) {
      _selectedIds.addAll(selectedIds);
    }
  }

  /// Returns an unmodifiable list of all magnetic nodes.
  UnmodifiableListView<MagneticNode> get nodes =>
      UnmodifiableListView<MagneticNode>(_nodes);

  /// Returns an unmodifiable set of selected node IDs.
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);

  /// Returns an unmodifiable list of currently selected nodes.
  UnmodifiableListView<MagneticNode> get selectedNodes =>
      UnmodifiableListView<MagneticNode>(
        _nodes
            .where((n) => _selectedIds.contains(n.id))
            .toList(growable: false),
      );

  /// Checks if a node with the given ID is selected.
  bool isSelected(String id) => _selectedIds.contains(id);

  /// Replaces all nodes with a new list.
  ///
  /// Any selected IDs that don't exist in the new node list will be removed.
  void setNodes(List<MagneticNode> nodes) {
    _nodes
      ..clear()
      ..addAll(nodes);
    _selectedIds.removeWhere((id) => !_nodes.any((n) => n.id == id));
    notifyListeners();
  }

  /// Adds a new node to the collection.
  void addNode(MagneticNode node) {
    _nodes.add(node);
    notifyListeners();
  }

  /// Removes a node by its ID.
  ///
  /// If the node is selected, it will also be removed from the selection.
  void removeNode(String id) {
    _nodes.removeWhere((n) => n.id == id);
    _selectedIds.remove(id);
    notifyListeners();
  }

  /// Removes all nodes and clears the selection.
  void clearNodes() {
    _nodes.clear();
    _selectedIds.clear();
    notifyListeners();
  }

  /// Sets the selection to exactly the provided set of node IDs.
  void setSelectedIds(Set<String> ids) {
    _selectedIds
      ..clear()
      ..addAll(ids);
    notifyListeners();
  }

  /// Clears the selection, deselecting all nodes.
  void resetSelection() {
    _selectedIds.clear();
    notifyListeners();
  }
}
