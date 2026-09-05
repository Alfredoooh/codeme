// ══════════════════════════════════════════════════════════════
// FILE: lib/aitab/aitab_tools.dart
// Execução de tool calls e o widget de ícone por-tool com fallback.
//
// SINCRONIZADO com o catálogo real de 36 tools ativas (kAllTools em
// api_service.dart):
// - Removidos os cases 'search_place' e 'search_calendar_date' (as
//   tools correspondentes saíram do catálogo enviado ao modelo — o
//   modelo nunca mais vai gerar essas chamadas, e as funções
//   resolvePlaceQuery/resolveCalendarDateQuery deixam de ser usadas
//   aqui; ficam disponíveis noutro módulo caso voltem a ser
//   necessárias).
// - kVisualTools perdeu generate_random_avatar (removida do
//   catálogo) e ganhou generate_barcode (existe no catálogo e
//   devolve content_base64 tal como as outras tools visuais).
// - kDocumentTools perdeu create_pdf_structured (absorvida por
//   create_pdf — já não é um nome de tool separado) e
//   html_to_docx/html_to_pdf/html_to_xlsx/html_to_pptx/
//   create_project_zip (removidas do catálogo); ganhou create_file
//   (devolve content_base64 + filename, mesmo formato de download).
// - kToolAttachmentFields perdeu as entradas para tools removidas
//   (extract_document_outline, docx_to_html, pdf_to_images,
//   pptx_to_images, audio_duration_check, get_image_colors,
//   image_metadata, vectorize_image) — mantidas só as que
//   correspondem a tools do catálogo atual.
//
// CORREÇÃO NESTA VERSÃO — CAMPO DE RESPOSTA NÃO NORMALIZADO:
// documents.py devolve o documento sob uma chave própria por tool
// (pdf_base64/docx_base64/xlsx_base64/pptx_base64), NÃO sob
// content_base64. O Worker passa isto adiante sem renomear — é o
// mesmo comportamento que o testador HTML de documentos já
// documenta e resolve via RAW_FIELD_BY_TOOL. extractDocumentPayload
// replica exatamente essa lógica aqui: para as 4 tools do
// documents.py, lê o campo certo por nome de tool; para as
// restantes kDocumentTools (create_file, csv_to_xlsx, merge_pdfs,
// split_pdf_pages), continua a ler content_base64 como já
// funcionava. Sem isto, os 4 documentos do documents.py caíam
// sempre no passthrough e nunca mostravam o ToolResultDownloadCard.
// ══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/theme/colors.dart';
// TODO: depende de api_service.dart (split futuro); manter este import para a etapa futura de split.
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
// TODO: depende de aiwidgets.dart (split futuro); manter este import para a etapa futura de split.
import '../ai_widgets/ai_widgets.dart';
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

/// Tools que devolvem content_base64 diretamente interpretável como
/// imagem PNG a mostrar inline no chat (ToolResultImageCard).
const Set<String> kVisualTools = {
  'generate_chart',
  'generate_function_plot',
  'generate_math_sheet',
  'generate_mindmap',
  'generate_qrcode',
  'generate_barcode',
  'generate_table_image',
  'download_image_for_project',
  'get_weather',
  // Utilitários de imagem que devolvem content_base64 diretamente:
  'convert_image_format', 'resize_image', 'crop_image', 'watermark_image',
};

/// Tools que devolvem um ficheiro para download (botão
/// ToolResultDownloadCard) em vez de uma imagem inline.
const Set<String> kDocumentTools = {
  'create_pdf', 'create_docx', 'create_xlsx', 'create_pptx',
  'create_file',
  'csv_to_xlsx',
  'merge_pdfs', 'split_pdf_pages',
};

const Set<String> kImageSearchTools = {'search_images'};

