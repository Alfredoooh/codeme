=====================================================================
lib/tools/images/image_watermark_tool.dart
=====================================================================

// watermark_image
//
// Desenha texto sobre a imagem via Canvas nativo (dart:ui), sem
// dependência externa.

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../shared/tool_result.dart';

class ImageWatermarkTool {
  /// watermark_image
  /// input: {
  ///   image_base64: String,
  ///   watermark_text: String,
  ///   position?: String — "top_left"|"top_right"|"bottom_left"|"bottom_right"|"center" (default "bottom_right")
  /// }
  static Future<ToolResult> apply(Map<String, dynamic> input) async {
    final String? imageBase64 = input['image_base64'] as String?;
    final String? text = input['watermark_text'] as String?;
    final String position = (input['position'] as String?) ?? 'bottom_right';

    if (imageBase64 == null || text == null) {
      return ToolResult.error('Parâmetros "image_base64" e "watermark_text" são obrigatórios.', code: 'INVALID_INPUT');
    }

    try {
      final bytes = base64Decode(imageBase64);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final srcImage = frame.image;
      final w = srcImage.width.toDouble();
      final h = srcImage.height.toDouble();

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
      canvas.drawImage(srcImage, Offset.zero, Paint());

      final fontSize = (w * 0.03).clamp(14, 48).toDouble();
      final textPainter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            shadows: const [Shadow(blurRadius: 4, color: Colors.black54)],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      final padding = w * 0.02;
      final offset = _resolveOffset(position, w, h, textPainter.width, textPainter.height, padding);
      textPainter.paint(canvas, offset);

      final picture = recorder.endRecording();
      final resultImage = await picture.toImage(w.toInt(), h.toInt());
      final byteData = await resultImage.toByteData(format: ui.ImageByteFormat.png);

      srcImage.dispose();
      resultImage.dispose();

      return ToolResult.ok({
        'image_base64': base64Encode(byteData!.buffer.asUint8List()),
      });
    } catch (e) {
      return ToolResult.error('Erro ao aplicar marca d\'água: $e', code: 'PROCESSING_ERROR');
    }
  }

  static Offset _resolveOffset(
    String position,
    double w,
    double h,
    double textW,
    double textH,
    double padding,
  ) {
    switch (position) {
      case 'top_left':
        return Offset(padding, padding);
      case 'top_right':
        return Offset(w - textW - padding, padding);
      case 'bottom_left':
        return Offset(padding, h - textH - padding);
      case 'center':
        return Offset((w - textW) / 2, (h - textH) / 2);
      case 'bottom_right':
      default:
        return Offset(w - textW - padding, h - textH - padding);
    }
  }
}