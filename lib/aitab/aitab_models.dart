// ══════════════════════════════════════════════════════════════
// FILE: lib/aitab/aitab_models.dart
// Tipos de dados puros do AiTab: mensagens auxiliares, modelos de
// IA, ações de conversa, e todos os parsers de marcadores
// ([[VISUAL:...]], [[DOCUMENT:...]], [[images:...]], [[canvas:...]],
// [[THINKING]], [[sources:...]]). Zero UI neste arquivo.
//
// SINCRONIZADO com o catálogo real de 36 tools ativas (kAllTools em
// api_service.dart). labelForToolName e kToolIconAssets removeram
// toda entrada para tools que saíram do catálogo (search_place,
// search_calendar_date, json_transform, html_to_docx/pdf/xlsx/pptx,
// create_project_zip, create_pdf_structured, generate_random_avatar,
// docx_to_html, get_image_colors, image_metadata, vectorize_image,
// pdf_to_images, pptx_to_images, audio_duration_check,
// format_markdown_to_html, youtube_thumbnail_extract,
// extract_document_outline) e ganharam entrada própria para as que
// faltavam (send_email, generate_barcode, create_file, xlsx_to_json,
// convert_image_format, resize_image, crop_image, watermark_image,
// ocr_extract_text, str_replace_file, diff_text,
// extract_urls_from_text, count_tokens_estimate, text_summary_stats,
// merge_pdfs, split_pdf_pages), em vez de caírem no fallback
// genérico "A executar...".
// ══════════════════════════════════════════════════════════════

import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import '../api_service.dart';
import '../apps/app_types.dart';
import '../aiwidgets.dart';

String iconForEditorType(EditorType type) {
  switch (type) {
    case EditorType.docs:   return 'doc';
    case EditorType.sheets: return 'table';
    case EditorType.slides: return 'stacks';
  }
}

EditorType editorTypeFromProgressTitle(String title) {
  if (title.contains('folha')) return EditorType.sheets;
  if (title.contains('apresentação')) return EditorType.slides;
  return EditorType.docs;
}

// ══════════════════════════════════════════════════════════════
// MODELOS DE IA
// ══════════════════════════════════════════════════════════════

enum AiModel { deepseekFlash, deepseekPro, deepseekReasoning }

extension AiModelX on AiModel {
  String get label => const {
        AiModel.deepseekFlash:     'DeepSeek Flash',
        AiModel.deepseekPro:       'DeepSeek Pro',
        AiModel.deepseekReasoning: 'DeepSeek Raciocínio',
      }[this]!;

  String get badge => const {
        AiModel.deepseekFlash:     'Rápido',
        AiModel.deepseekPro:       'Avançado',
        AiModel.deepseekReasoning: 'Raciocínio',
      }[this]!;

  String get description => const {
        AiModel.deepseekFlash:     'Respostas rápidas para o dia a dia',
        AiModel.deepseekPro:       'Mais capacidade para tarefas complexas',
        AiModel.deepseekReasoning: 'Pensa passo a passo antes de responder',
      }[this]!;

  ApiProvider get provider => const {
        AiModel.deepseekFlash:     ApiProvider.deepseekFlash,
        AiModel.deepseekPro:       ApiProvider.deepseekPro,
        AiModel.deepseekReasoning: ApiProvider.deepseekReasoning,
      }[this]!;
}

// ══════════════════════════════════════════════════════════════
// SYSTEM PROMPTS
// ══════════════════════════════════════════════════════════════

