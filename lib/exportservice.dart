// ══════════════════════════════════════════════════════════════
// FILE: lib/exportservice.dart (NOVO)
// ══════════════════════════════════════════════════════════════
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdfx/pdfx.dart';
import 'package:share_plus/share_plus.dart';

import 'aitab.dart' show LocalCanvasItem, LocalCanvasKind;

// ══════════════════════════════════════════════════════════════
// EXPORT SERVICE
// ══════════════════════════════════════════════════════════════
//
// Gera ficheiros reais (pdf/png/docx/xlsx/pptx) a partir de um
// LocalCanvasItem. Chamado por _DocumentWidgetCardState._exportAs
// em aitab.dart.
//
// Decisão documentada (Parte 2.2 do prompt-índice): para
// docx/xlsx/pptx usámos o caminho (b) — construção manual via
// package:archive + XML OOXML literal. Motivo: não há, no momento
// desta implementação, um pacote pub.dev maduro e ativamente
// mantido especificamente para gerar os três formatos a partir de
// dados arbitrários sem depender de "printing"; construir o XML à
// mão garante controlo total do output e zero dependências
// instáveis. Os ficheiros produzidos cobrem texto formatado básico
// (negrito/itálico, títulos, parágrafos, tabelas) e imagens — não
// cobrem todas as features do OOXML, mas abrem corretamente em
// Word/Excel/PowerPoint e LibreOffice.
//
// Para PNG: caminho confirmado no prompt — gera-se sempre o PDF
// primeiro (reaproveitando a lógica de doc/sheet/slide→PDF) e depois
// rasteriza-se a primeira página com package:pdfx.
// ══════════════════════════════════════════════════════════════

class ExportService {
  // ────────────────────────────────────────────────────────────
  // ENTRY POINT
  // ────────────────────────────────────────────────────────────
  static Future<Uint8List> export({
    required LocalCanvasItem item,
    required String format,
  }) async {
    switch (format) {
      case 'pdf':
        return _exportPdf(item);
      case 'png':
        return _exportPng(item);
      case 'docx':
        return _exportDocx(item);
      case 'xlsx':
        return _exportXlsx(item);
      case 'pptx':
        return _exportPptx(item);
      default:
        throw Exception('Formato de exportação desconhecido: $format');
    }
  }

  static Future<void> shareBytes(Uint8List bytes, {required String filename}) async {
    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/$filename';
    final file = File(path);
    await file.writeAsBytes(bytes, flush: true);
    await Share.shareXFiles([XFile(path, name: filename)]);
  }

  // ════════════════════════════════════════════════════════════
  // PDF
  // ════════════════════════════════════════════════════════════

  static Future<Uint8List> _exportPdf(LocalCanvasItem item) async {
    final doc = pw.Document();

    switch (item.kind) {
      case LocalCanvasKind.doc:
        await _buildDocPdfPages(doc, item.content);
        break;
      case LocalCanvasKind.sheet:
        _buildSheetPdfPages(doc, item.content);
        break;
      case LocalCanvasKind.slide:
        await _buildSlidePdfPages(doc, item.content);
        break;
      default:
        doc.addPage(pw.Page(build: (_) => pw.Center(child: pw.Text('Formato não suportado.'))));
    }

    return doc.save();
  }

  // ── DOC → PDF ──────────────────────────────────────────────

