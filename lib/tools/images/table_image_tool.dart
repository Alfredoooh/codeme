=====================================================================
lib/tools/images/table_image_tool.dart
=====================================================================

// generate_table_image
//
// Desenha uma tabela diretamente via Canvas (dart:ui) — mais leve
// que delegar para WebView, já que é um layout simples e previsível
// (grade de células).

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

import '../shared/tool_result.dart';
import '../shared/fonts.dart';

class TableImageTool {
  /// generate_table_image
  /// input: { title?: String, headers: List<String>, rows: List<List<String>> }
  static Future<ToolResult> generate(Map<String, dynamic> input) async {
    final List<dynamic>? headers = input['headers'] as List<dynamic>?;
    final List<dynamic>? rows = input['rows'] as List<dynamic>?;
    final String? title = input['title'] as String?;

    if (headers == null || rows == null) {
      return ToolResult.error('Parâmetros "headers" e "rows" são obrigatórios.', code: 'INVALID_INPUT');
    }

    try {
      const double cellPadding = 12;
      const double rowHeight = 40;
      const double colWidth = 160;
      final double titleHeight = title != null ? 50 : 0;
      final double width = colWidth * headers.length;
      final double height = titleHeight + rowHeight * (rows.length + 1);

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));
      canvas.drawRect(Rect.fromLTWH(0, 0, width, height), Paint()..color = Colors.white);

      double y = 0;

      if (title != null) {
        final tp = TextPainter(
          text: TextSpan(text: title, style: ToolFonts.bold(size: 20)),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(cellPadding, (titleHeight - tp.height) / 2));
        y = titleHeight;
      }

      // Cabeçalho
      final headerPaint = Paint()..color = const Color(0xFFF2F2F2);
      canvas.drawRect(Rect.fromLTWH(0, y, width, rowHeight), headerPaint);
      for (int c = 0; c < headers.length; c++) {
        final tp = TextPainter(
          text: TextSpan(text: headers[c].toString(), style: ToolFonts.bold(size: 14)),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: colWidth - cellPadding * 2);
        tp.paint(canvas, Offset(c * colWidth + cellPadding, y + (rowHeight - tp.height) / 2));
      }
      y += rowHeight;

      // Linhas
      final borderPaint = Paint()
        ..color = const Color(0xFFCCCCCC)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      for (final row in rows) {
        final cells = row as List<dynamic>;
        for (int c = 0; c < cells.length; c++) {
          final cellRect = Rect.fromLTWH(c * colWidth, y, colWidth, rowHeight);
          canvas.drawRect(cellRect, borderPaint);
          final tp = TextPainter(
            text: TextSpan(text: cells[c].toString(), style: ToolFonts.regular(size: 13)),
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: colWidth - cellPadding * 2);
          tp.paint(canvas, Offset(c * colWidth + cellPadding, y + (rowHeight - tp.height) / 2));
        }
        y += rowHeight;
      }

      final picture = recorder.endRecording();
      final image = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();

      return ToolResult.ok({
        'image_base64': base64Encode(byteData!.buffer.asUint8List()),
        'width': width,
        'height': height,
      });
    } catch (e) {
      return ToolResult.error('Erro ao gerar imagem de tabela: $e', code: 'GENERATION_ERROR');
    }
  }
}