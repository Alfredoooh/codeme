=====================================================================
lib/tools/charts/function_plot_tool.dart
=====================================================================

// generate_function_plot
//
// Usa math_expressions (já presente no pubspec) para parsear e
// avaliar a expressão matemática ponto a ponto, depois desenha a
// curva direto via Canvas — sem depender de lib de gráfico, já que
// é uma única linha/curva simples.

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:math_expressions/math_expressions.dart';

import '../shared/tool_result.dart';
import '../shared/fonts.dart';

class FunctionPlotTool {
  /// generate_function_plot
  /// input: {
  ///   expression: String (ex: "x^2 - 4"),
  ///   x_min?: number (default -10),
  ///   x_max?: number (default 10),
  ///   title?: String,
  ///   highlight_roots?: bool (default false)
  /// }
  static Future<ToolResult> generate(Map<String, dynamic> input) async {
    final String? expr = input['expression'] as String?;
    if (expr == null || expr.isEmpty) {
      return ToolResult.error('Parâmetro "expression" é obrigatório.', code: 'INVALID_INPUT');
    }

    final double xMin = (input['x_min'] as num?)?.toDouble() ?? -10;
    final double xMax = (input['x_max'] as num?)?.toDouble() ?? 10;
    final String? title = input['title'] as String?;
    final bool highlightRoots = (input['highlight_roots'] as bool?) ?? false;

    try {
      final parser = GrammarParser();
      final exp = parser.parse(expr);
      final contextModel = ContextModel();

      const int samples = 400;
      final points = <Offset>[];
      final roots = <double>[];

      double? prevY;
      for (int i = 0; i <= samples; i++) {
        final x = xMin + (xMax - xMin) * i / samples;
        contextModel.bindVariable(Variable('x'), Number(x));
        final y = exp.evaluate(EvaluationType.REAL, contextModel) as double;
        points.add(Offset(x, y));

        if (highlightRoots && prevY != null && prevY.sign != y.sign && y.isFinite && prevY.isFinite) {
          roots.add(x);
        }
        prevY = y;
      }

      final bytes = await _paintPlot(points, roots, xMin, xMax, title);

      return ToolResult.ok({
        'image_base64': base64Encode(bytes),
        'roots_found': roots,
      });
    } catch (e) {
      return ToolResult.error('Erro ao gerar gráfico da função: $e', code: 'GENERATION_ERROR');
    }
  }

  static Future<Uint8List> _paintPlot(
    List<Offset> points,
    List<double> roots,
    double xMin,
    double xMax,
    String? title,
  ) async {
    const double width = 800;
    const double height = 500;
    const double padding = 50;

    final yValues = points.map((p) => p.dy).where((y) => y.isFinite).toList();
    final yMin = yValues.isEmpty ? -10.0 : yValues.reduce((a, b) => a < b ? a : b);
    final yMax = yValues.isEmpty ? 10.0 : yValues.reduce((a, b) => a > b ? a : b);

    double toScreenX(double x) => padding + (x - xMin) / (xMax - xMin) * (width - padding * 2);
    double toScreenY(double y) => height - padding - (y - yMin) / (yMax - yMin) * (height - padding * 2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = Colors.white);

    if (title != null) {
      final tp = TextPainter(
        text: TextSpan(text: title, style: ToolFonts.bold(size: 18)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((width - tp.width) / 2, 10));
    }

    // Eixos
    final axisPaint = Paint()..color = Colors.black54..strokeWidth = 1.5;
    if (yMin <= 0 && yMax >= 0) {
      canvas.drawLine(Offset(padding, toScreenY(0)), Offset(width - padding, toScreenY(0)), axisPaint);
    }
    if (xMin <= 0 && xMax >= 0) {
      canvas.drawLine(Offset(toScreenX(0), padding), Offset(toScreenX(0), height - padding), axisPaint);
    }

    // Curva
    final curvePaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;

    final path = Path();
    bool first = true;
    for (final p in points) {
      if (!p.dy.isFinite) {
        first = true;
        continue;
      }
      final sx = toScreenX(p.dx);
      final sy = toScreenY(p.dy);
      if (first) {
        path.moveTo(sx, sy);
        first = false;
      } else {
        path.lineTo(sx, sy);
      }
    }
    canvas.drawPath(path, curvePaint);

    // Raízes destacadas
    final rootPaint = Paint()..color = Colors.red;
    for (final root in roots) {
      canvas.drawCircle(Offset(toScreenX(root), toScreenY(0)), 5, rootPaint);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData!.buffer.asUint8List();
  }
}