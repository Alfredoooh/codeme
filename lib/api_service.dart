// ══════════════════════════════════════════════════════════════
// FILE: lib/api_service.dart
// ══════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String kApiBase = 'https://ipc.alfredopjonas.workers.dev';

// ── Providers reais suportados pelo worker. O backend é DeepSeek —
//    os 3 modelos (flash/pro/reasoning) são todos provider "deepseek",
//    diferenciados pelo campo model. gemini/groq foram removidos
//    porque o chat principal já não os usa.
enum ApiProvider { deepseekFlash, deepseekPro, deepseekReasoning }

class ProviderConfig {
  final String provider; // será sempre "deepseek"
  final String deepseekModel;
  const ProviderConfig(this.provider, {required this.deepseekModel});
}

const Map<ApiProvider, ProviderConfig> kProviderMap = {
  ApiProvider.deepseekFlash:     ProviderConfig('deepseek', deepseekModel: 'flash'),
  ApiProvider.deepseekPro:       ProviderConfig('deepseek', deepseekModel: 'pro'),
  ApiProvider.deepseekReasoning: ProviderConfig('deepseek', deepseekModel: 'reasoning'),
};

// ══════════════════════════════════════════════════════════════
// MENSAGEM DE CHAT
// ══════════════════════════════════════════════════════════════
class ChatMessage {
  final String role; // "user" | "assistant" | "tool"
  final String content;
  final List<Map<String, dynamic>>? attachments;
  // Presentes apenas em mensagens do ciclo de tool calling:
  final String? toolCallId; // usado em mensagens role:"tool" — id da chamada que este resultado responde
  final List<Map<String, dynamic>>? toolCalls; // usado em mensagens role:"assistant" que pediram tool calls
  final String? name; // nome da função, usado em mensagens role:"tool"

  const ChatMessage({
    required this.role,
    required this.content,
    this.attachments,
    this.toolCallId,
    this.toolCalls,
    this.name,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        if (attachments != null && attachments!.isNotEmpty) 'attachments': attachments,
        if (toolCallId != null) 'tool_call_id': toolCallId,
        if (toolCalls != null) 'tool_calls': toolCalls,
        if (name != null) 'name': name,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        role: j['role']?.toString() ?? 'user',
        content: j['content']?.toString() ?? '',
        attachments: (j['attachments'] is List)
            ? (j['attachments'] as List).whereType<Map<String, dynamic>>().toList()
            : null,
        toolCallId: j['tool_call_id']?.toString(),
        toolCalls: (j['tool_calls'] is List)
            ? (j['tool_calls'] as List).whereType<Map<String, dynamic>>().toList()
            : null,
        name: j['name']?.toString(),
      );
}

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class CreditsExhaustedException extends ApiException {
  CreditsExhaustedException() : super('Sem créditos. Recarrega para continuar.', statusCode: 402);
}

sealed class ChatStreamEvent {}

class ChatTokenEvent extends ChatStreamEvent {
  final String text;
  ChatTokenEvent(this.text);
}

class ChatThinkEvent extends ChatStreamEvent {
  final String text;
  ChatThinkEvent(this.text);
}

class ChatDoneEvent extends ChatStreamEvent {
  final String fullText;
  ChatDoneEvent(this.fullText);
}

class ChatErrorEvent extends ChatStreamEvent {
  final String message;
  ChatErrorEvent(this.message);
}

class ChatCreditsExhaustedEvent extends ChatStreamEvent {}

// ══════════════════════════════════════════════════════════════
// TOOL CALLING
// ══════════════════════════════════════════════════════════════
//
// Fluxo: 1) Flutter manda `tools` no body do POST /ai/chat.
// 2) DeepSeek devolve tool_calls em vez de content, via SSE
//    (delta.tool_calls, fragmentado em vários chunks por índice).
// 3) Ao fechar o stream (finish_reason == "tool_calls" ou [DONE]
//    com tool_calls pendentes), emitimos ChatToolCallEvent com a
//    lista de chamadas já reconstruídas.
// 4) Quem consome o stream (aitab.dart) executa a função local
//    correspondente, e faz uma SEGUNDA chamada a streamChat
//    passando o histórico + a mensagem assistant com tool_calls +
//    uma mensagem role:"tool" com o resultado. Só essa segunda
//    resposta é que chega ao utilizador como texto final.
// ══════════════════════════════════════════════════════════════

class ToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  const ToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  Map<String, dynamic> toJson() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parameters,
        },
      };
}

class ToolCall {
  final String id;
  final String name;
  final String argumentsJson;
  const ToolCall({required this.id, required this.name, required this.argumentsJson});

  Map<String, dynamic> get arguments {
    if (argumentsJson.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(argumentsJson);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  /// Representação desta chamada como apareceria numa mensagem
  /// assistant com tool_calls, para reenviar no histórico da
  /// segunda chamada.
  Map<String, dynamic> toMessageJson() => {
        'id': id,
        'type': 'function',
        'function': {'name': name, 'arguments': argumentsJson},
      };
}

class ChatToolCallEvent extends ChatStreamEvent {
  final List<ToolCall> calls;
  ChatToolCallEvent(this.calls);
}

/// Se o Worker rejeitar `tools` uma vez (400/422) numa sessão de
/// app, paramos de o mandar nas chamadas seguintes em vez de
/// falhar sempre. Reinicia a cada abertura da app (estado em
/// memória, não persistido).
class ToolCallingSupport {
  static bool _supported = true;
  static bool get supported => _supported;
  static void markUnsupported() => _supported = false;
}

// ══════════════════════════════════════════════════════════════
// CANVAS
// ══════════════════════════════════════════════════════════════
enum CanvasKind { doc, sheet, slide, whiteboard }

extension CanvasKindX on CanvasKind {
  String get wireTag => const {
        CanvasKind.doc:        'doc',
        CanvasKind.sheet:      'sheet',
        CanvasKind.slide:      'slide',
        CanvasKind.whiteboard: 'whiteboard',
      }[this]!;

  static CanvasKind fromWire(String tag) {
    switch (tag) {
      case 'sheet': return CanvasKind.sheet;
      case 'slide': return CanvasKind.slide;
      case 'whiteboard': return CanvasKind.whiteboard;
      default: return CanvasKind.doc;
    }
  }
}

class CanvasItem {
  final String id;
  final CanvasKind kind;
  final String title;
  final String content;
  final int createdAt;

  const CanvasItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.content,
    required this.createdAt,
  });

  CanvasItem copyWith({String? title, String? content}) => CanvasItem(
        id: id,
        kind: kind,
        title: title ?? this.title,
        content: content ?? this.content,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.wireTag,
        'title': title,
        'content': content,
        'createdAt': createdAt,
      };

  factory CanvasItem.fromJson(Map<String, dynamic> j) => CanvasItem(
        id: j['id']?.toString() ?? '',
        kind: CanvasKindX.fromWire(j['kind']?.toString() ?? 'doc'),
        title: j['title']?.toString() ?? 'Sem título',
        content: j['content']?.toString() ?? '',
        createdAt: (j['createdAt'] is num) ? (j['createdAt'] as num).toInt() : 0,
      );
}