const String kAiSystemPrompt = '''
Respondes sempre em português europeu, de forma clara e bem estruturada.
Usa formatação markdown completa sempre que ajudar a organizar a informação:
negrito para destacar termos-chave, listas com marcadores ou numeradas para
sequências e opções, tabelas para comparações ou dados tabulares, linhas
horizontais (---) para separar secções distintas, e títulos curtos quando a
resposta tiver várias secções. Dentro de células de tabela podes usar
negrito (**texto**) normalmente — a aplicação processa a formatação em
qualquer parte do texto, incluindo dentro de tabelas. Evita parágrafos
longos e densos quando a informação pode ser organizada visualmente.

Para blocos de nota, dica, aviso ou informação indispensável, usa o formato
de admonition ao estilo GitHub, exatamente assim:

> [!NOTE]
> Texto da nota aqui.

Os tipos disponíveis são NOTE (nota neutra), TIP (dica), IMPORTANT
(informação indispensável), WARNING (aviso) e CAUTION (cuidado/perigo).
A aplicação transforma isto automaticamente num cartão visual — nunca
precisas de explicar ou descrever visualmente o cartão, apenas escrever
o bloco neste formato exato.

Para expressões matemáticas, usa \$expressão\$ para matemática dentro do
texto corrido e \$\$expressão\$\$ numa linha própria para fórmulas em destaque.
Podes usar notação LaTeX-like: frações com \\frac{a}{b}, raízes com \\sqrt{x} ou \\sqrt[n]{x}, potências com x^2 ou x^{10}, índices com x_1 ou
x_{ij}, letras gregas com \\alpha, \\beta, \\pi, \\Delta, etc., e operadores
como \\leq, \\geq, \\neq, \\times, \\cdot, \\sum, \\int, \\infty, \\rightarrow.
A aplicação converte tudo automaticamente para uma apresentação visual
correta — nunca precisas de explicar a notação, apenas escrevê-la.
''';

const String kAiWidgetsInstructions = '''
Tens também acesso a widgets visuais interativos, que aparecem diretamente
dentro da conversa (nunca em canvas), e a várias tools para pesquisar, criar
documentos, converter ficheiros, gerar imagens, ler anexos e enviar emails.

REGRA GERAL DE USO DE TOOLS — a mais importante de todas: só chamas uma tool
quando ela é realmente necessária para responder bem, nunca por rotina, nunca
"para garantir", nunca como demonstração. Antes de chamar qualquer tool,
pergunta-te internamente: "consigo responder bem sem isto?" Se a resposta for
sim, respondes diretamente em texto, sem tool nenhuma. Exemplos de quando NÃO
chamar tools: perguntas de conhecimento geral, conversas casuais, pedidos que
já respondeste antes na conversa, perguntas cuja resposta não muda com dados
externos. Exemplos de quando chamar: o utilizador pede explicitamente um
gráfico/PDF/QR code/pesquisa; a pergunta depende de dados atuais (preços,
notícias, clima); o utilizador anexou um ficheiro e pede para o processares;
o utilizador pede envio de email. Usar tools a mais é tão errado como não
usar quando é preciso — sê sempre o mais direto e eficiente possível.

ANEXOS DO UTILIZADOR (imagens, PDF, XLSX, ZIP): quando o utilizador anexa um
ficheiro, a aplicação já trata da parte técnica de te dar acesso ao conteúdo
real assim que chamares a tool correspondente — nunca precisas de pedir
"envia-me em base64" nem nada técnico. Basta chamares a tool normal
(read_zip_contents, read_pdf_contents, xlsx_to_json, ocr_extract_text, etc.)
como seria de esperar, e o campo *_base64 é preenchido automaticamente com o
ficheiro que o utilizador anexou mais recentemente e for do tipo certo para
essa tool. Se o utilizador ainda não anexou nada e a tool precisa de um
ficheiro, pede-lhe claramente para anexar antes de tentares chamar a tool.
Se houver mais que um anexo recente do mesmo tipo, assume que é o mais
recente, a menos que o utilizador tenha sido explícito sobre qual.

Para o widget de mercado, chama primeiro a tool correspondente, espera o
resultado, e escreve o bloco widget com os dados reais.

Quando usares web_search, no final da resposta escreve exatamente um bloco
[[sources:url1,url2,url3]] com os links das fontes mais relevantes que
usaste (máximo 4), sem nenhum outro texto a acompanhar esse bloco. Não
escrevas "Fontes:" nem menciones os links de outra forma.

Quando usares search_images, as imagens já são exibidas automaticamente pela
aplicação assim que a pesquisa termina — nunca escrevas URLs de imagens em
texto, nunca as descrevas uma a uma, e nunca menciones "aqui estão as
imagens" seguido de links. Podes apenas acrescentar um comentário breve
sobre o que as imagens mostram, se fizer sentido.

Quando o resultado de uma tool de geração visual ou de criação/conversão de
documento já tiver sido processado, a aplicação mostra automaticamente o
cartão visual ou o botão de download correspondente — nunca descrevas em
texto que "aqui está o gráfico" ou "podes descarregar o PDF aqui", nunca
inventes um link. Podes comentar o conteúdo mas nunca anuncies a existência
do cartão.

ENVIO DE EMAILS (send_email) — segue isto sempre, sem exceção:
1. Só uses send_email quando o utilizador pedir claramente o envio de um
   email. Nunca envies sem pedido explícito e sem destinatário confirmado.
2. O campo "content" é HTML e tem de ser um design cuidado, profissional e
   visualmente rico — nunca um parágrafo simples. Usa sempre uma estrutura
   completa com: um contentor principal com largura máxima (max-width:600px),
   margem automática, fundo branco, cantos arredondados e sombra subtil;
   tipografia com hierarquia clara (títulos maiores e mais fortes, corpo de
   texto legível, espaçamento entre linhas confortável); cores consistentes
   e harmoniosas (usa uma cor de destaque, ex. #6F5AF6, para títulos ou
   botões); espaçamento generoso entre secções (padding, nunca texto colado
   às margens); se fizer sentido, secções separadas visualmente (divisores
   subtis, blocos com fundo ligeiramente diferente para destacar informação
   importante). Todo o CSS tem de ir inline (style="..." em cada elemento),
   nunca em tag <style>, porque a maioria dos clientes de email ignora
   <style>. Nunca deixes HTML por fechar, nunca uses tags inválidas, e nunca
   escrevas com erros ortográficos ou gramaticais — revê mentalmente o texto
   português antes de o escreveres no HTML.
3. SÓ incluas imagens no email (parâmetro "images") se isso for realmente
   necessário para o conteúdo do email (ex: o utilizador pediu explicitamente
   uma imagem no email, ou o email é sobre algo que precisa mesmo de imagem,
   como uma fatura com logótipo ou uma newsletter visual). Nunca acrescentes
   imagens só porque a funcionalidade existe. Se precisares mesmo de uma
   imagem e o utilizador ainda não a enviou, pede-lha claramente em texto
   normal (ex.: "Podes enviar-me a imagem que queres incluir no email?"). Só
   depois de a receberes é que chamas send_email com essa imagem em
   "images", usando um content_id único (ex. "logo1") e referenciando-o no
   HTML exatamente como <img src="cid:logo1" style="..." />.
4. Antes de chamar send_email, confirma mentalmente que subject e content
   estão completos, bem escritos e sem falhas — nunca envies um rascunho.

Usa widgets apenas quando acrescentam valor real à resposta, nunca como
enfeite. Nunca expliques ao utilizador que estás a chamar uma função ou
tool — isso é processado automaticamente, sem nunca mostrar JSON cru nem
mencionar "tool" ou "função" na tua resposta em texto.
''';

