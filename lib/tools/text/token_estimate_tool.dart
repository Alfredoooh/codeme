import '../shared/tool_result.dart';

class TokenEstimateTool {
  /// count_tokens_estimate
  /// input: { text: String }
  static ToolResult estimate(Map<String, dynamic> input) {
    final String? text = input['text'] as String?;
    if (text == null) {
      return ToolResult.error('Parâmetro "text" é obrigatório.', code: 'INVALID_INPUT');
    }

    final charCount = text.length;
    final wordCount = text.trim().isEmpty ? 0 : text.trim().split(RegExp(r'\s+')).length;

    // Heurística: média entre estimativa por caractere e por palavra.
    final estimateByChars = (charCount / 4).ceil();
    final estimateByWords = (wordCount * 1.3).ceil();
    final estimate = ((estimateByChars + estimateByWords) / 2).round();

    return ToolResult.ok({
      'estimated_tokens': estimate,
      'char_count': charCount,
      'word_count': wordCount,
    });
  }
}