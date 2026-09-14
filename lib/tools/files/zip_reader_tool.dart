=====================================================================
lib/tools/files/zip_reader_tool.dart
=====================================================================

// read_zip_contents
//
// Usa archive (já presente no pubspec) para listar/extrair conteúdo
// de um .zip sem escrever nada em disco (tudo em memória).

import 'dart:convert';
import 'package:archive/archive.dart';

import '../shared/tool_result.dart';

class ZipReaderTool {
  /// read_zip_contents
  /// input: { zip_base64: String }
  static Future<ToolResult> readContents(Map<String, dynamic> input) async {
    final String? zipBase64 = input['zip_base64'] as String?;
    if (zipBase64 == null || zipBase64.isEmpty) {
      return ToolResult.error('Parâmetro "zip_base64" é obrigatório.', code: 'INVALID_INPUT');
    }

    try {
      final bytes = base64Decode(zipBase64);
      final archive = ZipDecoder().decodeBytes(bytes);

      final files = archive.map((file) {
        return {
          'name': file.name,
          'is_file': file.isFile,
          'size_bytes': file.isFile ? file.size : 0,
        };
      }).toList();

      return ToolResult.ok({
        'files': files,
        'total_entries': files.length,
      });
    } catch (e) {
      return ToolResult.error('Erro ao ler ZIP: $e', code: 'READ_ERROR');
    }
  }
}