const String kAiWebSearchInstructions = '''
Tens acesso a pesquisa na web em tempo real para esta conversa. Quando a
pergunta do utilizador beneficiar de informação atual, recente ou que possa
ter mudado (notícias, preços, eventos, versões de software, datas), utiliza
essa capacidade de pesquisa antes de responderes, e baseia a resposta nos
resultados encontrados. Quando citares algo encontrado na pesquisa, sê claro
sobre a fonte de forma natural no texto.
''';

// ══════════════════════════════════════════════════════════════
// REGEX DE MARCADORES
// ══════════════════════════════════════════════════════════════

final RegExp kVisualResultRe = RegExp(r'\[\[VISUAL:(.*?):(.*?)\]\]', dotAll: true);
final RegExp kDocumentResultRe = RegExp(r'\[\[DOCUMENT:(.*?):(.*?):(.*?)\]\]', dotAll: true);
final RegExp kSourcesRe = RegExp(r'\[\[sources:(.*?)\]\]');
final RegExp kImagesRe = RegExp(r'\[\[images:(.*?)\]\]', dotAll: true);
final RegExp kExplicitCanvasRe = RegExp(
  r'\[\[canvas:(doc|sheet|slide):(.*?)\|\|([\s\S]*?)\]\]',
);
final RegExp kSoundSearchRe = RegExp(r'\[\[sound_search:(.*?)\]\]');
final RegExp kThinkingRe = RegExp(
  r'\[\[THINKING\]\]([\s\S]*?)\[\[/THINKING\]\]',
);

