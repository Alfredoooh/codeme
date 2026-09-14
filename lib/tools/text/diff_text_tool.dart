=====================================================================
lib/tools/text/diff_text_tool.dart
=====================================================================

// diff_text
//
// Implementação simples de diff linha-a-linha (não usa lib externa
// de diff — cobre o caso comum de comparação de texto sem trazer
// dependência extra ao pubspec).

import '../shared/tool_result.dart';

class DiffTextTool {
  /// diff_text
  /// input: { text_before: String, text_after: String }
  static ToolResult diff(Map<String, dynamic> input) {
    final String? before = input['text_before'] as String?;
    final String? after = input['text_after'] as String?;

    if (before == null || after == null) {
      return ToolResult.error('Parâmetros "text_before" e "text_after" são obrigatórios.', code: 'INVALID_INPUT');
    }

    final beforeLines = before.split('\n');
    final afterLines = after.split('\n');
    final diffs = <Map<String, dynamic>>[];

    final maxLen = beforeLines.length > afterLines.length ? beforeLines.length : afterLines.length;
    for (int i = 0; i < maxLen; i++) {
      final b = i < beforeLines.length ? beforeLines[i] : null;
      final a = i < afterLines.length ? afterLines[i] : null;

      if (b == a) continue;

      if (b != null && a == null) {
        diffs.add({'type': 'removed', 'line': i + 1, 'content': b});
      } else if (b == null && a != null) {
        diffs.add({'type': 'added', 'line': i + 1, 'content': a});
      } else {
        diffs.add({'type': 'changed', 'line': i + 1, 'before': b, 'after': a});
      }
    }

    return ToolResult.ok({
      'diffs': diffs,
      'total_changes': diffs.length,
    });
  }
}