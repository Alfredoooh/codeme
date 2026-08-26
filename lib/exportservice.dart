// ══════════════════════════════════════════════════════════════
// FILE: lib/exportservice.dart
// ══════════════════════════════════════════════════════════════
//
// CORREÇÃO DE COMPILAÇÃO (build real falhou, confirmado no log):
// import 'package:pdfx/pdfx.dart' sem prefixo colidia com
// 'PdfDocument' de package:pdf/pdf.dart (também sem prefixo) — os
// dois pacotes exportam uma classe com o mesmo nome. Corrigido
// prefixando só o import de pdfx como 'pdfx_pkg' e qualificando a
// única chamada afetada (_exportPng, que usa a API do pdfx para
// rasterizar a 1ª página de um PDF em PNG). package:pdf continua sem
// prefixo (usado em toda a parte via 'pw.' já vindo de
// package:pdf/widgets.dart, e 'PdfColor' etc. de package:pdf/pdf.dart
// sem conflito, por isso não precisou de prefixo).
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
import 'package:pdfx/pdfx.dart' as pdfx_pkg;
import 'package:share_plus/share_plus.dart';

import 'apps/app_types.dart' show LocalCanvasItem, LocalCanvasKind;

// ══════════════════════════════════════════════════════════════
// EXPORT SERVICE — converte um LocalCanvasItem (doc/sheet/slide/
// whiteboard) para bytes num formato de ficheiro real, e partilha
// esses bytes através do painel nativo de partilha do sistema.
// ══════════════════════════════════════════════════════════════

