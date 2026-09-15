import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../shared/tool_result.dart';

class QrcodeTool {
  /// generate_qrcode
  /// input: {
  ///   content: String (obrigatório),
  ///   size?: number (default 400),
  ///   foreground_color?: String (hex, ex: "#000000"),
  ///   background_color?: String (hex, ex: "#FFFFFF"),
  ///   eye_style?: String — "square" | "rounded" | "circle" (default "square"),
  ///   module_style?: String — "square" | "dot" | "rounded" (default "square"),
  ///   gradient_color?: String (hex) — se fornecido, aplica gradiente
  ///                     linear entre foreground_color e gradient_color,
  ///   logo_base64?: String — imagem a embutir no centro do QR,
  /// }
  static Future<ToolResult> generate(Map<String, dynamic> input) async {
    final String? content = input['content'] as String?;
    if (content == null || content.isEmpty) {
      return ToolResult.error('Parâmetro "content" é obrigatório.',
          code: 'INVALID_INPUT');
    }

    final double size =
        ((input['size'] as num?)?.toDouble() ?? 400).clamp(100, 2000);
    final Color fgColor =
        _parseHexColor(input['foreground_color'] as String?) ?? Colors.black;
    final Color bgColor =
        _parseHexColor(input['background_color'] as String?) ?? Colors.white;
    final Color? gradientColor =
        _parseHexColor(input['gradient_color'] as String?);
    final String eyeStyle = (input['eye_style'] as String?) ?? 'square';
    final String moduleStyle =
        (input['module_style'] as String?) ?? 'square';
    final String? logoBase64 = input['logo_base64'] as String?;

    try {
      final qrValidationResult = QrValidator.validate(
        data: content,
        version: QrVersions.auto,
        errorCorrectionLevel: logoBase64 != null
            ? QrErrorCorrectLevel.H
            : QrErrorCorrectLevel.M,
      );

      if (qrValidationResult.status != QrValidationStatus.valid) {
        return ToolResult.error('Conteúdo inválido para gerar QR Code.',
            code: 'INVALID_INPUT');
      }

      final qrCode = qrValidationResult.qrCode!;
      // A partir do qr 3.x, isDark vive em QrImage, não em QrCode.
      final qrImage = QrImage(qrCode);

      final bytes = await _paintCustomQr(
        qrImage: qrImage,
        size: size,
        fgColor: fgColor,
        bgColor: bgColor,
        gradientColor: gradientColor,
        eyeStyle: eyeStyle,
        moduleStyle: moduleStyle,
        logoBase64: logoBase64,
      );

      return ToolResult.ok({
        'image_base64': base64Encode(bytes),
        'size': size,
      });
    } catch (e) {
      return ToolResult.error('Erro ao gerar QR Code: $e',
          code: 'GENERATION_ERROR');
    }
  }

  static Future<Uint8List> _paintCustomQr({
    required QrImage qrImage,
    required double size,
    required Color fgColor,
    required Color bgColor,
    required Color? gradientColor,
    required String eyeStyle,
    required String moduleStyle,
    required String? logoBase64,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    // Fundo
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size, size), Paint()..color = bgColor);

    final moduleCount = qrImage.moduleCount;
    final cellSize = size / moduleCount;

