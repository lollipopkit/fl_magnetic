import 'package:flutter/material.dart';

@immutable
class MagneticNodeStyle {
  final Color color;
  final Color selectedColor;
  final Color strokeColor;
  final double strokeWidth;
  final Color textColor;
  final Color selectedTextColor;
  final double fontSize;
  final double minFontSize;
  final int textMaxLines;
  final double radius;
  final double marginScale;
  final double scale;
  final double selectedScale;
  final double deselectedScale;
  final Duration animationDuration;

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
