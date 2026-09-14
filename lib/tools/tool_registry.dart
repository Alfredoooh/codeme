=====================================================================
lib/tools/tool_registry.dart  (ATUALIZADO — inclui datetime e shell)
=====================================================================

import 'shared/tool_result.dart';

import 'documents/pdf_tools.dart';
import 'documents/pdf_merge_split_tools.dart';
import 'documents/pdf_reader_tool.dart';
import 'documents/docx_tools.dart';
import 'documents/pptx_tools.dart';
import 'documents/xlsx_tools.dart';

import 'images/qrcode_tool.dart';
import 'images/barcode_tool.dart';
import 'images/image_format_tool.dart';
import 'images/image_resize_crop_tools.dart';
import 'images/image_watermark_tool.dart';
import 'images/ocr_tool.dart';
import 'images/table_image_tool.dart';
import 'images/html_to_image_tool.dart';

import 'charts/chart_tool.dart';
import 'charts/function_plot_tool.dart';
import 'charts/math_sheet_tool.dart';

import 'mindmap/mindmap_tool.dart';

import 'files/file_creation_tool.dart';
import 'files/zip_reader_tool.dart';

import 'text/str_replace_tool.dart';
import 'text/diff_text_tool.dart';
import 'text/url_extractor_tool.dart';
import 'text/token_estimate_tool.dart';
import 'text/text_stats_tool.dart';

import 'datetime/datetime_tool.dart';
import 'shell/shell_tool.dart';

Future<ToolResult> runTool(String name, Map<String, dynamic> input) async {
  try {
    switch (name) {
      // ── Documentos ──────────────────────────────────────
      case 'create_pdf':
        return await PdfTools.createPdf(input);
      case 'create_pdf_structured':
        return await PdfTools.createPdfStructured(input);
      case 'merge_pdfs':
        return await PdfMergeSplitTools.mergePdfs(input);
      case 'split_pdf_pages':
        return await PdfMergeSplitTools.splitPdfPages(input);
      case 'read_pdf_contents':
        return await PdfReaderTool.readPdfContents(input);
      case 'create_docx':
        return await DocxTools.createDocx(input);
      case 'create_pptx':
        return await PptxTools.createPptx(input);
      case 'create_xlsx':
        return await XlsxTools.createXlsx(input);
      case 'csv_to_xlsx':
        return await XlsxTools.csvToXlsx(input);
      case 'xlsx_to_json':
        return await XlsxTools.xlsxToJson(input);

      // ── Imagens ─────────────────────────────────────────
      case 'generate_qrcode':
        return await QrcodeTool.generate(input);
      case 'generate_barcode':
        return await BarcodeTool.generate(input);
      case 'convert_image_format':
        return await ImageFormatTool.convert(input);
      case 'resize_image':
        return await ImageResizeCropTools.resize(input);
      case 'crop_image':
        return await ImageResizeCropTools.crop(input);
      case 'watermark_image':
        return await ImageWatermarkTool.apply(input);
      case 'ocr_extract_text':
        return await OcrTool.extractText(input);
      case 'generate_table_image':
        return await TableImageTool.generate(input);
      case 'render_html_to_image':
        return await HtmlToImageTool.render(input);

      // ── Charts ──────────────────────────────────────────
      case 'generate_chart':
        return await ChartTool.generate(input);
      case 'generate_function_plot':
        return await FunctionPlotTool.generate(input);
      case 'generate_math_sheet':
        return await MathSheetTool.generate(input);

      // ── Mindmap ─────────────────────────────────────────
      case 'generate_mindmap':
        return await MindmapTool.generate(input);

      // ── Arquivos ────────────────────────────────────────
      case 'create_file':
        return await FileCreationTool.create(input);
      case 'read_zip_contents':
        return await ZipReaderTool.readContents(input);

      // ── Texto ───────────────────────────────────────────
      case 'str_replace_file':
        return StrReplaceTool.replace(input);
      case 'diff_text':
        return DiffTextTool.diff(input);
      case 'extract_urls_from_text':
        return UrlExtractorTool.extract(input);
      case 'count_tokens_estimate':
        return TokenEstimateTool.estimate(input);
      case 'text_summary_stats':
        return TextStatsTool.summarize(input);

      // ── Data/Hora ───────────────────────────────────────
      case 'get_current_datetime':
        return DateTimeTool.getCurrentDateTime(input);

      // ── Shell ───────────────────────────────────────────
      case 'run_shell_command':
        return await ShellTool.run(input);

      default:
        return ToolResult.error('Tool desconhecida: "$name"', code: 'UNKNOWN_TOOL');
    }
  } catch (e, st) {
    return ToolResult.error('Erro inesperado ao executar "$name": $e\n$st', code: 'UNEXPECTED_ERROR');
  }
}