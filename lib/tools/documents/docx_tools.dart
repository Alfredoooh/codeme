=====================================================================
lib/tools/documents/docx_tools.dart
=====================================================================

// create_docx
//
// ESTRATÉGIA: assim como o PDF, gerar a partir de HTML formatado —
// não montar parágrafo a parágrafo manualmente. O formato .docx é,
// internamente, um pacote ZIP com arquivos XML (OOXML). Sem lib Dart
// madura equivalente a `@turbodocx/html-to-docx` (Node), a abordagem
// viável é: parsear o HTML (pacote `html`, já presente no pubspec) e
// traduzir a árvore de elementos (h1, p, table, strong, em, etc.)
// para os elementos XML equivalentes do OOXML, empacotando tudo com
// `archive` (já presente no pubspec) no container .docx final.
//
// Esta é a tool de maior esforço de implementação de toda a pasta —
// o esqueleto abaixo cobre a estrutura mínima de um .docx válido
// (document.xml + relationships + content types) e um tradutor
// simplificado de HTML → parágrafos/runs, cobrindo tags comuns.
// Tabelas e estilos avançados exigem extensão incremental deste
// tradutor.

import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as dom;

import '../shared/tool_result.dart';
import '../server/tools_queue.dart';

class DocxTools {
  /// create_docx
  /// input: { html: String }
  static Future<ToolResult> createDocx(Map<String, dynamic> input) {
    return ToolsQueue.instance.enqueue(() => _createDocxImpl(input));
  }

  static Future<ToolResult> _createDocxImpl(Map<String, dynamic> input) async {
    final String? htmlString = input['html'] as String?;
    if (htmlString == null || htmlString.trim().isEmpty) {
      return ToolResult.error('Parâmetro "html" é obrigatório.', code: 'INVALID_INPUT');
    }

    try {
      final document = html_parser.parse(htmlString);
      final bodyXml = _htmlNodesToDocxXml(document.body?.nodes ?? []);

      final documentXml = _buildDocumentXml(bodyXml);
      final docxBytes = _packageDocx(documentXml);

      return ToolResult.ok({
        'docx_base64': base64Encode(docxBytes),
        'size_bytes': docxBytes.length,
      });
    } catch (e) {
      return ToolResult.error('Erro ao gerar DOCX: $e', code: 'GENERATION_ERROR');
    }
  }

  /// Tradutor simplificado: percorre nós HTML e gera parágrafos <w:p>
  /// equivalentes. Cobre: h1-h3, p, strong/b, em/i, br. Elementos não
  /// reconhecidos caem como texto simples em parágrafo próprio.
  static String _htmlNodesToDocxXml(List<dom.Node> nodes) {
    final buffer = StringBuffer();

    for (final node in nodes) {
      if (node is dom.Element) {
        switch (node.localName) {
          case 'h1':
          case 'h2':
          case 'h3':
            buffer.write(_paragraph(node.text, bold: true, sizePt: node.localName == 'h1' ? 28 : 22));
            break;
          case 'p':
            buffer.write(_paragraph(node.text));
            break;
          case 'strong':
          case 'b':
            buffer.write(_paragraph(node.text, bold: true));
            break;
          case 'em':
          case 'i':
            buffer.write(_paragraph(node.text, italic: true));
            break;
          default:
            if (node.text.trim().isNotEmpty) {
              buffer.write(_paragraph(node.text));
            }
        }
      } else if (node is dom.Text) {
        if (node.text.trim().isNotEmpty) {
          buffer.write(_paragraph(node.text));
        }
      }
    }

    return buffer.toString();
  }

  static String _paragraph(String text, {bool bold = false, bool italic = false, int sizePt = 22}) {
    final escaped = text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;');
    final rPr = '<w:rPr>${bold ? '<w:b/>' : ''}${italic ? '<w:i/>' : ''}<w:sz w:val="$sizePt"/></w:rPr>';
    return '<w:p><w:r>$rPr<w:t xml:space="preserve">$escaped</w:t></w:r></w:p>';
  }

  static String _buildDocumentXml(String bodyContent) {
    return '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
  <w:body>
    $bodyContent
    <w:sectPr/>
  </w:body>
</w:document>''';
  }

  static Uint8List _packageDocx(String documentXml) {
    final archive = Archive();

    archive.addFile(_textFile('[Content_Types].xml', _contentTypesXml()));
    archive.addFile(_textFile('_rels/.rels', _relsXml()));
    archive.addFile(_textFile('word/document.xml', documentXml));
    archive.addFile(_textFile('word/_rels/document.xml.rels', _documentRelsXml()));

    final zipData = ZipEncoder().encode(archive);
    return Uint8List.fromList(zipData!);
  }

  static ArchiveFile _textFile(String path, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(path, bytes.length, bytes);
  }

  static String _contentTypesXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="xml" ContentType="application/xml"/>
  <Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';

  static String _relsXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

  static String _documentRelsXml() => '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
</Relationships>''';
}