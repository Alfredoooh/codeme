=====================================================================
lib/tools/images/barcode_tool.dart
=====================================================================

// generate_barcode
//
// Usa o pacote `barcode` (precisa ser adicionado ao pubspec.yaml).
// Renderiza direto para SVG e depois converte para PNG via Canvas,
// suportando os formatos mais comuns (Code128, EAN13, QR não entra
// aqui pois já tem tool própria).

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:barcode/barcode.dart';

import '../shared/tool_result.dart';

class BarcodeTool {
  /// generate_barcode
  /// input: { content: String, format?: String — "code128" | "ean13" | "code39" (default "code128") }
  static Future<ToolResult> generate(Map<String, dynamic> input) async {
    final String? content = input['content'] as String?;
    if (content == null || content.isEmpty) {
      return ToolResult.error('Parâmetro "content" é obrigatório.', code: 'INVALID_INPUT');
    }

    final String format = (input['format'] as String?) ?? 'code128';

    try {
      final Barcode bc = _resolveBarcode(format);
      final bytes = await _renderBarcodeToPng(bc, content);

      return ToolResult.ok({
        'image_base64': base64Encode(bytes),
        'format': format,
      });
    } catch (e) {
      return ToolResult.error('Erro ao gerar código de barras: $e', code: 'GENERATION_ERROR');
    }
  }

  static Barcode _resolveBarcode(String format) {
    switch (format.toLowerCase()) {
      case 'ean13':
        return Barcode.ean13();
      case 'code39':
        return Barcode.code39();
      case 'code128':
      default:
        return Barcode.code128();
    }
  }

  static Future<Uint8List> _renderBarcodeToPng(Barcode bc, String content) async {
    const double width = 600;
    const double height = 200;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = Colors.white);

    final paint = Paint()..color = Colors.black;

    for (final element in bc.paint(content, width, height)) {
      // ignore: dead_code_on_catch_subtype
    }

    // A API do pacote `barcode` gera elementos gráficos (BarcodeBar,
    // BarcodeText, etc.) via bc.make(content, width: ..., height: ...);
    // desenhamos cada barra manualmente:
    for (final elem in bc.make(content, width: width, height: height)) {
      if (elem is BarcodeBar) {
        canvas.drawRect(
          Rect.fromLTWH(elem.left, elem.top, elem.width, elem.height),
          elem.black ? paint : Paint()..color = Colors.white,
        );
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData!.buffer.asUint8List();
  }
}