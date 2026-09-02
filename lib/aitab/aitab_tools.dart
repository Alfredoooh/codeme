// ══════════════════════════════════════════════════════════════
// FILE: lib/aitab/aitab_tools.dart
// Execução de tool calls e o widget de ícone por-tool com fallback.
//
// CORREÇÃO PRINCIPAL vs. versão anterior:
// 1. search_images é tratada localmente — o resultado JSON da tool
//    é convertido para [[images:...]] no cliente, sem depender do
//    modelo para reescrever URLs em prosa (era a causa do bug de
//    imagens aparecendo como texto).
// 2. Resultados visuais/documento/imagens SEMPRE geram uma segunda
//    chamada ao modelo com o resultado injetado como contexto —
//    antes, se todas as tools fossem "locais", o código terminava
//    ali sem nunca voltar a consultar o modelo, e o utilizador
//    ficava só com o cartão, sem nenhum texto de acompanhamento.
// ══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../colors.dart';
import '../api_service.dart';
import '../auth_service.dart';
import '../aiwidgets.dart';
import 'aitab_models.dart';

// ══════════════════════════════════════════════════════════════
// ÍCONE POR-TOOL COM FALLBACK
// ══════════════════════════════════════════════════════════════

/// Mostra o SVG específico da tool (via kToolIconAssets). Se o
/// ficheiro não existir em assets/icons/outline/, cai automaticamente
/// para o ícone genérico 'tools' — nunca deixa o card sem ícone.
class ToolIcon extends StatelessWidget {
  final String toolName;
  final double size;
  final Color color;
  const ToolIcon({
    super.key,
    required this.toolName,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final specificAsset = kToolIconAssets[toolName];
    final assetPath = specificAsset != null
        ? 'assets/icons/outline/$specificAsset.svg'
        : 'assets/icons/outline/tools.svg';

    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      // Fallback: se o SVG específico não existir no bundle, o
      // errorBuilder desenha o genérico em vez de deixar um buraco.
      placeholderBuilder: (_) => SvgPicture.asset(
        'assets/icons/outline/tools.svg',
        width: size,
        height: size,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// RESULTADOS DE TOOL — TIPOS INTERNOS
// ══════════════════════════════════════════════════════════════

class VisualToolResult {
  final String label;
  final String base64Png;
  const VisualToolResult({required this.label, required this.base64Png});
}

class DocumentToolResult {
  final String base64Data;
  final String filename;
  final String mimeType;
  const DocumentToolResult({
    required this.base64Data,
    required this.filename,
    required this.mimeType,
  });
}

class ImagesToolResult {
  final String marker;
  const ImagesToolResult({required this.marker});
}

const Set<String> kVisualTools = {
  'generate_chart', 'generate_mindmap', 'generate_qrcode', 'generate_barcode',
  'generate_math_sheet', 'generate_table_image',
  'generate_function_plot', 'download_image_for_project',
  'generate_random_avatar',
  'get_weather',
  // Utilitários de imagem que devolvem content_base64 diretamente:
  'convert_image_format', 'resize_image', 'crop_image', 'watermark_image',
};

const Set<String> kDocumentTools = {
  'create_pdf', 'create_pdf_structured', 'create_docx', 'create_xlsx', 'create_pptx',
  'csv_to_xlsx',
  'html_to_docx', 'html_to_pdf', 'html_to_xlsx', 'html_to_pptx',
  'create_project_zip',
  'merge_pdfs', 'split_pdf_pages',
};

const Set<String> kImageSearchTools = {'search_images'};

/// Resultado agregado de processar uma lista de tool calls: separa
/// o que foi resolvido localmente (visual/document/images, cada um
/// vira um marcador que a UI já sabe renderizar) do que precisa de
/// ir para o modelo interpretar (tudo o resto: web_search, mercado,
/// clima em texto, etc — o resultado JSON desses vai na mensagem
/// role:"tool" tal como antes).
class ToolExecutionOutcome {
  final List<VisualToolResult> visuals;
  final List<DocumentToolResult> documents;
  final List<ImagesToolResult> images;
  final List<ChatMessage> toolResultMessages;
  const ToolExecutionOutcome({
    required this.visuals,
    required this.documents,
    required this.images,
    required this.toolResultMessages,
  });
}

// ══════════════════════════════════════════════════════════════
// INJEÇÃO AUTOMÁTICA DE ANEXOS EM ARGUMENTOS DE TOOL
//
// O modelo nunca vê o base64 real de um ficheiro anexado — só sabe
// que existe pelo nome/tipo. Quando o modelo chama uma tool que
// precisa de um campo *_base64 e deixa esse campo vazio ou
// claramente inválido (< 100 caracteres não pode ser um ficheiro
// real), substituímos pelo base64 do anexo mais recente e
// compatível encontrado no histórico da conversa. Isto é o que
// destrava ZIP/PDF/DOCX/XLSX/imagens de facto funcionarem.
// ══════════════════════════════════════════════════════════════

/// Nome do campo de input que cada tool espera receber com o
/// conteúdo do ficheiro em base64, e que tipos mime são aceitáveis
/// para preencher esse campo automaticamente.
const Map<String, ({String field, List<String> mimePrefixes})> kToolAttachmentFields = {
  'read_zip_contents':        (field: 'zip_base64',   mimePrefixes: ['application/zip']),
  'read_pdf_contents':        (field: 'pdf_base64',   mimePrefixes: ['application/pdf']),
  'extract_document_outline': (field: 'pdf_base64',   mimePrefixes: ['application/pdf']),
  'xlsx_to_json':             (field: 'xlsx_base64',  mimePrefixes: ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'application/vnd.ms-excel']),
  'docx_to_html':             (field: 'docx_base64',  mimePrefixes: ['application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'application/msword']),
  'pdf_to_images':            (field: 'pdf_base64',   mimePrefixes: ['application/pdf']),
  'pptx_to_images':           (field: 'pptx_base64',  mimePrefixes: ['application/vnd.openxmlformats-officedocument.presentationml.presentation']),
  'audio_duration_check':     (field: 'audio_base64', mimePrefixes: ['audio/']),
  'get_image_colors':         (field: 'image_base64', mimePrefixes: ['image/']),
  'convert_image_format':     (field: 'image_base64', mimePrefixes: ['image/']),
  'resize_image':             (field: 'image_base64', mimePrefixes: ['image/']),
  'crop_image':               (field: 'image_base64', mimePrefixes: ['image/']),
  'watermark_image':          (field: 'image_base64', mimePrefixes: ['image/']),
  'image_metadata':           (field: 'image_base64', mimePrefixes: ['image/']),
  'vectorize_image':          (field: 'image_base64', mimePrefixes: ['image/']),
  'ocr_extract_text':         (field: 'image_base64', mimePrefixes: ['image/']),
};

/// Threshold mínimo de comprimento para considerar que o modelo já
/// escreveu um base64 real e válido no argumento — abaixo disto
/// (string vazia, placeholder, ou alucinação curta) substituímos
/// pelo anexo real do utilizador.
const int kMinPlausibleBase64Length = 100;

/// Procura, na lista de mensagens da conversa, o anexo mais recente
/// cujo mimeType comece por um dos prefixos aceites. Percorre de
/// trás para a frente (mais recente primeiro).
Map<String, dynamic>? findMostRecentAttachment(
  List<ChatMessage> history,
  List<String> mimePrefixes,
) {
  for (var i = history.length - 1; i >= 0; i--) {
    final atts = history[i].attachments;
    if (atts == null || atts.isEmpty) continue;
    for (var j = atts.length - 1; j >= 0; j--) {
      final att = atts[j];
      final mime = att['mimeType']?.toString() ?? '';
      final matches = mimePrefixes.any((p) => mime.startsWith(p));
      if (matches) return att;
    }
  }
  return null;
}

/// Dado o nome da tool e os argumentos que o modelo pediu, devolve
/// os argumentos já corrigidos com o base64 real injetado, se
/// aplicável. Se não houver campo a injetar, ou não houver anexo
/// compatível, devolve os argumentos originais sem alteração.
Map<String, dynamic> injectAttachmentIfNeeded(
  String toolName,
  Map<String, dynamic> arguments,
  List<ChatMessage> history,
) {
  final spec = kToolAttachmentFields[toolName];
  if (spec == null) return arguments;

  final current = arguments[spec.field]?.toString() ?? '';
  if (current.length >= kMinPlausibleBase64Length) return arguments;

  final attachment = findMostRecentAttachment(history, spec.mimePrefixes);
  if (attachment == null) return arguments;

  final base64Data = attachment['base64']?.toString();
  if (base64Data == null || base64Data.isEmpty) return arguments;

  final updated = Map<String, dynamic>.from(arguments);
  updated[spec.field] = base64Data;
  return updated;
}

/// Executa uma única tool call contra o backend (ou localmente para
/// search_market/search_place/search_calendar_date, que já tinham
/// resolvers locais antes desta refatoração).
///
/// [history] é o histórico da conversa até este ponto — usado
/// apenas para injeção automática de anexos (ver
/// injectAttachmentIfNeeded acima). Pode ser vazio para tools que
/// não usam ficheiros.
Future<Map<String, dynamic>> executeToolCall(
  ToolCall call,
  List<ChatMessage> history,
) async {
  final token = authController.token;
  if (token == null) {
    return {'found': false, 'reason': 'Sessão expirada'};
  }

  switch (call.name) {
    case 'search_market':
      final query = call.arguments['query']?.toString() ?? '';
      final result = await resolveMarketQuery(query);
      return result.toToolResultJson();
    case 'search_place':
      final query = call.arguments['query']?.toString() ?? '';
      final result = await resolvePlaceQuery(query);
      return result.toToolResultJson();
    case 'search_calendar_date':
      final query = call.arguments['query']?.toString() ?? '';
      final result = await resolveCalendarDateQuery(query);
      return result.toToolResultJson();
  }

  final effectiveArgs = injectAttachmentIfNeeded(call.name, call.arguments, history);

  try {
    final result = await ToolsApiService.executeTool(
      token: token,
      name: call.name,
      input: effectiveArgs,
    );
    return result;
  } catch (e) {
    return {'found': false, 'reason': 'Erro: $e'};
  }
}

/// Processa uma lista de tool calls já resolvidas, separando o que
/// é renderizável localmente do que precisa de ir para o modelo.
///
/// [history] é o histórico da conversa até este ponto (antes desta
/// rodada de tool calls) — necessário para a injeção automática de
/// anexos em tools que precisam de ficheiros do utilizador.
Future<ToolExecutionOutcome> processToolCalls(
  List<ToolCall> calls,
  List<ChatMessage> history,
) async {
  final visuals = <VisualToolResult>[];
  final documents = <DocumentToolResult>[];
  final images = <ImagesToolResult>[];
  final toolResultMsgs = <ChatMessage>[];

  for (final call in calls) {
    final resultJson = await executeToolCall(call, history);

    if (kImageSearchTools.contains(call.name)) {
      final marker = buildImagesMarker(resultJson);
      if (marker.isNotEmpty) {
        images.add(ImagesToolResult(marker: marker));
        toolResultMsgs.add(ChatMessage(
          role: 'tool',
          content: jsonEncode({'success': true, 'rendered': true, 'tool': call.name}),
          toolCallId: call.id,
          name: call.name,
        ));
        continue;
      }
      // Sem imagens encontradas: deixa cair para o passthrough
      // normal, para o modelo poder dizer "não encontrei imagens".
    }

    if (kVisualTools.contains(call.name)) {
      final base64Png = resultJson['content_base64']?.toString();
      if (base64Png != null && base64Png.isNotEmpty) {
        visuals.add(VisualToolResult(
          label: labelForToolName(call.name).replaceAll('...', ''),
          base64Png: base64Png,
        ));
        toolResultMsgs.add(ChatMessage(
          role: 'tool',
          content: jsonEncode({'success': true, 'rendered': true, 'tool': call.name}),
          toolCallId: call.id,
          name: call.name,
        ));
        continue;
      }
    }

    if (kDocumentTools.contains(call.name)) {
      final base64Data = resultJson['content_base64']?.toString();
      final filename = resultJson['filename']?.toString() ??
          '${call.name}_${DateTime.now().millisecondsSinceEpoch}.bin';
      final mimeType = resultJson['mime_type']?.toString() ?? 'application/octet-stream';
      if (base64Data != null && base64Data.isNotEmpty) {
        documents.add(DocumentToolResult(
          base64Data: base64Data,
          filename: filename,
          mimeType: mimeType,
        ));
        toolResultMsgs.add(ChatMessage(
          role: 'tool',
          content: jsonEncode({'success': true, 'filename': filename, 'ready_for_download': true}),
          toolCallId: call.id,
          name: call.name,
        ));
        continue;
      }
    }

    // Passthrough: o modelo recebe o JSON cru para interpretar
    // (web_search, search_market, clima em texto, json_transform, etc).
    toolResultMsgs.add(ChatMessage(
      role: 'tool',
      content: jsonEncode(resultJson),
      toolCallId: call.id,
      name: call.name,
    ));
  }

  return ToolExecutionOutcome(
    visuals: visuals,
    documents: documents,
    images: images,
    toolResultMessages: toolResultMsgs,
  );
}

/// Constrói o texto de assistente (marcadores locais) a inserir na
/// conversa a partir de um outcome — usado tanto para preview local
/// quanto para persistência.
String buildLocalResultMarkersText(ToolExecutionOutcome outcome) {
  final extras = <String>[];
  for (final v in outcome.visuals) {
    extras.add('[[VISUAL:${v.base64Png}:${v.label}]]');
  }
  for (final d in outcome.documents) {
    extras.add('[[DOCUMENT:${d.base64Data}:${d.filename}:${d.mimeType}]]');
  }
  for (final i in outcome.images) {
    extras.add(i.marker);
  }
  return extras.join('\n');
}