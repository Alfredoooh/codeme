// lib/tools/images/image_resize_crop_tools.dart

// resize_image, crop_image
//
// Usa dart:ui diretamente (decode + draw) — não precisa de lib
// externa de imagem, o Flutter já resolve nativamente via Skia.

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Rect, Paint;

import '../shared/tool_result.dart';

class ImageResizeCropTools {
  /// resize_image
  /// input: { image_base64: String, width: number, height: number }
  static Future<ToolResult> resize(Map<String, dynamic> input) async {
    final String? imageBase64 = input['image_base64'] as String?;
    final num? width = input['width'] as num?;
    final num? height = input['height'] as num?;

    if (imageBase64 == null || width == null || height == null) {
      return ToolResult.error('Parâmetros "image_base64", "width" e "height" são obrigatórios.', code: 'INVALID_INPUT');
    }

    try {
      final bytes = base64Decode(imageBase64);
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: width.toInt(),
        targetHeight: height.toInt(),
      );
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      frame.image.dispose();

      return ToolResult.ok({
        'image_base64': base64Encode(byteData!.buffer.asUint8List()),
        'width': width,
        'height': height,
      });
    } catch (e) {
      return ToolResult.error('Erro ao redimensionar imagem: $e', code: 'PROCESSING_ERROR');
    }
  }

  /// crop_image
  /// input: { image_base64: String, left: number, top: number, width: number, height: number }
  static Future<ToolResult> crop(Map<String, dynamic> input) async {
    final String? imageBase64 = input['image_base64'] as String?;
    final num? left = input['left'] as num?;
    final num? top = input['top'] as num?;
    final num? width = input['width'] as num?;
    final num? height = input['height'] as num?;

    if (imageBase64 == null || left == null || top == null || width == null || height == null) {
      return ToolResult.error('Parâmetros "image_base64", "left", "top", "width" e "height" são obrigatórios.', code: 'INVALID_INPUT');
    }

    try {
      final bytes = base64Decode(imageBase64);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      final srcImage = frame.image;

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final srcRect = Rect.fromLTWH(left.toDouble(), top.toDouble(), width.toDouble(), height.toDouble());
      final dstRect = Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());

      canvas.drawImageRect(srcImage, srcRect, dstRect, Paint());
      final picture = recorder.endRecording();
      final croppedImage = await picture.toImage(width.toInt(), height.toInt());

      final byteData = await croppedImage.toByteData(format: ui.ImageByteFormat.png);
      srcImage.dispose();
      croppedImage.dispose();

      return ToolResult.ok({
        'image_base64': base64Encode(byteData!.buffer.asUint8List()),
        'width': width,
        'height': height,
      });
    } catch (e) {
      return ToolResult.error('Erro ao recortar imagem: $e', code: 'PROCESSING_ERROR');
    }
  }
}