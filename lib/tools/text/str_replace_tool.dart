import '../shared/tool_result.dart';

class StrReplaceTool {
  /// str_replace_file
  /// input: { content: String, old_str: String, new_str: String }
  static ToolResult replace(Map<String, dynamic> input) {
    final String? content = input['content'] as String?;
    final String? oldStr = input['old_str'] as String?;
    final String? newStr = input['new_str'] as String?;

    if (content == null || oldStr == null || newStr == null) {
      return ToolResult.error('Parâmetros "content", "old_str" e "new_str" são obrigatórios.', code: 'INVALID_INPUT');
    }

    if (!content.contains(oldStr)) {
      return ToolResult.error('"old_str" não encontrado no conteúdo.', code: 'NOT_FOUND');
    }

    final occurrences = oldStr.isEmpty ? 0 : oldStr.allMatches(content).length;
    final result = content.replaceFirst(oldStr, newStr);

    return ToolResult.ok({
      'content': result,
      'occurrences_in_original': occurrences,
    });
  }
}