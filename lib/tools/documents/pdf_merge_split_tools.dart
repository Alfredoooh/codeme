=====================================================================
lib/tools/documents/pdf_merge_split_tools.dart  (IMPLEMENTADO — sem placeholders)
=====================================================================

// merge_pdfs, split_pdf_pages
//
// Operam sobre PDFs JÁ EXISTENTES (bytes) — manipulação de baixo
// nível via syncfusion_flutter_pdf (adicionado ao pubspec.yaml).

import 'dart:typed_data';
import 'dart:convert';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../shared/tool_result.dart';
import '../server/tools_queue.dart';

class PdfMergeSplitTools {
  /// merge_pdfs
  /// input: { pdfs_base64: List<String> }
  static Future<ToolResult> mergePdfs(Map<String, dynamic> input) {
    return ToolsQueue.instance.enqueue(() => _mergePdfsImpl(input));
  }

  static Future<ToolResult> _mergePdfsImpl(Map<String, dynamic> input) async {
    final List<dynamic>? pdfsBase64 = input['pdfs_base64'] as List<dynamic>?;
    if (pdfsBase64 == null || pdfsBase64.length < 2) {
      return ToolResult.error(
        'É necessário fornecer ao menos 2 PDFs em "pdfs_base64".',
        code: 'INVALID_INPUT',
      );
    }

    final merged = PdfDocument();
    final openedDocs = <PdfDocument>[];

    try {
      int totalPages = 0;

      for (final b64 in pdfsBase64) {
        final bytes = base64Decode(b64 as String);
        final doc = PdfDocument(inputBytes: bytes);
        openedDocs.add(doc);

        for (int i = 0; i < doc.pages.count; i++) {
          final template = doc.pages[i].createTemplate();
          final newPage = merged.pages.add();
          newPage.graphics.drawPdfTemplate(
            template,
            const Offset(0, 0),
            Size(newPage.getClientSize().width, newPage.getClientSize().height),
          );
          totalPages++;
        }
      }

      final Uint8List result = Uint8List.fromList(await merged.save());

      return ToolResult.ok({
        'pdf_base64': base64Encode(result),
        'pages_merged': totalPages,
        'source_files': pdfsBase64.length,
      });
    } catch (e) {
      return ToolResult.error('Erro ao combinar PDFs: $e', code: 'MERGE_ERROR');
    } finally {
      // Libera memória nativa de TODOS os documentos abertos, mesmo
      // em caso de erro no meio da junção — sem isto, um merge que
      // falha na metade vaza os handles dos PDFs já carregados.
      for (final doc in openedDocs) {
        doc.dispose();
      }
      merged.dispose();
    }
  }

  /// split_pdf_pages
  /// input: { pdf_base64: String, page_numbers: List<int> }
  /// page_numbers é 1-indexado (página 1 = primeira página).
  static Future<ToolResult> splitPdfPages(Map<String, dynamic> input) {
    return ToolsQueue.instance.enqueue(() => _splitPdfPagesImpl(input));
  }

  static Future<ToolResult> _splitPdfPagesImpl(Map<String, dynamic> input) async {
    final String? pdfBase64 = input['pdf_base64'] as String?;
    final List<dynamic>? pageNumbers = input['page_numbers'] as List<dynamic>?;

    if (pdfBase64 == null || pageNumbers == null || pageNumbers.isEmpty) {
      return ToolResult.error(
        'Parâmetros "pdf_base64" e "page_numbers" são obrigatórios.',
        code: 'INVALID_INPUT',
      );
    }

    PdfDocument? source;
    final output = PdfDocument();

    try {
      final bytes = base64Decode(pdfBase64);
      source = PdfDocument(inputBytes: bytes);

      final invalidPages = <int>[];
      for (final pageNum in pageNumbers) {
        final idx = (pageNum as int) - 1;
        if (idx < 0 || idx >= source.pages.count) {
          invalidPages.add(pageNum);
          continue;
        }

        final template = source.pages[idx].createTemplate();
        final newPage = output.pages.add();
        newPage.graphics.drawPdfTemplate(
          template,
          const Offset(0, 0),
          Size(newPage.getClientSize().width, newPage.getClientSize().height),
        );
      }

      if (output.pages.count == 0) {
        return ToolResult.error(
          'Nenhuma página válida encontrada. O PDF tem ${source.pages.count} página(s).',
          code: 'INVALID_INPUT',
        );
      }

      final Uint8List result = Uint8List.fromList(await output.save());

      return ToolResult.ok({
        'pdf_base64': base64Encode(result),
        'pages_extracted': output.pages.count,
        if (invalidPages.isNotEmpty) 'pages_ignored_out_of_range': invalidPages,
      });
    } catch (e) {
      return ToolResult.error('Erro ao dividir PDF: $e', code: 'SPLIT_ERROR');
    } finally {
      source?.dispose();
      output.dispose();
    }
  }
}