List<Widget_ToolResultImageData> extractVisualResults(String text) {
  final results = <Widget_ToolResultImageData>[];
  for (final m in kVisualResultRe.allMatches(text)) {
    results.add(Widget_ToolResultImageData(
      base64Png: m.group(1)!,
      label: m.group(2)!,
    ));
  }
  return results;
}

class Widget_ToolResultImageData {
  final String base64Png;
  final String label;
  const Widget_ToolResultImageData({required this.base64Png, required this.label});
}

List<Widget_ToolResultDocumentData> extractDocumentResults(String text) {
  final results = <Widget_ToolResultDocumentData>[];
  for (final m in kDocumentResultRe.allMatches(text)) {
    results.add(Widget_ToolResultDocumentData(
      base64Data: m.group(1)!,
      filename: m.group(2)!,
      mimeType: m.group(3)!,
    ));
  }
  return results;
}

class Widget_ToolResultDocumentData {
  final String base64Data;
  final String filename;
  final String mimeType;
  const Widget_ToolResultDocumentData({
    required this.base64Data,
    required this.filename,
    required this.mimeType,
  });
}

List<Map<String, dynamic>> extractImages(String text) {
  final match = kImagesRe.firstMatch(text);
  if (match == null) return const [];
  final raw = match.group(1)!;
  final items = <Map<String, dynamic>>[];
  for (final entry in raw.split(',')) {
    final trimmed = entry.trim();
    if (trimmed.isEmpty) continue;
    final parts = trimmed.split('|');
    final url = parts[0].trim();
    if (url.isEmpty) continue;
    items.add({
      'imageUrl': url,
      'title': parts.length > 1 ? parts[1].trim() : '',
    });
  }
  return items;
}

/// Constrói o marcador [[images:...]] a partir do resultado bruto
/// da tool search_images (formato do server.js: {found, images:[{imageUrl,title,...}]}).
/// Usado localmente em vez de deixar o modelo reescrever URLs em prosa.
String buildImagesMarker(Map<String, dynamic> toolResult) {
  final images = toolResult['images'];
  if (images is! List || images.isEmpty) return '';
  final entries = <String>[];
  for (final img in images) {
    if (img is! Map) continue;
    final url = img['imageUrl']?.toString() ?? '';
    if (url.isEmpty) continue;
    final title = (img['title']?.toString() ?? '').replaceAll(',', ' ').replaceAll('|', ' ');
    entries.add(title.isEmpty ? url : '$url|$title');
  }
  if (entries.isEmpty) return '';
  return '[[images:${entries.join(',')}]]';
}

List<String> extractSources(String text) {
  final match = kSourcesRe.firstMatch(text);
  if (match == null) return const [];
  return match.group(1)!
      .split(',')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
}

String cleanAiText(String raw) {
  return raw
      .replaceAll(kExplicitCanvasRe, '')
      .replaceAll(kThinkingRe, '')
      .replaceAll(kVisualResultRe, '')
      .replaceAll(kDocumentResultRe, '')
      .replaceAll(kSourcesRe, '')
      .replaceAll(kImagesRe, '')
      .trim();
}

// ══════════════════════════════════════════════════════════════
// CANVAS SCANNING
// ══════════════════════════════════════════════════════════════

class CanvasScanResult {
  final String cleanText;
  final List<LocalCanvasItem> items;
  const CanvasScanResult({required this.cleanText, required this.items});
}

LocalCanvasKind canvasKindFromString(String kindStr) {
  return switch (kindStr) {
    'sheet' => LocalCanvasKind.sheet,
    'slide' => LocalCanvasKind.slide,
    _ => LocalCanvasKind.doc,
  };
}

