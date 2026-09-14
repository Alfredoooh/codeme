=====================================================================
lib/tools/server/local_tools_server.dart
=====================================================================

// Servidor HTTP local — expõe todas as tools via POST /tools/:name,
// para ser chamado tanto pelo próprio app (ex: chat_tools.dart) quanto
// por processos externos na mesma rede, se necessário. Toda a lógica
// pesada já passa pela fila serial dentro de cada tool individual —
// este servidor só faz roteamento HTTP + serialização JSON.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../tool_registry.dart';
import '../shared/tool_result.dart';

class LocalToolsServer {
  HttpServer? _server;
  bool get isRunning => _server != null;

  static const int defaultPort = 8080;
  static const int _maxBodyBytes = 5 * 1024 * 1024; // 5MB — limite de segurança

  Future<void> start({int port = defaultPort}) async {
    if (_server != null) return; // já rodando, não duplica

    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);

    unawaited(_listen());
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _listen() async {
    await for (final request in _server!) {
      unawaited(_handle(request));
    }
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      if (request.method != 'POST' || !request.uri.path.startsWith('/tools/')) {
        response
          ..statusCode = HttpStatus.notFound
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'error': 'Rota não encontrada. Use POST /tools/:name'}));
        return;
      }

      final toolName = request.uri.path.replaceFirst('/tools/', '');

      final bodyBytes = await request.fold<List<int>>(
        [],
        (previous, element) => previous..addAll(element),
      );

      if (bodyBytes.length > _maxBodyBytes) {
        response
          ..statusCode = HttpStatus.requestEntityTooLarge
          ..write(jsonEncode({'error': 'Corpo da requisição excede o limite de ${_maxBodyBytes ~/ (1024 * 1024)}MB'}));
        return;
      }

      Map<String, dynamic> input = {};
      if (bodyBytes.isNotEmpty) {
        try {
          input = jsonDecode(utf8.decode(bodyBytes)) as Map<String, dynamic>;
        } catch (_) {
          response
            ..statusCode = HttpStatus.badRequest
            ..headers.contentType = ContentType.json
            ..write(jsonEncode({'error': 'JSON inválido no corpo da requisição.'}));
          return;
        }
      }

      final ToolResult result = await runTool(toolName, input);

      response
        ..statusCode = result.success ? HttpStatus.ok : HttpStatus.badRequest
        ..headers.contentType = ContentType.json
        ..write(jsonEncode(result.toJson()));
    } catch (e) {
      response
        ..statusCode = HttpStatus.internalServerError
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({'error': 'Erro interno: $e'}));
    } finally {
      await response.close();
    }
  }
}