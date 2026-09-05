import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../features/apps/app_types.dart';
import '../theme/colors.dart';


class AnimatedCanvasIcon extends StatefulWidget {
  final EditorType editorType;
  final double size;
  final bool animated;
  final AppColorScheme s;

  const AnimatedCanvasIcon({
    super.key,
    required this.editorType,
    required this.s,
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
      duration: const Duration(milliseconds: 2400),
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
    final scale = widget.size / 44.0;
    return SizedBox(
      width: 48 * scale,
      height: 44 * scale,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => CustomPaint(
          painter: _CanvasIconPainter(
            editorType: widget.editorType,
            progress: _controller.value,
            animated: widget.animated,
            scale: scale,
            isDark: widget.s.isDark,
            primary: widget.s.primary,
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
  final double scale;
  final bool isDark;
  final Color primary;

  _CanvasIconPainter({
    required this.editorType,
    required this.progress,
    required this.animated,
    required this.scale,
    required this.isDark,
    required this.primary,
  });

  // ── Cores dos papéis ──────────────────────────────────────────
  // Modo escuro: escuros profundos diferenciados do card de canvas
  // Modo claro: brancos quentes com 10% da cor primária misturada

  Color get _frontColor {
    if (isDark) {
      switch (editorType) {
        case EditorType.docs:   return const Color(0xFF1C2433); // azul muito escuro
        case EditorType.sheets: return const Color(0xFF172418); // verde muito escuro
        case EditorType.slides: return const Color(0xFF2A1A12); // laranja muito escuro
      }
    } else {
      // branco com 10% da cor primária correspondente
      switch (editorType) {
        case EditorType.docs:   return Color.lerp(Colors.white, const Color(0xFF2B579A), 0.10)!;
        case EditorType.sheets: return Color.lerp(Colors.white, const Color(0xFF1D6F42), 0.10)!;
        case EditorType.slides: return Color.lerp(Colors.white, const Color(0xFFC43E00), 0.10)!;
      }
    }
  }

  Color get _backColor {
    if (isDark) {
      switch (editorType) {
        case EditorType.docs:   return const Color(0xFF141B26);
        case EditorType.sheets: return const Color(0xFF101A11);
        case EditorType.slides: return const Color(0xFF1E1108);
      }
    } else {
      switch (editorType) {
        case EditorType.docs:   return Color.lerp(Colors.white, const Color(0xFF2B579A), 0.18)!;
        case EditorType.sheets: return Color.lerp(Colors.white, const Color(0xFF1D6F42), 0.18)!;
        case EditorType.slides: return Color.lerp(Colors.white, const Color(0xFFC43E00), 0.18)!;
      }
    }
  }

  Color get _borderColor {
    if (isDark) {
      return Colors.white.withOpacity(0.08);
    } else {
      return Colors.black.withOpacity(0.10);
    }
  }

  Color get _strokeColor {
    if (isDark) {
      return Colors.white.withOpacity(0.55);
    } else {
      switch (editorType) {
        case EditorType.docs:   return const Color(0xFF2B579A).withOpacity(0.75);
        case EditorType.sheets: return const Color(0xFF1D6F42).withOpacity(0.75);
        case EditorType.slides: return const Color(0xFFC43E00).withOpacity(0.75);
      }
    }
  }

  void _drawPaper(Canvas canvas, double left, double top, double width,
      double height, double angleDeg, Color fill) {
    final s = scale;
    final cx = (left + width / 2) * s;
    final cy = (top + height / 2) * s;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left * s, top * s, width * s, height * s),
      Radius.circular(5 * s),
    );

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angleDeg * math.pi / 180);
    canvas.translate(-cx, -cy);

    // fill
    canvas.drawRRect(rect, Paint()..color = fill);

    // borda sólida subtil
    canvas.drawRRect(
      rect,
      Paint()
        ..color = _borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8 * s,
    );

    canvas.restore();
  }

  void _withFrontTransform(Canvas canvas, void Function() draw) {
    const left = 0.0;
    const top = 0.0;
    const w = 36.0;
    const h = 46.0;
    final s = scale;
    final cx = (left + w / 2) * s;
    final cy = (top + h / 2) * s;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(-7 * math.pi / 180);
    canvas.translate(-cx, -cy);
    draw();
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawPaper(canvas, 10, 0, 36, 46, 10, _backColor);
    _drawPaper(canvas, 0, 0, 36, 46, -7, _frontColor);

    _withFrontTransform(canvas, () {
      switch (editorType) {
        case EditorType.docs:
          _drawDocLines(canvas);
          break;
        case EditorType.sheets:
          _drawSheetsGrid(canvas);
          break;
        case EditorType.slides:
          _drawSlidesElements(canvas);
          break;
      }
    });
  }

  // ── Doc: 4 linhas ────────────────────────────────────────────
  void _drawDocLines(Canvas canvas) {
    final s = scale;
    final paint = Paint()
      ..color = _strokeColor
      ..strokeWidth = 2.8 * s
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final lines = [
      (5.0, 11.5, 31.0),
      (5.0, 18.5, 25.0),
      (5.0, 25.5, 31.0),
      (5.0, 32.5, 21.0),
    ];

    for (int i = 0; i < lines.length; i++) {
      final (x1, y, x2) = lines[i];
      final fraction = _lineFraction(i, delayStep: 0.3);
      if (fraction <= 0) continue;
      final xEnd = x1 + (x2 - x1) * fraction;
      canvas.drawLine(Offset(x1 * s, y * s), Offset(xEnd * s, y * s), paint);
    }
  }

  // ── Sheets: grelha ───────────────────────────────────────────
  void _drawSheetsGrid(Canvas canvas) {
    final s = scale;

    // borda externa estática
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4 * s, 8 * s, 28 * s, 28 * s),
        Radius.circular(1.5 * s),
      ),
      Paint()
        ..color = _strokeColor.withOpacity(0.4)
        ..strokeWidth = 1.0 * s
        ..style = PaintingStyle.stroke,
    );

