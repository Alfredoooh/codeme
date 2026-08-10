// ══════════════════════════════════════════════════════════════
// FILE: lib/api_service.dart
// ══════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String kApiBase = 'https://ipc.alfredopjonas.workers.dev';

// ── Modelo local (mantemos os 3 "DeepSeek" pedidos como labels de UI,
//    mapeados para os providers reais que o worker expõe: gemini e groq).
//    O worker não tem DeepSeek — não inventamos endpoint que não existe.
enum ApiProvider { gemini, groqFast, groqVersatile }

class ProviderConfig {
  final String provider; // "gemini" | "groq"
  final String? groqModel;
  const ProviderConfig(this.provider, this.groqModel);
}

const Map<ApiProvider, ProviderConfig> kProviderMap = {
  ApiProvider.gemini:         ProviderConfig('gemini', null),
  ApiProvider.groqFast:       ProviderConfig('groq', 'llama-3.1-8b-instant'),
  ApiProvider.groqVersatile:  ProviderConfig('groq', 'llama-3.3-70b-versatile'),
};

class ChatMessage {
  final String role; // "user" | "assistant"
  final String content;
  const ChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        role: j['role']?.toString() ?? 'user',
        content: j['content']?.toString() ?? '',
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

// ── Eventos de stream emitidos por streamChat ──────────────────
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
// CANVAS — documentos/folhas/slides que a IA cria durante o chat.
// A IA sinaliza a criação com um bloco especial no texto da resposta:
//   [[canvas:doc:Título||conteúdo em html ou texto]]
//   [[canvas:sheet:Título||json da folha]]
//   [[canvas:slide:Título||json das slides]]
// O parser abaixo extrai esses blocos, monta CanvasItem, e devolve o
// texto "limpo" (sem o bloco cru) para mostrar na bolha de chat.
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
  final String content; // html (doc) / json (sheet, slide, whiteboard)
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

  /// Deteta se um bloco de canvas está a meio de streaming (aberto mas
  /// ainda não fechado) para mostrar o indicador "A criar documento...".
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
// PROJECTS — espelha exatamente o modelo do worker (proj:<userId>:<id>
// + projidx:<userId>). Um ProjectNode pode ser project (raiz),
// folder (subpasta) ou file (documento dentro de uma pasta/projeto).
// A árvore inteira do utilizador vem "achatada" numa única chamada e
// é reconstruída localmente via parentId — exatamente como o backend
// já a guarda.
// ══════════════════════════════════════════════════════════════

enum ProjectNodeType { project, folder, file }

extension ProjectNodeTypeX on ProjectNodeType {
  String get wire => const {
        ProjectNodeType.project: 'project',
        ProjectNodeType.folder:  'folder',
        ProjectNodeType.file:    'file',
      }[this]!;

  static ProjectNodeType fromWire(String tag) {
    switch (tag) {
      case 'folder': return ProjectNodeType.folder;
      case 'file':   return ProjectNodeType.file;
      default:       return ProjectNodeType.project;
    }
  }
}

enum ProjectFileKind {
  chat, pdf, docx, xlsx, pptx, doc, sheet, slide, whiteboard, code, other,
}

extension ProjectFileKindX on ProjectFileKind {
  String get wire => const {
        ProjectFileKind.chat:       'chat',
        ProjectFileKind.pdf:        'pdf',
        ProjectFileKind.docx:       'docx',
        ProjectFileKind.xlsx:       'xlsx',
        ProjectFileKind.pptx:       'pptx',
        ProjectFileKind.doc:        'doc',
        ProjectFileKind.sheet:      'sheet',
        ProjectFileKind.slide:      'slide',
        ProjectFileKind.whiteboard: 'whiteboard',
        ProjectFileKind.code:       'code',
        ProjectFileKind.other:      'other',
      }[this]!;

