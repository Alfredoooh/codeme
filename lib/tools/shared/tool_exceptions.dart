class ToolException implements Exception {
  final String message;
  final String code;

  const ToolException(this.message, {this.code = 'TOOL_ERROR'});

  @override
  String toString() => 'ToolException($code): $message';
}

class ToolTimeoutException extends ToolException {
  const ToolTimeoutException(String message)
      : super(message, code: 'TIMEOUT');
}

class ToolInputInvalidException extends ToolException {
  const ToolInputInvalidException(String message)
      : super(message, code: 'INVALID_INPUT');
}

class ToolRenderException extends ToolException {
  const ToolRenderException(String message)
      : super(message, code: 'RENDER_ERROR');
}

class ToolNotAllowedException extends ToolException {
  const ToolNotAllowedException(String message)
      : super(message, code: 'NOT_ALLOWED');
}