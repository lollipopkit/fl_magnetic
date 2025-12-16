/// A Flutter library for creating magnetic, physics-based bubble UIs.
///
/// This library provides widgets and utilities for creating interactive
/// bubble/magnetic interfaces similar to Apple's Magnetic UI patterns.
/// Bubbles are attracted to the center and collide with each other
/// using physics simulation.
///
/// Key features:
/// - Physics-based bubble movement with collision detection
/// - Customizable node styles and behaviors
/// - Support for text and image bubbles
/// - Selection and interaction handling
/// - Flexible physics configuration
///
/// Example usage:
/// ```dart
/// MagneticView(
///   nodes: [
///     MagneticNode.label(text: 'Hello'),
///     MagneticNode.image(image: AssetImage('asset.png'), text: 'World'),
///   ],
///   onSelect: (node) => print('Selected: ${node.text}'),
/// )
/// ```
library;

export 'src/magnetic_controller.dart';
export 'src/magnetic_view.dart';
export 'src/magnetic_node_style.dart';
export 'src/physics.dart';
