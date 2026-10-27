import 'package:flutter/material.dart';
import '../models/drawing_point.dart';

enum CanvasGridType { blank, dots, grid }

class InteractiveCanvas extends StatefulWidget {
  final List<Stroke> strokes;
  final Stroke? currentStroke;
  final CanvasGridType gridType;
  final Function(DrawingPoint) onPanStart;
  final Function(DrawingPoint) onPanUpdate;
  final Function() onPanEnd;

  const InteractiveCanvas({
    super.key,
    required this.strokes,
    required this.currentStroke,
    required this.gridType,
    required this.onPanStart,
    required this.onPanUpdate,
    required this.onPanEnd,
  });

  @override
  State<InteractiveCanvas> createState() => _InteractiveCanvasState();
}

class _InteractiveCanvasState extends State<InteractiveCanvas> {
  final List<Offset> _touchIndicators = [];

  void _addTouchIndicator(Offset point) {
    setState(() {
      _touchIndicators.add(point);
      if (_touchIndicators.length > 5) {
        _touchIndicators.removeAt(0);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (details) {
        _addTouchIndicator(details.localPosition);
        widget.onPanStart(
          DrawingPoint(
            offset: details.localPosition,
            paint: Paint(),
          ),
        );
      },
      onPanUpdate: (details) {
        widget.onPanUpdate(
          DrawingPoint(
            offset: details.localPosition,
            paint: Paint(),
          ),
        );
      },
      onPanEnd: (details) {
        widget.onPanEnd();
      },
      onTapDown: (details) {
        _addTouchIndicator(details.localPosition);
        widget.onPanStart(
          DrawingPoint(
            offset: details.localPosition,
            paint: Paint(),
          ),
        );
        widget.onPanEnd();
      },
      child: Stack(
        children: [
          CustomPaint(
            size: Size.infinite,
            painter: CanvasPainter(
              strokes: widget.strokes,
              currentStroke: widget.currentStroke,
              gridType: widget.gridType,
            ),
          ),
          // Live touch feedback indicators
          ..._touchIndicators.map(
            (point) => Positioned(
              left: point.dx - 12,
              top: point.dy - 12,
              child: IgnorePointer(
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 1.0, end: 0.0),
                  duration: const Duration(milliseconds: 400),
                  builder: (context, opacity, child) {
                    return Opacity(
                      opacity: opacity,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.orange.withValues(alpha: 0.4),
                          border: Border.all(color: Colors.orange, width: 2),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CanvasPainter extends CustomPainter {
  final List<Stroke> strokes;
  final Stroke? currentStroke;
  final CanvasGridType gridType;

  CanvasPainter({
    required this.strokes,
    required this.currentStroke,
    required this.gridType,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Canvas Background
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

    // 2. Draw Grid overlay if requested
    _drawGrid(canvas, size);

    // 3. Draw Completed Strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // 4. Draw Currently Active Stroke
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!);
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    if (gridType == CanvasGridType.blank) return;

    final gridPaint = Paint()
      ..color = Colors.orange.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;

    const spacing = 30.0;

    if (gridType == CanvasGridType.dots) {
      final dotPaint = Paint()..color = Colors.orange.withValues(alpha: 0.25);
      for (double x = spacing; x < size.width; x += spacing) {
        for (double y = spacing; y < size.height; y += spacing) {
          canvas.drawCircle(Offset(x, y), 2.0, dotPaint);
        }
      }
    } else if (gridType == CanvasGridType.grid) {
      for (double x = spacing; x < size.width; x += spacing) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
      for (double y = spacing; y < size.height; y += spacing) {
        canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
      }
    }
  }

  void _drawStroke(Canvas canvas, Stroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.isEraser ? Colors.white : stroke.color
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = stroke.strokeWidth
      ..style = PaintingStyle.stroke;

    if (stroke.points.length == 1) {
      final point = stroke.points.first;
      final dotPaint = Paint()
        ..color = stroke.isEraser ? Colors.white : stroke.color
        ..style = PaintingStyle.fill;
      canvas.drawCircle(point.offset, stroke.strokeWidth / 2, dotPaint);
      return;
    }

    final path = Path();
    path.moveTo(stroke.points.first.offset.dx, stroke.points.first.offset.dy);

    for (int i = 0; i < stroke.points.length - 1; i++) {
      final p1 = stroke.points[i].offset;
      final p2 = stroke.points[i + 1].offset;
      final midPoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
      path.quadraticBezierTo(p1.dx, p1.dy, midPoint.dx, midPoint.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return oldDelegate.strokes != strokes ||
        oldDelegate.currentStroke != currentStroke ||
        oldDelegate.gridType != gridType;
  }
}
