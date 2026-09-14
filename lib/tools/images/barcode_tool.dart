// lib/tools/images/barcode_tool.dart
//
// generate_barcode
//
// Usa o pacote `barcode` (precisa ser adicionado ao pubspec.yaml).
// Gera o código de barras via `Barcode.make(...)`, que retorna uma
// lista de `BarcodeElement` (barras e textos), e desenha tudo em um
// Canvas — depois exporta como PNG.
//
// API barcode 2.x:
//   - NÃO existe `bc.paint()`.
//   - `bc.make(content, width:, height:, drawText:, fontHeight:)`
//     devolve `Iterable<BarcodeElement>`.
//   - Subclasses relevantes: `BarcodeBar` (barra preta ou branca) e
//     `BarcodeText` (texto do rótulo — expõe left/top/width/height/
//     text, sem campo `fontHeight` próprio; o tamanho do rótulo vem
//     de `height`).

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:barcode/barcode.dart';

import '../shared/tool_result.dart';

class BarcodeTool {
  /// generate_barcode
  /// input: {
  ///   content: String,
  ///   format?: String — "code128" | "ean13" | "ean8" | "code39"
  ///                     | "itf14" | "upca" (default "code128"),
  ///   width?: number (default 600),
  ///   height?: number (default 200),
  ///   show_text?: bool (default true),
  /// }
  static Future<ToolResult> generate(Map<String, dynamic> input) async {
    final String? content = input['content'] as String?;
    if (content == null || content.isEmpty) {
      return ToolResult.error('Parâmetro "content" é obrigatório.',
          code: 'INVALID_INPUT');
    }

    final String format =
        ((input['format'] as String?) ?? 'code128').toLowerCase();
    final double width =
        ((input['width'] as num?)?.toDouble() ?? 600).clamp(80, 4000);
    final double height =
        ((input['height'] as num?)?.toDouble() ?? 200).clamp(60, 1000);
    final bool showText = (input['show_text'] as bool?) ?? true;

    try {
      final Barcode bc = _resolveBarcode(format);

      // Valida antes de tentar renderizar (evita exceção feia quando
      // o conteúdo não bate com o formato, ex.: EAN13 precisa ter
      // exatamente 12 ou 13 dígitos).
      if (!bc.isValid(content)) {
        return ToolResult.error(
          'Conteúdo inválido para o formato "$format".',
          code: 'INVALID_INPUT',
        );
      }

      final bytes = await _renderBarcodeToPng(
        bc: bc,
        content: content,
        width: width,
        height: height,
        showText: showText,
      );

      return ToolResult.ok({
        'image_base64': base64Encode(bytes),
        'format': format,
        'width': width,
        'height': height,
      });
    } catch (e) {
      return ToolResult.error('Erro ao gerar código de barras: $e',
          code: 'GENERATION_ERROR');
    }
  }

  static Barcode _resolveBarcode(String format) {
    switch (format) {
      case 'ean13':
        return Barcode.ean13();
      case 'ean8':
        return Barcode.ean8();
      case 'code39':
        return Barcode.code39();
      case 'itf14':
        return Barcode.itf14();
      case 'upca':
      case 'upc_a':
        return Barcode.upcA();
      case 'code128':
      default:
        return Barcode.code128();
    }
  }

  static Future<Uint8List> _renderBarcodeToPng({
    required Barcode bc,
    required String content,
    required double width,
    required double height,
    required bool showText,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width, height));

    // Fundo branco
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, height),
      Paint()..color = Colors.white,
    );

    final blackPaint = Paint()..color = Colors.black;
    final whitePaint = Paint()..color = Colors.white;

    // make() devolve BarcodeElement (barras pretas/brancas + texto).
    // Precisamos iterar e desenhar cada tipo.
    final Iterable<BarcodeElement> elements = bc.make(
      content,
      width: width,
      height: height,
      drawText: false, // texto desenhado manualmente abaixo (mais controle)
      fontHeight: 18,
      textPadding: 4,
    );

    for (final elem in elements) {
      if (elem is BarcodeBar) {
        final rect =
            Rect.fromLTWH(elem.left, elem.top, elem.width, elem.height);
        canvas.drawRect(rect, elem.black ? blackPaint : whitePaint);
      } else if (elem is BarcodeText) {
        // BarcodeText não expõe fontHeight — o tamanho do rótulo é o
        // próprio campo `height` herdado de BarcodeElement.
        final tp = TextPainter(
          text: TextSpan(
            text: elem.text,
            style: TextStyle(
              color: Colors.black,
              fontSize: elem.height,
              fontFamily: 'monospace',
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(
          canvas,
          Offset(elem.left + (elem.width - tp.width) / 2, elem.top),
        );
      }
    }

    // Texto manual (quando showText = true) — o `Barcode.make` com
    // drawText:true às vezes posiciona o texto por cima das barras
    // dependendo do formato; preferimos desenhar nós mesmos na base.
    if (showText) {
      final tp = TextPainter(
        text: TextSpan(
          text: content,
          style: const TextStyle(
            color: Colors.black,
            fontSize: 16,
            fontFamily: 'monospace',
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset((width - tp.width) / 2, height - 22));
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData!.buffer.asUint8List();
  }
}