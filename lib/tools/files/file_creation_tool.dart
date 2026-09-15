import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../shared/tool_result.dart';

class FileCreationTool {

  static Future<ToolResult> create(Map<String, dynamic> input) async {
    final String? filename = input['filename'] as String?;
    final String? content = input['content'] as String?;
    final bool isBase64 = (input['is_base64'] as bool?) ?? false;

    if (filename == null || content == null) {
      return ToolResult.error('Parâmetros "filename" e "content" são obrigatórios.', code: 'INVALID_INPUT');
    }

    // Impede path traversal (../../etc/passwd) e caracteres perigosos.
    final safeName = filename.replaceAll(RegExp(r'[\/\\]'), '_');

    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$safeName');

      if (isBase64) {
        await file.writeAsBytes(base64Decode(content));
      } else {
        await file.writeAsString(content);
      }

      return ToolResult.ok({
        'path': file.path,
        'size_bytes': await file.length(),
      });
    } catch (e) {
      return ToolResult.error('Erro ao criar arquivo: $e', code: 'IO_ERROR');
    }
  }
}