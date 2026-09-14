// lib/tools/images/html_to_image_tool.dart
//
// render_html_to_image
//
// Converte HTML formatado em imagem PNG. A IA decide a dimensão —
// `width`/`height` são OPCIONAIS: se não vierem no input, a tool
// mede a altura real do conteúdo renderizado e usa isso como
// dimensão final.
//
// API flutter_inappwebview 6.x:
//   - HeadlessInAppWebView usa `initialSize:` (NÃO `size:`).
//   - Não existe mais `controller.setSize` — redimensão é feita em
//     `headless.setSize(...)`.
//   - `headless` é anulável: use `?.run()` / `?.dispose()`.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Size;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../shared/tool_result.dart';
import '../server/tools_queue.dart';

class HtmlToImageTool {
  static const int _renderTimeoutMs = 15000;
  static const double _defaultWidth = 800;
  static const double _maxWidth = 2000;
  static const double _maxHeight = 4000;
  static const double _maxPixelRatio = 2.0;

  /// render_html_to_image
  /// input: {
  ///   html: String (obrigatório),
  ///   width?: number   — se omitido, usa _defaultWidth,
  ///   height?: number  — se omitido, a tool MEDE a altura real do
  ///                       conteúdo renderizado e usa esse valor,
  ///   scale?: number   — pixel ratio, capado em _maxPixelRatio,
  /// }
  static Future<ToolResult> render(Map<String, dynamic> input) {
    return ToolsQueue.instance.enqueue(() => _renderImpl(input));
  }

  static Future<ToolResult> _renderImpl(Map<String, dynamic> input) async {
    final String? html = input['html'] as String?;
    if (html == null || html.trim().isEmpty) {
      return ToolResult.error('Parâmetro "html" é obrigatório.',
          code: 'INVALID_INPUT');
    }

    double width = (input['width'] as num?)?.toDouble() ?? _defaultWidth;
    width = width.clamp(100, _maxWidth);

    final double? requestedHeight = (input['height'] as num?)?.toDouble();
    final double scale = ((input['scale'] as num?)?.toDouble() ?? 2.0)
        .clamp(1.0, _maxPixelRatio);

    try {
      final result = await _runHeadless(
        html: html,
        width: width,
        requestedHeight: requestedHeight,
        scale: scale,
      ).timeout(Duration(milliseconds: _renderTimeoutMs));

      return ToolResult.ok({
        'image_base64': base64Encode(result.bytes),
        'width': result.width,
        'height': result.height,
        'auto_sized': requestedHeight == null,
      });
    } on TimeoutException {
      return ToolResult.error('Timeout ao renderizar HTML em imagem.',
          code: 'TIMEOUT');
    } catch (e) {
      return ToolResult.error('Erro ao renderizar HTML: $e',
          code: 'RENDER_ERROR');
    }
  }

  static Future<_RenderOutput> _runHeadless({
    required String html,
    required double width,
    required double? requestedHeight,
    required double scale,
  }) async {
    final completer = Completer<_RenderOutput>();

    late final HeadlessInAppWebView headless;

    headless = HeadlessInAppWebView(
      // v6: parâmetro é `initialSize:` (não `size:`).
      initialSize: Size(width, requestedHeight ?? 600),
      initialData: InAppWebViewInitialData(data: html, mimeType: 'text/html'),
      initialSettings: InAppWebViewSettings(
        transparentBackground: true,
        disableHorizontalScroll: true,
        disableVerticalScroll: true,
        supportZoom: false,
        javaScriptEnabled: true,
      ),
      onLoadStop: (controller, url) async {
        try {
          await Future.delayed(const Duration(milliseconds: 250));

          double finalHeight = requestedHeight ?? 600;

          if (requestedHeight == null) {
            final measured = await controller.evaluateJavascript(
              source: 'document.body.scrollHeight',
            );
            final measuredHeight =
                (measured is num) ? measured.toDouble() : null;
            if (measuredHeight != null && measuredHeight > 0) {
              finalHeight = measuredHeight.clamp(100, _maxHeight);
              // v6: redimensão é no HeadlessInAppWebView (não existe
              // mais controller.setSize).
              await headless.setSize(Size(width, finalHeight));
              await Future.delayed(const Duration(milliseconds: 150));
            }
          }

          final Uint8List? screenshot = await controller.takeScreenshot(
            screenshotConfiguration: ScreenshotConfiguration(
              compressFormat: CompressFormat.PNG,
            ),
          );

          if (screenshot == null) {
            if (!completer.isCompleted) {
              completer.completeError('Captura retornou vazia.');
            }
            return;
          }

          if (!completer.isCompleted) {
            completer.complete(_RenderOutput(
              bytes: screenshot,
              width: width,
              height: finalHeight,
            ));
          }
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        } finally {
          await headless.dispose();
        }
      },
      onReceivedError: (controller, request, error) {
        if (!completer.isCompleted) {
          completer.completeError(
              'Erro ao carregar HTML: ${error.description}');
        }
      },
    );

    await headless.run();
    return completer.future;
  }
}

class _RenderOutput {
  final Uint8List bytes;
  final double width;
  final double height;

  _RenderOutput({
    required this.bytes,
    required this.width,
    required this.height,
  });
}