  static ProjectFileKind fromWire(String? tag) {
    switch (tag) {
      case 'chat':       return ProjectFileKind.chat;
      case 'pdf':        return ProjectFileKind.pdf;
      case 'docx':       return ProjectFileKind.docx;
      case 'xlsx':       return ProjectFileKind.xlsx;
      case 'pptx':       return ProjectFileKind.pptx;
      case 'doc':        return ProjectFileKind.doc;
      case 'sheet':      return ProjectFileKind.sheet;
      case 'slide':      return ProjectFileKind.slide;
      case 'whiteboard': return ProjectFileKind.whiteboard;
      case 'code':       return ProjectFileKind.code;
      default:           return ProjectFileKind.other;
    }
  }

  /// Ícone SVG associado (vive em assets/icons/svg/).
  String get svgAsset => const {
        ProjectFileKind.chat:       'ai_tab.svg',
        ProjectFileKind.pdf:        'doc.svg',
        ProjectFileKind.docx:       'doc.svg',
        ProjectFileKind.xlsx:       'sheet.svg',
        ProjectFileKind.pptx:       'slide.svg',
        ProjectFileKind.doc:        'doc.svg',
        ProjectFileKind.sheet:      'sheet.svg',
        ProjectFileKind.slide:      'slide.svg',
        ProjectFileKind.whiteboard: 'whiteboard.svg',
        ProjectFileKind.code:       'doc.svg',
        ProjectFileKind.other:      'doc.svg',
      }[this]!;

  String get label => const {
        ProjectFileKind.chat:       'Conversa',
        ProjectFileKind.pdf:        'PDF',
        ProjectFileKind.docx:       'Word',
        ProjectFileKind.xlsx:       'Excel',
        ProjectFileKind.pptx:       'PowerPoint',
        ProjectFileKind.doc:        'Documento',
        ProjectFileKind.sheet:      'Folha de cálculo',
        ProjectFileKind.slide:      'Apresentação',
        ProjectFileKind.whiteboard: 'Quadro branco',
        ProjectFileKind.code:       'Código',
        ProjectFileKind.other:      'Ficheiro',
      }[this]!;
}

class ProjectNode {
  final String id;
  final String? parentId;
  final ProjectNodeType type;
  final String name;
  final ProjectFileKind? fileKind; // só relevante quando type == file
  final String? conversationId;   // quando fileKind == chat
  final String? content;          // ficheiros pequenos gerados pela IA (html/json)
  final String? fileData;         // base64, uploads reais (pdf/docx/etc)
  final String? mimeType;
  final int createdAt;
  final int updatedAt;

