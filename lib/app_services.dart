import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

class WorkerConfig {
  /// Cola aqui o link do teu worker quando o tiveres.
  /// Ex.: https://teu-worker.seudominio.workers.dev
  static String baseUrl = const String.fromEnvironment('WORKER_BASE_URL', defaultValue: '');

  static String get resolvedBaseUrl {
    final v = baseUrl.trim();
    return v.isEmpty ? '' : v.replaceAll(RegExp(r'/$'), '');
  }
}

class WorkerSession {
  final String token;
  final String id;
  final String name;
  final String email;
  final int credits;
  final Map<String, dynamic> preferences;

  const WorkerSession({
    required this.token,
    required this.id,
    required this.name,
    required this.email,
    required this.credits,
    required this.preferences,
  });

  factory WorkerSession.fromJson(Map<String, dynamic> json) {
    return WorkerSession(
      token: (json['token'] ?? '') as String,
      id: (json['id'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      email: (json['email'] ?? '') as String,
      credits: (json['credits'] is int)
          ? json['credits'] as int
          : int.tryParse('${json['credits'] ?? 0}') ?? 0,
      preferences: Map<String, dynamic>.from(json['preferences'] as Map? ?? const {}),
    );
  }
}

class AppSessionController extends ChangeNotifier {
  WorkerSession? _session;

  WorkerSession? get session => _session;
  bool get isAuthenticated => _session != null;

  void setSession(WorkerSession session) {
    _session = session;
    notifyListeners();
  }

  void clear() {
    _session = null;
    notifyListeners();
  }
}

final AppSessionController appSession = AppSessionController();

class WorkerApiException implements Exception {
  final String message;
  final int? statusCode;
  WorkerApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ChatStreamEvent {
  final String type; // think | token | done | credits_exhausted | error
  final String text;
  final String? message;
  final String? fullText;
  const ChatStreamEvent._(this.type, this.text, this.message, this.fullText);

  const ChatStreamEvent.think(String text) : this._('think', text, null, null);
  const ChatStreamEvent.token(String text) : this._('token', text, null, null);
  const ChatStreamEvent.done(String fullText) : this._('done', '', null, fullText);
  const ChatStreamEvent.creditsExhausted() : this._('credits_exhausted', '', null, null);
  const ChatStreamEvent.error(String message) : this._('error', '', message, null);
}

class WorkerApi {
  final String baseUrl;
  WorkerApi({String? baseUrl}) : baseUrl = baseUrl ?? WorkerConfig.resolvedBaseUrl;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = baseUrl.trim();
    if (base.isEmpty) {
      throw WorkerApiException('Configura o link do worker antes de usar esta função.');
    }
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Future<Map<String, dynamic>> _jsonRequest(
    String method,
    String path, {
    Map<String, dynamic>? body,
    String? token,
    Map<String, String>? query,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final client = HttpClient();
    try {
      final req = await client.openUrl(method, _uri(path, query));
      req.headers.contentType = ContentType.json;
      if (token != null && token.isNotEmpty) {
        req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      }
      if (body != null) {
        req.add(utf8.encode(jsonEncode(body)));
      }
      final res = await req.close().timeout(timeout);
      final text = await utf8.decodeStream(res);
      final map = text.isEmpty ? <String, dynamic>{} : (jsonDecode(text) as Map<String, dynamic>);
      if (res.statusCode >= 400) {
        throw WorkerApiException(map['error']?.toString() ?? 'Erro no worker', res.statusCode);
      }
      return map;
    } finally {
      client.close(force: true);
    }
  }

  Future<WorkerSession> login(String email, String password) async {
    final data = await _jsonRequest('POST', '/auth/login', body: {'email': email, 'password': password});
    return WorkerSession.fromJson(data);
  }

  Future<WorkerSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final data = await _jsonRequest('POST', '/auth/register', body: {
      'name': name,
      'email': email,
      'password': password,
    });
    return WorkerSession.fromJson(data);
  }

  Future<void> logout(String token) async {
    await _jsonRequest('POST', '/auth/logout', token: token);
  }

  Future<Map<String, dynamic>> getMe(String token) async {
    return _jsonRequest('GET', '/user/me', token: token);
  }

  Future<Map<String, dynamic>> createConversation({
    required String token,
    required String title,
    required List<Map<String, dynamic>> messages,
    required String model,
  }) async {
    return _jsonRequest('POST', '/conversations', token: token, body: {
      'title': title,
      'messages': messages,
      'model': model,
    });
  }

  Future<Map<String, dynamic>> updateConversation({
    required String token,
    required String id,
    required String title,
    required List<Map<String, dynamic>> messages,
    required String model,
  }) async {
    return _jsonRequest('PUT', '/conversations/$id', token: token, body: {
      'title': title,
      'messages': messages,
      'model': model,
    });
  }

  Future<String> generateTitle({
    required String token,
    required String message,
    required String language,
  }) async {
    final data = await _jsonRequest('POST', '/ai/title', token: token, body: {
      'message': message,
      'language': language,
    });
    return (data['title']?.toString().trim().isNotEmpty ?? false)
        ? data['title'].toString().trim()
        : message.split(RegExp(r'\s+')).take(4).join(' ');
  }

  Future<String> transcribe({
    required String token,
    required List<int> bytes,
    required String filename,
    String language = 'pt',
    String prompt = '',
  }) async {
    final client = HttpClient();
    try {
      final req = await client.postUrl(_uri('/ai/transcribe'));
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      final boundary = '----nexa-${DateTime.now().microsecondsSinceEpoch}';
      req.headers.contentType = ContentType('multipart', 'form-data', parameters: {'boundary': boundary});

      void addField(String name, String value) {
        req.write('--$boundary\r\n');
        req.write('Content-Disposition: form-data; name="$name"\r\n\r\n');
        req.write(value);
        req.write('\r\n');
      }

      addField('language', language);
      if (prompt.isNotEmpty) addField('prompt', prompt);
      req.write('--$boundary\r\n');
      req.write('Content-Disposition: form-data; name="file"; filename="$filename"\r\n');
      req.write('Content-Type: application/octet-stream\r\n\r\n');
      req.add(bytes);
      req.write('\r\n--$boundary--\r\n');

      final res = await req.close();
      final text = await utf8.decodeStream(res);
      final map = jsonDecode(text) as Map<String, dynamic>;
      if (res.statusCode >= 400) {
        throw WorkerApiException(map['error']?.toString() ?? 'Erro ao transcrever', res.statusCode);
      }
      return map['text']?.toString() ?? '';
    } finally {
      client.close(force: true);
    }
  }

  Stream<ChatStreamEvent> streamChat({
    required String token,
    required List<Map<String, dynamic>> messages,
    required String model,
    required String language,
    required bool think,
    String provider = 'gemini',
    String systemPrompt = '',
  }) async* {
    final client = HttpClient();
    try {
      final req = await client.postUrl(_uri('/ai/chat'));
      req.headers.contentType = ContentType.json;
      req.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      req.add(utf8.encode(jsonEncode({
        'messages': messages,
        'stream': true,
        'language': language,
        'think': think,
        'provider': provider,
        'model': model,
        if (systemPrompt.trim().isNotEmpty) 'systemPrompt': systemPrompt,
      })));
      final res = await req.close();
      if (res.statusCode == 402) {
        yield const ChatStreamEvent.creditsExhausted();
        return;
      }
      if (res.statusCode >= 400) {
        final text = await utf8.decodeStream(res);
        yield ChatStreamEvent.error(text.isEmpty ? 'Erro $res' : text);
        return;
      }

      StringBuffer buffer = StringBuffer();
      var fullText = '';
      await for (final chunk in res.transform(utf8.decoder)) {
        buffer.write(chunk);
        final lines = buffer.toString().split('\n');
        buffer = StringBuffer();
        if (lines.isNotEmpty) buffer.write(lines.removeLast());
        for (final line in lines) {
          if (!line.startsWith('data: ')) continue;
          final raw = line.substring(6).trim();
          if (raw == '[DONE]') {
            yield ChatStreamEvent.done(fullText);
            return;
          }
          try {
            final data = jsonDecode(raw) as Map<String, dynamic>;
            final candidates = data['candidates'];
            if (candidates is! List || candidates.isEmpty) continue;
            final candidate = candidates.first as Map<String, dynamic>;
            final content = candidate['content'];
            if (content is! Map<String, dynamic>) continue;
            final parts = content['parts'];
            if (parts is! List) continue;
            for (final part in parts) {
              if (part is! Map<String, dynamic>) continue;
              final text = (part['text'] ?? '').toString();
              if (text.isEmpty) continue;
              if (part['thought'] == true) {
                yield ChatStreamEvent.think(text);
              } else {
                fullText += text;
                yield ChatStreamEvent.token(text);
              }
            }
            final fin = candidate['finishReason']?.toString();
            if (fin == 'STOP' || fin == 'MAX_TOKENS') {
              yield ChatStreamEvent.done(fullText);
              return;
            }
          } catch (_) {}
        }
      }
      yield ChatStreamEvent.done(fullText);
    } on WorkerApiException catch (e) {
      if (e.statusCode == 402) {
        yield const ChatStreamEvent.creditsExhausted();
      } else {
        yield ChatStreamEvent.error(e.message);
      }
    } catch (e) {
      yield ChatStreamEvent.error('Erro de rede: $e');
    } finally {
      client.close(force: true);
    }
  }
}
