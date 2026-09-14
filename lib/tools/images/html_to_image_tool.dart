=====================================================================
lib/tools/images/html_to_image_tool.dart
=====================================================================

// render_html_to_image
//
// Converte HTML formatado em imagem PNG. A IA decide a dimensão —
// ou seja, `width`/`height` são OPCIONAIS: se não vierem no input,
// a tool primeiro mede o conteúdo real renderizado (altura natural
// do HTML a uma largura padrão) e usa isso como dimensão final, em
// vez de forçar um tamanho fixo arbitrário. Isso evita imagens
// cortadas ou com espaço em branco sobrando.
//
// Usa flutter_inappwebview (headless), reaproveitando a mesma lib
// já usada em pdf_tools.dart. WebView headless é liberada logo após
// cada captura — HTML->imagem tende a ser chamado com mais frequência
// que HTML->PDF, então manter isso leve importa mais aqui.

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
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
      return ToolResult.error('Parâmetro "html" é obrigatório.', code: 'INVALID_INPUT');
    }

    double width = (input['width'] as num?)?.toDouble() ?? _defaultWidth;
    width = width.clamp(100, _maxWidth);

    double? requestedHeight = (input['height'] as num?)?.toDouble();
    final double scale =
        ((input['scale'] as num?)?.toDouble() ?? 2.0).clamp(1.0, _maxPixelRatio);

    HeadlessInAppWebView? headless;

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
      return ToolResult.error('Timeout ao renderizar HTML em imagem.', code: 'TIMEOUT');
    } catch (e) {
      return ToolResult.error('Erro ao renderizar HTML: $e', code: 'RENDER_ERROR');
    }
  }

  static Future<_RenderOutput> _runHeadless({
    required String html,
    required double width,
    required double? requestedHeight,
    required double scale,
  }) async {
    final completer = Completer<_RenderOutput>();
    HeadlessInAppWebView? headless;

    headless = HeadlessInAppWebView(
      initialSize: Size(width, requestedHeight ?? 600),
      initialData: InAppWebViewInitialData(data: html, mimeType: 'text/html'),
      onLoadStop: (controller, url) async {
        try {
          await Future.delayed(const Duration(milliseconds: 250));

          double finalHeight = requestedHeight ?? 600;

          // IA não especificou altura -> mede o conteúdo real via JS.
          if (requestedHeight == null) {
            final measured = await controller.evaluateJavascript(
              source: 'document.body.scrollHeight',
            );
            final measuredHeight = (measured is num) ? measured.toDouble() : null;
            if (measuredHeight != null && measuredHeight > 0) {
              finalHeight = measuredHeight.clamp(100, _maxHeight);
              // Redimensiona a view headless para a altura real medida
              // antes de capturar, evitando corte ou espaço sobrando.
              await controller.setSize(Size(width, finalHeight));
              await Future.delayed(const Duration(milliseconds: 150));
            }
          }

          final Uint8List? screenshot = await controller.takeScreenshot(
            screenshotConfiguration: ScreenshotConfiguration(
              compressFormat: CompressFormat.PNG,
            ),
          );

          if (screenshot == null) {
            completer.completeError('Captura retornou vazia.');
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
          await headless?.dispose();
        }
      },
      onReceivedError: (controller, request, error) {
        if (!completer.isCompleted) {
          completer.completeError('Erro ao carregar HTML: ${error.description}');
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

  _RenderOutput({required this.bytes, required this.width, required this.height});
}