class CanvasParseResult {
  final String cleanText;
  final List<CanvasItem> items;
  const CanvasParseResult(this.cleanText, this.items);
}

class CanvasParser {
  static final RegExp _blockRe = RegExp(
    r'\[\[canvas:(doc|sheet|slide|whiteboard):(.*?)\|\|([\s\S]*?)\]\]',
    multiLine: true,
  );

  static CanvasParseResult parse(String raw, {required String Function() idGen}) {
    final items = <CanvasItem>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    final cleaned = raw.replaceAllMapped(_blockRe, (m) {
      final kind = CanvasKindX.fromWire(m.group(1)!);
      final title = m.group(2)!.trim().isEmpty ? 'Sem título' : m.group(2)!.trim();
      final content = m.group(3)!.trim();
      items.add(CanvasItem(
        id: idGen(),
        kind: kind,
        title: title,
        content: content,
        createdAt: now,
      ));
      return '';
    }).trim();
    return CanvasParseResult(cleaned, items);
  }

  static bool hasOpenBlock(String raw) {
    final openIdx = raw.lastIndexOf('[[canvas:');
    if (openIdx == -1) return false;
    final closeIdx = raw.indexOf(']]', openIdx);
    return closeIdx == -1;
  }

  static CanvasKind? openBlockKind(String raw) {
    final openIdx = raw.lastIndexOf('[[canvas:');
    if (openIdx == -1) return null;
    final rest = raw.substring(openIdx + 9);
    final colonIdx = rest.indexOf(':');
    if (colonIdx == -1) return null;
    final tag = rest.substring(0, colonIdx);
    if (tag == 'sheet') return CanvasKind.sheet;
    if (tag == 'slide') return CanvasKind.slide;
    if (tag == 'whiteboard') return CanvasKind.whiteboard;
    if (tag == 'doc') return CanvasKind.doc;
    return null;
  }
}

