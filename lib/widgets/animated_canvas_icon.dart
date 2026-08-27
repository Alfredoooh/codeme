import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'apps/app_types.dart';

class AnimatedCanvasIcon extends StatefulWidget {
  final EditorType editorType;
  final double size;
  final bool animated;

  const AnimatedCanvasIcon({
    super.key,
    required this.editorType,
    this.size = 44,
    this.animated = false,
  });

  @override
  State<AnimatedCanvasIcon> createState() => _AnimatedCanvasIconState();
}

class _AnimatedCanvasIconState extends State<AnimatedCanvasIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (widget.animated) {
      _controller.repeat();
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant AnimatedCanvasIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated != oldWidget.animated) {
      if (widget.animated) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.value = 1.0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => CustomPaint(
          painter: _CanvasIconPainter(
            editorType: widget.editorType,
            progress: _controller.value,
            animated: widget.animated,
          ),
        ),
      ),
    );
  }
}

class _CanvasIconPainter extends CustomPainter {
  final EditorType editorType;
  final double progress;
  final bool animated;

  _CanvasIconPainter({
    required this.editorType,
    required this.progress,
    required this.animated,
  });

  Color get _primaryColor {
    switch (editorType) {
      case EditorType.docs:   return const Color(0xFF2B579A);
      case EditorType.sheets: return const Color(0xFF1D6F42);
      case EditorType.slides: return const Color(0xFFC43E00);
    }
  }

  Color get _secondaryColor {
    switch (editorType) {
      case EditorType.docs:   return const Color(0xFF1A3F6F);
      case EditorType.sheets: return const Color(0xFF145232);
      case EditorType.slides: return const Color(0xFF8C2A00);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawPaper(canvas, size);
    switch (editorType) {
      case EditorType.docs:   _drawDocLines(canvas, size); break;
      case EditorType.sheets: _drawSheetsGrid(canvas, size); break;
      case EditorType.slides: _drawSlidesElements(canvas, size); break;
    }
  }

  void _drawPaper(Canvas canvas, Size size) {
    final backRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.25, size.height * 0.08, size.width * 0.6, size.height * 0.84),
      Radius.circular(size.width * 0.08),
    );
    final backPaint = Paint()..color = _secondaryColor;
    canvas.save();
    canvas.translate(size.width * 0.5, size.height * 0.5);
    canvas.rotate(math.pi / 18);
    canvas.translate(-size.width * 0.5, -size.height * 0.5);
    canvas.drawRRect(backRect, backPaint);
    canvas.restore();

    final frontRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(size.width * 0.12, size.height * 0.08, size.width * 0.6, size.height * 0.84),
      Radius.circular(size.width * 0.08),
    );
    final frontPaint = Paint()..color = _primaryColor;
    canvas.save();
    canvas.translate(size.width * 0.5, size.height * 0.5);
    canvas.rotate(-math.pi / 25);
    canvas.translate(-size.width * 0.5, -size.height * 0.5);
    canvas.drawRRect(frontRect, frontPaint);
    canvas.restore();
  }

  void _drawDocLines(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = size.width * 0.07
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final lineGap = size.height * 0.16;
    final startY = size.height * 0.3;
    final maxX = size.width * 0.68;
    final startX = size.width * 0.2;

    for (int i = 0; i < 4; i++) {
      double lineProgress;
      if (animated) {
        final delay = i * 0.15;
        lineProgress = ((progress - delay) % 1.0).clamp(0.0, 1.0);
      } else {
        lineProgress = 1.0;
      }

      double xEnd;
      if (lineProgress < 0.5) {
        xEnd = maxX * (lineProgress / 0.5);
      } else if (lineProgress < 1.0) {
        xEnd = maxX * (1 - (lineProgress - 0.5) / 0.5);
      } else {
        xEnd = maxX;
      }

      if (xEnd > 0) {
        canvas.drawLine(
          Offset(startX, startY + i * lineGap),
          Offset(startX + xEnd, startY + i * lineGap),
          linePaint,
        );
      }
    }
  }

  void _drawSheetsGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..strokeWidth = size.width * 0.04
      ..style = PaintingStyle.stroke;

    final hGap = size.height * 0.18;
    final hStartY = size.height * 0.18;
    final leftX = size.width * 0.15;
    final rightX = size.width * 0.85;

    final vGap = size.width * 0.18;
    final vStartX = size.width * 0.3;
    final topY = size.height * 0.18;
    final bottomY = size.height * 0.82;

    for (int i = 0; i < 5; i++) {
      double lineProgress;
      if (animated) {
        final delay = i * 0.1;
        lineProgress = ((progress - delay) % 1.0).clamp(0.0, 1.0);
      } else {
        lineProgress = 1.0;
      }

      double drawFraction;
      if (lineProgress < 0.5) {
        drawFraction = lineProgress / 0.5;
      } else if (lineProgress < 1.0) {
        drawFraction = 1 - (lineProgress - 0.5) / 0.5;
      } else {
        drawFraction = 1.0;
      }

      if (drawFraction <= 0) continue;

      if (i < 3) {
        final y = hStartY + i * hGap;
        final xEnd = leftX + (rightX - leftX) * drawFraction;
        canvas.drawLine(Offset(leftX, y), Offset(xEnd, y), gridPaint);
      } else {
        final x = vStartX + (i - 3) * vGap;
        final yEnd = topY + (bottomY - topY) * drawFraction;
        canvas.drawLine(Offset(x, topY), Offset(x, yEnd), gridPaint);
      }
    }
  }

  void _drawSlidesElements(Canvas canvas, Size size) {
    final framePaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = size.width * 0.04
      ..style = PaintingStyle.stroke;

    final frameRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.15,
        size.height * 0.22,
        size.width * 0.7,
        size.height * 0.4,
      ),
      Radius.circular(size.width * 0.04),
    );

    if (animated) {
      final drawProgress = ((progress - 0.0) % 1.0).clamp(0.0, 1.0);
      final drawFraction = drawProgress < 0.5 ? drawProgress / 0.5 : 1.0;
      final path = Path()
        ..moveTo(frame