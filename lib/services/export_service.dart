// ══════════════════════════════════════════════════════════════
// FILE: lib/exportservice.dart
// ══════════════════════════════════════════════════════════════
//
// ATUALIZAÇÃO: Toda a lógica de exportação foi movida para o
// servidor de tools (ToolsApiService). O cliente apenas envia o
// conteúdo e recebe os bytes em base64, sem processamento local.
// ══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../features/apps/app_types.dart' show LocalCanvasItem, LocalCanvasKind;
// TODO: depende de api_service.dart (split futuro); manter este import para a etapa futura de split.

// TODO: depende de api_service.dart (split futuro); manter este import para a etapa futura de split.
import 'api_service.dart' show ToolsApiService, ApiException;
import 'auth_service.dart' show authController;


class ExportService {
  static Future<Uint8List> export({
    required LocalCanvasItem item,
    required String format,
  }) async {
    final token = authController.token;
    if (token == null) {
      throw Exception('Sessão expirada. Inicia sessão novamente.');
    }

    switch (item.kind) {
      case LocalCanvasKind.doc:
        return _exportDoc(token, item, format);
      case LocalCanvasKind.sheet:
        return _exportSheet(token, item, format);
      case LocalCanvasKind.slide:
        return _exportSlide(token, item, format);
      default:
        throw Exception('Tipo de documento não suportado');
    }
  }

  // ── Documento (HTML) ────────────────────────────────────────
  static Future<Uint8List> _exportDoc(
    String token,
    LocalCanvasItem item,
    String format,
  ) async {
    final htmlContent = item.content;
    switch (format) {
      case 'pdf':
        return await _callToolAndGetBytes(
          token: token,
          name: 'html_to_pdf',
          input: {'html_content': htmlContent, 'title': item.title},
        );
      case 'docx':
        return await _callToolAndGetBytes(
          token: token,
          name: 'html_to_docx',
          input: {'html_content': htmlContent, 'filename': item.title},
        );
      case 'xlsx':
        return await _callToolAndGetBytes(
          token: token,
          name: 'html_to_xlsx',
          input: {'html_content': htmlContent, 'sheet_name': item.title},
        );
      case 'pptx':
        return await _callToolAndGetBytes(
          token: token,
          name: 'html_to_pptx',
          input: {'html_content': htmlContent, 'title': item.title},
        );
      default:
        throw Exception('Formato "$format" não suportado para documentos');
    }
  }

  // ── Folha de cálculo ─────────────────────────────────────────
  static Future<Uint8List> _exportSheet(
    String token,
    LocalCanvasItem item,
    String format,
  ) async {
    if (format != 'xlsx') {
      throw Exception('Formato "$format" não suportado para folhas de cálculo');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(item.content) as Map<String, dynamic>;
    } catch (_) {
      data = {};
    }
    final cells = (data['cells'] as Map<String, dynamic>?) ?? {};

    // Extrai headers e rows no formato esperado pela tool create_xlsx
    int maxRow = 0;
    int maxCol = 0;
    final cellRefRe = RegExp(r'^([A-Z]+)(\d+)$');
    for (final key in cells.keys) {
      final m = cellRefRe.firstMatch(key);
      if (m == null) continue;
      final row = int.parse(m.group(2)!);
      final col = _colLettersToIndex(m.group(1)!);
      if (row > maxRow) maxRow = row;
      if (col > maxCol) maxCol = col;
    }

    final headers = <String>[];
    final rows = <List<String>>[];

    if (maxRow > 0) {
      // primeira linha como cabeçalho
      for (int c = 0; c <= maxCol; c++) {
        final ref = '${_indexToColLetters(c)}1';
        final cell = cells[ref] as Map<String, dynamic>?;
        headers.add(cell?['value']?.toString() ?? '');
      }
      // restantes linhas
      for (int r = 2; r <= maxRow; r++) {
        final row = <String>[];
        for (int c = 0; c <= maxCol; c++) {
          final ref = '${_indexToColLetters(c)}$r';
          final cell = cells[ref] as Map<String, dynamic>?;
          row.add(cell?['value']?.toString() ?? '');
        }
        rows.add(row);
      }
    }

    return await _callToolAndGetBytes(
      token: token,
      name: 'create_xlsx',
      input: {'headers': headers, 'rows': rows},
    );
  }

  // ── Apresentação ─────────────────────────────────────────────
  static Future<Uint8List> _exportSlide(
    String token,
    LocalCanvasItem item,
    String format,
  ) async {
    if (format != 'pptx') {
      throw Exception('Formato "$format" não suportado para apresentações');
    }

    Map<String, dynamic> data;
    try {
      data = jsonDecode(item.content) as Map<String, dynamic>;
    } catch (_) {
      data = {};
    }
    final slides = (data['slides'] as List?) ?? [];

    // Converte slides para o formato esperado pela tool create_pptx
    final convertedSlides = slides.map((slideRaw) {
      final slide = slideRaw as Map<String, dynamic>;
      final elements = (slide['elements'] as List?) ?? [];
      final bullets = <String>[];
      String? heading;
      for (final elRaw in elements) {
        final el = elRaw as Map<String, dynamic>;
        if (el['type'] == 'text') {
          final html = el['html']?.toString() ?? '';
          final plain = _stripHtml(html);
          if (heading == null) {
            heading = plain;
          } else {
            bullets.add(plain);
          }
        }
      }
      return {
        'heading': heading ?? '',
        'bullets': bullets,
      };
    }).toList();

    return await _callToolAndGetBytes(
      token: token,
      name: 'create_pptx',
      input: {'title': item.title, 'slides': convertedSlides},
    );
  }

  // ── Helpers ─────────────────────────────────────────────────
  static Future<Uint8List> _callToolAndGetBytes({
    required String token,
    required String name,
    required Map<String, dynamic> input,
  }) async {
    final result = await ToolsApiService.executeTool(
      token: token,
      name: name,
      input: input,
    );
    final base64 = result['content_base64']?.toString();
    if (base64 == null || base64.isEmpty) {
      throw Exception('Servidor não devolveu conteúdo');
    }
    try {
      return base64Decode(base64);
    } catch (_) {
      throw Exception('Base64 inválido recebido do servidor');
    }
  }

  static int _colLettersToIndex(String letters) {
    int result = 0;
    for (int i = 0; i < letters.length; i++) {
      result = result * 26 + (letters.codeUnitAt(i) - 65 + 1);
    }
    return result - 1;
  }

  static String _indexToColLetters(int index) {
    var n = index + 1;
    var result = '';
    while (n > 0) {
      final rem = (n - 1) % 26;
      result = String.fromCharCode(65 + rem) + result;
      n = (n - 1) ~/ 26;
    }
    return result;
  }

  static String _stripHtml(String html) =>
      html.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  // Partilha bytes usando o share_plus
  static Future<void> shareBytes(
    Uint8List bytes, {
    required String filename,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: filename);
  }
}
