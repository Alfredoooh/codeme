import '../shared/tool_result.dart';

class DateTimeTool {
  /// get_current_datetime
  /// input: { timezone_offset_hours?: number } — se omitido, usa o
  /// timezone local do dispositivo.
  static ToolResult getCurrentDateTime(Map<String, dynamic> input) {
    final now = DateTime.now();
    final utcNow = now.toUtc();

    final double? offsetHours = (input['timezone_offset_hours'] as num?)?.toDouble();
    final DateTime targetTime = offsetHours != null
        ? utcNow.add(Duration(minutes: (offsetHours * 60).round()))
        : now;

    const weekdays = [
      'Segunda-feira', 'Terça-feira', 'Quarta-feira', 'Quinta-feira',
      'Sexta-feira', 'Sábado', 'Domingo',
    ];
    const months = [
      'Janeiro', 'Fevereiro', 'Março', 'Abril', 'Maio', 'Junho',
      'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro',
    ];

    return ToolResult.ok({
      'iso_8601': targetTime.toIso8601String(),
      'date': '${targetTime.year.toString().padLeft(4, '0')}-'
          '${targetTime.month.toString().padLeft(2, '0')}-'
          '${targetTime.day.toString().padLeft(2, '0')}',
      'time': '${targetTime.hour.toString().padLeft(2, '0')}:'
          '${targetTime.minute.toString().padLeft(2, '0')}:'
          '${targetTime.second.toString().padLeft(2, '0')}',
      'weekday': weekdays[targetTime.weekday - 1],
      'month_name': months[targetTime.month - 1],
      'year': targetTime.year,
      'unix_timestamp': targetTime.millisecondsSinceEpoch ~/ 1000,
      'device_timezone_offset_hours': now.timeZoneOffset.inMinutes / 60,
    });
  }
}