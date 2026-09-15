import '../shared/tool_result.dart';

class TextStatsTool {
  /// text_summary_stats
  /// input: { text: String }
  static ToolResult summarize(Map<String, dynamic> input) {
    final String? text = input['text'] as String?;
    if (text == null) {
      return ToolResult.error('Parâmetro "text" é obrigatório.', code: 'INVALID_INPUT');
    }

    final trimmed = text.trim();
    final wordCount = trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
    final charCount = text.length;
    final charCountNoSpaces = text.replaceAll(RegExp(r'\s'), '').length;
    final paragraphCount = trimmed.isEmpty
        ? 0
        : trimmed.split(RegExp(r'\n\s*\n')).where((p) => p.trim().isNotEmpty).length;
    final sentenceCount = trimmed.isEmpty
        ? 0
        : RegExp(r'[.!?]+').allMatches(trimmed).length;

    return ToolResult.ok({
      'word_count': wordCount,
      'char_count': charCount,
      'char_count_no_spaces': charCountNoSpaces,
      'paragraph_count': paragraphCount,
      'sentence_count': sentenceCount,
      'avg_word_length': wordCount > 0 ? (charCountNoSpaces / wordCount).toStringAsFixed(1) : '0',
    });
  }
}