/// Mapeamento nome-da-tool → nome do campo que documents.py usa em
/// vez de content_base64, e o mime_type/extensão a atribuir já que
/// documents.py também não devolve mime_type/filename. Réplica
/// direta de RAW_FIELD_BY_TOOL no testador HTML de documentos —
/// mesma causa, mesma correção, só que aqui aplicada ao app real.
const Map<String, ({String field, String mime, String ext})> kRawDocumentFieldByTool = {
  'create_pdf':  (field: 'pdf_base64',  mime: 'application/pdf', ext: 'pdf'),
  'create_docx': (field: 'docx_base64', mime: 'application/vnd.openxmlformats-officedocument.wordprocessingml.document', ext: 'docx'),
  'create_xlsx': (field: 'xlsx_base64', mime: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', ext: 'xlsx'),
  'create_pptx': (field: 'pptx_base64', mime: 'application/vnd.openxmlformats-officedocument.presentationml.presentation', ext: 'pptx'),
};

/// Extrai (base64, filename, mimeType) de um resultado de tool,
/// cobrindo os dois formatos de resposta que existem no backend:
/// 1) o formato "normal" {content_base64, filename, mime_type} usado
///    por create_file/csv_to_xlsx/merge_pdfs/split_pdf_pages;
/// 2) o formato cru do documents.py {pdf_base64|docx_base64|
///    xlsx_base64|pptx_base64}, sem filename nem mime_type — usado
///    por create_pdf/create_docx/create_xlsx/create_pptx.
/// Devolve null se nenhum dos dois formatos produzir um base64
/// não-vazio.
({String base64Data, String filename, String mimeType})? extractDocumentPayload(
  String toolName,
  Map<String, dynamic> resultJson,
) {
  final rawCfg = kRawDocumentFieldByTool[toolName];
  if (rawCfg != null) {
    final raw = resultJson[rawCfg.field]?.toString();
    if (raw != null && raw.isNotEmpty) {
      return (
        base64Data: raw,
        filename: 'documento.${rawCfg.ext}',
        mimeType: rawCfg.mime,
      );
    }
    // Tool está no mapa de campo cru mas não veio o campo esperado
    // (ex: documents.py devolveu {"error": "..."}) — não tenta o
    // formato normal como fallback, porque não faz sentido para
    // estas 4 tools; deixa cair para o passthrough normal.
    return null;
  }

  final normal = resultJson['content_base64']?.toString();
  if (normal != null && normal.isNotEmpty) {
    return (
      base64Data: normal,
      filename: resultJson['filename']?.toString() ??
          '${toolName}_${DateTime.now().millisecondsSinceEpoch}.bin',
      mimeType: resultJson['mime_type']?.toString() ?? 'application/octet-stream',
    );
  }

  return null;
}

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
// destrava ZIP/PDF/XLSX/imagens de facto funcionarem.
// ══════════════════════════════════════════════════════════════

/// Nome do campo de input que cada tool espera receber com o
/// conteúdo do ficheiro em base64, e que tipos mime são aceitáveis
/// para preencher esse campo automaticamente. Só tools que existem
/// no catálogo atual de 36.
const Map<String, ({String field, List<String> mimePrefixes})> kToolAttachmentFields = {
  'read_zip_contents':  (field: 'zip_base64',  mimePrefixes: ['application/zip']),
  'read_pdf_contents':  (field: 'pdf_base64',  mimePrefixes: ['application/pdf']),
  'xlsx_to_json':       (field: 'xlsx_base64', mimePrefixes: ['application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'application/vnd.ms-excel']),
  'convert_image_format': (field: 'image_base64', mimePrefixes: ['image/']),
  'resize_image':       (field: 'image_base64', mimePrefixes: ['image/']),
  'crop_image':         (field: 'image_base64', mimePrefixes: ['image/']),
  'watermark_image':    (field: 'image_base64', mimePrefixes: ['image/']),
  'ocr_extract_text':   (field: 'image_base64', mimePrefixes: ['image/']),
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

/// Executa uma única tool call contra o backend.
///
/// [history] é o histórico da conversa até este ponto — usado
/// apenas para injeção automática de anexos (ver
/// injectAttachmentIfNeeded acima). Pode ser vazio para tools que
/// não usam ficheiros.
///
/// search_market continua resolvida localmente (resolveMarketQuery),
/// como já acontecia antes desta sincronização — as demais tools do
/// catálogo vão todas via ToolsApiService.executeTool.
Future<Map<String, dynamic>> executeToolCall(
  ToolCall call,
  List<ChatMessage> history,
) async {
  final token = authController.token;
  if (token == null) {
    return {'found': false, 'reason': 'Sessão expirada'};
  }

  if (call.name == 'search_market') {
    final query = call.arguments['query']?.toString() ?? '';
    final result = await resolveMarketQuery(query);
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
      final payload = extractDocumentPayload(call.name, resultJson);
      if (payload != null) {
        documents.add(DocumentToolResult(
          base64Data: payload.base64Data,
          filename: payload.filename,
          mimeType: payload.mimeType,
        ));
        toolResultMsgs.add(ChatMessage(
          role: 'tool',
          content: jsonEncode({'success': true, 'filename': payload.filename, 'ready_for_download': true}),
          toolCallId: call.id,
          name: call.name,
        ));
        continue;
      }
    }

    // Passthrough: o modelo recebe o JSON cru para interpretar
    // (web_search, search_market, clima em texto, read_website, ou
    // uma tool de documento que devolveu {"error": "..."}).
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