  const ProjectNode({
    required this.id,
    required this.parentId,
    required this.type,
    required this.name,
    this.fileKind,
    this.conversationId,
    this.content,
    this.fileData,
    this.mimeType,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isContainer => type == ProjectNodeType.project || type == ProjectNodeType.folder;

  ProjectNode copyWith({
    String? name,
    String? parentId,
    String? content,
    String? fileData,
    String? conversationId,
  }) => ProjectNode(
        id: id,
        parentId: parentId ?? this.parentId,
        type: type,
        name: name ?? this.name,
        fileKind: fileKind,
        conversationId: conversationId ?? this.conversationId,
        content: content ?? this.content,
        fileData: fileData ?? this.fileData,
        mimeType: mimeType,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory ProjectNode.fromJson(Map<String, dynamic> j) => ProjectNode(
        id: j['id']?.toString() ?? '',
        parentId: j['parentId']?.toString(),
        type: ProjectNodeTypeX.fromWire(j['type']?.toString() ?? 'project'),
        name: j['name']?.toString() ?? 'Sem nome',
        fileKind: j['fileKind'] != null ? ProjectFileKindX.fromWire(j['fileKind']?.toString()) : null,
        conversationId: j['conversationId']?.toString(),
        content: j['content']?.toString(),
        fileData: j['fileData']?.toString(),
        mimeType: j['mimeType']?.toString(),
        createdAt: (j['createdAt'] is num) ? (j['createdAt'] as num).toInt() : 0,
        updatedAt: (j['updatedAt'] is num) ? (j['updatedAt'] as num).toInt() : 0,
      );
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
    Map<String, dynamic>? preferences,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (password != null) body['password'] = password;
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
    List<CanvasItem> canvases = const [],
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$kApiBase/conversations'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'title': title,
          'messages': messages.map((m) => m.toJson()).toList(),
          if (model != null) 'model': model,
          'canvases': canvases.map((c) => c.toJson()).toList(),
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
    List<CanvasItem>? canvases,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (messages != null) body['messages'] = messages.map((m) => m.toJson()).toList();
      if (canvases != null) body['canvases'] = canvases.map((c) => c.toJson()).toList();
      await http.put(
        Uri.parse('$kApiBase/conversations/$id'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(body),
      );
    } catch (_) {}
  }

  /// Renomeia o título de uma conversa a partir do app — usado tanto
  /// pela geração automática (primeira mensagem) como pela edição
  /// manual do utilizador. Devolve true em caso de sucesso.
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
// PROJECTS API — CRUD de nós (project/folder/file), sempre isolado
// por utilizador no backend via token. list() devolve a árvore
// achatada inteira; o cliente reconstrói localmente via parentId.
// ══════════════════════════════════════════════════════════════

class ProjectsApiService {
  static Future<List<ProjectNode>> list(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$kApiBase/projects'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return [];
      final data = _decode(res.body);
      final nodes = data['nodes'];
      if (nodes is! List) return [];
      return nodes.whereType<Map<String, dynamic>>().map(ProjectNode.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<ProjectNode?> create(
    String token, {
    required ProjectNodeType type,
    required String name,
    String? parentId,
    ProjectFileKind? fileKind,
    String? conversationId,
    String? content,
    String? fileData,
    String? mimeType,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$kApiBase/projects'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'type': type.wire,
          'name': name,
          if (parentId != null) 'parentId': parentId,
          if (fileKind != null) 'fileKind': fileKind.wire,
          if (conversationId != null) 'conversationId': conversationId,
          if (content != null) 'content': content,
          if (fileData != null) 'fileData': fileData,
          if (mimeType != null) 'mimeType': mimeType,
        }),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      return ProjectNode.fromJson(_decode(res.body));
    } catch (_) {
      return null;
    }
  }

  static Future<ProjectNode?> update(
    String token,
    String id, {
    String? name,
    String? parentId,
    String? content,
    String? fileData,
    String? conversationId,
  }) async {
    try {
      final body = <String, dynamic>{};
      if (name != null) body['name'] = name;
      if (parentId != null) body['parentId'] = parentId;
      if (content != null) body['content'] = content;
      if (fileData != null) body['fileData'] = fileData;
      if (conversationId != null) body['conversationId'] = conversationId;
      final res = await http.put(
        Uri.parse('$kApiBase/projects/$id'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(body),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      return ProjectNode.fromJson(_decode(res.body));
    } catch (_) {
      return null;
    }
  }

  static Future<bool> delete(String token, String id) async {
    try {
      final res = await http.delete(
        Uri.parse('$kApiBase/projects/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}

// ══════════════════════════════════════════════════════════════
// AI CHAT API — streaming SSE real, mesmo protocolo do worker
// ══════════════════════════════════════════════════════════════

class AiApiService {
  /// Faz stream do chat via SSE.
  /// O worker devolve `data: {...}\n\n` linhas com o payload cru da
  /// Gemini API (quando provider=gemini) ou terminado a `[DONE]`.
  static Stream<ChatStreamEvent> streamChat({
    required String token,
    required List<ChatMessage> messages,
    required ApiProvider provider,
    String language = 'pt',
    bool think = false,
    String? systemPrompt,
  }) async* {
    final cfg = kProviderMap[provider]!;
    final client = http.Client();
    try {
      final req = http.Request('POST', Uri.parse('$kApiBase/ai/chat'));
      req.headers['Content-Type'] = 'application/json';
      req.headers['Authorization'] = 'Bearer $token';
      req.body = jsonEncode({
        'messages': messages.map((m) => m.toJson()).toList(),
        'stream': true,
        'language': language,
        'think': think,
        'provider': cfg.provider,
        if (cfg.groqModel != null) 'model': cfg.groqModel,
        if (systemPrompt != null && systemPrompt.trim().isNotEmpty) 'systemPrompt': systemPrompt,
      });

      final streamed = await client.send(req);

      if (streamed.statusCode == 402) {
        yield ChatCreditsExhaustedEvent();
        return;
      }
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        final bodyStr = await streamed.stream.bytesToString();
        String msg = 'Erro ${streamed.statusCode}';
        try {
          final decoded = jsonDecode(bodyStr);
          if (decoded is Map && decoded['error'] != null) msg = decoded['error'].toString();
        } catch (_) {}
        yield ChatErrorEvent(msg);
        return;
      }

      final buffer = StringBuffer();
      String pending = '';
      String fullText = '';

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
            yield ChatDoneEvent(fullText);
            return;
          }
          try {
            final decoded = jsonDecode(raw);
            if (decoded is! Map) continue;
            final candidates = decoded['candidates'];
            if (candidates is! List || candidates.isEmpty) continue;
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
                  buffer.write(text);
                  yield ChatTokenEvent(text);
                }
              }
            }
            final finishReason = first is Map ? first['finishReason']?.toString() : null;
            if (finishReason == 'STOP' || finishReason == 'MAX_TOKENS') {
              yield ChatDoneEvent(fullText);
              return;
            }

            // Formato Groq/OpenAI-like (choices[].delta.content), caso o
            // worker alguma vez normalize a stream Groq neste formato.
            final choices = decoded['choices'];
            if (choices is List && choices.isNotEmpty) {
              final choice = choices[0];
              final delta = choice is Map ? choice['delta'] : null;
              final deltaContent = delta is Map ? delta['content']?.toString() : null;
              if (deltaContent != null && deltaContent.isNotEmpty) {
                fullText += deltaContent;
                yield ChatTokenEvent(deltaContent);
              }
              final fr = choice is Map ? choice['finish_reason']?.toString() : null;
              if (fr != null && fr.isNotEmpty && fr != 'null') {
                yield ChatDoneEvent(fullText);
                return;
              }
            }
          } catch (_) {
            // linha SSE não-JSON — ignora e continua
          }
        }
      }

      yield ChatDoneEvent(fullText);
    } catch (e) {
      yield ChatErrorEvent('Erro de rede: $e');
    } finally {
      client.close();
    }
  }

  /// Chat não-streaming (usado como fallback caso o stream falhe).
  static Future<Map<String, dynamic>> chatOnce({
    required String token,
    required List<ChatMessage> messages,
    required ApiProvider provider,
    String language = 'pt',
    bool think = false,
    String? systemPrompt,
  }) async {
    final cfg = kProviderMap[provider]!;
    final res = await http.post(
      Uri.parse('$kApiBase/ai/chat'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'messages': messages.map((m) => m.toJson()).toList(),
        'stream': false,
        'language': language,
        'think': think,
        'provider': cfg.provider,
        if (cfg.groqModel != null) 'model': cfg.groqModel,
        if (systemPrompt != null && systemPrompt.trim().isNotEmpty) 'systemPrompt': systemPrompt,
      }),
    );
    final data = _decode(res.body);
    if (res.statusCode == 402) throw CreditsExhaustedException();
    if (res.statusCode < 200 || res.statusCode >= 300) {
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

  /// Edição de documento assistida por IA — usado pelo FAB de sparkles
  /// no EditTab. Devolve APENAS o conteúdo atualizado do documento
  /// (mesmo formato do original), sem texto explicativo à volta, para
  /// poupar tokens e permitir substituição direta no editor.
  static Future<String> editDocument({
    required String token,
    required String currentContent,
    required String instruction,
    required String docType, // "doc" | "sheet" | "slide" | "whiteboard"
    String? selection,
  }) async {
    final res = await http.post(
      Uri.parse('$kApiBase/ai/edit-document'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'currentContent': currentContent,
        'instruction': instruction,
        'docType': docType,
        if (selection != null) 'selection': selection,
      }),
    );
    final data = _decode(res.body);
    if (res.statusCode == 402) throw CreditsExhaustedException();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(data['error']?.toString() ?? 'Erro ao editar documento', statusCode: res.statusCode);
    }
    return data['content']?.toString() ?? currentContent;
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