=====================================================================
lib/screens/chat/chat_tools_local_bridge.dart  (COMPLETO)
=====================================================================

// Ponte entre o catálogo de 36 tools que o modelo conhece
// (kAllTools, em api_service.dart) e o motor de tools local
// (lib/tools/tool_registry.dart, runTool()).
//
// kLocallyExecutableTools (definida em api_service.dart, não aqui —
// para ficar ao lado de kAllTools) lista as 28 tools que já têm
// implementação local completa. executeToolCall (em chat_tools.dart)
// consulta esse Set tool a tool — nunca por conversa inteira — e só
// chama executeLocalTool() quando a tool está lá dentro.
//
// NORMALIZAÇÃO DE SHAPE (saída):
// runTool() devolve sempre um ToolResult (success/data/error/
// error_code). O resto de chat_tools.dart (kVisualTools,
// kDocumentTools, extractDocumentPayload) foi escrito à volta do
// shape achatado que a API sempre devolveu (content_base64,
// pdf_base64, filename, etc — sem o wrapper {success, data}). Esta
// ponte converte um no outro, tool a tool, para que TODO o resto do
// pipeline continue a funcionar sem qualquer alteração.
//
// NORMALIZAÇÃO DE SHAPE (entrada):
// o schema de kAllTools (o que o MODELO vê) e a implementação local
// de duas tools usam nomes de campo diferentes para a mesma coisa.
// Isto não é um bug da tool local nem do schema — é simplesmente que
// foram escritos em momentos diferentes. A ponte normaliza os
// argumentos ANTES de chamar runTool(), para que o modelo continue a
// gerar chamadas exatamente como o schema documenta, sem precisar
// saber que a tool corre localmente:
//
//   generate_chart:
//     modelo manda datasets: [{label, data, color}]
//     ChartTool espera datasets: [{name, values}]
//     -> _normalizeChartArgs() faz label->name, data->values.
//     'color' por dataset ainda não é suportado pela paleta fixa de
//     ChartTool (usa sempre _palette por índice) — o valor é aceite
//     e ignorado, nunca causa erro.
//
//   generate_barcode:
//     modelo pode mandar format: code128|ean13|ean8|upca|qrcode
//     BarcodeTool só reconhece code128|ean13|code39 (senão cai no
//     default code128) — ean8/upca/qrcode são aceites sem erro mas
//     sempre desenhados como code128. Não corrigido aqui de propósito
//     porque implementar ean8/upca corretamente exige mudar
//     barcode_tool.dart, não só a ponte; registado para tratares
//     depois se precisares desses formatos.

import 'dart:convert';
import 'dart:io';

import '../../services/api_service.dart' show kLocallyExecutableTools;
import '../../tools/tools.dart' as local_tools;

/// Tools cujo runTool() local devolve a imagem sob 'image_base64',
/// mas cujo consumidor em chat_tools.dart (kVisualTools) lê
/// 'content_base64' — divergência herdada do facto de a API nunca
/// ter usado 'image_base64' como nome de campo. Normalizamos aqui em
/// vez de mudar kVisualTools, para não arriscar quebrar o
/// passthrough das tools que ainda vêm da API.
const Set<String> _kLocalImageKeyTools = {
  'convert_image_format',
  'crop_image',
  'generate_barcode',
  'generate_chart',
  'generate_function_plot',
  'generate_math_sheet',
  'generate_mindmap',
  'generate_qrcode',
  'generate_table_image',
  'resize_image',
  'watermark_image',
};

/// Verdadeiro se [toolName] tem implementação local pronta a usar.
/// executeToolCall chama isto (via kLocallyExecutableTools) ANTES de
/// decidir ir à API.
bool hasLocalImplementation(String toolName) =>
    kLocallyExecutableTools.contains(toolName);