class ExportService {
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
        throw Exception('Formato de exportação não suportado: $format');
    }
  }

  static Future<void> shareBytes(Uint8List bytes, {required String filename}) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(bytes);
    await Share.shareXFiles([XFile(file.path)], text: filename);
  }

  // ════════════════════════════════════════════════════════════
  // PDF — base também usada por PNG (rasterização da 1ª página).
  // kind doc: parse do HTML via package:html, percorre o DOM e
  // desenha com pw.Text/pw.RichText/pw.Table/pw.Image.
  // kind sheet: item.content é JSON {"cells": {...}}.
  // kind slide: item.content é JSON {"slides": [...]}.
  // ════════════════════════════════════════════════════════════

  static Future<Uint8List> _exportPdf(LocalCanvasItem item) async {
    final doc = pw.Document();
    switch (item.kind) {
      case LocalCanvasKind.doc:
        await _buildDocPages(doc, item.content);
        break;
      case LocalCanvasKind.sheet:
        _buildSheetPage(doc, item.content);
        break;
      case LocalCanvasKind.slide:
        await _buildSlidePages(doc, item.content);
        break;
    }
    return doc.save();
  }

  static Future<void> _buildDocPages(pw.Document doc, String htmlContent) async {
    final document = html_parser.parse(htmlContent);
    final body = document.body;
    final widgets = <pw.Widget>[];
    if (body != null) {
      for (final node in body.nodes) {
        final w = await _domNodeToPdfWidget(node);
        if (w != null) widgets.add(w);
      }
    }
    doc.addPage(pw.MultiPage(
      build: (_) => widgets.isEmpty ? [pw.Text('')] : widgets,
    ));
  }

  static Future<pw.Widget?> _domNodeToPdfWidget(dom.Node node) async {
    if (node is dom.Text) {
      final t = node.text.trim();
      if (t.isEmpty) return null;
      return pw.Padding(padding: const pw.EdgeInsets.only(bottom: 4), child: pw.Text(t));
    }
    if (node is! dom.Element) return null;
    switch (node.localName) {
      case 'h1':
        return pw.Padding(padding: const pw.EdgeInsets.only(bottom: 8, top: 8), child: pw.Text(node.text, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)));
      case 'h2':
        return pw.Padding(padding: const pw.EdgeInsets.only(bottom: 6, top: 6), child: pw.Text(node.text, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)));
      case 'h3':
        return pw.Padding(padding: const pw.EdgeInsets.only(bottom: 5, top: 5), child: pw.Text(node.text, style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)));
      case 'p':
        return pw.Padding(padding: const pw.EdgeInsets.only(bottom: 6), child: pw.Text(node.text));
      case 'strong':
      case 'b':
        return pw.Text(node.text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold));
      case 'em':
      case 'i':
        return pw.Text(node.text, style: pw.TextStyle(fontStyle: pw.FontStyle.italic));
      case 'ul':
      case 'ol':
        final items = node.children.where((c) => c.localName == 'li').map((li) => pw.Bullet(text: li.text)).toList();
        return pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: items);
      case 'img':
        final src = node.attributes['src'];
        if (src == null || src.isEmpty) return null;
        try {
          final res = await http.get(Uri.parse(src)).timeout(const Duration(seconds: 10));
          if (res.statusCode == 200) {
            return pw.Padding(
              padding: const pw.EdgeInsets.symmetric(vertical: 6),
              child: pw.Image(pw.MemoryImage(res.bodyBytes), height: 200, fit: pw.BoxFit.contain),
            );
          }
        } catch (_) {
          // Falha de rede/URL: ignora esta imagem, não rebenta a exportação.
        }
        return null;
      case 'table':
        final rows = <List<String>>[];
        for (final tr in node.querySelectorAll('tr')) {
          rows.add(tr.querySelectorAll('td, th').map((c) => c.text.trim()).toList());
        }
        if (rows.isEmpty) return null;
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 6),
          child: pw.Table.fromTextArray(data: rows),
        );
      default:
        final t = node.text.trim();
        if (t.isEmpty) return null;
        return pw.Text(t);
    }
  }

  static void _buildSheetPage(pw.Document doc, String jsonContent) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonContent) as Map<String, dynamic>;
    } catch (_) {
      data = {};
    }
    final cells = (data['cells'] as Map<String, dynamic>?) ?? {};
    if (cells.isEmpty) {
      doc.addPage(pw.Page(build: (_) => pw.Center(child: pw.Text('Folha de cálculo vazia.'))));
      return;
    }

    int maxRow = 1;
    int maxCol = 0;
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
      for (int c = 0; c <= maxCol; c++) {
        final ref = '${_indexToColLetters(c)}$r';
        final cell = cells[ref] as Map<String, dynamic>?;
        final value = cell?['value']?.toString() ?? '';
        final bold = cell?['bold'] == true;
        final italic = cell?['italic'] == true;
        rowCells.add(pw.Padding(
          padding: const pw.EdgeInsets.all(4),
          child: pw.Text(value, style: pw.TextStyle(
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            fontStyle: italic ? pw.FontStyle.italic : pw.FontStyle.normal,
          )),
        ));
      }
      rows.add(pw.TableRow(children: rowCells));
    }

    doc.addPage(pw.MultiPage(
      build: (_) => [pw.Table(border: pw.TableBorder.all(width: 0.5), children: rows)],
    ));
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

  static Future<void> _buildSlidePages(pw.Document doc, String jsonContent) async {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonContent) as Map<String, dynamic>;
    } catch (_) {
      data = {};
    }
    final slides = (data['slides'] as List?) ?? [];
    if (slides.isEmpty) {
      doc.addPage(pw.Page(build: (_) => pw.Center(child: pw.Text('Apresentação vazia.'))));
      return;
    }

    const slideW = 960.0, slideH = 540.0;
    for (final slideRaw in slides) {
      final slide = slideRaw as Map<String, dynamic>;
      final elements = (slide['elements'] as List?) ?? [];
      final children = <pw.Widget>[];
      for (final elRaw in elements) {
        final el = elRaw as Map<String, dynamic>;
        final w = await _slideElementToPdfWidget(el, slideW, slideH);
        if (w != null) children.add(w);
      }
      doc.addPage(pw.Page(
        pageFormat: const PdfPageFormat(slideW, slideH),
        build: (_) => pw.Stack(children: children),
      ));
    }
  }

  static Future<pw.Widget?> _slideElementToPdfWidget(Map<String, dynamic> el, double slideW, double slideH) async {
    final type = el['type']?.toString();
    final x = (el['x'] as num?)?.toDouble() ?? 0;
    final y = (el['y'] as num?)?.toDouble() ?? 0;
    final w = (el['w'] as num?)?.toDouble() ?? 100;
    final h = (el['h'] as num?)?.toDouble() ?? 50;

    pw.Widget? content;
    switch (type) {
      case 'text':
        final fontSize = (el['fontSize'] as num?)?.toDouble() ?? 16;
        final colorHex = el['color']?.toString() ?? '#000000';
        content = pw.Text(
          _stripHtmlTags(el['html']?.toString() ?? ''),
          style: pw.TextStyle(fontSize: fontSize, color: _hexToPdfColor(colorHex)),
        );
        break;
      case 'image':
        final src = el['src']?.toString();
        if (src == null || src.isEmpty) return null;
        try {
          final res = await http.get(Uri.parse(src)).timeout(const Duration(seconds: 10));
          if (res.statusCode == 200) {
            content = pw.Image(pw.MemoryImage(res.bodyBytes), fit: pw.BoxFit.contain);
          }
        } catch (_) {
          return null;
        }
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

  static String _stripHtmlTags(String html) => html.replaceAll(RegExp(r'<[^>]*>'), '');

  static PdfColor _hexToPdfColor(String hex) {
    final cleaned = hex.replaceAll('#', '');
    final value = int.tryParse(cleaned, radix: 16) ?? 0x000000;
    return PdfColor.fromInt(0xFF000000 | value);
  }

  // ════════════════════════════════════════════════════════════
  // PNG (via PDF → rasterização da 1ª página com pdfx)
  // ════════════════════════════════════════════════════════════

  static Future<Uint8List> _exportPng(LocalCanvasItem item) async {
    final pdfBytes = await _exportPdf(item);
    final pdfDoc = await pdfx_pkg.PdfDocument.openData(pdfBytes);
    final page = await pdfDoc.getPage(1);
    final rendered = await page.render(
      width: page.width * 2,
      height: page.height * 2,
      format: pdfx_pkg.PdfPageImageFormat.png,
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
        switch (node.localName) {
          case 'h1':
          case 'h2':
          case 'h3':
            paragraphs.add(_docxParagraphXml(node.text, bold: true, size: node.localName == 'h1' ? 32 : node.localName == 'h2' ? 28 : 24));
            break;
          case 'p':
            paragraphs.add(_docxParagraphXml(node.text));
            break;
          case 'li':
            paragraphs.add(_docxParagraphXml('• ${node.text}'));
            break;
          default:
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

    final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>
${paragraphs.join('\n')}
<w:sectPr/>
</w:body>
</w:document>''';

    final archive = Archive();
    archive.addFile(ArchiveFile('[Content_Types].xml', -1, utf8.encode(_docxContentTypesXml())));
    archive.addFile(ArchiveFile('_rels/.rels', -1, utf8.encode(_docxRelsXml())));
    archive.addFile(ArchiveFile('word/document.xml', -1, utf8.encode(documentXml)));
    archive.addFile(ArchiveFile('word/_rels/document.xml.rels', -1, utf8.encode(_docxDocumentRelsXml())));

    final bytes = ZipEncoder().encode(archive);
    return Uint8List.fromList(bytes ?? []);
  }

  static String _docxParagraphXml(String text, {bool bold = false, int? size}) {
    final escaped = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    final rPr = <String>[];
    if (bold) rPr.add('<w:b/>');
    if (size != null) rPr.add('<w:sz w:val="$size"/>');
    final rPrXml = rPr.isEmpty ? '' : '<w:rPr>${rPr.join()}</w:rPr>';
    return '<w:p><w:r>$rPrXml<w:t xml:space="preserve">$escaped</w:t></w:r></w:p>';
  }

  static String _docxContentTypesXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';

  static String _docxRelsXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

  static String _docxDocumentRelsXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>''';

  static Uint8List _exportXlsx(LocalCanvasItem item) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(item.content) as Map<String, dynamic>;
    } catch (_) {
      data = {};
    }
    final cells = (data['cells'] as Map<String, dynamic>?) ?? {};

    final rowsMap = <int, List<MapEntry<String, dynamic>>>{};
    final cellRefRe = RegExp(r'^([A-Z]+)(\d+)$');
    for (final entry in cells.entries) {
      final m = cellRefRe.firstMatch(entry.key);
      if (m == null) continue;
      final row = int.parse(m.group(2)!);
      rowsMap.putIfAbsent(row, () => []).add(entry);
    }

    final sortedRows = rowsMap.keys.toList()..sort();
    final rowsXml = StringBuffer();
    for (final r in sortedRows) {
      final rowCells = rowsMap[r]!;
      final cellsXml = StringBuffer();
      for (final entry in rowCells) {
        final ref = entry.key;
        final cellData = entry.value as Map<String, dynamic>;
        final value = cellData['value']?.toString() ?? '';
        final escaped = value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
        cellsXml.write('<c r="$ref" t="inlineStr"><is><t xml:space="preserve">$escaped</t></is></c>');
      }
      rowsXml.write('<row r="$r">${cellsXml.toString()}</row>');
    }

    final sheetXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">
<sheetData>
${rowsXml.toString()}
</sheetData>
</worksheet>''';

    final archive = Archive();
    archive.addFile(ArchiveFile('[Content_Types].xml', -1, utf8.encode(_xlsxContentTypesXml())));
    archive.addFile(ArchiveFile('_rels/.rels', -1, utf8.encode(_xlsxRelsXml())));
    archive.addFile(ArchiveFile('xl/workbook.xml', -1, utf8.encode(_xlsxWorkbookXml())));
    archive.addFile(ArchiveFile('xl/_rels/workbook.xml.rels', -1, utf8.encode(_xlsxWorkbookRelsXml())));
    archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', -1, utf8.encode(sheetXml)));

    final bytes = ZipEncoder().encode(archive);
    return Uint8List.fromList(bytes ?? []);
  }

  static String _xlsxContentTypesXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>
<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>
</Types>''';

  static String _xlsxRelsXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>
</Relationships>''';

  static String _xlsxWorkbookXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">
<sheets>
<sheet name="Folha1" sheetId="1" r:id="rId1"/>
</sheets>
</workbook>''';

  static String _xlsxWorkbookRelsXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>
</Relationships>''';

  static Uint8List _exportPptx(LocalCanvasItem item) {
    Map<String, dynamic> data;
    try {
      data = jsonDecode(item.content) as Map<String, dynamic>;
    } catch (_) {
      data = {};
    }
    final slides = (data['slides'] as List?) ?? [];

    final archive = Archive();
    archive.addFile(ArchiveFile('_rels/.rels', -1, utf8.encode(_pptxRelsXml())));
    archive.addFile(ArchiveFile('ppt/presentation.xml', -1, utf8.encode(_pptxPresentationXml(slides.length))));
    archive.addFile(ArchiveFile('ppt/_rels/presentation.xml.rels', -1, utf8.encode(_pptxPresentationRelsXml(slides.length))));

    final contentTypesOverrides = StringBuffer();
    for (int i = 0; i < slides.length; i++) {
      final slideNum = i + 1;
      final slide = slides[i] as Map<String, dynamic>;
      final elements = (slide['elements'] as List?) ?? [];
      final shapesXml = StringBuffer();
      int shapeId = 2;
      for (final elRaw in elements) {
        final el = elRaw as Map<String, dynamic>;
        if (el['type'] == 'text') {
          final text = _stripHtmlTags(el['html']?.toString() ?? '')
              .replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
          final x = ((el['x'] as num?)?.toDouble() ?? 0) * 9525;
          final y = ((el['y'] as num?)?.toDouble() ?? 0) * 9525;
          final w = ((el['w'] as num?)?.toDouble() ?? 100) * 9525;
          final h = ((el['h'] as num?)?.toDouble() ?? 50) * 9525;
          shapesXml.write('''
<p:sp>
<p:nvSpPr><p:cNvPr id="$shapeId" name="TextBox$shapeId"/><p:cNvSpPr txBox="1"/><p:nvPr/></p:nvSpPr>
<p:spPr><a:xfrm><a:off x="${x.round()}" y="${y.round()}"/><a:ext cx="${w.round()}" cy="${h.round()}"/></a:xfrm></p:spPr>
<p:txBody><a:bodyPr/><a:p><a:r><a:t>$text</a:t></a:r></a:p></p:txBody>
</p:sp>''');
          shapeId++;
        }
      }
      final slideXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
<p:cSld><p:spTree>
<p:nvGrpSpPr><p:cNvPr id="1" name=""/><p:cNvGrpSpPr/><p:nvPr/></p:nvGrpSpPr>
<p:grpSpPr/>
${shapesXml.toString()}
</p:spTree></p:cSld>
</p:sld>''';
      archive.addFile(ArchiveFile('ppt/slides/slide$slideNum.xml', -1, utf8.encode(slideXml)));
      archive.addFile(ArchiveFile('ppt/slides/_rels/slide$slideNum.xml.rels', -1, utf8.encode(_pptxSlideRelsXml())));
      contentTypesOverrides.write('<Override PartName="/ppt/slides/slide$slideNum.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>');
    }

    archive.addFile(ArchiveFile('[Content_Types].xml', -1, utf8.encode(_pptxContentTypesXml(contentTypesOverrides.toString()))));

    final bytes = ZipEncoder().encode(archive);
    return Uint8List.fromList(bytes ?? []);
  }

  static String _pptxContentTypesXml(String slideOverrides) => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
$slideOverrides
</Types>''';

  static String _pptxRelsXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>''';

  static String _pptxPresentationXml(int slideCount) {
    final sldIdLst = StringBuffer();
    for (int i = 0; i < slideCount; i++) {
      sldIdLst.write('<p:sldId id="${256 + i}" r:id="rId${i + 2}"/>');
    }
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
<p:sldIdLst>
${sldIdLst.toString()}
</p:sldIdLst>
<p:sldSz cx="9144000" cy="5143500"/>
</p:presentation>''';
  }

  static String _pptxPresentationRelsXml(int slideCount) {
    final rels = StringBuffer();
    for (int i = 0; i < slideCount; i++) {
      rels.write('<Relationship Id="rId${i + 2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide${i + 1}.xml"/>');
    }
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
${rels.toString()}
</Relationships>''';
  }

  static String _pptxSlideRelsXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>''';
}