    final linePaint = Paint()
      ..color = _strokeColor
      ..strokeWidth = 1.0 * s
      ..style = PaintingStyle.stroke;

    final hLines = [
      (4.0, 14.0, 32.0, 14.0),
      (4.0, 22.0, 32.0, 22.0),
      (4.0, 30.0, 32.0, 30.0),
    ];
    final vLines = [
      (14.0, 8.0, 14.0, 36.0),
      (24.0, 8.0, 24.0, 36.0),
    ];

    for (int i = 0; i < hLines.length; i++) {
      final (x1, y1, x2, _) = hLines[i];
      final fraction = _lineFraction(i, delayStep: 0.25);
      if (fraction <= 0) continue;
      final xEnd = x1 + (x2 - x1) * fraction;
      canvas.drawLine(Offset(x1 * s, y1 * s), Offset(xEnd * s, y1 * s), linePaint);
    }

    for (int i = 0; i < vLines.length; i++) {
      final (x1, y1, _, y2) = vLines[i];
      final fraction = _lineFraction(i + hLines.length, delayStep: 0.25);
      if (fraction <= 0) continue;
      final yEnd = y1 + (y2 - y1) * fraction;
      canvas.drawLine(Offset(x1 * s, y1 * s), Offset(x1 * s, yEnd * s), linePaint);
    }
  }

  // ── Slides: frame + barras ───────────────────────────────────
  void _drawSlidesElements(Canvas canvas) {
    final s = scale;

    final framePaint = Paint()
      ..color = _strokeColor
      ..strokeWidth = 1.0 * s
      ..style = PaintingStyle.stroke;

    final frameFraction = animated ? _lineFraction(0, delayStep: 0, totalDuration: 2.8) : 1.0;
    if (frameFraction > 0) {
      final path = _buildRectPath(4, 9, 28, 18, frameFraction, s);
      canvas.drawPath(path, framePaint);
    }

    final barPaint = Paint()
      ..color = _strokeColor
      ..style = PaintingStyle.fill;

    // x, bottom_y, w, max_h
    final bars = [
      (8.0, 25.0, 4.0, 4.0),
      (14.0, 25.0, 4.0, 8.0),
      (20.0, 25.0, 4.0, 12.0),
    ];

    for (int i = 0; i < bars.length; i++) {
      final (bx, by, bw, bh) = bars[i];
      final fraction = animated ? _lineFraction(i, delayStep: 0.25) : 1.0;
      if (fraction <= 0) continue;
      final currentH = bh * fraction;
      final currentY = by - currentH;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bx * s, currentY * s, bw * s, currentH * s),
          Radius.circular(0.5 * s),
        ),
        barPaint,
      );
    }
  }

  Path _buildRectPath(
      double x, double y, double w, double h, double fraction, double s) {
    final perimeter = 2 * (w + h);
    final drawn = perimeter * fraction;
    final path = Path();
    path.moveTo(x * s, y * s);

    double rem = drawn;
    if (rem > 0) {
      final seg = math.min(rem, w);
      path.lineTo((x + seg) * s, y * s);
      rem -= seg;
    }
    if (rem > 0) {
      final seg = math.min(rem, h);
      path.lineTo((x + w) * s, (y + seg) * s);
      rem -= seg;
    }
    if (rem > 0) {
      final seg = math.min(rem, w);
      path.lineTo((x + w - seg) * s, (y + h) * s);
      rem -= seg;
    }
    if (rem > 0) {
      final seg = math.min(rem, h);
      path.lineTo(x * s, (y + h - seg) * s);
    }
    return path;
  }

  double _lineFraction(int i,
      {required double delayStep, double totalDuration = 2.4}) {
    if (!animated) return 1.0;
    final delayFraction = (i * delayStep) / totalDuration;
    final t = ((progress - delayFraction) % 1.0 + 1.0) % 1.0;
    if (t < 0.45) return t / 0.45;
    if (t < 0.70) return 1.0;
    if (t < 0.95) return 1.0 - (t - 0.70) / 0.25;
    return 0.0;
  }

  @override
  bool shouldRepaint(covariant _CanvasIconPainter oldDelegate) =>
      oldDelegate.editorType != editorType ||
      oldDelegate.progress != progress ||
      oldDelegate.animated != animated ||
      oldDelegate.scale != scale ||
      oldDelegate.isDark != isDark;
}