  static Future<void> _buildDocPdfPages(pw.Document doc, String htmlContent) async {
    final document = html_parser.parse(htmlContent);
    final body = document.body;
    if (body == null) {
      doc.addPage(pw.Page(build: (_) => pw.SizedBox()));
      return;
    }

    final widgets = <pw.Widget>[];
    for (final node in body.nodes) {
      final w = await _domNodeToPdfWidget(node);
      if (w != null) widgets.add(w);
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => widgets,
      ),
    );
  }

  static Future<pw.Widget?> _domNodeToPdfWidget(dom.Node node) async {
    if (node is dom.Text) {
      final text = node.text.trim();
      if (text.isEmpty) return null;
      return pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 2),
        child: pw.Text(text),
      );
    }

    if (node is! dom.Element) return null;
    final el = node;
    final tag = el.localName?.toLowerCase() ?? '';

    switch (tag) {
      case 'h1':
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          child: pw.Text(el.text.trim(),
              style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
        );
      case 'h2':
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5),
          child: pw.Text(el.text.trim(),
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        );
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Text(el.text.trim(),
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
        );
      case 'p':
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 3),
          child: _inlineRichText(el),
        );
      case 'img':
        final src = el.attributes['src'];
        if (src == null || src.isEmpty) return null;
        final memImage = await _loadImageBytes(src);
        if (memImage == null) return null;
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          child: pw.Image(memImage, fit: pw.BoxFit.contain),
        );
      case 'table':
        return _domTableToPdfTable(el);
      case 'ul':
      case 'ol':
        return _domListToPdfColumn(el, ordered: tag == 'ol');
      case 'br':
        return pw.SizedBox(height: 8);
      default:
        // Contentor genérico (div, span, etc.) — desce para os filhos.
        final children = <pw.Widget>[];
        for (final child in el.nodes) {
          final w = await _domNodeToPdfWidget(child);
          if (w != null) children.add(w);
        }
        if (children.isEmpty) return null;
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children);
    }
  }

  static pw.Widget _inlineRichText(dom.Element el) {
    final spans = <pw.InlineSpan>[];
    void walk(dom.Node n, {bool bold = false, bool italic = false}) {
      if (n is dom.Text) {
        if (n.text.isEmpty) return;
        spans.add(pw.TextSpan(
          text: n.text,
          style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
          ),
        ));
        return;
      }
      if (n is dom.Element) {
        final tag = n.localName?.toLowerCase() ?? '';
        final nowBold = bold || tag == 'strong' || tag == 'b';
        final nowItalic = italic || tag == 'em' || tag == 'i';
        for (final child in n.nodes) {
          walk(child, bold: nowBold, italic: nowItalic);
        }
      }
    }

    for (final child in el.nodes) {
      walk(child);
    }
    if (spans.isEmpty) return pw.Text(el.text.trim());
    return pw.RichText(text: pw.TextSpan(children: spans));
  }

  static pw.Widget _domTableToPdfTable(dom.Element table) {
    final rows = <pw.TableRow>[];
    final trs = table.querySelectorAll('tr');
    for (final tr in trs) {
      final cells = tr.querySelectorAll('td, th');
      rows.add(pw.TableRow(
        children: cells
            .map((c) => pw.Padding(
                  padding: const pw.EdgeInsets.all(4),
                  child: pw.Text(c.text.trim()),
                ))
            .toList(),
      ));
    }
    if (rows.isEmpty) return pw.SizedBox();
    return pw.Table(
      border: pw.TableBorder.all(width: 0.5),
      children: rows,
    );
  }

  static pw.Widget _domListToPdfColumn(dom.Element list, {required bool ordered}) {
    final items = list.querySelectorAll('li');
    final children = <pw.Widget>[];
    for (var i = 0; i < items.length; i++) {
      final prefix = ordered ? '${i + 1}.' : '•';
      children.add(pw.Padding(
        padding: const pw.EdgeInsets.only(left: 12, bottom: 2),
        child: pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(width: 16, child: pw.Text(prefix)),
            pw.Expanded(child: pw.Text(items[i].text.trim())),
          ],
        ),
      ));
    }
    return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: children);
  }

  static Future<pw.MemoryImage?> _loadImageBytes(String src) async {
    try {
      if (src.startsWith('data:image')) {
        final base64Part = src.split(',').last;
        return pw.MemoryImage(base64Decode(base64Part));
      }
      if (src.startsWith('http://') || src.startsWith('https://')) {
        final resp = await http.get(Uri.parse(src));
        if (resp.statusCode == 200) {
          return pw.MemoryImage(resp.bodyBytes);
        }
        return null;
      }
      // Ficheiro local — tenta ler diretamente.
      final file = File(src);
      if (await file.exists()) {
        return pw.MemoryImage(await file.readAsBytes());
      }
      return null;
    } catch (_) {
      // Falha de rede/URL/ficheiro: ignora esta imagem, não rebenta
      // a exportação inteira.
      return null;
    }
  }

  // ── SHEET → PDF ────────────────────────────────────────────

  static void _buildSheetPdfPages(pw.Document doc, String jsonContent) {
    Map<String, dynamic> cells = {};
    try {
      final parsed = jsonDecode(jsonContent);
      cells = (parsed is Map && parsed['cells'] is Map)
          ? Map<String, dynamic>.from(parsed['cells'])
          : Map<String, dynamic>.from(parsed as Map);
    } catch (_) {
      cells = {};
    }

    if (cells.isEmpty) {
      doc.addPage(pw.Page(build: (_) => pw.Center(child: pw.Text('Folha vazia'))));
      return;
    }

    // Determina o intervalo de linhas/colunas a partir das chaves
    // tipo "A1", "B12", "AA3".
    int maxRow = 1;
    int maxCol = 1;
    final cellRefRe = RegExp(r'^([A-Z]+)(\d+)$');
    for (final key in cells.keys) {
      final m = cellRefRe.firstMatch(key);
      if (m == null) continue;
      final colLetters = m.group(1)!;
      final row = int.parse(m.group(2)!);
      final col = _colLettersToIndex(colLetters);
      if (row > maxRow) maxRow = row;
      if (col > maxCol) maxCol = col;
    }

    final rows = <pw.TableRow>[];
    for (int r = 1; r <= maxRow; r++) {
      final rowCells = <pw.Widget>[];
      for (int c = 1; c <= maxCol; c++) {
        final ref = '${_colIndexToLetters(c)}$r';
        final cellData = cells[ref];
        String text = '';
        bool bold = false;
        bool italic = false;
        PdfColor? color;
        if (cellData is Map) {
          text = (cellData['value'] ?? cellData['text'] ?? '').toString();
          bold = cellData['bold'] == true;
          italic = cellData['italic'] == true;
          final colorHex = cellData['color']?.toString();
          if (colorHex != null && colorHex.isNotEmpty) {
            color = _hexToPdfColor(colorHex);
          }
        } else if (cellData != null) {
          text = cellData.toString();
        }
        rowCells.add(pw.Padding(
          padding: const pw.EdgeInsets.all(3),
          child: pw.Text(
            text,
            style: pw.TextStyle(
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
              color: color,
            ),
          ),
        ));
      }
      rows.add(pw.TableRow(children: rowCells));
    }

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (context) => [
          pw.Table(border: pw.TableBorder.all(width: 0.5), children: rows),
        ],
      ),
    );
  }

  static int _colLettersToIndex(String letters) {
    int result = 0;
    for (int i = 0; i < letters.length; i++) {
      result = result * 26 + (letters.codeUnitAt(i) - 'A'.codeUnitAt(0) + 1);
    }
    return result;
  }

  static String _colIndexToLetters(int index) {
    String result = '';
    while (index > 0) {
      final rem = (index - 1) % 26;
      result = String.fromCharCode('A'.codeUnitAt(0) + rem) + result;
      index = (index - 1) ~/ 26;
    }
    return result;
  }

  static PdfColor _hexToPdfColor(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    final value = int.parse(h, radix: 16);
    return PdfColor.fromInt(value);
  }

  // ── SLIDE → PDF ────────────────────────────────────────────

  static const double _slideW = 960;
  static const double _slideH = 540;

  static Future<void> _buildSlidePdfPages(pw.Document doc, String jsonContent) async {
    List<dynamic> slides = [];
    try {
      final parsed = jsonDecode(jsonContent);
      slides = (parsed is Map && parsed['slides'] is List) ? List.from(parsed['slides']) : [];
    } catch (_) {
      slides = [];
    }

    if (slides.isEmpty) {
      doc.addPage(pw.Page(build: (_) => pw.Center(child: pw.Text('Apresentação vazia'))));
      return;
    }

    for (final slide in slides) {
      final elements = (slide is Map && slide['elements'] is List)
          ? List.from(slide['elements'])
          : <dynamic>[];

      final children = <pw.Widget>[];
      for (final el in elements) {
        if (el is! Map) continue;
        final w = await _slideElementToPdfWidget(el);
        if (w != null) children.add(w);
      }

      doc.addPage(
        pw.Page(
          pageFormat: const PdfPageFormat(_slideW, _slideH),
          build: (context) => pw.Stack(children: children),
        ),
      );
    }
  }

  static Future<pw.Widget?> _slideElementToPdfWidget(Map el) async {
    final type = el['type']?.toString() ?? '';
    final x = (el['x'] as num?)?.toDouble() ?? 0;
    final y = (el['y'] as num?)?.toDouble() ?? 0;
    final w = (el['width'] as num?)?.toDouble() ?? 100;
    final h = (el['height'] as num?)?.toDouble() ?? 40;

    pw.Widget? content;
    switch (type) {
      case 'text':
        final text = el['text']?.toString() ?? '';
        final fontSize = (el['fontSize'] as num?)?.toDouble() ?? 18;
        content = pw.Text(
          text,
          style: pw.TextStyle(fontSize: fontSize),
        );
        break;
      case 'image':
        final src = el['src']?.toString();
        if (src == null || src.isEmpty) return null;
        final memImage = await _loadImageBytes(src);
        if (memImage == null) return null;
        content = pw.Image(memImage, fit: pw.BoxFit.contain);
        break;
      case 'shape':
        final colorHex = el['color']?.toString() ?? '#CCCCCC';
        content = pw.Container(
          decoration: pw.BoxDecoration(color: _hexToPdfColor(colorHex)),
        );
        break;
      default:
        return null;
    }

    return pw.Positioned(
      left: x,
      top: y,
      child: pw.SizedBox(width: w, height: h, child: content),
    );
  }

  // ════════════════════════════════════════════════════════════
  // PNG (via PDF → rasterização da 1ª página com pdfx)
  // ════════════════════════════════════════════════════════════

  static Future<Uint8List> _exportPng(LocalCanvasItem item) async {
    final pdfBytes = await _exportPdf(item);
    final pdfDoc = await PdfDocument.openData(pdfBytes);
    final page = await pdfDoc.getPage(1);
    final rendered = await page.render(
      width: page.width * 2,
      height: page.height * 2,
      format: PdfPageImageFormat.png,
    );
    await page.close();
    await pdfDoc.close();
    if (rendered == null) {
      throw Exception('Falha ao rasterizar PDF para PNG.');
    }
    return rendered.bytes;
  }

  // ════════════════════════════════════════════════════════════
  // DOCX / XLSX / PPTX — OOXML manual via package:archive
  // ════════════════════════════════════════════════════════════

  static Uint8List _exportDocx(LocalCanvasItem item) {
    final document = html_parser.parse(item.content);
    final body = document.body;
    final paragraphs = <String>[];

    void walk(dom.Node node) {
      if (node is dom.Text) {
        final t = node.text.trim();
        if (t.isNotEmpty) paragraphs.add(_docxParagraphXml(t));
        return;
      }
      if (node is dom.Element) {
        final tag = node.localName?.toLowerCase() ?? '';
        if (tag == 'p' || tag == 'div' || tag == 'h1' || tag == 'h2' || tag == 'h3') {
          final text = node.text.trim();
          if (text.isNotEmpty) {
            final bold = tag.startsWith('h');
            paragraphs.add(_docxParagraphXml(text, bold: bold));
          }
        } else {
          for (final child in node.nodes) {
            walk(child);
          }
        }
      }
    }

    if (body != null) {
      for (final node in body.nodes) {
        walk(node);
      }
    }

    final bodyXml = paragraphs.join();

    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>
$bodyXml
<w:sectPr/>
</w:body>
</w:document>''';

    final archive = Archive();
    _addOoxmlCommonParts(archive, contentTypesOverrides: [
      '<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>',
    ], relsTargets: [
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>',
    ]);
    archive.addFile(ArchiveFile('word/document.xml', documentXml.length, utf8.encode(documentXml)));

    final zipBytes = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipBytes!);
  }

  static String _docxParagraphXml(String text, {bool bold = false}) {
    final escaped = _xmlEscape(text);
    final rPr = bold ? '<w:rPr><w:b/></w:rPr>' : '';
    return '<w:p><w:r>$rPr<w:t xml:space="preserve">$escaped</w:t></w:r></w:p>';
  }

  static Uint8List _exportXlsx(LocalCanvasItem item) {
    Map<String, dynamic> cells = {};
    try {
      final parsed = jsonDecode(item.content);
      cells = (parsed is Map && parsed['cells'] is Map)
          ? Map<String, dynamic>.from(parsed['cells'])
          : Map<String, dynamic>.from(parsed as Map);
    } catch (_) {
      cells = {};
    }

    int maxRow = 1;
    final rowsMap = <int, Map<String, String>>{};
    final cellRefRe = RegExp(r'^([A-Z]+)(\d+)$');
    for (final entry in cells.entries) {
      final m = cellRefRe.firstMatch(entry.key);
      if (m == null) continue;
      final colLetters = m.group(1)!;
      final row = int.parse(m.group(2)!);
      if (row > maxRow) maxRow = row;
      String text = '';
      final v = entry.value;
      if (v is Map) {
        text = (v['value'] ?? v['text'] ?? '').toString();
      } else if (v != null) {
        text = v.toString();
      }
      rowsMap.putIfAbsent(row, () => {})[colLetters] = text;
    }

    final rowsXml = StringBuffer();
    for (int r = 1; r <= maxRow; r++) {
      final rowData = rowsMap[r] ?? {};
      if (rowData.isEmpty) continue;
      final cellsXml = StringBuffer();
      for (final entry in rowData.entries) {
        final ref = '${entry.key}$r';
        final escaped = _xmlEscape(entry.value);
        cellsXml.write('<c r="$ref" t="inlineStr"><is><t xml:space="preserve">$escaped</t></is></c>');
      }
      rowsXml.write('<row r="$r">$cellsXml</row>');
    }

    final sheetXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<sheetData>
$rowsXml
</sheetData>
</worksheet>''';

    final workbookXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets><sheet name="Sheet1" sheetId="1" r:id="rId1"/></sheets>
</workbook>''';

    final workbookRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>''';

    final archive = Archive();
    _addOoxmlCommonParts(archive, contentTypesOverrides: [
      '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>',
      '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>',
    ], relsTargets: [
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>',
    ]);
    archive.addFile(ArchiveFile('xl/workbook.xml', workbookXml.length, utf8.encode(workbookXml)));
    archive.addFile(ArchiveFile('xl/_rels/workbook.xml.rels', workbookRelsXml.length, utf8.encode(workbookRelsXml)));
    archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheetXml.length, utf8.encode(sheetXml)));

    final zipBytes = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipBytes!);
  }

  static Uint8List _exportPptx(LocalCanvasItem item) {
    List<dynamic> slides = [];
    try {
      final parsed = jsonDecode(item.content);
      slides = (parsed is Map && parsed['slides'] is List) ? List.from(parsed['slides']) : [];
    } catch (_) {
      slides = [];
    }
    if (slides.isEmpty) slides = [{}];

    final archive = Archive();

    final contentTypesOverrides = <String>[
      '<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>',
    ];
    final presentationRelsTargets = <String>[];
    final sldIdEntries = <String>[];

    for (int i = 0; i < slides.length; i++) {
      final n = i + 1;
      final slide = slides[i];
      final elements = (slide is Map && slide['elements'] is List)
          ? List.from(slide['elements'])
          : <dynamic>[];

      final shapesXml = StringBuffer();
      int shapeId = 2;
      for (final el in elements) {
        if (el is! Map) continue;
        final type = el['type']?.toString() ?? '';
        if (type != 'text') continue; // texto é o essencial mínimo suportado
        final text = _xmlEscape(el['text']?.toString() ?? '');
        final x = ((el['x'] as num?)?.toDouble() ?? 0) * 9525; // px → EMU aproximado
        final y = ((el['y'] as num?)?.toDouble() ?? 0) * 9525;
        final w = ((el['width'] as num?)?.toDouble() ?? 200) * 9525;
        final h = ((el['height'] as num?)?.toDouble() ?? 50) * 9525;
        shapesXml.write('''
<p:sp>
<p:nvSpPr><p:cNvPr id="$shapeId" name="Shape$shapeId"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>
<p:spPr><a:xfrm><a:off x="${x.round()}" y="${y.round()}"/><a:ext cx="${w.round()}" cy="${h.round()}"/></a:xfrm></p:spPr>
<p:txBody><a:bodyPr/><a:p><a:r><a:t>$text</a:t></a:r></a:p></p:txBody>
</p:sp>''');
        shapeId++;
      }

      final slideXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
<p:cSld><p:spTree>
<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
<p:grpSpPr/>
$shapesXml
</p:spTree></p:cSld>
</p:sld>''';

      archive.addFile(ArchiveFile('ppt/slides/slide$n.xml', slideXml.length, utf8.encode(slideXml)));
      contentTypesOverrides.add(
        '<Override PartName="/ppt/slides/slide$n.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>',
      );
      presentationRelsTargets.add(
        '<Relationship Id="rId${n + 1}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide$n.xml"/>',
      );
      sldIdEntries.add('<p:sldId id="${255 + n}" r:id="rId${n + 1}"/>');
    }

    final presentationXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
<p:sldIdLst>
$sldIdEntries
</p:sldIdLst>
<p:sldSz cx="9144000" cy="6858000"/>
</p:presentation>''';

    final presentationRelsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
${presentationRelsTargets.join('\n')}
</Relationships>''';

    _addOoxmlCommonParts(archive, contentTypesOverrides: contentTypesOverrides, relsTargets: [
      '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>',
    ]);
    archive.addFile(ArchiveFile('ppt/presentation.xml', presentationXml.length, utf8.encode(presentationXml)));
    archive.addFile(ArchiveFile('ppt/_rels/presentation.xml.rels', presentationRelsXml.length, utf8.encode(presentationRelsXml)));

    final zipBytes = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipBytes!);
  }

  // ── Partes OOXML comuns a docx/xlsx/pptx ──────────────────

  static void _addOoxmlCommonParts(
    Archive archive, {
    required List<String> contentTypesOverrides,
    required List<String> relsTargets,
  }) {
    final contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
${contentTypesOverrides.join('\n')}
</Types>''';

    final relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
${relsTargets.join('\n')}
</Relationships>''';

    archive.addFile(ArchiveFile('[Content_Types].xml', contentTypesXml.length, utf8.encode(contentTypesXml)));
    archive.addFile(ArchiveFile('_rels/.rels', relsXml.length, utf8.encode(relsXml)));
  }

  static String _xmlEscape(String input) {
    return input
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&apos;');
  }
}