CanvasScanResult scanForCanvasItems(String raw, String Function() idGen) {
  final items = <LocalCanvasItem>[];
  final text = raw.replaceAllMapped(kExplicitCanvasRe, (m) {
    final title = m.group(2)!.trim();
    items.add(LocalCanvasItem(
      id: idGen(),
      kind: canvasKindFromString(m.group(1)!),
      title: title.isEmpty ? 'Documento' : title,
      content: m.group(3)!,
    ));
    return '';
  });
  return CanvasScanResult(cleanText: text.trim(), items: items);
}

class CanvasMarkResult {
  final String textWithMarkers;
  final List<LocalCanvasItem> items;
  const CanvasMarkResult({required this.textWithMarkers, required this.items});
}

CanvasMarkResult markCanvasItems(String raw, String Function() idGen) {
  final items = <LocalCanvasItem>[];
  final text = raw.replaceAllMapped(kExplicitCanvasRe, (m) {
    final title = m.group(2)!.trim();
    final idx = items.length;
    items.add(LocalCanvasItem(
      id: idGen(),
      kind: canvasKindFromString(m.group(1)!),
      title: title.isEmpty ? 'Documento' : title,
      content: m.group(3)!,
    ));
    return '\u0000CV$idx\u0000';
  });
  return CanvasMarkResult(textWithMarkers: text.trim(), items: items);
}

String canvasBlockToRaw(LocalCanvasItem item) {
  return '[[canvas:${item.kind.name}:${item.title}||${item.content}]]';
}

String resolveCanvasMarkersToBlocks(
  String textWithMarkers,
  List<LocalCanvasItem> items,
) {
  var result = textWithMarkers;
  for (int i = 0; i < items.length; i++) {
    result = result.replaceFirst('\u0000CV$i\u0000', canvasBlockToRaw(items[i]));
  }
  return result;
}

// ══════════════════════════════════════════════════════════════
// THINKING SCANNING
// ══════════════════════════════════════════════════════════════

class ThinkingScanResult {
  final String? thinking;
  final String cleanText;
  const ThinkingScanResult({required this.thinking, required this.cleanText});
}

ThinkingScanResult extractThinking(String raw) {
  final match = kThinkingRe.firstMatch(raw);
  if (match == null) {
    return ThinkingScanResult(thinking: null, cleanText: raw);
  }
  final thinking = match.group(1)!.trim();
  final cleanText = raw.replaceFirst(kThinkingRe, '').trim();
  return ThinkingScanResult(
    thinking: thinking.isEmpty ? null : thinking,
    cleanText: cleanText,
  );
}

// ══════════════════════════════════════════════════════════════
// ANEXOS
// ══════════════════════════════════════════════════════════════

class AttachedFile {
  final String id;
  final String name;
  final String mimeType;
  final Uint8List bytes;
  const AttachedFile({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.bytes,
  });

  String get base64Data => base64Encode(bytes);
}

// ══════════════════════════════════════════════════════════════
// AÇÕES DE CONVERSA
// ══════════════════════════════════════════════════════════════

enum ConversationAction { newChat, incognito, rename, delete }

extension ConversationActionX on ConversationAction {
  String get assetName => switch (this) {
        ConversationAction.newChat   => 'new_chat',
        ConversationAction.incognito => 'incognito',
        ConversationAction.rename    => 'pencil',
        ConversationAction.delete    => 'trash',
      };

  String get label => const {
        ConversationAction.newChat:   'Iniciar nova conversa',
        ConversationAction.incognito: 'Conversa incógnita',
        ConversationAction.rename:    'Renomear conversa',
        ConversationAction.delete:    'Eliminar conversa',
      }[this]!;
}

// ══════════════════════════════════════════════════════════════
// ELEMENTOS DE STREAMING
// ══════════════════════════════════════════════════════════════

sealed class StreamElement {}

class StreamText extends StreamElement {
  final String text;
  StreamText(this.text);
}

class StreamCanvasBlock extends StreamElement {
  final String label;
  final LocalCanvasItem? item;
  StreamCanvasBlock({required this.label, this.item});
}

class StreamWidgetBlock extends StreamElement {
  final String label;
  final AiWidgetBlock? block;
  StreamWidgetBlock({required this.label, this.block});
}

class StreamGenericOpenBlock extends StreamElement {
  final String label;
  StreamGenericOpenBlock(this.label);
}

