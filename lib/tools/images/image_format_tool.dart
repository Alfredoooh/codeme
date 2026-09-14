=====================================================================
lib/tools/images/image_format_tool.dart
=====================================================================

// convert_image_format
//
// Usa flutter_image_compress (já presente no pubspec) para conversão
// entre formatos comuns (PNG, JPEG, WebP, HEIC quando suportado pela
// plataforma).

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../shared/tool_result.dart';

class ImageFormatTool {
  /// convert_image_format
  /// input: { image_base64: String, target_format: String — "png"|"jpeg"|"webp" }
  static Future<ToolResult> convert(Map<String, dynamic> input) async {
    final String? imageBase64 = input['image_base64'] as String?;
    final String? targetFormat = input['target_format'] as String?;

    if (imageBase64 == null || targetFormat == null) {
      return ToolResult.error('Parâmetros "image_base64" e "target_format" são obrigatórios.', code: 'INVALID_INPUT');
    }

    try {
      final inputBytes = base64Decode(imageBase64);
      final format = _resolveFormat(targetFormat);

      final Uint8List? result = await FlutterImageCompress.compressWithList(
        inputBytes,
        format: format,
        quality: 90,
      );

      if (result == null) {
        return ToolResult.error('Falha na conversão de formato.', code: 'CONVERSION_ERROR');
      }

      return ToolResult.ok({
        'image_base64': base64Encode(result),
        'format': targetFormat,
        'size_bytes': result.length,
      });
    } catch (e) {
      return ToolResult.error('Erro ao converter formato: $e', code: 'CONVERSION_ERROR');
    }
  }

  static CompressFormat _resolveFormat(String format) {
    switch (format.toLowerCase()) {
      case 'jpeg':
      case 'jpg':
        return CompressFormat.jpeg;
      case 'webp':
        return CompressFormat.webp;
      case 'png':
      default:
        return CompressFormat.png;
    }
  }
}