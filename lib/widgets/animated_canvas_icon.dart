import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../apps/app_types.dart';

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
    // wrap idêntico ao HTML: width=48, height=44
    // mas escalado proporcionalmente ao size pedido (base=44)
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

  _CanvasIconPainter({
    required this.editorType,
    required this.progress,
    required this.animated,
    required this.scale,
  });

  // Dimensões base (px do HTML)
  // icon-wrap: 48 × 44
  // paper:     36 × 46   (pode sair além do wrap em height — igual ao HTML)
  // paper-back:  left=10, top=0, rotate=+10deg
  // paper-front: left=0,  top=0, rotate=-7deg

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

  // Desenha um papel (rect arredondado) com origem, rotação e cor
  void _drawPaper(Canvas canvas, double left, double top, double width,
      double height, double angleDeg, Color color) {
    final s = scale;
    final cx = (left + width / 2) * s;
    final cy = (top + height / 2) * s;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(left * s, top * s, width * s, height * s),
      Radius.circular(5 * s),
    );
    final paint = Paint()..color = color;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angleDeg * math.pi / 180);
    canvas.translate(-cx, -cy);
    canvas.drawRRect(rect, paint);
    // sombra
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * s);
    canvas.drawRRect(rect, shadowPaint);
    canvas.restore();
  }

  // Aplica a rotação do paper-front ao canvas e chama o callback de ícone
  void _withFrontTransform(Canvas canvas, void Function() draw) {
    // paper-front: left=0, top=0, w=36, h=46, rotate=-7deg
    // centro de rotação = centro do papel
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
    // 1) Paper de trás: left=10, top=0, rotate=+10deg, cor secundária
    _drawPaper(canvas, 10, 0, 36, 46, 10, _secondaryColor);

    // 2) Paper da frente: left=0, top=0, rotate=-7deg, cor primária
    _drawPaper(canvas, 0, 0, 36, 46, -7, _primaryColor);

    // 3) Ícone por cima do paper-front, com a mesma rotação -7deg
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

  // ── Doc: 4 linhas horizontais ──────────────────────────────────────────
  // SVG viewBox 0 0 36 46, paths em coordenadas do viewBox
  // M5 11.5 H31  |  M5 18.5 H25  |  M5 25.5 H31  |  M5 32.5 H21
  void _drawDocLines(Canvas canvas) {
    final s = scale;
    // factor de escala do viewBox (36×46) para o papel real (36×46) → 1:1
    // paper começa em left=0, top=0
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.8)
      ..strokeWidth = 3 * s
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
      double fraction = _lineFraction(i, delayStep: 0.3);
      if (fraction <= 0) continue;

      final xEnd = x1 + (x2 - x1) * fraction;
      canvas.drawLine(
        Offset(x1 * s, y * s),
        Offset(xEnd * s, y * s),
        paint,
      );
    }
  }

  // ── Sheets: grelha ────────────────────────────────────────────────────
  // rect x=4 y=8 w=28 h=28 (border fixo)
  // linhas H: y=14,22,30   linhas V: x=14,24
  void _drawSheetsGrid(Canvas canvas) {
    final s = scale;

    // borda externa (estática)
    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 1.2 * s
      ..style = PaintingStyle.stroke;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4 * s, 8 * s, 28 * s, 28 * s),
        Radius.circular(1 * s),
      ),
      borderPaint,
    );

    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.6)
      ..strokeWidth = 1.2 * s
      ..strokeCap = StrokeCap.butt
      ..style = PaintingStyle.stroke;

    // 3 linhas H + 2 linhas V = 5 linhas animadas
    final hLines = [(4.0, 14.0, 32.0, 14.0), (4.0, 22.0, 32.0, 22.0), (4.0, 30.0, 32.0, 30.0)];
    final vLines = [(14.0, 8.0, 14.0, 36.0), (24.0, 8.0, 24.0, 36.0)];

    for (int i = 0; i < hLines.length; i++) {
      final (x1, y1, x2, y2) = hLines[i];
      double fraction = _lineFraction(i, delayStep: 0.25);
      if (fraction <= 0) continue;
      final xEnd = x1 + (x2 - x1) * fraction;
      canvas.drawLine(Offset(x1 * s, y1 * s), Offset(xEnd * s, y2 * s), linePaint);
    }

    for (int i = 0; i < vLines.length; i++) {
      final (x1, y1, x2, y2) = vLines[i];
      double fraction = _lineFraction(i + hLines.length, delayStep: 0.25);
      if (fraction <= 0) continue;
      final yEnd = y1 + (y2 - y1) * fraction;
      canvas.drawLine(Offset(x1 * s, y1 * s), Offset(x2 * s, yEnd * s), linePaint);
    }
  }

  // ── Slides: frame + 3 barras ──────────────────────────────────────────
  // frame: x=4 y=9 w=28 h=18
  // barras: (8,21,4,4) (14,17,4,8) (20,13,4,12)
  void _drawSlidesElements(Canvas canvas) {
    final s = scale;

    // frame
    final framePaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..strokeWidth = 1.2 * s
      ..style = PaintingStyle.stroke;

    double frameFraction = animated ? _lineFraction(0, delayStep: 0, totalDuration: 2.8) : 1.0;
    if (frameFraction > 0) {
      // desenha o frame progressivamente pelos 4 lados
      final path = _buildRectPath(4, 9, 28, 18, frameFraction, s);
      canvas.drawPath(path, framePaint);
    }

    // barras
    final barPaint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.fill;

    final bars = [
      (8.0, 25.0, 4.0, 4.0),   // x, bottom_y, w, max_h
      (14.0, 25.0, 4.0, 8.0),
      (20.0, 25.0, 4.0, 12.0),
    ];

    for (int i = 0; i < bars.length; i++) {
      final (bx, by, bw, bh) = bars[i];
      double fraction = animated ? _lineFraction(i, delayStep: 0.25) : 1.0;
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

  // Constrói path do rect progressivamente (perimetralmente)
  Path _buildRectPath(
      double x, double y, double w, double h, double fraction, double s) {
    final perimeter = 2 * (w + h);
    final drawn = perimeter * fraction;
    final path = Path();
    path.moveTo(x * s, y * s);

    double rem = drawn;
    // top
    if (rem > 0) {
      final seg = math.min(rem, w);
      path.lineTo((x + seg) * s, y * s);
      rem -= seg;
    }
    // right
    if (rem > 0) {
      final seg = math.min(rem, h);
      path.lineTo((x + w) * s, (y + seg) * s);
      rem -= seg;
    }
    // bottom (reversed)
    if (rem > 0) {
      final seg = math.min(rem, w);
      path.lineTo((x + w - seg) * s, (y + h) * s);
      rem -= seg;
    }
    // left (reversed)
    if (rem > 0) {
      final seg = math.min(rem, h);
      path.lineTo(x * s, (y + h - seg) * s);
    }
    return path;
  }

  // Calcula a fração de desenho/apagamento para a linha i
  // Espelha o CSS: draw-erase com delay escalonado
  double _lineFraction(int i,
      {required double delayStep, double totalDuration = 2.4}) {
    if (!animated) return 1.0;

    // normaliza o delay em fração do ciclo
    final delayFraction = (i * delayStep) / totalDuration;
    final t = ((progress - delayFraction) % 1.0 + 1.0) % 1.0;

    // 0–0.45 → desenha (0→1)
    // 0.45–0.70 → mantém
    // 0.70–0.95 → apaga (1→0)
    // 0.95–1.0  → zero
    if (t < 0.45) {
      return t / 0.45;
    } else if (t < 0.70) {
      return 1.0;
    } else if (t < 0.95) {
      return 1.0 - (t - 0.70) / 0.25;
    } else {
      return 0.0;
    }
  }

  @override
  bool shouldRepaint(covariant _CanvasIconPainter oldDelegate) =>
      oldDelegate.editorType != editorType ||
      oldDelegate.progress != progress ||
      oldDelegate.animated != animated ||
      oldDelegate.scale != scale;
}