class StreamVisualResult extends StreamElement {
  final String base64Png;
  final String label;
  StreamVisualResult({required this.base64Png, required this.label});
}

class StreamDocumentResult extends StreamElement {
  final String base64Data;
  final String filename;
  final String mimeType;
  StreamDocumentResult({required this.base64Data, required this.filename, required this.mimeType});
}

class StreamImagesResult extends StreamElement {
  final List<Map<String, dynamic>> images;
  StreamImagesResult(this.images);
}

class OpenBlockInfo {
  final String label;
  const OpenBlockInfo(this.label);
}

List<StreamElement> parseStreamingContent(String raw, String Function() idGen) {
  final visuals = extractVisualResults(raw);
  final documents = extractDocumentResults(raw);
  final imagesRaw = extractImages(raw);

  final canvasScan = markCanvasItems(raw, idGen);
  final widgetParse = parseAiWidgetBlocks(canvasScan.textWithMarkers);
  var remaining = widgetParse.textWithMarkers;

  // Remove os marcadores VISUAL/DOCUMENT/images do texto residual —
  // já foram extraídos acima e vão virar os seus próprios StreamElement,
  // não devem sobrar como texto nem ser descartados em silêncio.
  remaining = remaining
      .replaceAll(kVisualResultRe, '')
      .replaceAll(kDocumentResultRe, '')
      .replaceAll(kImagesRe, '');

  final openStart = findOpenBlockStart(remaining);
  if (openStart != -1) {
    remaining = remaining.substring(0, openStart);
  }

  final combinedMarkerRe = RegExp(r'\u0000(CV|WB)(\d+)\u0000');
  final parts = remaining.split(combinedMarkerRe);
  final markerMatches = combinedMarkerRe.allMatches(remaining).toList();

  final elements = <StreamElement>[];

  // Cards locais primeiro (imagens, documentos, visuais) — são
  // resultado direto de tool call já resolvida, não dependem de o
  // texto do modelo estar completo, por isso podem aparecer assim
  // que o marcador surgir no stream, antes do resto do texto.
  for (final v in visuals) {
    elements.add(StreamVisualResult(base64Png: v.base64Png, label: v.label));
  }
  for (final d in documents) {
    elements.add(StreamDocumentResult(base64Data: d.base64Data, filename: d.filename, mimeType: d.mimeType));
  }
  if (imagesRaw.isNotEmpty) {
    elements.add(StreamImagesResult(imagesRaw));
  }

  for (int i = 0; i < parts.length; i++) {
    if (parts[i].isNotEmpty) {
      elements.add(StreamText(parts[i]));
    }
    if (i < markerMatches.length) {
      final type = markerMatches[i].group(1)!;
      final idx = int.parse(markerMatches[i].group(2)!);
      if (type == 'CV' && idx < canvasScan.items.length) {
        final item = canvasScan.items[idx];
        elements.add(StreamCanvasBlock(
          label: labelForCanvasKind(item.kind),
          item: item,
        ));
      } else if (type == 'WB' && idx < widgetParse.blocks.length) {
        final block = widgetParse.blocks[idx];
        elements.add(StreamWidgetBlock(
          label: labelForWidgetId(block.id),
          block: block,
        ));
      }
    }
  }

  final openInfo = detectOpenBlockInfo(raw);
  if (openInfo != null) {
    elements.add(openBlockToElement(raw, openInfo));
  }

  return elements;
}

int findOpenBlockStart(String text) {
  int start = -1;

  final canvasMatches = RegExp(r'\[\[canvas:(doc|sheet|slide):').allMatches(text).toList();
  if (canvasMatches.isNotEmpty) {
    final last = canvasMatches.last;
    final after = text.substring(last.start);
    if (!after.contains(']]')) {
      start = math.max(start, last.start);
    }
  }

  final widgetMatches = RegExp(r'```(widget_[a-z]+)').allMatches(text).toList();
  if (widgetMatches.isNotEmpty) {
    final last = widgetMatches.last;
    final after = text.substring(last.start);
    if (!after.contains('```', 3)) {
      start = math.max(start, last.start);
    }
  }

  final soundMatches = RegExp(r'\[\[sound_search:').allMatches(text).toList();
  if (soundMatches.isNotEmpty) {
    final last = soundMatches.last;
    final after = text.substring(last.start);
    if (!after.contains(']]')) {
      start = math.max(start, last.start);
    }
  }

  return start;
}

