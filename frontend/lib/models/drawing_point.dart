import 'package:flutter/material.dart';

class DrawingPoint {
  final Offset offset;
  final Paint paint;

  DrawingPoint({
    required this.offset,
    required this.paint,
  });
}

class Stroke {
  final List<DrawingPoint> points;
  final Color color;
  final double strokeWidth;
  final bool isEraser;

  Stroke({
    required this.points,
    required this.color,
    required this.strokeWidth,
    this.isEraser = false,
  });
}
