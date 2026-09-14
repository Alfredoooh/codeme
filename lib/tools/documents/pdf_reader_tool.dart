// lib/tools/documents/pdf_reader_tool.dart  (IMPLEMENTADO — sem placeholders)
//
// read_pdf_contents
//
// Extrai texto e contagem de páginas de um PDF existente via
// syncfusion_flutter_pdf (PdfTextExtractor).

import 'dart:convert';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../shared/tool_result.dart';
import '../server/tools_queue.dart';

class PdfReaderTool {
  /// read_pdf_contents
  /// input: { pdf_base64: String }
  static Future<ToolResult> readPdfContents(Map<String, dynamic> input) {
    return ToolsQueue.instance.enqueue(() => _readImpl(input));
  }

  static Future<ToolResult> _readImpl(Map<String, dynamic> input) async {
    final String? pdfBase64 = input['pdf_base64'] as String?;
    if (pdfBase64 == null || pdfBase64.isEmpty) {
      return ToolResult.error('Parâmetro "pdf_base64" é obrigatório.', code: 'INVALID_INPUT');
    }

    PdfDocument? doc;
    try {
      final bytes = base64Decode(pdfBase64);
      doc = PdfDocument(inputBytes: bytes);

      final extractor = PdfTextExtractor(doc);
      final String fullText = extractor.extractText();
      final int pageCount = doc.pages.count;

      return ToolResult.ok({
        'text': fullText,
        'page_count': pageCount,
        'byte_size': bytes.length,
      });
    } catch (e) {
      return ToolResult.error('Erro ao ler PDF: $e', code: 'READ_ERROR');
    } finally {
      doc?.dispose();
    }
  }
}