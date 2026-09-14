=====================================================================
lib/tools/text/url_extractor_tool.dart
=====================================================================

// extract_urls_from_text

import '../shared/tool_result.dart';

class UrlExtractorTool {
  static final RegExp _urlRegex = RegExp(
    r'(https?:\/\/[^\s<>"]+)',
    caseSensitive: false,
  );

  /// extract_urls_from_text
  /// input: { text: String }
  static ToolResult extract(Map<String, dynamic> input) {
    final String? text = input['text'] as String?;
    if (text == null) {
      return ToolResult.error('Parâmetro "text" é obrigatório.', code: 'INVALID_INPUT');
    }

    final matches = _urlRegex.allMatches(text).map((m) => m.group(0)!).toSet().toList();

    return ToolResult.ok({
      'urls': matches,
      'count': matches.length,
    });
  }
}