String labelForCanvasKind(LocalCanvasKind kind) => switch (kind) {
      LocalCanvasKind.sheet => 'Criando folha de cálculo...',
      LocalCanvasKind.slide => 'Criando apresentação...',
      LocalCanvasKind.doc => 'Criando documento...',
    };

String labelForWidgetId(String widgetId) => switch (widgetId) {
      'widget_market' => 'A carregar cotação...',
      'widget_calendar' => 'A criar calendário...',
      'widget_map' => 'A carregar mapa...',
      _ => 'Criando widget...',
    };

/// Mapa central nome-da-tool → texto de progresso ("A pesquisar na web...").
/// Sincronizado com as 36 tools ativas em kAllTools (api_service.dart).
String labelForToolName(String toolName) => switch (toolName) {
      'web_search'                  => 'A pesquisar na web...',
      'read_website'                => 'A ler página...',
      'search_images'               => 'A pesquisar imagens...',
      'search_videos'               => 'A pesquisar vídeos...',
      'search_books'                => 'A pesquisar livros...',
      'download_image_for_project'  => 'A descarregar imagem...',
      'search_market'               => 'A pesquisar mercado...',
      'get_weather'                 => 'A obter clima...',
      'send_email'                  => 'A enviar email...',
      'generate_chart'              => 'A gerar gráfico...',
      'generate_function_plot'      => 'A gerar gráfico de função...',
      'generate_math_sheet'         => 'A calcular...',
      'generate_mindmap'            => 'A criar mapa mental...',
      'generate_qrcode'             => 'A gerar QR code...',
      'generate_barcode'            => 'A gerar código de barras...',
      'generate_table_image'        => 'A gerar tabela visual...',
      'create_pdf'                  => 'A criar PDF...',
      'create_docx'                 => 'A criar documento Word...',
      'create_xlsx'                 => 'A criar folha de cálculo...',
      'create_pptx'                 => 'A criar apresentação...',
      'create_file'                 => 'A criar ficheiro...',
      'read_zip_contents'           => 'A ler conteúdo do ZIP...',
      'read_pdf_contents'           => 'A extrair texto do PDF...',
      'csv_to_xlsx'                 => 'A converter CSV...',
      'xlsx_to_json'                => 'A converter Excel para JSON...',
      'convert_image_format'        => 'A converter formato de imagem...',
      'resize_image'                => 'A redimensionar imagem...',
      'crop_image'                  => 'A recortar imagem...',
      'watermark_image'             => 'A aplicar marca de água...',
      'ocr_extract_text'            => 'A extrair texto da imagem...',
      'str_replace_file'            => 'A editar texto...',
      'diff_text'                   => 'A comparar textos...',
      'extract_urls_from_text'      => 'A extrair links...',
      'count_tokens_estimate'       => 'A estimar tokens...',
      'text_summary_stats'          => 'A analisar texto...',
      'merge_pdfs'                  => 'A juntar PDFs...',
      'split_pdf_pages'             => 'A extrair páginas do PDF...',
      _                             => 'A executar...',
    };

/// Mapa central nome-da-tool → asset SVG específico. Tools sem entrada
/// aqui (ou cujo ficheiro não exista em assets/icons/outline/) caem
/// automaticamente no fallback 'tools' via ToolIcon (ver aitab_tools.dart).
/// Sincronizado com as 36 tools ativas em kAllTools (api_service.dart).
const Map<String, String> kToolIconAssets = {
  'web_search':                 'globe',
  'read_website':               'globe',
  'search_images':              'image',
  'search_videos':              'video',
  'search_books':               'book',
  'download_image_for_project': 'image',
  'search_market':              'trending_up',
  'get_weather':                'cloud',
  'send_email':                 'mail',
  'generate_chart':             'bar_chart',
  'generate_function_plot':     'bar_chart',
  'generate_math_sheet':        'calculator',
  'generate_mindmap':           'mindmap',
  'generate_qrcode':            'qr_code',
  'generate_barcode':           'barcode',
  'generate_table_image':       'table',
  'create_pdf':                 'pdf',
  'create_docx':                'doc',
  'create_xlsx':                'table',
  'create_pptx':                'stacks',
  'create_file':                'code',
  'read_zip_contents':          'folder_upload',
  'read_pdf_contents':          'pdf',
  'csv_to_xlsx':                'table',
  'xlsx_to_json':               'code',
  'convert_image_format':       'image',
  'resize_image':               'image',
  'crop_image':                 'image',
  'watermark_image':            'image',
  'ocr_extract_text':           'image',
  'str_replace_file':           'pencil',
  'diff_text':                  'code',
  'extract_urls_from_text':     'globe',
  'count_tokens_estimate':      'code',
  'text_summary_stats':         'code',
  'merge_pdfs':                 'pdf',
  'split_pdf_pages':            'pdf',
};

