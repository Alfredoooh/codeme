=====================================================================
lib/tools/shared/tool_result.dart
=====================================================================

// Contrato de retorno padrão de TODAS as tools. Toda tool devolve
// este objeto — nunca lança exceção "solta" para quem chamou,
// exceto erros de programação genuínos (bugs).

class ToolResult {
  final bool success;
  final dynamic data; // Map, List, String, etc.
  final String? errorMessage;
  final String? errorCode; // ex: "TIMEOUT", "INVALID_INPUT", "IO_ERROR"

  const ToolResult._({
    required this.success,
    this.data,
    this.errorMessage,
    this.errorCode,
  });

  factory ToolResult.ok(dynamic data) {
    return ToolResult._(success: true, data: data);
  }

  factory ToolResult.error(String message, {String? code}) {
    return ToolResult._(
      success: false,
      errorMessage: message,
      errorCode: code,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      if (data != null) 'data': data,
      if (errorMessage != null) 'error': errorMessage,
      if (errorCode != null) 'error_code': errorCode,
    };
  }
}