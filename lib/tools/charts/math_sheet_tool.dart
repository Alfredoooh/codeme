// lib/tools/charts/math_sheet_tool.dart
//
// generate_math_sheet
//
// Gera uma folha visual com passo a passo resumido de uma expressão,
// mais gráfico opcional. Reaproveita FunctionPlotTool para o gráfico
// e math_expressions para simplificação/avaliação.
//
// math_expressions 2.x: parser é `Parser` (não GrammarParser nem
// ShuntingYardParser).

import 'package:math_expressions/math_expressions.dart';

import '../shared/tool_result.dart';
import 'function_plot_tool.dart';

class MathSheetTool {
  /// generate_math_sheet
  /// input: { expression: String, show_graph?: bool }
  static Future<ToolResult> generate(Map<String, dynamic> input) async {
    final String? expr = input['expression'] as String?;
    if (expr == null || expr.isEmpty) {
      return ToolResult.error('Parâmetro "expression" é obrigatório.',
          code: 'INVALID_INPUT');
    }

    final bool showGraph = (input['show_graph'] as bool?) ?? false;

    try {
      final parser = Parser();
      final Expression exp = parser.parse(expr);
      final Expression simplified = exp.simplify();

      String? graphImageBase64;
      if (showGraph) {
        final plotResult = await FunctionPlotTool.generate({
          'expression': expr,
          'x_min': -10,
          'x_max': 10,
        });
        if (plotResult.success) {
          graphImageBase64 =
              (plotResult.data as Map)['image_base64'] as String?;
        }
      }

      return ToolResult.ok({
        'original_expression': expr,
        'simplified_expression': simplified.toString(),
        if (graphImageBase64 != null)
          'graph_image_base64': graphImageBase64,
      });
    } catch (e) {
      return ToolResult.error('Erro ao gerar folha matemática: $e',
          code: 'GENERATION_ERROR');
    }
  }
}