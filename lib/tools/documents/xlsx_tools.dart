// create_xlsx, csv_to_xlsx, xlsx_to_json
//
// Usa package:excel (adicionado ao pubspec.yaml) para gerar e ler
// planilhas .xlsx de verdade — sem placeholders.

import 'dart:convert';
import 'package:excel/excel.dart';

import '../shared/tool_result.dart';
import '../server/tools_queue.dart';

class XlsxTools {
  /// create_xlsx
  /// input: { sheet_name?: String, headers: List<String>, rows: List<List<dynamic>> }
  static Future<ToolResult> createXlsx(Map<String, dynamic> input) {
    return ToolsQueue.instance.enqueue(() => _createXlsxImpl(input));
  }

  static Future<ToolResult> _createXlsxImpl(Map<String, dynamic> input) async {
    final List<dynamic>? headers = input['headers'] as List<dynamic>?;
    final List<dynamic>? rows = input['rows'] as List<dynamic>?;
    final String sheetName = (input['sheet_name'] as String?) ?? 'Sheet1';

    if (headers == null || rows == null) {
      return ToolResult.error('Parâmetros "headers" e "rows" são obrigatórios.', code: 'INVALID_INPUT');
    }

    try {
      final excelFile = Excel.createExcel();

      // Excel.createExcel() já vem com uma aba padrão chamada
      // 'Sheet1'. Se o nome pedido for diferente, renomeia-a em vez
      // de criar uma segunda aba vazia.
      const defaultSheetName = 'Sheet1';
      if (sheetName != defaultSheetName) {
        excelFile.rename(defaultSheetName, sheetName);
      }
      final Sheet sheet = excelFile[sheetName];

      sheet.appendRow(
        headers.map((h) => TextCellValue(h.toString())).toList(),
      );

      for (final row in rows) {
        final cells = (row as List).map(_toCellValue).toList();
        sheet.appendRow(cells);
      }

      final List<int>? bytes = excelFile.encode();
      if (bytes == null) {
        return ToolResult.error('Falha ao codificar o arquivo XLSX.', code: 'GENERATION_ERROR');
      }

      return ToolResult.ok({
        'xlsx_base64': base64Encode(bytes),
        'sheet_name': sheetName,
        'row_count': rows.length,
      });
    } catch (e) {
      return ToolResult.error('Erro ao gerar XLSX: $e', code: 'GENERATION_ERROR');
    }
  }

  /// Converte um valor dinâmico vindo do input (String, int, double,
  /// bool, null) na CellValue tipada que package:excel exige. Sem
  /// isso, números e booleanos ficariam sempre como texto na planilha.
  static CellValue _toCellValue(dynamic value) {
    if (value == null) return TextCellValue('');
    if (value is int) return IntCellValue(value);
    if (value is double) return DoubleCellValue(value);
    if (value is bool) return BoolCellValue(value);
    return TextCellValue(value.toString());
  }

  /// csv_to_xlsx
  /// input: { csv_content: String }
  static Future<ToolResult> csvToXlsx(Map<String, dynamic> input) {
    return ToolsQueue.instance.enqueue(() => _csvToXlsxImpl(input));
  }

  static Future<ToolResult> _csvToXlsxImpl(Map<String, dynamic> input) async {
    final String? csvContent = input['csv_content'] as String?;
    if (csvContent == null || csvContent.trim().isEmpty) {
      return ToolResult.error('Parâmetro "csv_content" é obrigatório.', code: 'INVALID_INPUT');
    }

    try {
      final lines = csvContent.split('\n').where((l) => l.trim().isNotEmpty).toList();
      if (lines.isEmpty) {
        return ToolResult.error('CSV vazio.', code: 'INVALID_INPUT');
      }

      final headers = _parseCsvLine(lines.first);
      final rows = lines.skip(1).map(_parseCsvLine).toList();

      return _createXlsxImpl({
        'headers': headers,
        'rows': rows,
      });
    } catch (e) {
      return ToolResult.error('Erro ao converter CSV: $e', code: 'CONVERSION_ERROR');
    }
  }

  /// Parser de CSV minimamente correto: respeita campos entre aspas
  /// que contenham vírgulas ou aspas escapadas (""), em vez do
  /// split(',') ingênuo que quebra em qualquer CSV com texto livre.
  static List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i++; // pula a segunda aspa do par escapado
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(char);
        }
      } else {
        if (char == '"') {
          inQuotes = true;
        } else if (char == ',') {
          result.add(buffer.toString());
          buffer.clear();
        } else {
          buffer.write(char);
        }
      }
    }
    result.add(buffer.toString());
    return result;
  }

  /// xlsx_to_json
  /// input: { xlsx_base64: String }
  static Future<ToolResult> xlsxToJson(Map<String, dynamic> input) {
    return ToolsQueue.instance.enqueue(() => _xlsxToJsonImpl(input));
  }

  static Future<ToolResult> _xlsxToJsonImpl(Map<String, dynamic> input) async {
    final String? xlsxBase64 = input['xlsx_base64'] as String?;
    if (xlsxBase64 == null || xlsxBase64.isEmpty) {
      return ToolResult.error('Parâmetro "xlsx_base64" é obrigatório.', code: 'INVALID_INPUT');
    }

    try {
      final bytes = base64Decode(xlsxBase64);
      final excelFile = Excel.decodeBytes(bytes);

      final Map<String, dynamic> result = {};
      for (final sheetName in excelFile.tables.keys) {
        final sheet = excelFile.tables[sheetName]!;
        result[sheetName] = sheet.rows
            .map((row) => row.map((cell) => cell?.value?.toString()).toList())
            .toList();
      }

      return ToolResult.ok(result);
    } catch (e) {
      return ToolResult.error('Erro ao ler XLSX: $e', code: 'READ_ERROR');
    }
  }
}