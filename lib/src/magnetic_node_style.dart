import 'package:flutter/material.dart';

/// Style configuration for magnetic nodes.
///
/// Defines the visual appearance of nodes including colors, sizes,
/// text properties, and animation settings. Nodes can use individual
/// style overrides or inherit from a default style.
@immutable
class MagneticNodeStyle {
  /// Background color of unselected nodes.
  final Color color;

  /// Background color of selected nodes.
  final Color selectedColor;

  /// Color of the node border/stroke.
  final Color strokeColor;

  /// Width of the node border/stroke.
  final double strokeWidth;

  /// Text color for unselected nodes.
  final Color textColor;

  /// Text color for selected nodes.
  final Color selectedTextColor;

  /// Maximum font size for node text.
  final double fontSize;

  /// Minimum font size for adaptive text sizing.
  final double minFontSize;

  /// Maximum number of lines for text display.
  final int textMaxLines;

  /// Base radius of the node (used for circular nodes).
  final double radius;

  /// Scale factor for collision margins (spacing between nodes).
  final double marginScale;

  /// Scale factor for normal (unselected) nodes.
  final double scale;

  /// Scale factor for selected nodes.
  final double selectedScale;

  /// Scale factor for deselected nodes (when others are selected).
  final double deselectedScale;

  /// Duration for scale animations.
  final Duration animationDuration;

  /// Creates a new magnetic node style.
  ///
  /// The default values provide a clean, Material Design-inspired appearance.
  const MagneticNodeStyle({
    this.color = const Color(0xFFE0E0E0),
    this.selectedColor = const Color(0xFF2196F3),
    this.strokeColor = const Color(0xFFBDBDBD),
    this.strokeWidth = 2.0,
    this.textColor = Colors.black,
    this.selectedTextColor = Colors.white,
    this.fontSize = 14.0,
    this.minFontSize = 10.0,
    this.textMaxLines = 3,
    this.radius = 40.0,
    this.marginScale = 1.3,
    this.scale = 1.0,
    this.selectedScale = 1.2,
    this.deselectedScale = 0.85,
    this.animationDuration = const Duration(milliseconds: 250),
  });

  /// Creates a copy of this style with the given fields replaced.
  ///
  /// Any parameter that is not provided will keep its current value.
  MagneticNodeStyle copyWith({
    Color? color,
    Color? selectedColor,
    Color? strokeColor,
    double? strokeWidth,
    Color? textColor,
    Color? selectedTextColor,
    double? fontSize,
    double? minFontSize,
    int? textMaxLines,
    double? radius,
    double? marginScale,
    double? scale,
    double? selectedScale,
    double? deselectedScale,
    Duration? animationDuration,
  }) {
    return MagneticNodeStyle(
      color: color ?? this.color,
      selectedColor: selectedColor ?? this.selectedColor,
      strokeColor: strokeColor ?? this.strokeColor,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      textColor: textColor ?? this.textColor,
      selectedTextColor: selectedTextColor ?? this.selectedTextColor,
      fontSize: fontSize ?? this.fontSize,
      minFontSize: minFontSize ?? this.minFontSize,
      textMaxLines: textMaxLines ?? this.textMaxLines,
      radius: radius ?? this.radius,
      marginScale: marginScale ?? this.marginScale,
      scale: scale ?? this.scale,
      selectedScale: selectedScale ?? this.selectedScale,
      deselectedScale: deselectedScale ?? this.deselectedScale,
      animationDuration: animationDuration ?? this.animationDuration,
    );
  }
}