    final paint = Paint()..style = PaintingStyle.fill;
    if (gradientColor != null) {
      paint.shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(size, size),
        [fgColor, gradientColor],
      );
    } else {
      paint.color = fgColor;
    }

    // Posições dos 3 "olhos" (top-left, top-right, bottom-left) —
    // desenhados separadamente para permitir estilo diferente do
    // resto dos módulos.
    final eyePositions = <Offset>[
      const Offset(0, 0),
      Offset((moduleCount - 7).toDouble(), 0),
      Offset(0, (moduleCount - 7).toDouble()),
    ];

    bool _isInsideAnyEye(int x, int y) {
      for (final eyePos in eyePositions) {
        if (x >= eyePos.dx &&
            x < eyePos.dx + 7 &&
            y >= eyePos.dy &&
            y < eyePos.dy + 7) {
          return true;
        }
      }
      return false;
    }

    // Módulos normais (fora dos olhos). isDark(row, col) agora vive
    // em QrImage (pacote qr >= 3.0.0), não mais em QrCode.
    for (int x = 0; x < moduleCount; x++) {
      for (int y = 0; y < moduleCount; y++) {
        if (!qrImage.isDark(y, x)) continue;
        if (_isInsideAnyEye(x, y)) continue;

        final rect =
            Rect.fromLTWH(x * cellSize, y * cellSize, cellSize, cellSize);
        _drawModule(canvas, rect, paint, moduleStyle);
      }
    }

    // Olhos (estilo separado)
    for (final eyePos in eyePositions) {
      _drawEye(canvas, eyePos, cellSize, paint, eyeStyle, bgColor);
    }

    // Logo central, se fornecido
    if (logoBase64 != null) {
      try {
        final logoBytes = base64Decode(logoBase64);
        final codec = await ui.instantiateImageCodec(logoBytes);
        final frame = await codec.getNextFrame();
        final logoSize = size * 0.2;
        final logoRect = Rect.fromCenter(
          center: Offset(size / 2, size / 2),
          width: logoSize,
          height: logoSize,
        );
        // Fundo branco atrás do logo para legibilidade do QR
        canvas.drawRect(logoRect.inflate(6), Paint()..color = bgColor);
        canvas.drawImageRect(
          frame.image,
          Rect.fromLTWH(
            0,
            0,
            frame.image.width.toDouble(),
            frame.image.height.toDouble(),
          ),
          logoRect,
          Paint(),
        );
      } catch (_) {
        // Logo inválido — segue sem logo em vez de falhar o QR inteiro.
      }
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return byteData!.buffer.asUint8List();
  }

  static void _drawModule(
      Canvas canvas, Rect rect, Paint paint, String style) {
    switch (style) {
      case 'dot':
        canvas.drawCircle(rect.center, rect.width / 2.4, paint);
        break;
      case 'rounded':
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            rect.deflate(rect.width * 0.05),
            Radius.circular(rect.width * 0.3),
          ),
          paint,
        );
        break;
      case 'square':
      default:
        canvas.drawRect(rect, paint);
    }
  }

  static void _drawEye(
    Canvas canvas,
    Offset moduleOffset,
    double cellSize,
    Paint paint,
    String style,
    Color bgColor,
  ) {
    final outerRect = Rect.fromLTWH(
      moduleOffset.dx * cellSize,
      moduleOffset.dy * cellSize,
      cellSize * 7,
      cellSize * 7,
    );
    final innerRect = outerRect.deflate(cellSize * 2);

    // Cor de "furo" dos olhos usa a cor de fundo real (não branco
    // fixo), para o QR não ficar com "buracos" brancos caso o fundo
    // seja customizado.
    final holePaint = Paint()..color = bgColor;

    switch (style) {
      case 'circle':
        canvas.drawOval(outerRect, paint);
        canvas.drawOval(innerRect.deflate(cellSize * 0.2), holePaint);
        canvas.drawOval(innerRect.deflate(cellSize * 1.2), paint);
        break;
      case 'rounded':
        canvas.drawRRect(
          RRect.fromRectAndRadius(outerRect, Radius.circular(cellSize * 2)),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            innerRect.deflate(cellSize * 0.2),
            Radius.circular(cellSize * 1.5),
          ),
          holePaint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            innerRect.deflate(cellSize * 1.2),
            Radius.circular(cellSize),
          ),
          paint,
        );
        break;
      case 'square':
      default:
        canvas.drawRect(outerRect, paint);
        canvas.drawRect(innerRect.deflate(cellSize * 0.2), holePaint);
        canvas.drawRect(innerRect.deflate(cellSize * 1.2), paint);
    }
  }

  static Color? _parseHexColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceAll('#', '');
    final value = int.tryParse(
      cleaned.length == 6 ? 'FF$cleaned' : cleaned,
      radix: 16,
    );
    return value != null ? Color(value) : null;
  }
}