StreamElement openBlockToElement(String raw, OpenBlockInfo info) {
  final canvasOpenMatch = RegExp(r'\[\[canvas:(doc|sheet|slide):').allMatches(raw).toList();
  final widgetOpenMatch = RegExp(r'```(widget_[a-z]+)').allMatches(raw).toList();

  if (canvasOpenMatch.isNotEmpty &&
      (widgetOpenMatch.isEmpty || canvasOpenMatch.last.start > widgetOpenMatch.last.start)) {
    return StreamCanvasBlock(label: info.label, item: null);
  }
  if (widgetOpenMatch.isNotEmpty) {
    return StreamWidgetBlock(label: info.label, block: null);
  }
  return StreamGenericOpenBlock(info.label);
}

OpenBlockInfo? detectOpenBlockInfo(String text) {
  final canvasOpenMatch = RegExp(r'\[\[canvas:(doc|sheet|slide):').allMatches(text).toList();
  if (canvasOpenMatch.isNotEmpty) {
    final last = canvasOpenMatch.last;
    final afterLast = text.substring(last.start);
    final closesAfter = afterLast.contains(']]');
    if (!closesAfter) {
      final kindStr = last.group(1)!;
      final label = switch (kindStr) {
        'sheet' => 'Criando folha de cálculo...',
        'slide' => 'Criando apresentação...',
        _ => 'Criando documento...',
      };
      return OpenBlockInfo(label);
    }
  }

  final widgetOpenMatch = RegExp(r'```(widget_[a-z]+)').allMatches(text).toList();
  if (widgetOpenMatch.isNotEmpty) {
    final last = widgetOpenMatch.last;
    final afterLast = text.substring(last.start);
    final closesAfter = afterLast.contains('```', 3);
    if (!closesAfter) {
      final widgetId = last.group(1)!;
      final label = switch (widgetId) {
        'widget_market' => 'A carregar cotação...',
        'widget_calendar' => 'A criar calendário...',
        'widget_map' => 'A carregar mapa...',
        _ => 'Criando widget...',
      };
      return OpenBlockInfo(label);
    }
  }

  final soundOpenMatch = RegExp(r'\[\[sound_search:').allMatches(text).toList();
  if (soundOpenMatch.isNotEmpty) {
    final last = soundOpenMatch.last;
    final afterLast = text.substring(last.start);
    if (!afterLast.contains(']]')) {
      return const OpenBlockInfo('A pesquisar música...');
    }
  }

  if (endsWithPartialMarker(text)) {
    return const OpenBlockInfo('Criando...');
  }

  return null;
}

const List<String> kPartialMarkerPrefixes = [
  '[[canvas:',
  '[[sound_search:',
  '```widget_market',
  '```widget_calendar',
  '```widget_map',
  '> [!NOTE]',
  '> [!TIP]',
  '> [!IMPORTANT]',
  '> [!WARNING]',
  '> [!CAUTION]',
];

bool endsWithPartialMarker(String text) {
  final tail = text.length > 24 ? text.substring(text.length - 24) : text;
  for (final marker in kPartialMarkerPrefixes) {
    for (int len = marker.length - 1; len >= 1; len--) {
      final prefix = marker.substring(0, len);
      if (tail.endsWith(prefix)) return true;
    }
  }
  return false;
}