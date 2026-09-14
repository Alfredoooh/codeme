=====================================================================
lib/tools/documents/pptx_tools.dart
=====================================================================

// create_pptx
//
// Mesma lógica do docx: .pptx também é um ZIP de XMLs OOXML, mas com
// estrutura de slides em vez de document.xml. Sem lib Dart madura
// equivalente ao `pptxgenjs` (Node), a implementação monta o
// esqueleto mínimo de um .pptx válido com 1+ slides de texto.
// Layouts avançados (imagens, gráficos embutidos) exigem extensão.

import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';

import '../shared/tool_result.dart';
import '../server/tools_queue.dart';

class PptxTools {
  /// create_pptx
  /// input: { title?: String, slides: List<Map> } — cada slide:
  /// { heading?: String, body?: String }
  static Future<ToolResult> createPptx(Map<String, dynamic> input) {
    return ToolsQueue.instance.enqueue(() => _createPptxImpl(input));
  }

  static Future<ToolResult> _createPptxImpl(Map<String, dynamic> input) async {
    final List<dynamic>? slides = input['slides'] as List<dynamic>?;
    if (slides == null || slides.isEmpty) {
      return ToolResult.error('Parâmetro "slides" é obrigatório e não pode ser vazio.', code: 'INVALID_INPUT');
    }

    try {
      final archive = Archive();

      archive.addFile(_textFile('[Content_Types].xml', _contentTypesXml(slides.length)));
      archive.addFile(_textFile('_rels/.rels', _rootRelsXml()));
      archive.addFile(_textFile('ppt/presentation.xml', _presentationXml(slides.length)));
      archive.addFile(_textFile('ppt/_rels/presentation.xml.rels', _presentationRelsXml(slides.length)));

      for (int i = 0; i < slides.length; i++) {
        final slide = slides[i] as Map<String, dynamic>;
        final heading = (slide['heading'] as String?) ?? '';
        final body = (slide['body'] as String?) ?? '';
        archive.addFile(_textFile('ppt/slides/slide${i + 1}.xml', _slideXml(heading, body)));
      }

      final zipData = ZipEncoder().encode(archive);
      final bytes = Uint8List.fromList(zipData!);

      return ToolResult.ok({
        'pptx_base64': base64Encode(bytes),
        'slide_count': slides.length,
        'size_bytes': bytes.length,
      });
    } catch (e) {
      return ToolResult.error('Erro ao gerar PPTX: $e', code: 'GENERATION_ERROR');
    }
  }

  static ArchiveFile _textFile(String path, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(path, bytes.length, bytes);
  }

  static String _contentTypesXml(int slideCount) {
    final overrides = List.generate(
      slideCount,
      (i) => '<Override PartName="/ppt/slides/slide${i + 1}.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.slide+xml"/>',
    ).join();
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/ppt/presentation.xml" ContentType="application/vnd.openxmlformats-officedocument.presentationml.presentation.main+xml"/>
  $overrides
</Types>''';
  }

  static String _rootRelsXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="ppt/presentation.xml"/>
</Relationships>''';

  static String _presentationXml(int slideCount) {
    final sldIdLst = List.generate(
      slideCount,
      (i) => '<p:sldId id="${256 + i}" r:id="rId${i + 2}"/>',
    ).join();
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:presentation xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:sldIdLst>$sldIdLst</p:sldIdLst>
  <p:sldSz cx="9144000" cy="6858000"/>
</p:presentation>''';
  }

  static String _presentationRelsXml(int slideCount) {
    final rels = List.generate(
      slideCount,
      (i) => '<Relationship Id="rId${i + 2}" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/slide" Target="slides/slide${i + 1}.xml"/>',
    ).join();
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  $rels
</Relationships>''';
  }

  static String _slideXml(String heading, String body) {
    final escapedHeading = _escape(heading);
    final escapedBody = _escape(body);
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<p:sld xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" xmlns:p="http://schemas.openxmlformats.org/presentationml/2006/main">
  <p:cSld>
    <p:spTree>
      <p:sp>
        <p:txBody>
          <a:p><a:r><a:rPr sz="3200" b="1"/><a:t>$escapedHeading</a:t></a:r></a:p>
          <a:p><a:r><a:rPr sz="1800"/><a:t>$escapedBody</a:t></a:r></a:p>
        </p:txBody>
      </p:sp>
    </p:spTree>
  </p:cSld>
</p:sld>''';
  }

  static String _escape(String s) =>
      s.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;');
}