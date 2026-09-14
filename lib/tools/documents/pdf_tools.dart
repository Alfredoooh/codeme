// lib/tools/documents/pdf_tools.dart

// create_pdf, create_pdf_structured
//
// ESTRATÉGIA: gerar PDF a partir de HTML/CSS formatado, não montando
// o PDF campo a campo no pacote `pdf`. Isso permite documentos ricos
// (tabelas, estilos, layout complexo) com fidelidade real.
//
// flutter_inappwebview (já presente no pubspec) tem suporte nativo a
// exportação de PDF a partir do conteúdo renderizado da WebView, via
// InAppWebViewController.createPdf() (Android/iOS). É a forma mais
// fiel de converter HTML complexo em PDF sem reescrever um motor de
// layout CSS em Dart puro.
//
// NOTA (flutter_inappwebview 6.1.5): o parâmetro iosWKPdfConfiguration
// está deprecated em favor de pdfConfiguration (classe
// PDFConfiguration), que é multiplataforma e não só iOS.
//
// Este arquivo depende de server/tools_queue.dart para garantir que
// apenas uma renderização aconteça por vez (ver discussão de RAM/fila
// serial já feita na conversa).

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import '../shared/tool_result.dart';
import '../server/tools_queue.dart';

class PdfTools {
  // Instância única de HeadlessInAppWebView, reaproveitada entre
  // chamadas — nunca cria uma nova WebView por requisição.
  static HeadlessInAppWebView? _headlessWebView;
  static InAppWebViewController? _controller;

  static const int _renderTimeoutMs = 20000;

  /// create_pdf
  /// input: { html: String, page_format?: String }
  static Future<ToolResult> createPdf(Map<String, dynamic> input) {
    return ToolsQueue.instance.enqueue(() => _renderHtmlToPdf(input));
  }

  /// create_pdf_structured
  /// input: { title?: String, html: String }
  /// Diferença de create_pdf: injeta um wrapper de estilo padrão
  /// (título + margens consistentes) antes de renderizar, garantindo
  /// aparência de "documento estruturado" mesmo que o HTML de entrada
  /// seja só um corpo solto.
  static Future<ToolResult> createPdfStructured(Map<String, dynamic> input) {
    final String rawHtml = (input['html'] as String?) ?? '';
    final String? title = input['title'] as String?;

    final wrappedHtml = '''
<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<style>
  body { font-family: -apple-system, Arial, sans-serif; margin: 40px; color: #1a1a1a; }
  h1.doc-title { font-size: 24px; margin-bottom: 24px; border-bottom: 2px solid #333; padding-bottom: 8px; }
  table { border-collapse: collapse; width: 100%; margin: 16px 0; }
  th, td { border: 1px solid #ccc; padding: 8px 12px; text-align: left; }
  th { background: #f2f2f2; }
</style>
</head>
<body>
  ${title != null ? '<h1 class="doc-title">$title</h1>' : ''}
  $rawHtml
</body>
</html>
''';

    return ToolsQueue.instance.enqueue(
      () => _renderHtmlToPdf({...input, 'html': wrappedHtml}),
    );
  }

  static Future<ToolResult> _renderHtmlToPdf(Map<String, dynamic> input) async {
    final String? html = input['html'] as String?;
    if (html == null || html.trim().isEmpty) {
      return ToolResult.error('Parâmetro "html" é obrigatório.', code: 'INVALID_INPUT');
    }

    try {
      final Uint8List? pdfBytes = await _renderInHeadlessWebView(html)
          .timeout(const Duration(milliseconds: _renderTimeoutMs));

      if (pdfBytes == null) {
        return ToolResult.error('Falha ao gerar PDF: retorno vazio.', code: 'RENDER_FAILED');
      }

      return ToolResult.ok({
        'pdf_base64': base64EncodeBytes(pdfBytes),
        'size_bytes': pdfBytes.length,
      });
    } on TimeoutException {
      return ToolResult.error('Timeout ao renderizar PDF.', code: 'TIMEOUT');
    } catch (e) {
      return ToolResult.error('Erro ao gerar PDF: $e', code: 'RENDER_ERROR');
    } finally {
      // Libera a WebView headless após cada geração — PDF costuma
      // ser conteúdo maior/mais pesado que uma captura de imagem
      // simples, então não vale a pena mantê-la viva entre chamadas.
      await _disposeHeadlessWebView();
    }
  }

  static Future<Uint8List?> _renderInHeadlessWebView(String html) async {
    final completer = Completer<Uint8List?>();

    _headlessWebView = HeadlessInAppWebView(
      initialData: InAppWebViewInitialData(data: html, mimeType: 'text/html'),
      onWebViewCreated: (controller) {
        _controller = controller;
      },
      onLoadStop: (controller, url) async {
        try {
          // Pequeno delay para garantir que fontes/imagens/CSS
          // terminaram de aplicar antes de exportar.
          await Future.delayed(const Duration(milliseconds: 300));
          final pdfBytes = await controller.createPdf(
            pdfConfiguration: PDFConfiguration(),
          );
          if (!completer.isCompleted) completer.complete(pdfBytes);
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
      onReceivedError: (controller, request, error) {
        if (!completer.isCompleted) {
          completer.completeError('Erro ao carregar HTML: ${error.description}');
        }
      },
    );

    await _headlessWebView!.run();
    return completer.future;
  }

  static Future<void> _disposeHeadlessWebView() async {
    await _headlessWebView?.dispose();
    _headlessWebView = null;
    _controller = null;
  }
}

// Helper local — evita import direto de dart:convert espalhado.
String base64EncodeBytes(Uint8List bytes) {
  return const Base64Encoder().convert(bytes);
}