/// Executa [toolName] via runTool() local e devolve o resultado já
/// normalizado no MESMO shape achatado que ToolsApiService.executeTool
/// sempre devolveu — para que executeToolCall, kVisualTools,
/// kDocumentTools e extractDocumentPayload não precisem saber se a
/// tool correu no dispositivo ou na API.
Future<Map<String, dynamic>> executeLocalTool(
  String toolName,
  Map<String, dynamic> input,
) async {
  final normalizedInput = _normalizeInputIfNeeded(toolName, input);
  final result = await local_tools.runTool(toolName, normalizedInput);

  if (!result.success) {
    // Mesmo shape de erro que o passthrough genérico já sabe
    // interpretar (era o formato que a API devolvia em falha, antes
    // de lançar ApiException — aqui não há exceção porque runTool()
    // nunca lança, só devolve success:false).
    return {
      'error': result.errorMessage ?? 'Erro desconhecido ao executar "$toolName".',
      'error_code': result.errorCode ?? 'UNKNOWN_ERROR',
    };
  }

  final data = result.data;
  final flat = data is Map
      ? Map<String, dynamic>.from(data)
      : <String, dynamic>{'value': data};

  // create_file é um caso especial: a tool local grava em disco e
  // devolve só {path, size_bytes} — nunca bytes. O resto do
  // pipeline (kDocumentTools) espera content_base64 pronto para
  // download/preview, então aqui lemos o ficheiro do disco e
  // convertemos para base64 antes de devolver.
  if (toolName == 'create_file' && flat.containsKey('path')) {
    return _readCreatedFileAsBase64(flat, input);
  }

  // Normaliza image_base64 -> content_base64 só para as tools onde
  // isso é necessário (ver _kLocalImageKeyTools acima). Mantém
  // image_base64 também presente, sem remover — não custa nada e
  // evita quebrar qualquer código que porventura já leia esse nome.
  if (_kLocalImageKeyTools.contains(toolName) && flat.containsKey('image_base64')) {
    flat['content_base64'] = flat['image_base64'];
  }

  return flat;
}

/// Normaliza os argumentos ANTES de chamar runTool(), para as tools
/// onde o schema visível ao modelo (kAllTools) usa nomes de campo
/// diferentes dos que a implementação local espera. Só
/// 'generate_chart' precisa disto hoje — as outras 27 tools locais
/// já usam exatamente os mesmos nomes em kAllTools e no
/// runTool()/*_tool.dart correspondente.
Map<String, dynamic> _normalizeInputIfNeeded(
  String toolName,
  Map<String, dynamic> input,
) {
  if (toolName == 'generate_chart') {
    return _normalizeChartArgs(input);
  }
  return input;
}

/// datasets: [{label, data, color}] (schema do modelo)
///        -> [{name, values}] (o que ChartTool.generate espera)
Map<String, dynamic> _normalizeChartArgs(Map<String, dynamic> input) {
  final rawDatasets = input['datasets'];
  if (rawDatasets is! List) return input;

  final normalizedDatasets = rawDatasets.map((d) {
    if (d is! Map) return d;
    final map = Map<String, dynamic>.from(d);
    return {
      // Aceita tanto o nome do schema (label/data) quanto o nome
      // "nativo" da tool (name/values), para o caso de o modelo já
      // vir a mandar o segundo no futuro sem quebrar nada.
      'name': map['name'] ?? map['label'],
      'values': map['values'] ?? map['data'] ?? [],
      // 'color' é aceite e passado adiante — ChartTool.generate
      // ainda não o lê, mas mantê-lo no map não causa erro.
      if (map['color'] != null) 'color': map['color'],
    };
  }).toList();

  final updated = Map<String, dynamic>.from(input);
  updated['datasets'] = normalizedDatasets;
  return updated;
}

/// Lê de volta o ficheiro que FileCreationTool.create() gravou em
/// disco e devolve-o no shape {content_base64, filename, mime_type}
/// que kDocumentTools/extractDocumentPayload esperam. Se a leitura
/// falhar por qualquer razão, devolve o shape de erro em vez de
/// deixar o ficheiro "invisível" para o utilizador.
Future<Map<String, dynamic>> _readCreatedFileAsBase64(
  Map<String, dynamic> toolOutput,
  Map<String, dynamic> originalInput,
) async {
  final String path = toolOutput['path'].toString();
  try {
    final file = File(path);
    final bytes = await file.readAsBytes();
    final filename = originalInput['filename']?.toString() ?? file.uri.pathSegments.last;

    return {
      'content_base64': base64Encode(bytes),
      'filename': filename,
      'mime_type': _guessMimeType(filename),
      'size_bytes': toolOutput['size_bytes'],
    };
  } catch (e) {
    return {
      'error': 'Ficheiro criado em disco mas não foi possível lê-lo de volta: $e',
      'error_code': 'IO_ERROR',
    };
  }
}

/// Adivinhação simples de mime type pela extensão — create_file
/// aceita qualquer nome de ficheiro, então não há como saber o tipo
/// com certeza; isto cobre os casos mais comuns sem depender de lib
/// externa só para isto.
String _guessMimeType(String filename) {
  final ext = filename.toLowerCase().split('.').last;
  const map = {
    'txt': 'text/plain',
    'md': 'text/markdown',
    'json': 'application/json',
    'csv': 'text/csv',
    'html': 'text/html',
    'xml': 'application/xml',
    'pdf': 'application/pdf',
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
  };
  return map[ext] ?? 'application/octet-stream';
}