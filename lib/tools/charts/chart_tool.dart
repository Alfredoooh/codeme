=====================================================================
lib/tools/charts/chart_tool.dart  (IMPLEMENTADO — sem placeholders)
=====================================================================

// generate_chart
//
// Usa fl_chart para montar o gráfico como widget, depois captura via
// o host de renderização off-screen (widget_render_host.dart) — mais
// leve que WebView, pois não carrega motor de browser.

import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../shared/tool_result.dart';
import '../shared/fonts.dart';
import '../server/widget_render_host.dart';
import '../server/tools_queue.dart';

class ChartTool {
  static const double _width = 800;
  static const double _height = 500;

  static final List<Color> _palette = [
    Colors.blue, Colors.orange, Colors.green, Colors.red,
    Colors.purple, Colors.teal, Colors.brown, Colors.pink,
  ];

  /// generate_chart
  /// input: {
  ///   chart_type: String — "bar" | "line" | "pie",
  ///   title?: String,
  ///   labels: List<String>,
  ///   datasets: List<{ name?: String, values: List<num> }>
  /// }
  static Future<ToolResult> generate(Map<String, dynamic> input) {
    // Renderização de widget é uma operação pesada o suficiente
    // (constrói árvore, faz layout, pinta, captura Skia) para
    // justificar passar pela fila serial — mesmo padrão das outras
    // tools de imagem/PDF.
    return ToolsQueue.instance.enqueue(() => _generateImpl(input));
  }

  static Future<ToolResult> _generateImpl(Map<String, dynamic> input) async {
    final String? chartType = input['chart_type'] as String?;
    final List<dynamic>? labels = input['labels'] as List<dynamic>?;
    final List<dynamic>? rawDatasets = input['datasets'] as List<dynamic>?;
    final String? title = input['title'] as String?;

    if (chartType == null || labels == null || rawDatasets == null) {
      return ToolResult.error('Parâmetros "chart_type", "labels" e "datasets" são obrigatórios.', code: 'INVALID_INPUT');
    }
    if (labels.isEmpty || rawDatasets.isEmpty) {
      return ToolResult.error('"labels" e "datasets" não podem estar vazios.', code: 'INVALID_INPUT');
    }

    try {
      final datasets = rawDatasets.map((d) {
        final map = d as Map<String, dynamic>;
        return (
          name: map['name']?.toString(),
          values: (map['values'] as List<dynamic>).map((v) => (v as num).toDouble()).toList(),
        );
      }).toList();

      final chartWidget = _buildChart(chartType, labels.cast<String>(), datasets);

      final content = Container(
        width: _width,
        height: _height,
        color: Colors.white,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Text(title, style: ToolFonts.bold(size: 20)),
              const SizedBox(height: 16),
            ],
            Expanded(child: chartWidget),
            if (datasets.length > 1 || datasets.any((d) => d.name != null)) ...[
              const SizedBox(height: 12),
              _buildLegend(datasets),
            ],
          ],
        ),
      );

      final Uint8List bytes = await WidgetRenderHost.instance.renderToPng(
        widget: content,
        size: const Size(_width, _height),
      );

      return ToolResult.ok({
        'image_base64': base64Encode(bytes),
        'chart_type': chartType,
      });
    } catch (e) {
      return ToolResult.error('Erro ao gerar gráfico: $e', code: 'GENERATION_ERROR');
    }
  }

  static Widget _buildChart(
    String chartType,
    List<String> labels,
    List<({String? name, List<double> values})> datasets,
  ) {
    switch (chartType) {
      case 'line':
        return _buildLineChart(labels, datasets);
      case 'pie':
        return _buildPieChart(labels, datasets.first.values);
      case 'bar':
      default:
        return _buildBarChart(labels, datasets);
    }
  }

  static Widget _buildBarChart(
    List<String> labels,
    List<({String? name, List<double> values})> datasets,
  ) {
    final groups = <BarChartGroupData>[];
    for (int i = 0; i < labels.length; i++) {
      final rods = <BarChartRodData>[];
      for (int d = 0; d < datasets.length; d++) {
        final values = datasets[d].values;
        final value = i < values.length ? values[i] : 0.0;
        rods.add(BarChartRodData(
          toY: value,
          color: _palette[d % _palette.length],
          width: datasets.length > 1 ? 14 : 22,
          borderRadius: BorderRadius.circular(4),
        ));
      }
      groups.add(BarChartGroupData(x: i, barRods: rods, barsSpace: 4));
    }

    return BarChart(
      BarChartData(
        barGroups: groups,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(labels[idx], style: ToolFonts.regular(size: 11)),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildLineChart(
    List<String> labels,
    List<({String? name, List<double> values})> datasets,
  ) {
    final lines = <LineChartBarData>[];
    for (int d = 0; d < datasets.length; d++) {
      final values = datasets[d].values;
      final spots = <FlSpot>[
        for (int i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
      ];
      lines.add(LineChartBarData(
        spots: spots,
        isCurved: true,
        color: _palette[d % _palette.length],
        barWidth: 3,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(
          show: datasets.length == 1,
          color: _palette[d % _palette.length].withOpacity(0.12),
        ),
      ));
    }

    return LineChart(
      LineChartData(
        lineBarsData: lines,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx < 0 || idx >= labels.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(labels[idx], style: ToolFonts.regular(size: 11)),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  static Widget _buildPieChart(List<String> labels, List<double> values) {
    final total = values.fold<double>(0, (a, b) => a + b);
    final sections = <PieChartSectionData>[];

    for (int i = 0; i < values.length; i++) {
      final percent = total > 0 ? (values[i] / total * 100) : 0.0;
      sections.add(PieChartSectionData(
        value: values[i],
        color: _palette[i % _palette.length],
        title: '${percent.toStringAsFixed(0)}%',
        radius: 90,
        titleStyle: ToolFonts.bold(size: 13, color: Colors.white),
      ));
    }

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(PieChartData(sections: sections, sectionsSpace: 2, centerSpaceRadius: 40)),
        ),
        Expanded(
          flex: 1,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (int i = 0; i < labels.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Container(width: 10, height: 10, color: _palette[i % _palette.length]),
                      const SizedBox(width: 6),
                      Flexible(child: Text(labels[i], style: ToolFonts.regular(size: 11), overflow: TextOverflow.ellipsis)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildLegend(List<({String? name, List<double> values})> datasets) {
    return Wrap(
      spacing: 16,
      children: [
        for (int d = 0; d < datasets.length; d++)
          if (datasets[d].name != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, color: _palette[d % _palette.length]),
                const SizedBox(width: 6),
                Text(datasets[d].name!, style: ToolFonts.regular(size: 12)),
              ],
            ),
      ],
    );
  }
}