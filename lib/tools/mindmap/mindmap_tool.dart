import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../shared/tool_result.dart';
import '../shared/fonts.dart';

class MindmapTool {
  /// generate_mindmap
  /// input: { root: { label: String, children?: List<root-like> } }
  static Future<ToolResult> generate(Map<String, dynamic> input) async {
    final Map<String, dynamic>? root = input['root'] as Map<String, dynamic>?;
    if (root == null || root['label'] == null) {
      return ToolResult.error('Parâmetro "root" (com "label") é obrigatório.', code: 'INVALID_INPUT');
    }

    try {
      const double size = 900;
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));
      canvas.drawRect(Rect.fromLTWH(0, 0, size, size), Paint()..color = Colors.white);

      final center = Offset(size / 2, size / 2);
      _drawNode(canvas, center, root['label'] as String, isRoot: true);

      final children = (root['children'] as List<dynamic>?) ?? [];
      _drawChildrenRing(canvas, center, children, radius: 220, depth: 1);

      final picture = recorder.endRecording();
      final image = await picture.toImage(size.toInt(), size.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      return ToolResult.ok({
        'image_base64': base64Encode(byteData!.buffer.asUint8List()),
      });
    } catch (e) {
      return ToolResult.error('Erro ao gerar mapa mental: $e', code: 'GENERATION_ERROR');
    }
  }

  static void _drawChildrenRing(
    Canvas canvas,
    Offset center,
    List<dynamic> children,
    {required double radius, required int depth}
  ) {
    if (children.isEmpty || depth > 2) return;

    final angleStep = (2 * math.pi) / children.length;
    for (int i = 0; i < children.length; i++) {
      final child = children[i] as Map<String, dynamic>;
      final angle = angleStep * i;
      final childCenter = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );

      canvas.drawLine(center, childCenter, Paint()..color = Colors.black26..strokeWidth = 1.5);
      _drawNode(canvas, childCenter, child['label'] as String? ?? '', isRoot: false);

      final grandChildren = (child['children'] as List<dynamic>?) ?? [];
      if (grandChildren.isNotEmpty) {
        _drawChildrenRing(canvas, childCenter, grandChildren, radius: radius * 0.55, depth: depth + 1);
      }
    }
  }

  static void _drawNode(Canvas canvas, Offset center, String label, {required bool isRoot}) {
    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: isRoot ? ToolFonts.bold(size: 18, color: Colors.white) : ToolFonts.regular(size: 13),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 140);

    final padding = isRoot ? 20.0 : 12.0;
    final rect = Rect.fromCenter(
      center: center,
      width: tp.width + padding * 2,
      height: tp.height + padding,
    );

    final bgPaint = Paint()..color = isRoot ? Colors.blue : Colors.blue.shade50;
    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), bgPaint);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(10)), borderPaint);

    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
  }
}