// ══════════════════════════════════════════════════════════════
// AUTH API
// ══════════════════════════════════════════════════════════════
class AuthApiService {
  static Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$kApiBase/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = _decode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(data['error']?.toString() ?? 'Erro ao iniciar sessão', statusCode: res.statusCode);
    }
    return data;
  }

  static Future<Map<String, dynamic>> register({
    required String name,
    required String email,
    required String password,
    int? age,
    String? country,
    String? state,
    String? city,
    String? occupation,
    String? occupationDetail,
  }) async {
    final body = <String, dynamic>{'name': name, 'email': email, 'password': password};
    if (age != null) body['age'] = age;
    if (country != null) body['country'] = country;
    if (state != null) body['state'] = state;
    if (city != null) body['city'] = city;
    if (occupation != null) body['occupation'] = occupation;
    if (occupationDetail != null) body['occupationDetail'] = occupationDetail;

    final res = await http.post(
      Uri.parse('$kApiBase/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    final data = _decode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(data['error']?.toString() ?? 'Erro ao criar conta', statusCode: res.statusCode);
    }
    return data;
  }

  static Future<void> logout(String token) async {
    try {
      await http.post(
        Uri.parse('$kApiBase/auth/logout'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {}
  }

  static Future<bool> logoutAll(String token) async {
    try {
      final res = await http.post(
        Uri.parse('$kApiBase/auth/logout-all'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> forgotPassword(String email) async {
    final res = await http.post(
      Uri.parse('$kApiBase/auth/forgot-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );
    final data = _decode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(data['error']?.toString() ?? 'Erro ao pedir recuperação', statusCode: res.statusCode);
    }
    return data;
  }

  static Future<Map<String, dynamic>> resetPassword(String token, String password) async {
    final res = await http.post(
      Uri.parse('$kApiBase/auth/reset-password'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'password': password}),
    );
    final data = _decode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(data['error']?.toString() ?? 'Erro ao repor password', statusCode: res.statusCode);
    }
    return data;
  }
}

// ══════════════════════════════════════════════════════════════
// PROFILE / USER API
// ══════════════════════════════════════════════════════════════
class ProfileApiService {
  static Future<Map<String, dynamic>> getMe(String token) async {
    final res = await http.get(
      Uri.parse('$kApiBase/user/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = _decode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(data['error']?.toString() ?? 'Erro ao carregar perfil', statusCode: res.statusCode);
    }
    return data;
  }

  static Future<Map<String, dynamic>> updateAccount(
    String token, {
    String? name,
    String? password,
    String? currentPassword,
    Map<String, dynamic>? preferences,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (password != null) body['password'] = password;
    if (currentPassword != null) body['currentPassword'] = currentPassword;
    if (preferences != null) body['preferences'] = preferences;

    final res = await http.put(
      Uri.parse('$kApiBase/user/me'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(body),
    );
    final data = _decode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(data['error']?.toString() ?? 'Erro ao atualizar conta', statusCode: res.statusCode);
    }
    return data;
  }

  static Future<Map<String, dynamic>> updateProfile(
    String token,
    Map<String, dynamic> profileFields,
  ) async {
    final res = await http.put(
      Uri.parse('$kApiBase/user/profile'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode(profileFields),
    );
    final data = _decode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(data['error']?.toString() ?? 'Erro ao atualizar perfil', statusCode: res.statusCode);
    }
    return data;
  }

  static Future<Map<String, dynamic>> updateAvatar(String token, String avatarBase64) async {
    final res = await http.put(
      Uri.parse('$kApiBase/user/avatar'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'avatar': avatarBase64}),
    );
    final data = _decode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(data['error']?.toString() ?? 'Erro ao atualizar avatar', statusCode: res.statusCode);
    }
    return data;
  }
}

// ══════════════════════════════════════════════════════════════
// CREDITS API
// ══════════════════════════════════════════════════════════════
class CreditsApiService {
  static Future<Map<String, dynamic>?> getBalance(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$kApiBase/credits/balance'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      return _decode(res.body);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>> checkout(String token, String packageId) async {
    final res = await http.post(
      Uri.parse('$kApiBase/credits/checkout'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'package': packageId}),
    );
    final data = _decode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(data['error']?.toString() ?? 'Erro checkout', statusCode: res.statusCode);
    }
    return data;
  }
}

// ══════════════════════════════════════════════════════════════
// CONVERSATIONS API
// ══════════════════════════════════════════════════════════════
class ConversationsApiService {
  static Future<List<Map<String, dynamic>>> list(String token, {bool archived = false}) async {
    try {
      final uri = Uri.parse('$kApiBase/conversations').replace(
        queryParameters: archived ? {'archived': 'true'} : null,
      );
      final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode < 200 || res.statusCode >= 300) return [];
      final data = _decode(res.body);
      final list = data['conversations'];
      if (list is! List) return [];
      return list.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Map<String, dynamic>?> create(
    String token, {
    required String title,
    List<ChatMessage> messages = const [],
    String? model,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$kApiBase/conversations'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'title': title,
          'messages': messages.map((m) => m.toJson()).toList(),
          if (model != null) 'model': model,
        }),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      return _decode(res.body);
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> get(String token, String id) async {
    try {
      final res = await http.get(
        Uri.parse('$kApiBase/conversations/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      return _decode(res.body);
    } catch (_) {
      return null;
    }
  }

  static Future<void> update(
    String token,
    String id, {
    String? title,
    List<ChatMessage>? messages,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (messages != null) body['messages'] = messages.map((m) => m.toJson()).toList();
      await http.put(
        Uri.parse('$kApiBase/conversations/$id'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(body),
      );
    } catch (_) {}
  }

  static Future<bool> rename(String token, String id, String title) async {
    try {
      final res = await http.put(
        Uri.parse('$kApiBase/conversations/$id'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'title': title}),
      );
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Future<void> delete(String token, String id) async {
    try {
      await http.delete(
        Uri.parse('$kApiBase/conversations/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {}
  }

  static Future<void> deleteAll(String token) async {
    try {
      await http.delete(
        Uri.parse('$kApiBase/conversations/all'),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (_) {}
  }

  static Future<void> pin(String token, String id, bool pinned) async {
    try {
      await http.put(
        Uri.parse('$kApiBase/conversations/$id/pin'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'pinned': pinned}),
      );
    } catch (_) {}
  }

  static Future<void> archive(String token, String id, bool archived) async {
    try {
      await http.put(
        Uri.parse('$kApiBase/conversations/$id/archive'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'archived': archived}),
      );
    } catch (_) {}
  }

  static Future<List<Map<String, dynamic>>> search(String token, String query) async {
    try {
      final uri = Uri.parse('$kApiBase/conversations/search').replace(
        queryParameters: {'q': query},
      );
      final res = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      if (res.statusCode < 200 || res.statusCode >= 300) return [];
      final data = _decode(res.body);
      final list = data['conversations'];
      if (list is! List) return [];
      return list.whereType<Map<String, dynamic>>().toList();
    } catch (_) {
      return [];
    }
  }
}

// ══════════════════════════════════════════════════════════════
// EVENTS API
// ══════════════════════════════════════════════════════════════
class EventItem {
  final String id;
  final String title;
  final String description;
  final int startAt;
  final int endAt;
  final bool allDay;
  final String color;

  const EventItem({
    required this.id,
    required this.title,
    required this.description,
    required this.startAt,
    required this.endAt,
    required this.allDay,
    required this.color,
  });

  DateTime get startDate => DateTime.fromMillisecondsSinceEpoch(startAt);
  DateTime get endDate => DateTime.fromMillisecondsSinceEpoch(endAt);

  factory EventItem.fromJson(Map<String, dynamic> j) => EventItem(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        description: j['description']?.toString() ?? '',
        startAt: (j['startAt'] is num) ? (j['startAt'] as num).toInt() : 0,
        endAt: (j['endAt'] is num) ? (j['endAt'] as num).toInt() : 0,
        allDay: j['allDay'] == true,
        color: j['color']?.toString() ?? '#6F5AF6',
      );
}

class EventsApiService {
  static Future<List<EventItem>> list(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$kApiBase/events'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return [];
      final data = _decode(res.body);
      final events = data['events'];
      if (events is! List) return [];
      return events.whereType<Map<String, dynamic>>().map(EventItem.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<EventItem?> create(
    String token, {
    required String title,
    String description = '',
    required int startAt,
    int? endAt,
    bool allDay = false,
    String color = '#6F5AF6',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$kApiBase/events'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'title': title,
          'description': description,
          'startAt': startAt,
          if (endAt != null) 'endAt': endAt,
          'allDay': allDay,
          'color': color,
        }),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      return EventItem.fromJson(_decode(res.body));
    } catch (_) {
      return null;
    }
  }

  static Future<bool> delete(String token, String id) async {
    try {
      final res = await http.delete(
        Uri.parse('$kApiBase/events/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}

// ══════════════════════════════════════════════════════════════
// AI CHAT API
// ══════════════════════════════════════════════════════════════
class AiApiService {
  static Stream<ChatStreamEvent> streamChat({
    required String token,
    required List<ChatMessage> messages,
    required ApiProvider provider,
    String language = 'pt',
    String? systemPrompt,
    List<ToolDefinition>? tools,
  }) async* {
    final cfg = kProviderMap[provider]!;
    final client = http.Client();
    final sendTools = tools != null && tools.isNotEmpty && ToolCallingSupport.supported;

    try {
      final req = http.Request('POST', Uri.parse('$kApiBase/ai/chat'));
      req.headers['Content-Type'] = 'application/json';
      req.headers['Authorization'] = 'Bearer $token';
      req.body = jsonEncode({
        'messages': messages.map((m) => m.toJson()).toList(),
        'stream': true,
        'language': language,
        'provider': cfg.provider,
        'model': cfg.deepseekModel,
        if (systemPrompt != null && systemPrompt.trim().isNotEmpty) 'systemPrompt': systemPrompt,
        if (sendTools) 'tools': tools.map((t) => t.toJson()).toList(),
      });

      final streamed = await client.send(req);

      if (streamed.statusCode == 402) {
        yield ChatCreditsExhaustedEvent();
        return;
      }
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        final bodyStr = await streamed.stream.bytesToString();
        if (sendTools && (streamed.statusCode == 400 || streamed.statusCode == 422)) {
          ToolCallingSupport.markUnsupported();
        }
        String msg = 'Erro ${streamed.statusCode}';
        try {
          final decoded = jsonDecode(bodyStr);
          if (decoded is Map && decoded['error'] != null) msg = decoded['error'].toString();
        } catch (_) {}
        yield ChatErrorEvent(msg);
        return;
      }

      String pending = '';
      String fullText = '';
      final Map<int, ({String? id, String name, StringBuffer args})> pendingToolCalls = {};

      List<ToolCall> finalizeToolCalls() {
        final entries = pendingToolCalls.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        return entries
            .where((e) => e.value.id != null && e.value.name.isNotEmpty)
            .map((e) => ToolCall(
                  id: e.value.id!,
                  name: e.value.name,
                  argumentsJson: e.value.args.toString(),
                ))
            .toList();
      }

      await for (final chunk in streamed.stream.transform(utf8.decoder)) {
        pending += chunk;
        final lines = pending.split('\n');
        pending = lines.isNotEmpty ? lines.removeLast() : '';

        for (final rawLine in lines) {
          final line = rawLine.trimRight();
          if (!line.startsWith('data: ')) continue;
          final raw = line.substring(6).trim();
          if (raw.isEmpty) continue;
          if (raw == '[DONE]') {
            if (pendingToolCalls.isNotEmpty) {
              final calls = finalizeToolCalls();
              if (calls.isNotEmpty) {
                yield ChatToolCallEvent(calls);
                return;
              }
            }
            yield ChatDoneEvent(fullText);
            return;
          }
          try {
            final decoded = jsonDecode(raw);
            if (decoded is! Map) continue;

            final choices = decoded['choices'];
            bool handledAsChoices = false;
            if (choices is List && choices.isNotEmpty) {
              final choice = choices[0];
              final delta = choice is Map ? choice['delta'] : null;

              if (delta is Map) {
                final rawToolCalls = delta['tool_calls'];
                if (rawToolCalls is List) {
                  for (final tc in rawToolCalls) {
                    if (tc is! Map) continue;
                    final index = (tc['index'] is num) ? (tc['index'] as num).toInt() : 0;
                    final fn = tc['function'];
                    final existing = pendingToolCalls[index];
                    final id = tc['id']?.toString() ?? existing?.id;
                    final name = (fn is Map ? fn['name']?.toString() : null) ?? existing?.name ?? '';
                    final argsFragment = (fn is Map ? fn['arguments']?.toString() : null) ?? '';
                    final buf = existing?.args ?? StringBuffer();
                    buf.write(argsFragment);
                    pendingToolCalls[index] = (id: id, name: name, args: buf);
                  }
                  handledAsChoices = true;
                }

                final deltaContent = delta['content']?.toString();
                final deltaThink = delta['reasoning_content']?.toString() ?? delta['reasoning']?.toString();
                if (deltaThink != null && deltaThink.isNotEmpty) {
                  yield ChatThinkEvent(deltaThink);
                  handledAsChoices = true;
                }
                if (deltaContent != null && deltaContent.isNotEmpty) {
                  fullText += deltaContent;
                  yield ChatTokenEvent(deltaContent);
                  handledAsChoices = true;
                }
              }

              final fr = choice is Map ? choice['finish_reason']?.toString() : null;
              if (fr != null && fr.isNotEmpty && fr != 'null') {
                if (fr == 'tool_calls' && pendingToolCalls.isNotEmpty) {
                  final calls = finalizeToolCalls();
                  if (calls.isNotEmpty) {
                    yield ChatToolCallEvent(calls);
                    return;
                  }
                }
                yield ChatDoneEvent(fullText);
                return;
              }
              if (handledAsChoices) continue;
            }

            final candidates = decoded['candidates'];
            if (candidates is List && candidates.isNotEmpty) {
              final first = candidates[0];
              final content = first is Map ? first['content'] : null;
              final parts = (content is Map ? content['parts'] : null);
              if (parts is List) {
                for (final part in parts) {
                  if (part is! Map) continue;
                  final text = part['text']?.toString() ?? '';
                  if (text.isEmpty) continue;
                  if (part['thought'] == true) {
                    yield ChatThinkEvent(text);
                  } else {
                    fullText += text;
                    yield ChatTokenEvent(text);
                  }
                }
              }
              final finishReason = first is Map ? first['finishReason']?.toString() : null;
              if (finishReason == 'STOP' || finishReason == 'MAX_TOKENS') {
                yield ChatDoneEvent(fullText);
                return;
              }
            }
          } catch (_) {}
        }
      }

      if (pendingToolCalls.isNotEmpty) {
        final calls = finalizeToolCalls();
        if (calls.isNotEmpty) {
          yield ChatToolCallEvent(calls);
          return;
        }
      }
      yield ChatDoneEvent(fullText);
    } catch (e) {
      yield ChatErrorEvent('Erro de rede: $e');
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> chatOnce({
    required String token,
    required List<ChatMessage> messages,
    required ApiProvider provider,
    String language = 'pt',
    String? systemPrompt,
    List<ToolDefinition>? tools,
  }) async {
    final cfg = kProviderMap[provider]!;
    final sendTools = tools != null && tools.isNotEmpty && ToolCallingSupport.supported;
    final res = await http.post(
      Uri.parse('$kApiBase/ai/chat'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'messages': messages.map((m) => m.toJson()).toList(),
        'stream': false,
        'language': language,
        'provider': cfg.provider,
        'model': cfg.deepseekModel,
        if (systemPrompt != null && systemPrompt.trim().isNotEmpty) 'systemPrompt': systemPrompt,
        if (sendTools) 'tools': tools.map((t) => t.toJson()).toList(),
      }),
    );
    final data = _decode(res.body);
    if (res.statusCode == 402) throw CreditsExhaustedException();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (sendTools && (res.statusCode == 400 || res.statusCode == 422)) {
        ToolCallingSupport.markUnsupported();
      }
      throw ApiException(data['error']?.toString() ?? 'Erro ${res.statusCode}', statusCode: res.statusCode);
    }
    return data;
  }

  static Future<String> generateTitle(String token, String message, {String language = 'pt'}) async {
    try {
      final res = await http.post(
        Uri.parse('$kApiBase/ai/title'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({'message': message, 'language': language}),
      );
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final data = _decode(res.body);
        final title = data['title']?.toString();
        if (title != null && title.isNotEmpty) return title;
      }
    } catch (_) {}
    final words = message.trim().split(RegExp(r'\s+'));
    final short = words.take(4).join(' ');
    return short.length > 40 ? short.substring(0, 40) : (short.isEmpty ? 'Nova conversa' : short);
  }

  static Future<String> summarize(String token, List<ChatMessage> messages, {String language = 'pt'}) async {
    final res = await http.post(
      Uri.parse('$kApiBase/ai/summarize'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'messages': messages.map((m) => m.toJson()).toList(),
        'language': language,
      }),
    );
    final data = _decode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(data['error']?.toString() ?? 'Erro ao resumir', statusCode: res.statusCode);
    }
    return data['summary']?.toString() ?? '';
  }
}

Map<String, dynamic> _decode(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) return decoded;
    return {};
  } catch (_) {
    return {};
  }
}

// ══════════════════════════════════════════════════════════════
// TOOLS API — execução no servidor de tools
// ══════════════════════════════════════════════════════════════
class ToolsApiService {
  static Future<Map<String, dynamic>> executeTool({
    required String token,
    required String name,
    required Map<String, dynamic> input,
  }) async {
    final res = await http.post(
      Uri.parse('$kApiBase/tools/execute'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'name': name, 'input': input}),
    );
    final data = _decode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(data['error']?.toString() ?? 'Erro ao executar tool', statusCode: res.statusCode);
    }
    if (data.containsKey('result')) {
      final result = data['result'];
      if (result is Map<String, dynamic>) return result;
      if (result is Map) return Map<String, dynamic>.from(result);
      return {};
    }
    return data;
  }
}

// ══════════════════════════════════════════════════════════════
// DEFINIÇÕES COMPLETAS DAS TOOLS — sincronizado com o catálogo
// real do server.js (TOOL_CATALOG do testador de tools em HTML).
// 57 tools no total, agrupadas nas mesmas categorias do testador.
//
// EXCLUÍDAS DE PROPÓSITO:
//   - generate_html_image: removida do catálogo do servidor.
//   - animate_html, generate_infographic: bloqueadas por defeito
//     no servidor (ENABLE_HEAVY_TOOLS=false) — fora por agora,
//     re-adicionar aqui quando a flag for ligada em produção.
// ══════════════════════════════════════════════════════════════
const List<ToolDefinition> kAllTools = [
  // ── Busca / dados (10) ──────────────────────────────────────
  ToolDefinition(
    name: 'web_search',
    description: 'Pesquisa informação atual na web. Devolve resultados com snippets, imagens e a data atual injetada automaticamente. Usa sempre que precisares de informação recente — nunca inventes resultados.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'description': 'Termo de busca'},
      },
      'required': ['query'],
    },
  ),
  ToolDefinition(
    name: 'read_website',
    description: 'Lê e extrai o conteúdo textual de uma página web a partir do seu URL. Usa quando o utilizador dá um link e pede para ler, resumir ou analisar o que lá está.',
    parameters: {
      'type': 'object',
      'properties': {
        'url': {'type': 'string', 'description': 'URL completo da página a ler'},
      },
      'required': ['url'],
    },
  ),
  ToolDefinition(
    name: 'search_images',
    description: 'Pesquisa imagens na web via Serper. Devolve URLs de imagens relevantes. Usa quando o utilizador pede imagens de algo.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'description': 'Termo de busca de imagens'},
        'max_results': {'type': 'number', 'description': 'Número máximo de imagens a devolver'},
      },
      'required': ['query'],
    },
  ),
  ToolDefinition(
    name: 'search_videos',
    description: 'Pesquisa vídeos na web via Serper. Devolve título, link e thumbnail de cada vídeo encontrado. Usa quando o utilizador pede vídeos, tutoriais em vídeo, etc.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'description': 'Termo de busca de vídeos'},
        'max_results': {'type': 'number', 'description': 'Número máximo de vídeos a devolver'},
      },
      'required': ['query'],
    },
  ),
  ToolDefinition(
    name: 'search_books',
    description: 'Pesquisa livros via Google Books API. Devolve título, autores, thumbnail e rating de cada livro encontrado. Usa quando o utilizador pergunta sobre livros ou pede recomendações de leitura.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'description': 'Título, autor ou tema do livro'},
        'max_results': {'type': 'number', 'description': 'Número máximo de livros a devolver'},
      },
      'required': ['query'],
    },
  ),
  ToolDefinition(
    name: 'download_image_for_project',
    description: 'Descarrega uma imagem real da web (por URL direto ou por pesquisa de termo) e devolve-a em base64 pronta para ser anexada a um projeto, documento ou ZIP. Usa quando o utilizador pedir para adicionar uma imagem real a um ficheiro/projeto que estás a criar. Devolve content_base64 — exibe diretamente no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'query_or_url': {'type': 'string', 'description': 'URL direto da imagem OU um termo de pesquisa (nesse caso pesquisa e usa o primeiro resultado)'},
        'target_filename': {'type': 'string', 'description': 'Nome sugerido para o ficheiro dentro do projeto, ex "logo.png"'},
      },
      'required': ['query_or_url'],
    },
  ),
  ToolDefinition(
    name: 'search_market',
    description: 'Pesquisa dados reais de um ativo financeiro: cripto (nome/símbolo, ex "bitcoin"), câmbio (código ISO, ex "EUR", "USD/JPY"), ou ação/índice (ticker, ex "AAPL"). Devolve preço e variação reais — nunca inventes valores.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'description': 'Nome, símbolo, código ou ticker'},
      },
      'required': ['query'],
    },
  ),
  ToolDefinition(
    name: 'search_place',
    description: 'Pesquisa a localização real (coordenadas e nome formal) de um lugar — cidade, morada, ponto de interesse. Nunca inventes coordenadas.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'description': 'Nome do lugar'},
      },
      'required': ['query'],
    },
  ),
  ToolDefinition(
    name: 'search_calendar_date',
    description: 'Resolve uma data em linguagem natural (ex "próxima sexta-feira") para ISO (YYYY-MM-DD).',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'description': 'Referência de data em linguagem natural'},
      },
      'required': ['query'],
    },
  ),
  ToolDefinition(
    name: 'get_weather',
    description: 'Obtém o clima atual de uma cidade e gera um card visual PNG base64. Usa sempre que o utilizador perguntar sobre o tempo ou clima — nunca inventes valores meteorológicos.',
    parameters: {
      'type': 'object',
      'properties': {
        'city': {'type': 'string', 'description': 'Nome da cidade'},
      },
      'required': ['city'],
    },
  ),

  // ── Email (1) ────────────────────────────────────────────────
  ToolDefinition(
    name: 'send_email',
    description: 'Envia um email real através do servidor. Suporta HTML rico no corpo e imagens embutidas inline via Content-ID (CID): cada imagem em "images" recebe um content_id, e esse mesmo valor deve ser referenciado no HTML do "content" como <img src="cid:AQUELE_ID">, para a imagem aparecer embutida no corpo do email em vez de anexada. Usa apenas quando o utilizador pedir explicitamente o envio de um email — nunca envies sem confirmação clara do destinatário.',
    parameters: {
      'type': 'object',
      'properties': {
        'to': {'type': 'string', 'description': 'Endereço de email do destinatário'},
        'subject': {'type': 'string', 'description': 'Assunto do email'},
        'content': {'type': 'string', 'description': 'Corpo do email em HTML. Para embutir uma imagem de "images", usa <img src="cid:CONTENT_ID_DA_IMAGEM">'},
        'from_name': {'type': 'string', 'description': 'Nome do remetente a mostrar (opcional)'},
        'images': {
          'type': 'array',
          'description': 'Imagens a embutir inline no corpo do email via CID. Cada uma deve ter um content_id único, referenciado no HTML de "content" como cid:content_id.',
          'items': {
            'type': 'object',
            'properties': {
              'content_base64': {'type': 'string', 'description': 'Imagem em base64'},
              'content_id': {'type': 'string', 'description': 'Identificador único usado no HTML como cid:content_id'},
              'filename': {'type': 'string', 'description': 'Nome do ficheiro da imagem'},
            },
            'required': ['content_base64', 'content_id'],
          },
        },
      },
      'required': ['to', 'subject', 'content'],
    },
  ),

  // ── Geração de imagem (9) ───────────────────────────────────
  ToolDefinition(
    name: 'generate_chart',
    description: 'Gera um gráfico visual como PNG base64. Suporta line, bar, pie, doughnut, radar, polarArea, scatter, bubble. Aceita múltiplos datasets. Devolve content_base64 com PNG — exibe diretamente no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'chart_type': {'type': 'string', 'enum': ['line', 'bar', 'pie', 'doughnut', 'radar', 'polarArea', 'scatter', 'bubble']},
        'title': {'type': 'string'},
        'labels': {'type': 'array', 'items': {'type': 'string'}},
        'datasets': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'label': {'type': 'string'},
              'data': {'type': 'array', 'items': {'type': 'number'}},
              'color': {'type': 'string'},
            },
          },
        },
      },
      'required': ['chart_type', 'labels', 'datasets'],
    },
  ),
  ToolDefinition(
    name: 'generate_function_plot',
    description: 'Gera o gráfico REAL de uma função matemática (parábolas, senos, cúbicas, raiz, exponenciais) avaliando a expressão ponto a ponto num intervalo e desenhando com eixos, grelha e marcação de zero. Usa esta tool em vez de generate_math_sheet sempre que o pedido for "gráfico de uma função", "parábola", "esboça y = ...", etc. Devolve content_base64 — exibe diretamente no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'expression': {'type': 'string', 'description': 'Expressão em função de x, ex: "x^2 - 4*x + 3", "sin(x)", "sqrt(x)"'},
        'x_min': {'type': 'number', 'description': 'Default -10'},
        'x_max': {'type': 'number', 'description': 'Default 10'},
        'title': {'type': 'string'},
        'highlight_roots': {'type': 'boolean', 'description': 'Se true, marca visualmente onde a função cruza y=0 (raízes aproximadas)'},
      },
      'required': ['expression'],
    },
  ),
  ToolDefinition(
    name: 'generate_math_sheet',
    description: 'Avalia uma expressão matemática e gera imagem PNG com resultado, incluindo o gráfico se "show_graph" for true. Devolve content_base64 — exibe diretamente no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'expression': {'type': 'string', 'description': 'Expressão matemática ex: "2^10", "sqrt(144)", "x^2 + 2*x + 1"'},
        'show_graph': {'type': 'boolean', 'description': 'Se true e a expressão for função de x, inclui o gráfico'},
      },
      'required': ['expression'],
    },
  ),
  ToolDefinition(
    name: 'generate_mindmap',
    description: 'Gera um mapa mental hierárquico de alta qualidade como PNG base64: layout automático sem sobreposição, fundo branco, cores por nível, ligações curvas suaves, texto sempre bem enquadrado dentro do nó (nunca cortado). Usa estrutura de nó raiz com filhos aninhados até 4 níveis. Devolve content_base64 — exibe diretamente no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'root': {
          'type': 'object',
          'properties': {
            'label': {'type': 'string'},
            'children': {'type': 'array', 'items': {'type': 'object'}},
          },
        },
      },
      'required': ['root'],
    },
  ),
  ToolDefinition(
    name: 'generate_qrcode',
    description: 'Gera um QR code como PNG base64 a partir de qualquer texto ou URL. Devolve content_base64 — exibe diretamente no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'content': {'type': 'string', 'description': 'Texto ou URL para o QR code'},
        'size': {'type': 'number', 'description': 'Tamanho em pixels (default 300)'},
      },
      'required': ['content'],
    },
  ),
  ToolDefinition(
    name: 'generate_barcode',
    description: 'Gera um código de barras como PNG base64. Devolve content_base64 — exibe diretamente no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'content': {'type': 'string', 'description': 'Conteúdo do código de barras'},
        'format': {'type': 'string', 'enum': ['code128', 'ean13', 'ean8', 'upca', 'qrcode']},
      },
      'required': ['content'],
    },
  ),
  ToolDefinition(
    name: 'generate_table_image',
    description: 'Gera uma tabela complexa como PNG base64. Usa quando markdown não é suficiente. Devolve content_base64 — exibe diretamente no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'headers': {'type': 'array', 'items': {'type': 'string'}},
        'rows': {'type': 'array', 'items': {'type': 'array', 'items': {'type': 'string'}}},
        'theme': {'type': 'string', 'enum': ['dark', 'light', 'purple']},
      },
      'required': ['headers', 'rows'],
    },
  ),
  ToolDefinition(
    name: 'generate_color_scheme',
    description: 'Gera uma paleta de cores harmoniosa a partir de uma cor base hexadecimal. Devolve as cores derivadas em campos de dados — usa quando o utilizador pedir sugestões de esquema de cores para design.',
    parameters: {
      'type': 'object',
      'properties': {
        'base_color_hex': {'type': 'string', 'description': 'Cor base em hexadecimal, ex "#6F5AF6"'},
      },
      'required': ['base_color_hex'],
    },
  ),
  ToolDefinition(
    name: 'generate_random_avatar',
    description: 'Gera um avatar aleatório determinístico a partir de um seed (ex: email ou username) como PNG base64. Mesma seed produz sempre o mesmo avatar. Devolve content_base64 — exibe diretamente no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'seed': {'type': 'string', 'description': 'String usada como semente do avatar, ex email ou username'},
        'size': {'type': 'number', 'description': 'Tamanho em pixels (default 200)'},
      },
      'required': ['seed'],
    },
  ),

  // ── Documentos (6) ───────────────────────────────────────────
  ToolDefinition(
    name: 'create_pdf',
    description: 'Gera um PDF a partir de HTML rico. Pode incluir imagens reais (via image_urls) e/ou um gráfico gerado (via embed_chart) diretamente dentro do PDF. Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'html_content': {'type': 'string'},
        'image_urls': {'type': 'array', 'items': {'type': 'string'}, 'description': 'URLs de imagens da web para descarregar e incluir no PDF, na ordem dada'},
        'embed_chart': {
          'type': 'object',
          'description': 'Opcional: gera um gráfico e insere-o no PDF. Mesma estrutura de generate_chart.',
          'properties': {
            'chart_type': {'type': 'string'},
            'labels': {'type': 'array', 'items': {'type': 'string'}},
            'datasets': {'type': 'array', 'items': {'type': 'object'}},
          },
        },
      },
      'required': ['title', 'html_content'],
    },
  ),
  ToolDefinition(
    name: 'create_pdf_structured',
    description: 'Gera um PDF a partir de uma estrutura de secções (título, subtítulo, parágrafos e listas com marcadores por secção), sem precisar escrever HTML. Usa quando o conteúdo é claramente organizado em secções de relatório. Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'subtitle': {'type': 'string'},
        'sections': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'heading': {'type': 'string'},
              'paragraphs': {'type': 'array', 'items': {'type': 'string'}},
              'bullet_list': {'type': 'array', 'items': {'type': 'string'}},
            },
          },
        },
      },
      'required': ['title', 'sections'],
    },
  ),
  ToolDefinition(
    name: 'create_docx',
    description: 'Gera um Word (.docx) a partir de HTML. Pode incluir imagens reais (via image_urls) e/ou um gráfico gerado (via embed_chart) diretamente dentro do documento. Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'html_content': {'type': 'string'},
        'image_urls': {'type': 'array', 'items': {'type': 'string'}},
        'embed_chart': {
          'type': 'object',
          'properties': {
            'chart_type': {'type': 'string'},
            'labels': {'type': 'array', 'items': {'type': 'string'}},
            'datasets': {'type': 'array', 'items': {'type': 'object'}},
          },
        },
      },
      'required': ['title', 'html_content'],
    },
  ),
  ToolDefinition(
    name: 'create_xlsx',
    description: 'Gera planilha Excel (.xlsx). Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'sheet_name': {'type': 'string'},
        'headers': {'type': 'array', 'items': {'type': 'string'}},
        'rows': {'type': 'array', 'items': {'type': 'array', 'items': {'type': 'string'}}},
      },
      'required': ['headers', 'rows'],
    },
  ),
  ToolDefinition(
    name: 'create_pptx',
    description: 'Gera PowerPoint (.pptx). Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'slides': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'heading': {'type': 'string'},
              'bullets': {'type': 'array', 'items': {'type': 'string'}},
            },
          },
        },
      },
      'required': ['title', 'slides'],
    },
  ),
  ToolDefinition(
    name: 'create_project_zip',
    description: 'Cria um projeto completo como ficheiro ZIP, com estrutura de pastas e múltiplos ficheiros de código/texto de uma vez. Usa quando o utilizador pedir para gerar/criar um projeto inteiro (app, script, template) para download. Pode incluir imagens reais da web via image_urls_to_include. Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'project_name': {'type': 'string'},
        'files': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'path': {'type': 'string', 'description': 'Caminho relativo dentro do zip, ex "lib/main.dart" ou "README.md"'},
              'content': {'type': 'string'},
            },
            'required': ['path', 'content'],
          },
        },
        'image_urls_to_include': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'url': {'type': 'string'},
              'path': {'type': 'string', 'description': 'Caminho relativo dentro do zip para a imagem, ex "assets/logo.png"'},
            },
          },
        },
      },
      'required': ['project_name', 'files'],
    },
  ),

  // ── Leitura de ficheiros (3) ─────────────────────────────────
  ToolDefinition(
    name: 'read_zip_contents',
    description: 'Lê o conteúdo de um ficheiro .zip enviado pelo utilizador (código-fonte de um projeto, etc). Descompacta e devolve a árvore de ficheiros com o texto de cada ficheiro de código/texto, e as imagens em base64. Limite: 15MB, 100 ficheiros, 15000 caracteres por ficheiro de texto, até 10 imagens decodificadas.',
    parameters: {
      'type': 'object',
      'properties': {
        'zip_base64': {'type': 'string', 'description': 'Conteúdo do .zip em base64'},
      },
      'required': ['zip_base64'],
    },
  ),
  ToolDefinition(
    name: 'read_pdf_contents',
    description: 'Extrai o texto de um PDF enviado pelo utilizador. Devolve o texto por página até um limite de 40 páginas (páginas seguintes são ignoradas e sinalizadas).',
    parameters: {
      'type': 'object',
      'properties': {
        'pdf_base64': {'type': 'string', 'description': 'Conteúdo do PDF em base64'},
      },
      'required': ['pdf_base64'],
    },
  ),
  ToolDefinition(
    name: 'extract_document_outline',
    description: 'Extrai a estrutura/índice (títulos, secções, hierarquia) de um documento PDF. Usa quando o utilizador pedir o esboço, índice ou estrutura de um documento sem precisar do texto completo.',
    parameters: {
      'type': 'object',
      'properties': {
        'pdf_base64': {'type': 'string', 'description': 'Conteúdo do PDF em base64'},
        'source_type': {'type': 'string', 'description': 'Tipo de origem do documento, ex "pdf"'},
      },
      'required': ['pdf_base64'],
    },
  ),

  // ── Conversão (8) ─────────────────────────────────────────────
  ToolDefinition(
    name: 'csv_to_xlsx',
    description: 'Converte CSV em Excel (.xlsx). Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'csv_content': {'type': 'string'},
      },
      'required': ['csv_content'],
    },
  ),
  ToolDefinition(
    name: 'json_transform',
    description: 'Transforma array JSON de objetos em tabela (headers + rows).',
    parameters: {
      'type': 'object',
      'properties': {
        'json_data': {'type': 'string'},
      },
      'required': ['json_data'],
    },
  ),
  ToolDefinition(
    name: 'xlsx_to_json',
    description: 'Converte uma planilha Excel (.xlsx) enviada pelo utilizador em dados JSON estruturados. Usa quando o utilizador pedir para extrair os dados de um Excel para JSON.',
    parameters: {
      'type': 'object',
      'properties': {
        'xlsx_base64': {'type': 'string', 'description': 'Conteúdo do .xlsx em base64'},
      },
      'required': ['xlsx_base64'],
    },
  ),
  ToolDefinition(
    name: 'html_to_docx',
    description: 'Converte HTML em Word (.docx). Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'html_content': {'type': 'string'},
        'filename': {'type': 'string'},
      },
      'required': ['html_content'],
    },
  ),
  ToolDefinition(
    name: 'html_to_pdf',
    description: 'Converte HTML em PDF. Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'html_content': {'type': 'string'},
        'title': {'type': 'string'},
      },
      'required': ['html_content'],
    },
  ),
  ToolDefinition(
    name: 'html_to_xlsx',
    description: 'Converte HTML em Excel (.xlsx). Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'html_content': {'type': 'string'},
        'sheet_name': {'type': 'string'},
      },
      'required': ['html_content'],
    },
  ),
  ToolDefinition(
    name: 'html_to_pptx',
    description: 'Converte HTML em PowerPoint (.pptx). Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'html_content': {'type': 'string'},
        'title': {'type': 'string'},
      },
      'required': ['html_content'],
    },
  ),
  ToolDefinition(
    name: 'docx_to_html',
    description: 'Converte um Word (.docx) enviado pelo utilizador em HTML. Usa quando o utilizador pedir para extrair ou reaproveitar o conteúdo de um .docx como HTML.',
    parameters: {
      'type': 'object',
      'properties': {
        'docx_base64': {'type': 'string', 'description': 'Conteúdo do .docx em base64'},
      },
      'required': ['docx_base64'],
    },
  ),

  // ── Imagem — utilitários (11) ────────────────────────────────
  ToolDefinition(
    name: 'get_image_colors',
    description: 'Extrai a paleta de cores dominantes de uma imagem. Usa quando o utilizador pedir para saber ou usar as cores de uma imagem.',
    parameters: {
      'type': 'object',
      'properties': {
        'image_base64': {'type': 'string', 'description': 'Imagem em base64'},
        'num_colors': {'type': 'number', 'description': 'Número de cores dominantes a extrair'},
      },
      'required': ['image_base64'],
    },
  ),
  ToolDefinition(
    name: 'convert_image_format',
    description: 'Converte uma imagem para outro formato (ex: webp, png, jpeg). Devolve content_base64 — exibe diretamente no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'image_base64': {'type': 'string', 'description': 'Imagem em base64'},
        'target_format': {'type': 'string', 'description': 'Formato de destino, ex "webp", "png", "jpeg"'},
      },
      'required': ['image_base64', 'target_format'],
    },
  ),
  ToolDefinition(
    name: 'resize_image',
    description: 'Redimensiona uma imagem para uma largura (e opcionalmente altura) especificada, mantendo proporção se só a largura for dada. Devolve content_base64 — exibe diretamente no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'image_base64': {'type': 'string', 'description': 'Imagem em base64'},
        'width': {'type': 'number', 'description': 'Largura de destino em pixels'},
        'height': {'type': 'number', 'description': 'Altura de destino em pixels (opcional)'},
      },
      'required': ['image_base64', 'width'],
    },
  ),
  ToolDefinition(
    name: 'crop_image',
    description: 'Recorta uma região retangular de uma imagem, definida por posição (left/top) e tamanho (width/height). Os valores têm de caber dentro das dimensões da imagem original. Devolve content_base64 — exibe diretamente no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'image_base64': {'type': 'string', 'description': 'Imagem em base64'},
        'left': {'type': 'number', 'description': 'Posição X do canto superior esquerdo do recorte'},
        'top': {'type': 'number', 'description': 'Posição Y do canto superior esquerdo do recorte'},
        'width': {'type': 'number', 'description': 'Largura do recorte'},
        'height': {'type': 'number', 'description': 'Altura do recorte'},
      },
      'required': ['image_base64', 'left', 'top', 'width', 'height'],
    },
  ),
  ToolDefinition(
    name: 'watermark_image',
    description: 'Adiciona uma marca de água de texto sobre uma imagem, numa posição escolhida. Devolve content_base64 — exibe diretamente no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'image_base64': {'type': 'string', 'description': 'Imagem em base64'},
        'watermark_text': {'type': 'string', 'description': 'Texto a colocar como marca de água'},
        'position': {'type': 'string', 'enum': ['top-left', 'top-right', 'bottom-left', 'bottom-right', 'center']},
      },
      'required': ['image_base64', 'watermark_text'],
    },
  ),
  ToolDefinition(
    name: 'image_metadata',
    description: 'Devolve os metadados de uma imagem: dimensões, formato, tamanho em bytes, e outras propriedades técnicas.',
    parameters: {
      'type': 'object',
      'properties': {
        'image_base64': {'type': 'string', 'description': 'Imagem em base64'},
      },
      'required': ['image_base64'],
    },
  ),
  ToolDefinition(
    name: 'vectorize_image',
    description: 'Converte uma imagem raster (PNG/JPEG) em SVG vetorizado. Usa quando o utilizador pedir para vetorizar um logo ou desenho simples. Devolve svg (string).',
    parameters: {
      'type': 'object',
      'properties': {
        'image_base64': {'type': 'string', 'description': 'Imagem em base64'},
        'mode': {'type': 'string', 'description': 'Modo de vetorização, ex "black_transparent"'},
      },
      'required': ['image_base64'],
    },
  ),
  ToolDefinition(
    name: 'ocr_extract_text',
    description: 'Extrai texto de uma imagem via OCR. Usa quando o utilizador enviar uma foto ou print com texto e pedir para extrair/transcrever esse texto.',
    parameters: {
      'type': 'object',
      'properties': {
        'image_base64': {'type': 'string', 'description': 'Imagem em base64'},
        'language': {'type': 'string', 'description': 'Código de idioma para o OCR, ex "por" para português'},
      },
      'required': ['image_base64'],
    },
  ),
  ToolDefinition(
    name: 'pdf_to_images',
    description: 'Converte páginas de um PDF em imagens PNG, uma por página, até um máximo de páginas definido. Usa quando o utilizador quiser visualizar páginas de um PDF como imagens.',
    parameters: {
      'type': 'object',
      'properties': {
        'pdf_base64': {'type': 'string', 'description': 'Conteúdo do PDF em base64'},
        'max_pages': {'type': 'number', 'description': 'Número máximo de páginas a converter'},
      },
      'required': ['pdf_base64'],
    },
  ),
  ToolDefinition(
    name: 'pptx_to_images',
    description: 'Converte os slides de um PowerPoint (.pptx) em imagens, um por slide. Usa quando o utilizador quiser visualizar os slides de uma apresentação como imagens.',
    parameters: {
      'type': 'object',
      'properties': {
        'pptx_base64': {'type': 'string', 'description': 'Conteúdo do .pptx em base64'},
      },
      'required': ['pptx_base64'],
    },
  ),
  ToolDefinition(
    name: 'audio_duration_check',
    description: 'Devolve a duração e metadados técnicos de um ficheiro de áudio (mp3, wav, m4a). Usa quando o utilizador pedir informação sobre um áudio enviado.',
    parameters: {
      'type': 'object',
      'properties': {
        'audio_base64': {'type': 'string', 'description': 'Conteúdo do ficheiro de áudio em base64'},
      },
      'required': ['audio_base64'],
    },
  ),

  // ── Texto / dados (9) ─────────────────────────────────────────
  ToolDefinition(
    name: 'str_replace_file',
    description: 'Substitui uma ocorrência de texto (old_str) por outro (new_str) dentro de um conteúdo de texto fornecido. Usa para edições pontuais de texto sem reescrever tudo.',
    parameters: {
      'type': 'object',
      'properties': {
        'content': {'type': 'string', 'description': 'Texto original completo'},
        'old_str': {'type': 'string', 'description': 'Trecho de texto a substituir'},
        'new_str': {'type': 'string', 'description': 'Novo trecho de texto'},
      },
      'required': ['content', 'old_str', 'new_str'],
    },
  ),
  ToolDefinition(
    name: 'diff_text',
    description: 'Compara dois textos e devolve as diferenças entre eles (linhas adicionadas, removidas, alteradas). Usa quando o utilizador quiser ver o que mudou entre duas versões de um texto.',
    parameters: {
      'type': 'object',
      'properties': {
        'text_before': {'type': 'string', 'description': 'Versão original do texto'},
        'text_after': {'type': 'string', 'description': 'Versão modificada do texto'},
      },
      'required': ['text_before', 'text_after'],
    },
  ),
  ToolDefinition(
    name: 'extract_urls_from_text',
    description: 'Extrai todos os URLs presentes num bloco de texto. Usa quando o utilizador quiser recolher todos os links de um texto.',
    parameters: {
      'type': 'object',
      'properties': {
        'text': {'type': 'string', 'description': 'Texto de onde extrair os URLs'},
      },
      'required': ['text'],
    },
  ),
  ToolDefinition(
    name: 'format_markdown_to_html',
    description: 'Converte texto em Markdown para HTML formatado. Usa quando precisares de transformar markdown (títulos, negrito, listas) em HTML para outra tool ou documento.',
    parameters: {
      'type': 'object',
      'properties': {
        'markdown': {'type': 'string', 'description': 'Conteúdo em Markdown'},
      },
      'required': ['markdown'],
    },
  ),
  ToolDefinition(
    name: 'count_tokens_estimate',
    description: 'Estima o número de tokens de um texto. Usa quando o utilizador perguntar quantos tokens um texto tem ou ocuparia.',
    parameters: {
      'type': 'object',
      'properties': {
        'text': {'type': 'string', 'description': 'Texto a estimar'},
      },
      'required': ['text'],
    },
  ),
  ToolDefinition(
    name: 'text_summary_stats',
    description: 'Devolve estatísticas de um texto: número de palavras, frases, parágrafos, caracteres, tempo estimado de leitura. Usa quando o utilizador pedir estatísticas ou análise quantitativa de um texto.',
    parameters: {
      'type': 'object',
      'properties': {
        'text': {'type': 'string', 'description': 'Texto a analisar'},
      },
      'required': ['text'],
    },
  ),
  ToolDefinition(
    name: 'youtube_thumbnail_extract',
    description: 'Extrai a thumbnail (miniatura) de um vídeo do YouTube a partir do seu URL. Usa quando o utilizador der um link do YouTube e pedir a imagem de capa.',
    parameters: {
      'type': 'object',
      'properties': {
        'youtube_url': {'type': 'string', 'description': 'URL do vídeo no YouTube'},
      },
      'required': ['youtube_url'],
    },
  ),
  ToolDefinition(
    name: 'merge_pdfs',
    description: 'Junta vários ficheiros PDF num único PDF, pela ordem dada. Precisa de pelo menos 2 PDFs em base64. Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'pdfs_base64': {'type': 'array', 'items': {'type': 'string'}, 'description': 'Lista de PDFs em base64, na ordem em que devem ser juntados'},
      },
      'required': ['pdfs_base64'],
    },
  ),
  ToolDefinition(
    name: 'split_pdf_pages',
    description: 'Extrai páginas específicas de um PDF para um novo PDF, dado o número dessas páginas. Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'pdf_base64': {'type': 'string', 'description': 'Conteúdo do PDF original em base64'},
        'page_numbers': {'type': 'array', 'items': {'type': 'number'}, 'description': 'Números das páginas a extrair (1-indexado)'},
      },
      'required': ['pdf_base64', 'page_numbers'],
    },
  ),
];