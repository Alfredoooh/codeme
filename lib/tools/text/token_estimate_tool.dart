=====================================================================
lib/tools/text/token_estimate_tool.dart
=====================================================================

// count_tokens_estimate
//
// Estimativa por regra simples (sem tokenizador oficial): aproxima
// 1 token ≈ 4 caracteres em inglês, ajustado levemente para PT-BR
// (que tende a ter tokens um pouco maiores devido a acentuação).

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