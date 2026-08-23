// ══════════════════════════════════════════════════════════════
// FILE: lib/aitab.dart
// ══════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'colors.dart';
import 'widgets.dart';
import 'richtext.dart';
import 'editorscreen.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'aiwidgets.dart';
import 'exportservice.dart';
import 'drawermenu.dart' show conversationsController, ConversationItem, showRenameSheet;
import 'app_sheet.dart';

// ══════════════════════════════════════════════════════════════
// HELPER: mapeia EditorType para nome de asset SVG
// ══════════════════════════════════════════════════════════════
String _iconForEditorType(EditorType type) {
  switch (type) {
    case EditorType.docs:       return 'doc';
    case EditorType.sheets:     return 'table';
    case EditorType.slides:     return 'grid';
    case EditorType.whiteboard: return 'pencil';
  }
}

// ══════════════════════════════════════════════════════════════
// AI MODEL — 3 modelos DeepSeek reais (flash/pro/reasoning)
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
// SYSTEM PROMPT
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

Quando o utilizador pedir para criares, escreveres ou editares um documento
de texto, gera o conteúdo e embrulha-o EXATAMENTE neste formato, no fim da
tua resposta:

[[canvas:doc:Título do documento||<p>conteúdo em html aqui</p>]]

O HTML dentro de um documento "doc" pode conter qualquer elemento que uma
página web normal suporta, não só texto: podes incluir imagens reais através
de <img src="https://url-real-da-imagem.jpg" /> sempre que isso ajudar o
documento (fotografias, diagramas, capas), tabelas HTML, listas, títulos,
citações, e qualquer formatação inline. Usa sempre URLs de imagem reais e
publicamente acessíveis quando incluíres uma imagem — nunca inventes um URL
que não sabes se existe.

Podes aplicar cor ao texto e destaque (highlight/marcador) diretamente no
HTML gerado, usando estilos inline no próprio texto, exatamente como o
editor os interpreta:
- Cor de texto: <span style="color:#HEXCOR">texto colorido</span>
- Destaque/marcador: <span style="background-color:#HEXCOR">texto realçado</span>
Podes combinar ambos no mesmo span quando fizer sentido. Usa cor com intenção —
por exemplo vermelho para avisos, verde para conclusões positivas, amarelo para
destacar pontos importantes — e nunca abuses, só onde realmente ajudar a leitura.

Podes também inserir gráficos dentro do documento, no mesmo bloco html,
usando um elemento especial que a aplicação transforma automaticamente
num gráfico real (Chart.js). Nunca escrevas um <canvas> à mão — usa em vez
disso um marcador neste formato exato dentro do html:

<div data-ai-chart='{"type":"bar","data":{"labels":["A","B"],"datasets":[{"label":"Serie","data":[1,2]}]}}'></div>

O JSON dentro de data-ai-chart segue o formato de configuração nativo do
Chart.js (type, data, options). A aplicação substitui este marcador por um
gráfico interativo real no documento.

Quando o utilizador pedir para criares uma FOLHA DE CÁLCULO, gera o
conteúdo e embrulha-o EXATAMENTE neste formato, no fim da tua resposta:

[[canvas:sheet:Título da folha||<json>]]

O <json> segue este formato exato — um objeto "cells" em que cada chave é
a referência da célula (ex: "A1", "B3") e o valor é um objeto com o
conteúdo e formatação dessa célula:

{"cells":{"A1":{"value":"Produto","bold":true},"B1":{"value":"Preço","bold":true},"A2":{"value":"Café"},"B2":{"value":"3.50"},"A3":{"value":"Chá"},"B3":{"value":"2.80"}}}

Campos aceites em cada célula: "value" (texto ou número, obrigatório),
"bold", "italic", "underline" (booleanos, opcionais), "align" ("left",
"center" ou "right", opcional), "color" (cor do texto em hex, opcional),
"fill" (cor de fundo da célula em hex, opcional). Usa referências de
célula normais (colunas A-Z, linhas numeradas a partir de 1). Gera sempre
JSON válido, sem comentários, sem vírgulas a mais.

Quando o utilizador pedir para criares uma APRESENTAÇÃO ou SLIDES, gera o
conteúdo e embrulha-o EXATAMENTE neste formato, no fim da tua resposta:

[[canvas:slide:Título da apresentação||<json>]]

O <json> segue este formato exato — uma lista de slides, cada um com uma
lista de elementos posicionados (coordenadas em pixels num slide de
960x540):

{"slides":[{"id":0,"elements":[{"id":0,"type":"text","x":80,"y":60,"w":800,"h":100,"fontSize":36,"color":"#1a1a1a","html":"Título da apresentação"},{"id":1,"type":"text","x":80,"y":180,"w":800,"h":300,"fontSize":20,"color":"#444444","html":"Texto de conteúdo do primeiro slide"}]},{"id":1,"elements":[{"id":2,"type":"image","x":100,"y":100,"w":400,"h":260,"src":"https://url-real-da-imagem.jpg"}]}],"currentSlideIndex":0}

Cada elemento tem "type": "text" (com "html", "fontSize", "color"),
"image" (com "src", que deve ser um URL real e publicamente acessível), ou
"shape" (com "shapeKind": "rect" ou "circle", e "color"). Todos os
elementos precisam de "id" (número único crescente dentro da
apresentação), "x", "y", "w", "h" em pixels. Gera sempre JSON válido.

Nunca mostres qualquer bloco [[canvas:...]] ao utilizador como texto
explicado — ele é processado automaticamente pela aplicação e transformado
num cartão de documento navegável, com pré-visualização real e opções de
abrir no editor ou descarregar.

IMPORTANTE: blocos de código normais (```dart, ```python, ```js, ```html,
```css, etc.) NUNCA devem ser embrulhados em [[canvas:...]] — mesmo que sejam
uma página HTML completa, um componente, ou um ficheiro inteiro. Blocos de
código ficam sempre como blocos de código markdown normais, visíveis
diretamente na conversa, exatamente como qualquer outra resposta técnica.
Só documentos (doc), folhas de cálculo (sheet) e apresentações (slide) usam
o formato [[canvas:...]] — nunca código.
''';

const String kAiWidgetsInstructions = '''

Tens também acesso a widgets visuais interativos, que aparecem diretamente
dentro da conversa (nunca em canvas). Quando fizer sentido para a resposta,
gera um bloco de código com uma das seguintes linguagens especiais, contendo
APENAS um objeto JSON válido no corpo do bloco:

- ```widget_market``` — { "type": "crypto", "symbol": "BTC", "name": "Bitcoin" } ou { "type": "forex", "symbol": "USDEUR" }
- ```widget_calendar``` — { "events": [{"date":"2026-08-10","name":"Reunião","time":"14:00","color":"#6F5AF6"}] }
- ```widget_map``` — { "lat": 38.7223, "lng": -9.1393, "zoom": 12, "name": "Lisboa" }

Não uses widget_code — blocos de código normais já aparecem automaticamente
formatados. Não uses widget_sheet — foi descontinuado (usa
[[canvas:sheet:...]] para folhas de cálculo reais). Usa estes widgets
apenas quando acrescentam valor real à resposta (dados quantitativos,
comparações visuais, localização, tempo), nunca como enfeite. Nunca
expliques ao utilizador que estás a gerar um bloco widget — ele é
processado automaticamente e transformado num cartão interativo, sem nunca
mostrar o JSON cru.
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
// TEXT CLEANUP
// ══════════════════════════════════════════════════════════════
String cleanAiText(String raw) {
  var t = raw;
  t = t.replaceAll(RegExp(r'\[\[canvas:[\s\S]*?\]\]'), '');
  return t.trim();
}

// ══════════════════════════════════════════════════════════════
// LOCAL CANVAS
// ══════════════════════════════════════════════════════════════
enum LocalCanvasKind { doc, sheet, slide, whiteboard }

extension LocalCanvasKindX on LocalCanvasKind {
  EditorType get editorType {
    switch (this) {
      case LocalCanvasKind.sheet:      return EditorType.sheets;
      case LocalCanvasKind.slide:      return EditorType.slides;
      case LocalCanvasKind.whiteboard: return EditorType.whiteboard;
      case LocalCanvasKind.doc:        return EditorType.docs;
    }
  }

  String get shortLabel => const {
        LocalCanvasKind.doc:        'Documento',
        LocalCanvasKind.sheet:      'Folha de cálculo',
        LocalCanvasKind.slide:      'Apresentação',
        LocalCanvasKind.whiteboard: 'Quadro branco',
      }[this]!;
}

class LocalCanvasItem {
  final String id;
  final LocalCanvasKind kind;
  final String title;
  final String content;
  const LocalCanvasItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.content,
  });
}

class _CanvasScanResult {
  final String cleanText;
  final List<LocalCanvasItem> items;
  const _CanvasScanResult({required this.cleanText, required this.items});
}

final RegExp _kExplicitCanvasRe = RegExp(
  r'\[\[canvas:(doc|sheet|slide|whiteboard):(.*?)\|\|([\s\S]*?)\]\]',
);

_CanvasScanResult _scanForCanvasItems(String raw, String Function() idGen) {
  final items = <LocalCanvasItem>[];
  final text = raw.replaceAllMapped(_kExplicitCanvasRe, (m) {
    final kindStr = m.group(1)!;
    final title = m.group(2)!.trim();
    final content = m.group(3)!;
    final kind = switch (kindStr) {
      'sheet' => LocalCanvasKind.sheet,
      'slide' => LocalCanvasKind.slide,
      'whiteboard' => LocalCanvasKind.whiteboard,
      _ => LocalCanvasKind.doc,
    };
    items.add(LocalCanvasItem(
      id: idGen(),
      kind: kind,
      title: title.isEmpty ? 'Documento' : title,
      content: content,
    ));
    return '';
  });
  return _CanvasScanResult(cleanText: text.trim(), items: items);
}

// ══════════════════════════════════════════════════════════════
// ATTACHED FILES
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
// CONVERSATION MENU
// ══════════════════════════════════════════════════════════════
enum ConversationAction { newChat, incognito, rename, delete }

extension ConversationActionX on ConversationAction {
  String get assetName => switch (this) {
        ConversationAction.newChat   => 'add',
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

class PopupMenu<T> extends StatefulWidget {
  final AppColorScheme s;
  final Widget anchor;
  final List<PopupMenuEntry<T>> entries;
  final ValueChanged<T> onSelect;
  final double width;
  final double estimatedHeight;

  const PopupMenu({
    super.key,
    required this.s,
    required this.anchor,
    required this.entries,
    required this.onSelect,
    this.width = 240,
    this.estimatedHeight = 200,
  });

  @override
  State<PopupMenu<T>> createState() => PopupMenuState<T>();
}

class PopupMenuEntry<T> {
  final T value;
  final String label;
  final String? subtitle;
  final String assetName;
  final bool selected;
  final bool disabled;
  final bool destructive;
  const PopupMenuEntry({
    required this.value,
    required this.label,
    this.subtitle,
    required this.assetName,
    this.selected = false,
    this.disabled = false,
    this.destructive = false,
  });
}

class PopupMenuState<T> extends State<PopupMenu<T>>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _ov;
  late AnimationController _ac;
  final GlobalKey _anchorBoxKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() { _ac.dispose(); _ov?.remove(); super.dispose(); }

  void toggle() => _ov == null ? open() : close();

  void open() {
    final box = _anchorBoxKey.currentContext!.findRenderObject() as RenderBox;
    final off = box.localToGlobal(Offset.zero);
    final sz  = box.size;
    _ac.forward(from: 0);

    _ov = OverlayEntry(builder: (ctx) {
      final s = widget.s;
      final screenSize = MediaQuery.of(ctx).size;
      final desiredTop = off.dy + sz.height + 6;
      final overflowsBottom = desiredTop + widget.estimatedHeight > screenSize.height - 24;
      final opensUp = overflowsBottom;
      final top = opensUp ? null : desiredTop;
      final bottom = opensUp ? screenSize.height - off.dy + 6 : null;
      final right = (screenSize.width - off.dx - sz.width).clamp(12.0, screenSize.width - widget.width - 12);

      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: close,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          top: top,
          bottom: bottom,
          right: right,
          child: AnimatedBuilder(
            animation: _ac,
            builder: (_, child) => Opacity(
              opacity: CurvedAnimation(
                      parent: _ac,
                      curve: const Interval(0, 0.5, curve: Curves.easeOut))
                  .value,
              child: Transform.scale(
                scale: Tween(begin: 0.92, end: 1.0)
                    .animate(CurvedAnimation(parent: _ac, curve: kCupertinoOut))
                    .value,
                alignment: opensUp ? Alignment.bottomRight : Alignment.topRight,
                child: child,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                width: widget.width,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: s.floatingSurface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: s.floatingShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: widget.entries
                      .map((e) => _PopupRow<T>(
                            s: s,
                            entry: e,
                            onTap: () {
                              if (e.disabled) return;
                              close();
                              widget.onSelect(e.value);
                            },
                          ))
                      .toList(),
                ),
              ),
            ),
          ),
        ),
      ]);
    });
    Overlay.of(context).insert(_ov!);
    setState(() {});
  }

  void close() {
    _ac.reverse().then((_) {
      _ov?.remove();
      _ov = null;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: _anchorBoxKey,
        behavior: HitTestBehavior.opaque,
        onTap: toggle,
        child: IgnorePointer(child: widget.anchor),
      );
}

class _PopupRow<T> extends StatefulWidget {
  final AppColorScheme s;
  final PopupMenuEntry<T> entry;
  final VoidCallback onTap;
  const _PopupRow({required this.s, required this.entry, required this.onTap});
  @override State<_PopupRow<T>> createState() => _PopupRowState<T>();
}

class _PopupRowState<T> extends State<_PopupRow<T>> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final e = widget.entry;
    final color = e.disabled
        ? s.onSurfaceVariant.withOpacity(0.4)
        : e.destructive
            ? s.error
            : e.selected
                ? s.primary
                : s.onSurface;

    return Opacity(
      opacity: e.disabled ? 0.55 : 1.0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown:   e.disabled ? null : (_) => setState(() => _h = true),
        onTapCancel: e.disabled ? null : ()  => setState(() => _h = false),
        onTapUp:     e.disabled ? null : (_) => setState(() => _h = false),
        onTap:       widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _h && !e.disabled
                ? s.hover
                : e.selected
                    ? s.primaryContainer.withOpacity(0.4)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(children: [
            AppIcon(e.assetName, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(e.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: e.selected ? FontWeight.w600 : FontWeight.w400,
                        color: color,
                      )),
                  if (e.subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(e.subtitle!,
                        style: TextStyle(fontSize: 11.5, color: s.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            if (e.selected)
              AppIcon('check', size: 16, color: s.primary),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// AI CONVERSATION MENU BUTTON (popup de três pontos) — AGORA
// ancorado manualmente via RenderBox, sem LayerLink.
// ══════════════════════════════════════════════════════════════
class AiConversationMenuButton extends StatelessWidget {
  final AppColorScheme s;
  final ValueChanged<ConversationAction> onSelect;
  final bool hasMessages;

  const AiConversationMenuButton({
    super.key,
    required this.s,
    required this.onSelect,
    required this.hasMessages,
  });

  @override
  Widget build(BuildContext context) {
    return _HeaderMenuButton(
      s: s,
      hasMessages: hasMessages,
      onSelect: onSelect,
    );
  }
}

class _HeaderMenuButton extends StatefulWidget {
  final AppColorScheme s;
  final bool hasMessages;
  final ValueChanged<ConversationAction> onSelect;

  const _HeaderMenuButton({
    required this.s,
    required this.hasMessages,
    required this.onSelect,
  });

  @override
  State<_HeaderMenuButton> createState() => _HeaderMenuButtonState();
}

class _HeaderMenuButtonState extends State<_HeaderMenuButton>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _ov;
  late AnimationController _ac;
  final GlobalKey _anchorKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
  }

  @override
  void dispose() {
    _ac.dispose();
    _ov?.remove();
    super.dispose();
  }

  void _toggle() => _ov == null ? _open() : _close();

  void _open() {
    final box = _anchorKey.currentContext!.findRenderObject() as RenderBox;
    final off = box.localToGlobal(Offset.zero);
    final sz = box.size;
    _ac.forward(from: 0);

    _ov = OverlayEntry(builder: (ctx) {
      final s = widget.s;
      const width = 260.0;
      const estimatedHeight = 230.0;
      final screenSize = MediaQuery.of(ctx).size;
      final desiredTop = off.dy + sz.height + 6;
      final opensUp = desiredTop + estimatedHeight > screenSize.height - 24;
      final top = opensUp ? null : desiredTop;
      final bottom = opensUp ? screenSize.height - off.dy + 6 : null;
      final right = (screenSize.width - off.dx - sz.width).clamp(12.0, screenSize.width - width - 12);

      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _close,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          top: top,
          bottom: bottom,
          right: right,
          child: AnimatedBuilder(
            animation: _ac,
            builder: (_, child) => Opacity(
              opacity: CurvedAnimation(
                      parent: _ac,
                      curve: const Interval(0, 0.5, curve: Curves.easeOut))
                  .value,
              child: Transform.scale(
                scale: Tween(begin: 0.92, end: 1.0)
                    .animate(CurvedAnimation(parent: _ac, curve: kCupertinoOut))
                    .value,
                alignment: opensUp ? Alignment.bottomRight : Alignment.topRight,
                child: child,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                width: width,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: s.floatingSurface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: s.floatingShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _MenuActionRow(
                      s: s,
                      assetName: ConversationAction.newChat.assetName,
                      label: ConversationAction.newChat.label,
                      onTap: () { _close(); widget.onSelect(ConversationAction.newChat); },
                    ),
                    _MenuActionRow(
                      s: s,
                      assetName: ConversationAction.incognito.assetName,
                      label: ConversationAction.incognito.label,
                      disabled: widget.hasMessages,
                      onTap: () {
                        if (widget.hasMessages) return;
                        _close();
                        widget.onSelect(ConversationAction.incognito);
                      },
                    ),
                    _MenuActionRow(
                      s: s,
                      assetName: ConversationAction.rename.assetName,
                      label: ConversationAction.rename.label,
                      onTap: () { _close(); widget.onSelect(ConversationAction.rename); },
                    ),
                    _MenuActionRow(
                      s: s,
                      assetName: ConversationAction.delete.assetName,
                      label: ConversationAction.delete.label,
                      destructive: true,
                      onTap: () { _close(); widget.onSelect(ConversationAction.delete); },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]);
    });
    Overlay.of(context).insert(_ov!);
    setState(() {});
  }

  void _close() {
    _ac.reverse().then((_) {
      _ov?.remove();
      _ov = null;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        key: _anchorKey,
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: AppIcon(
            'more_vert',
            color: widget.s.onSurface,
            size: 20,
          ),
        ),
      );
}

class _MenuActionRow extends StatefulWidget {
  final AppColorScheme s;
  final String assetName;
  final String label;
  final bool destructive;
  final bool disabled;
  final VoidCallback onTap;
  const _MenuActionRow({
    required this.s,
    required this.assetName,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.disabled = false,
  });
  @override State<_MenuActionRow> createState() => _MenuActionRowState();
}

class _MenuActionRowState extends State<_MenuActionRow> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final color = widget.disabled
        ? widget.s.onSurfaceVariant.withOpacity(0.4)
        : widget.destructive
            ? widget.s.error
            : widget.s.onSurface;
    return Opacity(
      opacity: widget.disabled ? 0.55 : 1.0,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown:   widget.disabled ? null : (_) => setState(() => _h = true),
        onTapCancel: widget.disabled ? null : ()  => setState(() => _h = false),
        onTapUp:     widget.disabled ? null : (_) => setState(() => _h = false),
        onTap:       widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: _h && !widget.disabled ? widget.s.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(children: [
            AppIcon(widget.assetName, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(widget.label,
                  style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w500)),
            ),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SIMPLE CANVAS CARD
// ══════════════════════════════════════════════════════════════
class SimpleCanvasCard extends StatelessWidget {
  final AppColorScheme s;
  final LocalCanvasItem item;
  final VoidCallback onTap;

  const SimpleCanvasCard({
    super.key,
    required this.s,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final s = this.s;
    final item = this.item;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: s.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: s.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.primaryContainer.withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: AppIcon(
                _iconForEditorType(item.kind.editorType),
                size: 20,
                color: s.onSurface,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: s.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.kind.shortLabel,
                    style: TextStyle(
                      fontSize: 12,
                      color: s.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            AppIcon('chevron_forward', color: s.onSurfaceVariant, size: 16),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// STREAM ELEMENTS
// ══════════════════════════════════════════════════════════════
sealed class _StreamElement {}

class _StreamText extends _StreamElement {
  final String text;
  _StreamText(this.text);
}

class _StreamOpenBlock extends _StreamElement {
  final String label;
  final String partialContent;
  _StreamOpenBlock(this.label, this.partialContent);
}

class _StreamClosedCanvas extends _StreamElement {
  final LocalCanvasItem item;
  _StreamClosedCanvas(this.item);
}

class _StreamClosedWidget extends _StreamElement {
  final AiWidgetBlock block;
  _StreamClosedWidget(this.block);
}

class _OpenBlockInfo {
  final String label;
  final String partialContent;
  const _OpenBlockInfo(this.label, this.partialContent);
}

List<_StreamElement> _parseStreamingContent(String raw, String Function() idGen) {
  final elements = <_StreamElement>[];
  final canvasScan = _scanForCanvasItems(raw, idGen);

  var remaining = canvasScan.cleanText;
  final widgetParse = parseAiWidgetBlocks(remaining);
  remaining = widgetParse.textWithMarkers;

  final parts = remaining.split(RegExp(r'\u0000WB(\d+)\u0000'));
  final markerMatches = RegExp(r'\u0000WB(\d+)\u0000').allMatches(remaining).toList();

  for (int i = 0; i < parts.length; i++) {
    if (parts[i].isNotEmpty) {
      elements.add(_StreamText(parts[i]));
    }
    if (i < markerMatches.length) {
      final idx = int.parse(markerMatches[i].group(1)!);
      if (idx < widgetParse.blocks.length) {
        elements.add(_StreamClosedWidget(widgetParse.blocks[idx]));
      }
    }
  }

  for (final item in canvasScan.items) {
    elements.add(_StreamClosedCanvas(item));
  }

  final openInfo = _detectOpenBlockInfo(raw);
  if (openInfo != null) {
    elements.add(_StreamOpenBlock(openInfo.label, openInfo.partialContent));
  }

  return elements;
}

_OpenBlockInfo? _detectOpenBlockInfo(String text) {
  final canvasOpenMatch = RegExp(r'\[\[canvas:(doc|sheet|slide|whiteboard):').allMatches(text).toList();
  if (canvasOpenMatch.isNotEmpty) {
    final last = canvasOpenMatch.last;
    final afterLast = text.substring(last.start);
    final closesAfter = afterLast.contains(']]');
    if (!closesAfter) {
      final kindStr = last.group(1)!;
      final label = switch (kindStr) {
        'sheet' => 'A criar folha de cálculo...',
        'slide' => 'A criar apresentação...',
        'whiteboard' => 'A criar quadro branco...',
        _ => 'A criar documento...',
      };
      final markerEnd = text.indexOf('||', last.start);
      final partial = markerEnd >= 0 ? text.substring(markerEnd + 2) : '';
      return _OpenBlockInfo(label, partial);
    }
  }

  final widgetOpen = RegExp(r'```widget_').allMatches(text).toList();
  if (widgetOpen.isNotEmpty) {
    final last = widgetOpen.last;
    final afterLast = text.substring(last.start);
    final closesAfter = afterLast.contains('```');
    if (!closesAfter) {
      final newlineIdx = text.indexOf('\n', last.start);
      final partial = newlineIdx >= 0 ? text.substring(newlineIdx + 1) : '';
      return _OpenBlockInfo('A criar widget...', partial);
    }
  }

  if (_endsWithPartialMarker(text)) {
    return const _OpenBlockInfo('A criar...', '');
  }

  return null;
}

const List<String> _kPartialMarkerPrefixes = [
  '[[canvas:',
  '```widget_market',
  '```widget_calendar',
  '```widget_map',
  '> [!NOTE]',
  '> [!TIP]',
  '> [!IMPORTANT]',
  '> [!WARNING]',
  '> [!CAUTION]',
];

bool _endsWithPartialMarker(String text) {
  final tail = text.length > 24 ? text.substring(text.length - 24) : text;
  for (final marker in _kPartialMarkerPrefixes) {
    for (int len = marker.length - 1; len >= 1; len--) {
      final prefix = marker.substring(0, len);
      if (tail.endsWith(prefix)) return true;
    }
  }
  return false;
}

// ══════════════════════════════════════════════════════════════
// NEXA LOADER LOGO COM SHIMMER
// ══════════════════════════════════════════════════════════════
class _NexaDotSpec {
  final double left;
  final double top;
  final Color color;
  final double delaySeconds;
  const _NexaDotSpec({
    required this.left,
    required this.top,
    required this.color,
    required this.delaySeconds,
  });
}

final List<_NexaDotSpec> _kNexaDots = [
  _NexaDotSpec(left: 28.21 / 128, top: 55.26 / 128, color: const Color.fromRGBO(88, 148, 247, 1),  delaySeconds: 0.00),
  _NexaDotSpec(left: 42.30 / 128, top: 49.85 / 128, color: const Color.fromRGBO(91, 150, 247, 1),  delaySeconds: 0.07),
  _NexaDotSpec(left: 35.05 / 128, top: 42.55 / 128, color: const Color.fromRGBO(99, 155, 247, 1),  delaySeconds: 0.13),
  _NexaDotSpec(left: 42.45 / 128, top: 35.10 / 128, color: const Color.fromRGBO(112, 164, 248, 1), delaySeconds: 0.20),
  _NexaDotSpec(left: 49.44 / 128, top: 42.51 / 128, color: const Color.fromRGBO(130, 175, 249, 1), delaySeconds: 0.27),
  _NexaDotSpec(left: 55.21 / 128, top: 29.38 / 128, color: const Color.fromRGBO(150, 188, 250, 1), delaySeconds: 0.33),
  _NexaDotSpec(left: 67.36 / 128, top: 29.33 / 128, color: const Color.fromRGBO(171, 201, 251, 1), delaySeconds: 0.40),
  _NexaDotSpec(left: 72.92 / 128, top: 42.55 / 128, color: const Color.fromRGBO(193, 215, 252, 1), delaySeconds: 0.47),
  _NexaDotSpec(left: 79.96 / 128, top: 35.10 / 128, color: const Color.fromRGBO(213, 228, 253, 1), delaySeconds: 0.53),
  _NexaDotSpec(left: 87.37 / 128, top: 42.55 / 128, color: const Color.fromRGBO(230, 239, 253, 1), delaySeconds: 0.60),
  _NexaDotSpec(left: 79.96 / 128, top: 49.85 / 128, color: const Color.fromRGBO(243, 247, 254, 1), delaySeconds: 0.67),
  _NexaDotSpec(left: 94.05 / 128, top: 55.26 / 128, color: const Color.fromRGBO(252, 253, 254, 1), delaySeconds: 0.73),
  _NexaDotSpec(left: 94.05 / 128, top: 67.82 / 128, color: const Color.fromRGBO(255, 255, 255, 1), delaySeconds: 0.80),
  _NexaDotSpec(left: 79.96 / 128, top: 73.53 / 128, color: const Color.fromRGBO(252, 253, 254, 1), delaySeconds: 0.87),
  _NexaDotSpec(left: 87.31 / 128, top: 80.78 / 128, color: const Color.fromRGBO(243, 247, 254, 1), delaySeconds: 0.93),
  _NexaDotSpec(left: 79.96 / 128, top: 88.13 / 128, color: const Color.fromRGBO(230, 239, 253, 1), delaySeconds: 1.00),
  _NexaDotSpec(left: 72.82 / 128, top: 80.78 / 128, color: const Color.fromRGBO(213, 228, 253, 1), delaySeconds: 1.07),
  _NexaDotSpec(left: 67.30 / 128, top: 93.94 / 128, color: const Color.fromRGBO(193, 215, 252, 1), delaySeconds: 1.13),
  _NexaDotSpec(left: 54.95 / 128, top: 93.94 / 128, color: const Color.fromRGBO(171, 201, 251, 1), delaySeconds: 1.20),
  _NexaDotSpec(left: 49.44 / 128, top: 80.78 / 128, color: const Color.fromRGBO(150, 188, 250, 1), delaySeconds: 1.27),
  _NexaDotSpec(left: 42.30 / 128, top: 88.13 / 128, color: const Color.fromRGBO(130, 175, 249, 1), delaySeconds: 1.33),
  _NexaDotSpec(left: 34.95 / 128, top: 80.78 / 128, color: const Color.fromRGBO(112, 164, 248, 1), delaySeconds: 1.40),
  _NexaDotSpec(left: 42.30 / 128, top: 73.53 / 128, color: const Color.fromRGBO(99, 155, 247, 1),  delaySeconds: 1.47),
  _NexaDotSpec(left: 28.21 / 128, top: 67.81 / 128, color: const Color.fromRGBO(91, 150, 247, 1),  delaySeconds: 1.53),
];

class NexaLoaderLogo extends StatefulWidget {
  final double size;
  const NexaLoaderLogo({super.key, this.size = 40});

  @override
  State<NexaLoaderLogo> createState() => _NexaLoaderLogoState();
}

class _NexaLoaderLogoState extends State<NexaLoaderLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final AnimationController _shimmer;

  static const double _cycleSeconds = 1.6;
  static const double _dotFraction = 5.64 / 128;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_cycleSeconds * 1000).round()),
    )..repeat();
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  double _opacityFor(double delaySeconds, double t) {
    final delayFrac = delaySeconds / _cycleSeconds;
    var local = (t - delayFrac) % 1.0;
    if (local < 0) local += 1.0;
    final phase = (local * 2).clamp(0.0, 2.0);
    final eased = phase <= 1.0 ? phase : (2.0 - phase);
    return 0.25 + (0.75 * eased);
  }

  @override
  Widget build(BuildContext context) {
    final dotSize = widget.size * _dotFraction;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_c, _shimmer]),
        builder: (_, __) {
          final shimmerX = (_shimmer.value * 2 - 1) * widget.size * 0.4;
          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.45),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ).createShader(bounds.shift(Offset(shimmerX, 0)));
            },
            blendMode: BlendMode.srcIn,
            child: Stack(
              children: [
                for (final dot in _kNexaDots)
                  Positioned(
                    left: dot.left * widget.size,
                    top: dot.top * widget.size,
                    child: Opacity(
                      opacity: _opacityFor(dot.delaySeconds, _c.value),
                      child: Container(
                        width: dotSize,
                        height: dotSize,
                        decoration: BoxDecoration(
                          color: dot.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// AI TAB
// ══════════════════════════════════════════════════════════════
class AiTab extends StatefulWidget {
  final VoidCallback onFirstMessage;
  final String? initialConversationId;
  final ConversationAction? externalAction;
  final VoidCallback? onExternalActionConsumed;
  final ValueChanged<bool>? onHasMessagesChanged;
  final VoidCallback? onHeaderStateChanged;
  final ValueChanged<LocalCanvasItem>? onCanvasCreated;
  const AiTab({
    super.key,
    required this.onFirstMessage,
    this.initialConversationId,
    this.externalAction,
    this.onExternalActionConsumed,
    this.onHasMessagesChanged,
    this.onHeaderStateChanged,
    this.onCanvasCreated,
  });
  @override State<AiTab> createState() => AiTabState();
}

class AiTabState extends State<AiTab> with ThemeReactive<AiTab> {
  final TextEditingController _ctrl   = TextEditingController();
  final ScrollController       _scroll = ScrollController();
  final List<ChatMessage>      _msgs  = [];
  final List<LocalCanvasItem>  _canvases = [];

  bool     _incognito    = false;
  bool     _sending      = false;
  bool     _widgetsEnabled = true;
  bool     _webSearchEnabled = false;
  bool     _showScrollToBottom = false;
  String   _streamingText = '';
  String?  _streamingThink;
  String?  _conversationId;
  AiModel  _model        = AiModel.deepseekFlash;
  EditorType? _attachedTool;
  int      _canvasIdSeq  = 0;

  final List<AttachedFile> _attachedFiles = [];
  int _attachedFileIdSeq = 0;

  List<AttachedFile> get attachedFiles => List.unmodifiable(_attachedFiles);

  int get canvasCount => _canvases.length;
  bool get widgetsEnabled => _widgetsEnabled;
  bool get webSearchEnabled => _webSearchEnabled;
  String? get conversationId => _conversationId;

  bool get _hasMessages => _msgs.isNotEmpty;

  StreamSubscription<ChatStreamEvent>? _streamSub;

  final FocusNode _inputFocus = FocusNode();
  final GlobalKey _attachButtonKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    if (widget.initialConversationId != null) {
      _loadConversation(widget.initialConversationId!);
    }
  }

  @override
  void didUpdateWidget(covariant AiTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.externalAction != null && widget.externalAction != oldWidget.externalAction) {
      _onConversationAction(widget.externalAction!);
      widget.onExternalActionConsumed?.call();
    }
    if (widget.initialConversationId != null &&
        widget.initialConversationId != oldWidget.initialConversationId &&
        widget.initialConversationId != _conversationId) {
      _loadConversation(widget.initialConversationId!);
    }
  }

  void _onScroll() {
    if (!_scroll.hasClients) return;
    final distanceFromBottom = _scroll.position.maxScrollExtent - _scroll.position.pixels;
    final shouldShow = distanceFromBottom > 240;
    if (shouldShow != _showScrollToBottom) {
      setState(() => _showScrollToBottom = shouldShow);
    }
  }

  void _notifyHeader() => widget.onHeaderStateChanged?.call();

  void setWidgetsEnabled(bool v) {
    setState(() => _widgetsEnabled = v);
    _notifyHeader();
  }

  void setWebSearchEnabled(bool v) {
    setState(() => _webSearchEnabled = v);
    _notifyHeader();
  }

  void openCanvasPopupExternally() => _openCanvasPopup();

  Future<void> _loadConversation(String id) async {
    final token = authController.token;
    if (token == null) return;
    final data = await ConversationsApiService.get(token, id);
    if (!mounted || data == null) return;
    final rawMsgs = data['messages'];
    setState(() {
      _msgs.clear();
      if (rawMsgs is List) {
        _msgs.addAll(rawMsgs.whereType<Map<String, dynamic>>().map(ChatMessage.fromJson));
      }
      _canvases.clear();
      for (final m in _msgs) {
        if (m.role == 'assistant') {
          final scan = _scanForCanvasItems(m.content, _nextCanvasId);
          _canvases.addAll(scan.items);
        }
      }
      _conversationId = id;
      _incognito = false;
      _sending = false;
      _streamingText = '';
      _streamingThink = null;
      _attachedFiles.clear();
    });
    if (_msgs.isNotEmpty) widget.onFirstMessage();
    widget.onHasMessagesChanged?.call(_hasMessages);
    _notifyHeader();
    _scrollToEnd();
  }

  String _nextCanvasId() => 'cv_${DateTime.now().millisecondsSinceEpoch}_${_canvasIdSeq++}';
  String _nextAttachedFileId() => 'af_${DateTime.now().millisecondsSinceEpoch}_${_attachedFileIdSeq++}';

  String get _effectiveSystemPrompt {
    var prompt = kAiSystemPrompt;
    if (_widgetsEnabled) prompt += kAiWidgetsInstructions;
    if (_webSearchEnabled) prompt += kAiWebSearchInstructions;
    return prompt;
  }

  void sendSuggestedMessage(String text) {
    if (text.trim().isEmpty || _sending) return;
    _ctrl.text = text;
    _send();
  }

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if ((t.isEmpty && _attachedFiles.isEmpty) || _sending) return;
    final isFirst = _msgs.isEmpty;

    final pendingAttachments = List<AttachedFile>.from(_attachedFiles);
    final imageAttachments = pendingAttachments.where((f) => f.mimeType.startsWith('image/')).toList();

    var effectiveContent = t;
    if (imageAttachments.isNotEmpty) {
      final names = imageAttachments.map((f) => f.name).join(', ');
      final note = '[Nota: o utilizador anexou ${imageAttachments.length == 1 ? 'a imagem' : 'as imagens'} '
          '"$names", mas não é possível analisar imagens neste momento. '
          'Informa isso ao utilizador em vez de descrever ou assumir o conteúdo da imagem.]';
      effectiveContent = effectiveContent.isEmpty ? note : '$effectiveContent\n\n$note';
    }

    final userMsg = ChatMessage(
      role: 'user',
      content: effectiveContent,
      attachments: pendingAttachments.isEmpty
          ? null
          : pendingAttachments
              .map((f) => {
                    'name': f.name,
                    'mimeType': f.mimeType,
                    'base64': f.base64Data,
                  })
              .toList(),
    );

    setState(() {
      _msgs.add(userMsg);
      _ctrl.clear();
      _attachedTool = null;
      _attachedFiles.clear();
      _sending = true;
      _streamingText = '';
      _streamingThink = null;
    });
    if (isFirst) {
      widget.onFirstMessage();
      widget.onHasMessagesChanged?.call(true);
    }
    _scrollToEnd();

    final token = authController.token;
    if (token == null) {
      setState(() {
        _sending = false;
        _msgs.add(const ChatMessage(
            role: 'assistant', content: 'Sessão expirada. Volta a iniciar sessão.'));
      });
      return;
    }

    _streamSub?.cancel();
    _streamSub = AiApiService.streamChat(
      token: token,
      messages: _msgs,
      provider: _model.provider,
      language: 'pt',
      systemPrompt: _effectiveSystemPrompt,
    ).listen(
      (event) {
        if (!mounted) return;
        switch (event) {
          case ChatTokenEvent(text: final text):
            setState(() {
              _streamingText += text;
            });
            _scrollToEnd();
            break;
          case ChatThinkEvent(text: final text):
            setState(() => _streamingThink = (_streamingThink ?? '') + text);
            break;
          case ChatDoneEvent(fullText: final fullText):
            final finalText = fullText.isNotEmpty ? fullText : _streamingText;
            final scan = _scanForCanvasItems(finalText, _nextCanvasId);
            setState(() {
              if (scan.cleanText.trim().isNotEmpty || scan.items.isNotEmpty) {
                _msgs.add(ChatMessage(role: 'assistant', content: finalText));
              }
              _canvases.addAll(scan.items);
              _sending = false;
              _streamingText = '';
              _streamingThink = null;
            });
            _notifyHeader();
            _scrollToEnd();
            if (isFirst && _conversationId == null && !_incognito) {
              _createConversationWithGeneratedTitle(t);
            } else {
              _persistConversation();
            }
            if (scan.items.isNotEmpty) {
              widget.onCanvasCreated?.call(scan.items.last);
            }
            break;
          case ChatErrorEvent(message: final message):
            setState(() {
              _sending = false;
              _streamingText = '';
              _streamingThink = null;
              _msgs.add(ChatMessage(role: 'assistant', content: 'Erro: $message'));
            });
            _scrollToEnd();
            break;
          case ChatCreditsExhaustedEvent():
            setState(() {
              _sending = false;
              _streamingText = '';
              _streamingThink = null;
              _msgs.add(const ChatMessage(
                  role: 'assistant',
                  content: 'Sem créditos disponíveis. Recarrega para continuar a conversar.'));
            });
            _scrollToEnd();
            authController.refreshBalance();
            break;
        }
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _sending = false;
          _streamingText = '';
          _streamingThink = null;
          _msgs.add(ChatMessage(role: 'assistant', content: 'Erro de rede: $e'));
        });
        _scrollToEnd();
      },
    );
  }

  void _pauseGeneration() {
    if (!_sending) return;
    _streamSub?.cancel();
    _streamSub = null;
    final partial = _streamingText;
    setState(() {
      if (partial.trim().isNotEmpty) {
        _msgs.add(ChatMessage(role: 'assistant', content: partial));
      }
      _sending = false;
      _streamingText = '';
      _streamingThink = null;
    });
    _notifyHeader();
    _persistConversation();
  }

  Future<void> _createConversationWithGeneratedTitle(String firstMessage) async {
    final token = authController.token;
    if (token == null) return;
    if (_conversationId != null) return;
    final title = await AiApiService.generateTitle(token, firstMessage);
    if (!mounted) return;
    if (_incognito || _conversationId != null) return;
    final created = await ConversationsApiService.create(
      token,
      title: title,
      messages: _msgs,
    );
    if (created != null && created['id'] != null) {
      _conversationId = created['id'].toString();
      conversationsController.upsertLocal(ConversationItem.fromJson(created));
      _notifyHeader();
    }
  }

  Future<void> _persistConversation() async {
    if (_incognito) return;
    final token = authController.token;
    if (token == null) return;
    if (_conversationId == null) {
      final created = await ConversationsApiService.create(
        token,
        title: 'Nova conversa',
        messages: _msgs,
      );
      if (created != null && created['id'] != null) {
        _conversationId = created['id'].toString();
        conversationsController.upsertLocal(ConversationItem.fromJson(created));
      }
    } else {
      await ConversationsApiService.update(token, _conversationId!,
          messages: _msgs);
      final existing = conversationsController.items
          .where((c) => c.id == _conversationId)
          .toList();
      conversationsController.upsertLocal(ConversationItem(
        id: _conversationId!,
        title: existing.isNotEmpty ? existing.first.title : 'Nova conversa',
        preview: _msgs.isNotEmpty ? _msgs.last.content : '',
        pinned: existing.isNotEmpty ? existing.first.pinned : false,
        archived: existing.isNotEmpty ? existing.first.archived : false,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  void _scrollToEnd({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        if (animated) {
          _scroll.animateTo(_scroll.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300), curve: kCupertinoOut);
        } else {
          _scroll.jumpTo(_scroll.position.maxScrollExtent);
        }
      }
    });
  }

  void _onModelSelected(AiModel model) {
    setState(() => _model = model);
  }

  void _onAttachFiles() async {
    final result = await FilePicker.pickFiles(allowMultiple: true, withData: true);
    if (result == null || result.files.isEmpty) return;
    final newFiles = <AttachedFile>[];
    for (final f in result.files) {
      final bytes = f.bytes;
      if (bytes == null) continue;
      newFiles.add(AttachedFile(
        id: _nextAttachedFileId(),
        name: f.name,
        mimeType: _guessMimeType(f.name, f.extension),
        bytes: bytes,
      ));
    }
    if (newFiles.isEmpty) return;
    setState(() => _attachedFiles.addAll(newFiles));
  }

  void _onAttachPhotos() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _attachedFiles.add(AttachedFile(
          id: _nextAttachedFileId(),
          name: picked.name,
          mimeType: picked.mimeType ?? _guessMimeType(picked.name, null),
          bytes: bytes,
        )));
  }

  void _onOpenCamera() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.camera);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _attachedFiles.add(AttachedFile(
          id: _nextAttachedFileId(),
          name: picked.name,
          mimeType: picked.mimeType ?? _guessMimeType(picked.name, null),
          bytes: bytes,
        )));
  }

  String _guessMimeType(String name, String? extension) {
    final ext = (extension ?? name.split('.').last).toLowerCase();
    const map = {
      'png': 'image/png', 'jpg': 'image/jpeg', 'jpeg': 'image/jpeg',
      'gif': 'image/gif', 'webp': 'image/webp',
      'pdf': 'application/pdf',
      'txt': 'text/plain', 'md': 'text/markdown',
      'csv': 'text/csv', 'json': 'application/json',
      'doc': 'application/msword',
      'docx': 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'xls': 'application/vnd.ms-excel',
      'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    };
    return map[ext] ?? 'application/octet-stream';
  }

  void _onRemoveAttachedFile(String id) {
    setState(() => _attachedFiles.removeWhere((f) => f.id == id));
  }

  void _openAttachedFilesSheet() {
    showAttachedFilesSheet(
      context,
      AppTheme.of(context),
      files: _attachedFiles,
      onRemove: _onRemoveAttachedFile,
    );
  }

  void _onToolSelected(EditorType t) => setState(() => _attachedTool = t);
  void _onClearTool() => setState(() => _attachedTool = null);

  void _openAttachSheet() {
    showAttachPopup(
      context,
      AppTheme.of(context),
      anchorKey: _attachButtonKey,
      onFiles: _onAttachFiles,
      onPhotos: _onAttachPhotos,
      onCamera: _onOpenCamera,
      onSelectTool: _onToolSelected,
    );
  }

  void _openVoiceSheet() {
    showVoiceRecordSheet(
      context,
      AppTheme.of(context),
      onTranscribed: (text) {
        setState(() {
          _ctrl.text = text;
          _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
        });
      },
    );
  }

  void _openCanvasPopup() {
    showCanvasSheet(
      context,
      AppTheme.of(context),
      canvases: _canvases,
      onOpenCanvas: _onOpenCanvas,
    );
  }

  void _openAiOptionsSheet() {
    showAiOptionsSheet(
      context,
      AppTheme.of(context),
      currentModel: _model,
      webSearchEnabled: _webSearchEnabled,
      widgetsEnabled: _widgetsEnabled,
      onModelSelected: _onModelSelected,
      onWebSearchChanged: setWebSearchEnabled,
      onWidgetsChanged: setWidgetsEnabled,
      onOpenCanvas: _openCanvasPopup,
    );
  }

  void _onOpenCanvas(LocalCanvasItem item) {
    editTabController.requestLoadLocal(item);
    AiTabHostNavigation.of(context)?.goToEditTab(item.kind.editorType);
  }

  void _onConversationAction(ConversationAction action) {
    switch (action) {
      case ConversationAction.newChat:
        _streamSub?.cancel();
        setState(() {
          _msgs.clear();
          _canvases.clear();
          _incognito = false;
          _sending = false;
          _streamingText = '';
          _streamingThink = null;
          _conversationId = null;
          _attachedFiles.clear();
        });
        widget.onHasMessagesChanged?.call(false);
        _notifyHeader();
        break;
      case ConversationAction.incognito:
        if (_hasMessages) return;
        _streamSub?.cancel();
        setState(() {
          _msgs.clear();
          _canvases.clear();
          _incognito = true;
          _sending = false;
          _streamingText = '';
          _streamingThink = null;
          _conversationId = null;
          _attachedFiles.clear();
        });
        widget.onHasMessagesChanged?.call(false);
        _notifyHeader();
        break;
      case ConversationAction.rename:
        if (_conversationId == null) return;
        showRenameSheet(
          context,
          AppTheme.of(context),
          currentTitle: conversationsController.items
                  .where((c) => c.id == _conversationId)
                  .map((c) => c.title)
                  .firstOrNull ??
              '',
          onConfirm: (newTitle) {
            conversationsController.rename(_conversationId!, newTitle);
          },
        );
        break;
      case ConversationAction.delete:
        if (_conversationId != null) {
          final token = authController.token;
          if (token != null) ConversationsApiService.delete(token, _conversationId!);
        }
        _streamSub?.cancel();
        setState(() {
          _msgs.clear();
          _canvases.clear();
          _incognito = false;
          _sending = false;
          _streamingText = '';
          _streamingThink = null;
          _conversationId = null;
          _attachedFiles.clear();
        });
        widget.onHasMessagesChanged?.call(false);
        _notifyHeader();
        break;
    }
  }

  void _onBubbleEdit(int index) {
    final msg = _msgs[index];
    if (msg.role != 'user') return;
    setState(() {
      _ctrl.text = msg.content;
      _ctrl.selection = TextSelection.collapsed(offset: _ctrl.text.length);
      _msgs.removeRange(index, _msgs.length);
    });
  }

  void _onBubbleCopy(int index) {
    final msg = _msgs[index];
    Clipboard.setData(ClipboardData(text: msg.content));
  }

  void _onBubbleDelete(int index) {
    setState(() => _msgs.removeAt(index));
    _persistConversation();
  }

  void _onBubbleSelectText(int index) {
    showSelectTextSheet(context, AppTheme.of(context), text: _msgs[index].content);
  }

  void _onAssistantThumbUp(int index) {}
  void _onAssistantThumbDown(int index) {}

  void _onAssistantCopy(int index) {
    final msg = _msgs[index];
    Clipboard.setData(ClipboardData(text: msg.content));
  }

  void _onAssistantRefresh(int index) {
    if (_sending) return;
    int userIdx = index - 1;
    while (userIdx >= 0 && _msgs[userIdx].role != 'user') {
      userIdx--;
    }
    if (userIdx < 0) return;
    final userText = _msgs[userIdx].content;
    setState(() {
      _msgs.removeRange(userIdx, _msgs.length);
      _ctrl.text = userText;
    });
    _send();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _ctrl.dispose();
    _scroll.dispose();
    _inputFocus.dispose();
    _streamSub?.cancel();
    super.dispose();
  }

  List<LocalCanvasItem> _canvasesForMessage(String rawContent) {
    final scan = _scanForCanvasItems(rawContent, () => '');
    if (scan.items.isEmpty) return const [];
    final matched = <LocalCanvasItem>[];
    for (final local in scan.items) {
      final found = _canvases.firstWhere(
        (c) => c.kind == local.kind && c.title == local.title && c.content == local.content,
        orElse: () => local,
      );
      matched.add(found);
    }
    return matched;
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    final headerHeight = topInset + 6 + 40 + 12;
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    final baseCount = _msgs.length + (_sending ? 1 : 0);
    final showDisclaimer = _msgs.isNotEmpty || _sending;
    final totalCount = baseCount + (showDisclaimer ? 1 : 0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        color: s.pageBackground,
        child: Column(children: [
          Expanded(
            child: Stack(children: [
              _incognito
                  ? const _IncognitoState()
                  : (_msgs.isEmpty && _streamingText.isEmpty)
                      ? _EmptyState(s: s, topPadding: headerHeight)
                      : ListView.builder(
                          controller: _scroll,
                          padding: EdgeInsets.fromLTRB(16, headerHeight, 16, 8),
                          itemCount: totalCount,
                          itemBuilder: (_, i) {
                            if (showDisclaimer && i == totalCount - 1) {
                              return const _DisclaimerFooter();
                            }
                            if (i >= _msgs.length) {
                              final elements = _parseStreamingContent(_streamingText, _nextCanvasId);
                              final isThinkingOnly = _streamingText.isEmpty && (_streamingThink == null || _streamingThink!.isEmpty);
                              return _StreamingBubble(
                                s: s,
                                elements: elements,
                                thinking: _streamingThink != null
                                    ? cleanAiText(_streamingThink!)
                                    : null,
                                showLogoLoader: isThinkingOnly,
                                widgetsEnabled: _widgetsEnabled,
                                onEnableWidgets: () => setWidgetsEnabled(true),
                                onSuggestionTap: sendSuggestedMessage,
                                onOpenCanvas: _onOpenCanvas,
                              );
                            }
                            final msg = _msgs[i];
                            if (msg.role == 'user') {
                              return _Bubble(
                                s: s,
                                text: msg.content,
                                onEdit: () => _onBubbleEdit(i),
                                onCopy: () => _onBubbleCopy(i),
                                onDelete: () => _onBubbleDelete(i),
                                onSelectText: () => _onBubbleSelectText(i),
                              );
                            }
                            final scan = _scanForCanvasItems(msg.content, () => '');
                            final msgCanvases = _canvasesForMessage(msg.content);
                            return _AssistantBubble(
                              s: s,
                              text: cleanAiText(scan.cleanText),
                              canvases: msgCanvases,
                              onOpenCanvas: _onOpenCanvas,
                              onThumbUp: () => _onAssistantThumbUp(i),
                              onThumbDown: () => _onAssistantThumbDown(i),
                              onCopy: () => _onAssistantCopy(i),
                              onRefresh: () => _onAssistantRefresh(i),
                              widgetsEnabled: _widgetsEnabled,
                              onEnableWidgets: () => setWidgetsEnabled(true),
                              onSuggestionTap: sendSuggestedMessage,
                            );
                          },
                        ),
              if (!_incognito && (_msgs.isNotEmpty || _streamingText.isNotEmpty))
                Positioned(
                  left: 0, right: 0,
                  bottom: 8,
                  child: Center(
                    child: AnimatedOpacity(
                      opacity: _showScrollToBottom ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      child: IgnorePointer(
                        ignoring: !_showScrollToBottom,
                        child: _ScrollToBottomButton(
                          s: s,
                          onTap: () => _scrollToEnd(),
                        ),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          // ── Wrapper do bottombar com gradiente progressivo ──
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  s.pageBackground.withOpacity(0.0),
                  s.pageBackground,
                ],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ChatInput(
                    s: s,
                    ctrl: _ctrl,
                    focusNode: _inputFocus,
                    attachedTool: _attachedTool,
                    attachedFilesCount: _attachedFiles.length,
                    incognito: _incognito,
                    sending: _sending,
                    attachButtonKey: _attachButtonKey,
                    onSend: _send,
                    onPause: _pauseGeneration,
                    onAttach: _openAttachSheet,
                    onVoice: _openVoiceSheet,
                    onOpenAiOptions: _openAiOptionsSheet,
                    onClearTool: _onClearTool,
                    onOpenAttachedFiles: _openAttachedFilesSheet,
                  ),
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: kCupertinoOut,
                    height: keyboardInset > 0 ? keyboardInset + 8 : MediaQuery.of(context).padding.bottom + 8,
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class AiTabHostNavigation extends InheritedWidget {
  final void Function(EditorType type) goToEditTab;
  const AiTabHostNavigation({
    super.key,
    required this.goToEditTab,
    required super.child,
  });

  static AiTabHostNavigation? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AiTabHostNavigation>();

  @override
  bool updateShouldNotify(AiTabHostNavigation oldWidget) => true;
}

class _IncognitoState extends StatelessWidget {
  const _IncognitoState();

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Center(
      child: AppIcon(
        'incognito',
        color: s.onSurface,
        size: 72,
      ),
    );
  }
}

// ── Rodapé fixo de aviso — alinhado à direita ──────────────────

class _DisclaimerFooter extends StatelessWidget {
  const _DisclaimerFooter();

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Align(
        alignment: Alignment.centerRight,
        child: Text(
          'O DeepSeek é uma IA e pode cometer erros.',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontSize: 10.5,
            color: s.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

// ── Botão circular flutuante de "ir para o fim" ─────────────────

class _ScrollToBottomButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _ScrollToBottomButton({required this.s, required this.onTap});
  @override State<_ScrollToBottomButton> createState() => _ScrollToBottomButtonState();
}

class _ScrollToBottomButtonState extends State<_ScrollToBottomButton> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _p = true),
      onTapCancel: ()  => setState(() => _p = false),
      onTapUp:     (_) => setState(() => _p = false),
      onTap:       widget.onTap,
      child: AnimatedScale(
        scale: _p ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: kCupertinoOut,
        child: Container(
          width: 38, height: 38,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: s.cardBackground,
            shape: BoxShape.circle,
            boxShadow: s.floatingShadow,
          ),
          child: AppIcon('double_arrow_down', color: s.onSurface, size: 18),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final AppColorScheme s;
  final double topPadding;
  const _EmptyState({required this.s, required this.topPadding});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const NexaLoaderLogo(size: 56),
                const SizedBox(height: 14),
                Text(
                  'Olá, o que vamos criar hoje?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: s.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _Bubble extends StatefulWidget {
  final AppColorScheme s;
  final String text;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final VoidCallback onSelectText;
  const _Bubble({
    required this.s,
    required this.text,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
    required this.onSelectText,
  });
  @override State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale, _op;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 280));
    _scale = Tween(begin: 0.92, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: kCupertinoOut));
    _op = Tween(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _c,
            curve: const Interval(0, 0.5, curve: Curves.easeOut)));
    _c.forward();
  }

  @override void dispose() { _c.dispose(); super.dispose(); }

  void _onLongPress() {
    final box = context.findRenderObject() as RenderBox;
    final off = box.localToGlobal(Offset.zero);
    final sz = box.size;
    showMessageActionsPopup(
      context,
      widget.s,
      anchorOffset: off,
      anchorSize: sz,
      onEdit: widget.onEdit,
      onCopy: widget.onCopy,
      onDelete: widget.onDelete,
      onSelectText: widget.onSelectText,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bubbleColor = widget.s.isDark
        ? widget.s.primaryContainer
        : const Color(0xFFD7E7FE);
    final textColor = widget.s.isDark
        ? widget.s.onPrimaryContainer
        : const Color(0xFF0A3B72);

    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Opacity(
        opacity: _op.value.clamp(0.0, 1.0),
        child: Transform.scale(
            scale: _scale.value, alignment: Alignment.centerRight, child: child),
      ),
      child: Align(
        alignment: Alignment.centerRight,
        child: GestureDetector(
          onLongPress: _onLongPress,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: bubbleColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: widget.s.cardShadow,
            ),
            child: Text(widget.text,
                style: TextStyle(color: textColor, fontSize: 14)),
          ),
        ),
      ),
    );
  }
}

class _AssistantBubble extends StatelessWidget {
  final AppColorScheme s;
  final String text;
  final List<LocalCanvasItem> canvases;
  final ValueChanged<LocalCanvasItem> onOpenCanvas;
  final VoidCallback onThumbUp;
  final VoidCallback onThumbDown;
  final VoidCallback onCopy;
  final VoidCallback onRefresh;
  final bool widgetsEnabled;
  final VoidCallback onEnableWidgets;
  final ValueChanged<String> onSuggestionTap;
  const _AssistantBubble({
    required this.s,
    required this.text,
    required this.canvases,
    required this.onOpenCanvas,
    required this.onThumbUp,
    required this.onThumbDown,
    required this.onCopy,
    required this.onRefresh,
    required this.widgetsEnabled,
    required this.onEnableWidgets,
    required this.onSuggestionTap,
  });

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 18),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.92),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (text.isNotEmpty)
                RichAiText(
                  text: text,
                  s: s,
                  widgetsEnabled: widgetsEnabled,
                  onEnableWidgets: onEnableWidgets,
                  onSuggestionTap: onSuggestionTap,
                ),
              for (final item in canvases) ...[
                const SizedBox(height: 8),
                SimpleCanvasCard(s: s, item: item, onTap: () => onOpenCanvas(item)),
              ],
              const SizedBox(height: 6),
              _AssistantActionBar(
                s: s,
                onThumbUp: onThumbUp,
                onThumbDown: onThumbDown,
                onCopy: onCopy,
                onRefresh: onRefresh,
              ),
            ],
          ),
        ),
      );
}

class _AssistantActionBar extends StatelessWidget {
  final AppColorScheme s;
  final VoidCallback onThumbUp;
  final VoidCallback onThumbDown;
  final VoidCallback onCopy;
  final VoidCallback onRefresh;
  const _AssistantActionBar({
    required this.s,
    required this.onThumbUp,
    required this.onThumbDown,
    required this.onCopy,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _AssistantActionIcon(s: s, assetName: 'thumbs_up', onTap: onThumbUp),
          const SizedBox(width: 4),
          _AssistantActionIcon(s: s, assetName: 'thumbs_down', onTap: onThumbDown),
          const SizedBox(width: 4),
          _AssistantActionIcon(s: s, assetName: 'copy', onTap: onCopy),
          const SizedBox(width: 4),
          _AssistantActionIcon(s: s, assetName: 'refresh', onTap: onRefresh),
        ],
      );
}

class _AssistantActionIcon extends StatefulWidget {
  final AppColorScheme s;
  final String assetName;
  final VoidCallback onTap;
  const _AssistantActionIcon({
    required this.s,
    required this.assetName,
    required this.onTap,
  });
  @override State<_AssistantActionIcon> createState() => _AssistantActionIconState();
}

class _AssistantActionIconState extends State<_AssistantActionIcon> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _h = true),
      onTapCancel: ()  => setState(() => _h = false),
      onTapUp:     (_) => setState(() => _h = false),
      onTap:       widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 28, height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _h ? s.hover : Colors.transparent,
          shape: BoxShape.circle,
        ),
        child: AppIcon(
          widget.assetName,
          color: s.onSurfaceVariant,
          size: 16,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// STREAMING BUBBLE — AGORA COM PENSAMENTO COLAPSÁVEL
// ══════════════════════════════════════════════════════════════
class _StreamingBubble extends StatefulWidget {
  final AppColorScheme s;
  final List<_StreamElement> elements;
  final String? thinking;
  final bool showLogoLoader;
  final bool widgetsEnabled;
  final VoidCallback onEnableWidgets;
  final ValueChanged<String> onSuggestionTap;
  final ValueChanged<LocalCanvasItem> onOpenCanvas;
  const _StreamingBubble({
    required this.s,
    required this.elements,
    this.thinking,
    this.showLogoLoader = false,
    required this.widgetsEnabled,
    required this.onEnableWidgets,
    required this.onSuggestionTap,
    required this.onOpenCanvas,
  });

  @override
  State<_StreamingBubble> createState() => _StreamingBubbleState();
}

class _StreamingBubbleState extends State<_StreamingBubble> {
  bool _thinkingExpanded = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final thinking = widget.thinking;
    final children = <Widget>[];

    if (thinking != null && thinking.isNotEmpty) {
      children.add(_ThinkingCollapsible(
        s: s,
        thinking: thinking,
        expanded: _thinkingExpanded,
        onToggle: () => setState(() => _thinkingExpanded = !_thinkingExpanded),
      ));
    }

    bool anyContent = false;
    for (final el in widget.elements) {
      switch (el) {
        case _StreamText(:final text):
          final cleaned = cleanAiText(text);
          if (cleaned.trim().isEmpty) continue;
          anyContent = true;
          children.add(RichAiText(
            text: cleaned,
            s: s,
            widgetsEnabled: widget.widgetsEnabled,
            onEnableWidgets: widget.onEnableWidgets,
            onSuggestionTap: widget.onSuggestionTap,
          ));
        case _StreamOpenBlock(:final label, :final partialContent):
          anyContent = true;
          children.add(_StreamingMarkdownCard(
            s: s,
            label: label,
            partialContent: partialContent,
            widgetsEnabled: widget.widgetsEnabled,
            onEnableWidgets: widget.onEnableWidgets,
            onSuggestionTap: widget.onSuggestionTap,
          ));
        case _StreamClosedCanvas(:final item):
          anyContent = true;
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: SimpleCanvasCard(s: s, item: item, onTap: () => widget.onOpenCanvas(item)),
          ));
        case _StreamClosedWidget(:final block):
          anyContent = true;
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: buildAiWidget(block, s),
          ));
      }
    }

    if (!anyContent && thinking == null) {
      children.add(widget.showLogoLoader
          ? const NexaLoaderLogo(size: 28)
          : AiSmallDotsLoader(color: s.onSurfaceVariant));
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.92),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      ),
    );
  }
}

// ── Componente de pensamento colapsável ────────────────────────

class _ThinkingCollapsible extends StatelessWidget {
  final AppColorScheme s;
  final String thinking;
  final bool expanded;
  final VoidCallback onToggle;
  const _ThinkingCollapsible({
    required this.s,
    required this.thinking,
    required this.expanded,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: s.hover.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  const NexaLoaderLogo(size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pensando...',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: s.onSurfaceVariant,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: AppIcon('chevron_down', size: 14, color: s.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
              child: RichAiText(
                text: thinking,
                s: s,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// STREAMING MARKDOWN CARD
// ══════════════════════════════════════════════════════════════
class _StreamingMarkdownCard extends StatefulWidget {
  final AppColorScheme s;
  final String label;
  final String partialContent;
  final bool widgetsEnabled;
  final VoidCallback onEnableWidgets;
  final ValueChanged<String> onSuggestionTap;

  const _StreamingMarkdownCard({
    super.key,
    required this.s,
    required this.label,
    required this.partialContent,
    required this.widgetsEnabled,
    required this.onEnableWidgets,
    required this.onSuggestionTap,
  });

  @override
  State<_StreamingMarkdownCard> createState() => _StreamingMarkdownCardState();
}

class _StreamingMarkdownCardState extends State<_StreamingMarkdownCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final content = widget.partialContent.trim();

    if (content.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            AiSmallDotsLoader(color: s.onSurfaceVariant),
            const SizedBox(width: 8),
            Text(
              widget.label,
              style: TextStyle(fontSize: 12.5, color: s.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: s.hover.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                AiSmallDotsLoader(color: s.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: s.onSurfaceVariant,
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: AppIcon(
                    'chevron_down',
                    size: 14,
                    color: s.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            crossFadeState: _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: RichAiText(
                text: content,
                s: s,
                widgetsEnabled: widget.widgetsEnabled,
                onEnableWidgets: widget.onEnableWidgets,
                onSuggestionTap: widget.onSuggestionTap,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BLINKING GRID LOADER
// ══════════════════════════════════════════════════════════════
class BlinkingGridLoader extends StatefulWidget {
  final Color color;
  final double dotSize;
  final double gap;
  const BlinkingGridLoader({
    super.key,
    required this.color,
    this.dotSize = 7,
    this.gap = 5,
  });

  @override
  State<BlinkingGridLoader> createState() => _BlinkingGridLoaderState();
}

class _BlinkingGridLoaderState extends State<BlinkingGridLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  static const int _cols = 3;
  static const int _rows = 3;
  static const double _cycleMs = 1200;
  static const double _stepDelayMs = 100;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _cycleMs.round()),
    )..repeat();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  double _opacityFor(int index, double t) {
    final delay = (index * _stepDelayMs) / _cycleMs;
    var local = (t - delay) % 1.0;
    if (local < 0) local += 1.0;
    final phase = (local * 2).clamp(0.0, 2.0);
    final eased = phase <= 1.0 ? phase : (2.0 - phase);
    return 0.15 + (0.85 * eased);
  }

  @override
  Widget build(BuildContext context) {
    final size = _cols * widget.dotSize + (_cols - 1) * widget.gap;
    return SizedBox(
      width: size,
      height: _rows * widget.dotSize + (_rows - 1) * widget.gap,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Column(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_rows, (r) => Padding(
            padding: EdgeInsets.only(bottom: r == _rows - 1 ? 0 : widget.gap),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_cols, (c) {
                final index = r * _cols + c;
                return Padding(
                  padding: EdgeInsets.only(right: c == _cols - 1 ? 0 : widget.gap),
                  child: Opacity(
                    opacity: _opacityFor(index, _c.value),
                    child: Container(
                      width: widget.dotSize,
                      height: widget.dotSize,
                      decoration: BoxDecoration(
                        color: widget.color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                );
              }),
            ),
          )),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MESSAGE ACTIONS POPUP
// ══════════════════════════════════════════════════════════════
void showMessageActionsPopup(
  BuildContext context,
  AppColorScheme s, {
  required Offset anchorOffset,
  required Size anchorSize,
  required VoidCallback onEdit,
  required VoidCallback onCopy,
  required VoidCallback onDelete,
  required VoidCallback onSelectText,
}) {
  final screenSize = MediaQuery.of(context).size;
  late OverlayEntry entry;
  final controller = AnimationController(
    vsync: Navigator.of(context),
    duration: const Duration(milliseconds: 180),
  );

  void close() {
    controller.reverse().then((_) {
      entry.remove();
      controller.dispose();
    });
  }

  entry = OverlayEntry(builder: (ctx) {
    const menuHeight = 216.0;
    final desiredTop = anchorOffset.dy - 6 - menuHeight;
    final opensUp = desiredTop >= 40;
    final top = opensUp ? desiredTop : anchorOffset.dy + anchorSize.height + 6;
    final right = (screenSize.width - anchorOffset.dx - anchorSize.width).clamp(12.0, screenSize.width - 244);

    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          onTap: close,
          behavior: HitTestBehavior.opaque,
          child: Container(color: Colors.transparent),
        ),
      ),
      Positioned(
        top: top,
        right: right,
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, child) => Opacity(
            opacity: CurvedAnimation(
                    parent: controller, curve: const Interval(0, 0.6, curve: Curves.easeOut))
                .value,
            child: Transform.scale(
              scale: Tween(begin: 0.92, end: 1.0)
                  .animate(CurvedAnimation(parent: controller, curve: kCupertinoOut))
                  .value,
              alignment: opensUp ? Alignment.bottomRight : Alignment.topRight,
              child: child,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: 224,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: s.floatingSurface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: s.floatingShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MessageActionRow(
                    s: s,
                    assetName: 'pencil',
                    label: 'Editar',
                    onTap: () { close(); onEdit(); },
                  ),
                  _MessageActionRow(
                    s: s,
                    assetName: 'copy',
                    label: 'Copiar',
                    onTap: () { close(); onCopy(); },
                  ),
                  _MessageActionRow(
                    s: s,
                    assetName: 'select_text',
                    label: 'Selecionar texto',
                    onTap: () { close(); onSelectText(); },
                  ),
                  _MessageActionRow(
                    s: s,
                    assetName: 'trash',
                    label: 'Eliminar',
                    destructive: true,
                    onTap: () { close(); onDelete(); },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  });

  Overlay.of(context).insert(entry);
  controller.forward();
}

class _MessageActionRow extends StatefulWidget {
  final AppColorScheme s;
  final String assetName;
  final String label;
  final bool destructive;
  final VoidCallback onTap;
  const _MessageActionRow({
    required this.s,
    required this.assetName,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
  @override State<_MessageActionRow> createState() => _MessageActionRowState();
}

class _MessageActionRowState extends State<_MessageActionRow> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final color = widget.destructive ? widget.s.error : widget.s.onSurface;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _h = true),
      onTapCancel: ()  => setState(() => _h = false),
      onTapUp:     (_) => setState(() => _h = false),
      onTap:       widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _h ? widget.s.hover : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(children: [
          AppIcon(widget.assetName, size: 18, color: color),
          const SizedBox(width: 10),
          Text(widget.label,
              style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w500)),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SELECT TEXT SHEET
// ══════════════════════════════════════════════════════════════
Future<void> showSelectTextSheet(
  BuildContext context,
  AppColorScheme s, {
  required String text,
}) {
  return showAppSheet<void>(
    context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selecionar texto',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: s.onSurface)),
          const SizedBox(height: 12),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7,
            ),
            child: SingleChildScrollView(
              child: SelectableText(
                text,
                style: TextStyle(fontSize: 15, color: s.onSurface, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// ATTACHED FILES SHEET
// ══════════════════════════════════════════════════════════════
Future<void> showAttachedFilesSheet(
  BuildContext context,
  AppColorScheme s, {
  required List<AttachedFile> files,
  required ValueChanged<String> onRemove,
}) {
  return showAppSheet<void>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              AppIcon('attach', color: s.onSurface, size: 18),
              const SizedBox(width: 8),
              Text(
                'Anexos desta mensagem',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: s.onSurface),
              ),
            ]),
            const SizedBox(height: 12),
            if (files.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Sem anexos.',
                      style: TextStyle(fontSize: 13.5, color: s.onSurfaceVariant)),
                ),
              )
            else
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(ctx).size.height * 0.7,
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: files.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final f = files[i];
                    return _AttachedFileRow(
                      s: s,
                      file: f,
                      onRemove: () {
                        onRemove(f.id);
                        setModalState(() {});
                        if (files.length <= 1) Navigator.pop(ctx);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _AttachedFileRow extends StatelessWidget {
  final AppColorScheme s;
  final AttachedFile file;
  final VoidCallback onRemove;
  const _AttachedFileRow({required this.s, required this.file, required this.onRemove});

  String get _sizeLabel {
    final kb = file.bytes.length / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }

  bool get _isImage => file.mimeType.startsWith('image/');

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: s.hover,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          if (_isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(file.bytes, width: 40, height: 40, fit: BoxFit.cover),
            )
          else
            Container(
              width: 40, height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.primaryContainer.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: AppIcon('paperclip',
                  color: s.onPrimaryContainer, size: 18),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(file.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: s.onSurface)),
                Text(_sizeLabel, style: TextStyle(fontSize: 11.5, color: s.onSurfaceVariant)),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 28, height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: s.error.withOpacity(0.12), shape: BoxShape.circle),
              child: AppIcon('close', color: s.error, size: 14),
            ),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════
// CHAT INPUT — botão de enviar branco durante resposta
// ══════════════════════════════════════════════════════════════
class _ChatInput extends StatelessWidget {
  final AppColorScheme s;
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final EditorType? attachedTool;
  final int attachedFilesCount;
  final bool incognito;
  final bool sending;
  final GlobalKey attachButtonKey;
  final VoidCallback onSend;
  final VoidCallback onPause;
  final VoidCallback onAttach;
  final VoidCallback onVoice;
  final VoidCallback onOpenAiOptions;
  final VoidCallback onClearTool;
  final VoidCallback onOpenAttachedFiles;

  const _ChatInput({
    required this.s,
    required this.ctrl,
    required this.focusNode,
    required this.attachedTool,
    required this.attachedFilesCount,
    required this.incognito,
    required this.sending,
    required this.attachButtonKey,
    required this.onSend,
    required this.onPause,
    required this.onAttach,
    required this.onVoice,
    required this.onOpenAiOptions,
    required this.onClearTool,
    required this.onOpenAttachedFiles,
  });

  @override
  Widget build(BuildContext context) {
    final floatingShadow = <BoxShadow>[
      BoxShadow(
        color: Colors.black.withOpacity(s.isDark ? 0.28 : 0.10),
        blurRadius: 20,
        offset: const Offset(0, 6),
      ),
      BoxShadow(
        color: Colors.black.withOpacity(s.isDark ? 0.14 : 0.04),
        blurRadius: 4,
        offset: const Offset(0, 1),
      ),
    ];

    final inner = Container(
      decoration: BoxDecoration(
        color: s.isDark ? s.cardBackground : s.floatingSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: floatingShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (attachedTool != null || attachedFilesCount > 0)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Wrap(
                spacing: 8, runSpacing: 8,
                children: [
                  if (attachedTool != null)
                    _AttachedToolPill(
                        s: s, type: attachedTool!, onClear: onClearTool),
                  if (attachedFilesCount > 0)
                    _AttachedFilesPill(
                        s: s, count: attachedFilesCount, onTap: onOpenAttachedFiles),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: ctrl,
              focusNode: focusNode,
              minLines: 1, maxLines: 6,
              style: const TextStyle(fontSize: 16.5, letterSpacing: 0.15).copyWith(color: s.onSurface),
              cursorColor: s.primary,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: incognito ? 'Mensagem incógnita...' : 'Conversar com DeepSeek...',
                hintStyle: TextStyle(fontSize: 16.5, letterSpacing: 0.15, color: s.onSurfaceVariant),
                contentPadding: EdgeInsets.zero,
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 12, 10),
            child: Row(
              children: [
                GestureDetector(
                  key: attachButtonKey,
                  onTap: onAttach,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: AppIcon(
                      'add',
                      color: s.onSurface,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: onOpenAiOptions,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: AppIcon(
                      'sliders',
                      color: s.onSurface,
                      size: 22,
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onVoice,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: AppIcon(
                      'mic',
                      color: s.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: sending ? onPause : onSend,
                  child: Container(
                    width: 36, height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: sending ? Colors.white : s.primary,
                      shape: BoxShape.circle,
                      border: sending ? Border.all(color: s.primary) : null,
                    ),
                    child: AppIcon(
                      sending ? 'pause' : 'arrow_up',
                      color: sending ? s.primary : Colors.white,
                      size: sending ? 16 : 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final bordered = incognito
        ? DashedRRectBorder(color: s.outline, radius: 20, child: inner)
        : inner;

    return bordered;
  }
}

class _AttachedToolPill extends StatelessWidget {
  final AppColorScheme s;
  final EditorType type;
  final VoidCallback onClear;
  const _AttachedToolPill(
      {required this.s, required this.type, required this.onClear});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: s.primaryContainer,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon(_iconForEditorType(type),
                  size: 13, color: s.onPrimaryContainer),
              const SizedBox(width: 4),
              Text(type.label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: s.onPrimaryContainer)),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: AppIcon('close',
                    color: s.onPrimaryContainer, size: 9),
              ),
            ],
          ),
        ),
      );
}

class _AttachedFilesPill extends StatelessWidget {
  final AppColorScheme s;
  final int count;
  final VoidCallback onTap;
  const _AttachedFilesPill({required this.s, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final bg = s.isDark ? s.hover : s.primary.withOpacity(0.12);
    final fg = s.isDark ? s.onSurfaceVariant : s.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon('paperclip', color: fg, size: 13),
            const SizedBox(width: 4),
            Text('$count anexo${count == 1 ? '' : 's'}',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ATTACH POPUP
// ══════════════════════════════════════════════════════════════
enum _AttachAction { files, photos, camera }

void showAttachPopup(
  BuildContext context,
  AppColorScheme s, {
  required GlobalKey anchorKey,
  required VoidCallback onFiles,
  required VoidCallback onPhotos,
  required VoidCallback onCamera,
  required ValueChanged<EditorType> onSelectTool,
}) {
  final anchorContext = anchorKey.currentContext;
  if (anchorContext == null) return;
  final box = anchorContext.findRenderObject() as RenderBox;
  final anchorOffset = box.localToGlobal(Offset.zero);
  final anchorSize = box.size;

  late OverlayEntry entry;
  final controller = AnimationController(
    vsync: Navigator.of(context),
    duration: const Duration(milliseconds: 200),
  );

  void close() {
    controller.reverse().then((_) {
      entry.remove();
      controller.dispose();
    });
  }

  entry = OverlayEntry(builder: (ctx) {
    const width = 240.0;
    const estimatedHeight = 200.0;
    final screenSize = MediaQuery.of(ctx).size;

    final desiredTop = anchorOffset.dy - 6 - estimatedHeight;
    final opensUp = desiredTop >= 40;
    final top = opensUp ? desiredTop : anchorOffset.dy + anchorSize.height + 6;
    final left = anchorOffset.dx.clamp(8.0, screenSize.width - width - 8);

    final entries = <PopupMenuEntry<_AttachAction>>[
      const PopupMenuEntry(
          value: _AttachAction.files,
          label: 'Arquivos',
          subtitle: 'Enviar qualquer tipo de arquivo',
          assetName: 'folder'),
      const PopupMenuEntry(
          value: _AttachAction.photos,
          label: 'Fotos',
          subtitle: 'Enviar fotos da galeria',
          assetName: 'image'),
      const PopupMenuEntry(
          value: _AttachAction.camera,
          label: 'Câmera',
          subtitle: 'Tirar uma foto agora',
          assetName: 'camera'),
    ];

    return Stack(children: [
      Positioned.fill(
        child: GestureDetector(
          onTap: close,
          behavior: HitTestBehavior.opaque,
          child: Container(color: Colors.transparent),
        ),
      ),
      Positioned(
        left: left,
        top: top,
        child: AnimatedBuilder(
          animation: controller,
          builder: (_, child) => Opacity(
            opacity: CurvedAnimation(
                    parent: controller, curve: const Interval(0, 0.5, curve: Curves.easeOut))
                .value,
            child: Transform.scale(
              scale: Tween(begin: 0.92, end: 1.0)
                  .animate(CurvedAnimation(parent: controller, curve: kCupertinoOut))
                  .value,
              alignment: opensUp ? Alignment.bottomLeft : Alignment.topLeft,
              child: child,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: Container(
              width: width,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: s.floatingSurface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: s.floatingShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final e in entries)
                    _PopupRow<_AttachAction>(
                      s: s,
                      entry: e,
                      onTap: () {
                        close();
                        switch (e.value) {
                          case _AttachAction.files: onFiles(); break;
                          case _AttachAction.photos: onPhotos(); break;
                          case _AttachAction.camera: onCamera(); break;
                        }
                      },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ]);
  });

  Overlay.of(context).insert(entry);
  controller.forward();
}

// ══════════════════════════════════════════════════════════════
// CANVAS SHEET
// ══════════════════════════════════════════════════════════════
Future<void> showCanvasSheet(
  BuildContext context,
  AppColorScheme s, {
  required List<LocalCanvasItem> canvases,
  required ValueChanged<LocalCanvasItem> onOpenCanvas,
}) {
  return showAppSheet<void>(
    context,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            AppIcon('grid', color: s.onSurface, size: 18),
            const SizedBox(width: 8),
            Text('Canvas desta conversa',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w600, color: s.onSurface)),
          ]),
          const SizedBox(height: 12),
          if (canvases.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('Ainda não há documentos nesta conversa.',
                    style: TextStyle(fontSize: 13.5, color: s.onSurfaceVariant)),
              ),
            )
          else
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(ctx).size.height * 0.75,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: canvases.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final item = canvases[canvases.length - 1 - i];
                  return _CanvasCard(
                    s: s,
                    item: item,
                    onTap: () {
                      Navigator.pop(ctx);
                      onOpenCanvas(item);
                    },
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );
}

class _CanvasCard extends StatefulWidget {
  final AppColorScheme s;
  final LocalCanvasItem item;
  final VoidCallback onTap;
  const _CanvasCard({required this.s, required this.item, required this.onTap});
  @override State<_CanvasCard> createState() => _CanvasCardState();
}

class _CanvasCardState extends State<_CanvasCard> {
  bool _h = false;

  EditorType get _editorType => widget.item.kind.editorType;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _h = true),
      onTapCancel: ()  => setState(() => _h = false),
      onTapUp:     (_) => setState(() => _h = false),
      onTap:       widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _h ? s.hover : s.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: s.cardShadow,
        ),
        child: Row(children: [
          Container(
            width: 40, height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: s.primaryContainer.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: AppIcon(_iconForEditorType(_editorType),
                size: 20, color: s.onSurface),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: s.onSurface)),
                const SizedBox(height: 2),
                Text(_editorType.label,
                    style: TextStyle(fontSize: 12, color: s.onSurfaceVariant)),
              ],
            ),
          ),
          AppIcon('chevron_forward',
              color: s.onSurfaceVariant, size: 14),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// VOICE RECORD SHEET
// ══════════════════════════════════════════════════════════════
Future<void> showVoiceRecordSheet(
  BuildContext context,
  AppColorScheme s, {
  required ValueChanged<String> onTranscribed,
}) {
  return showAppSheet<void>(
    context,
    builder: (ctx) => _VoiceRecordSheetContent(
      s: s,
      onTranscribed: onTranscribed,
    ),
  );
}

class _VoiceRecordSheetContent extends StatefulWidget {
  final AppColorScheme s;
  final ValueChanged<String> onTranscribed;
  const _VoiceRecordSheetContent(
      {required this.s, required this.onTranscribed});
  @override
  State<_VoiceRecordSheetContent> createState() =>
      _VoiceRecordSheetContentState();
}

class _VoiceRecordSheetContentState extends State<_VoiceRecordSheetContent>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;
  bool _recording = true;
  Timer? _timer;
  int _seconds = 0;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  @override
  void dispose() {
    _pulse.dispose();
    _timer?.cancel();
    super.dispose();
  }

  String get _formattedTime {
    final m = (_seconds ~/ 60).toString().padLeft(2, '0');
    final sec = (_seconds % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  void _stopAndTranscribe() {
    setState(() => _recording = false);
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _recording ? 'A ouvir...' : 'A transcrever...',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: s.onSurface),
          ),
          const SizedBox(height: 6),
          Text(
            _formattedTime,
            style: TextStyle(
                fontSize: 13, color: s.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) {
              final scale = _recording
                  ? 1.0 + (_pulse.value * 0.12)
                  : 1.0;
              return Transform.scale(scale: scale, child: child);
            },
            child: Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                color: s.error.withOpacity(s.isDark ? 0.20 : 0.12),
                shape: BoxShape.circle,
                border: Border.all(color: s.error, width: 1.5),
              ),
              child: AppIcon(
                _recording ? 'mic' : 'mic_off',
                size: 30,
                color: s.error,
              ),
            ),
          ),
          const SizedBox(height: 24),
          GestureDetector(
            onTap: _recording ? _stopAndTranscribe : null,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                _recording ? 'Concluir' : 'A processar...',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: s.onPrimary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// BOTTOM SHEET DE OPÇÕES DE IA
// ══════════════════════════════════════════════════════════════
Future<void> showAiOptionsSheet(
  BuildContext context,
  AppColorScheme s, {
  required AiModel currentModel,
  required bool webSearchEnabled,
  required bool widgetsEnabled,
  required ValueChanged<AiModel> onModelSelected,
  required ValueChanged<bool> onWebSearchChanged,
  required ValueChanged<bool> onWidgetsChanged,
  required VoidCallback onOpenCanvas,
}) {
  return showAppSheet<void>(
    context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Opções de IA',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: s.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Modelo',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: s.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            for (final model in AiModel.values) ...[
              _ModelOptionRow(
                s: s,
                model: model,
                selected: model == currentModel,
                onTap: () {
                  onModelSelected(model);
                  setModalState(() {});
                },
              ),
              if (model != AiModel.values.last) const SizedBox(height: 4),
            ],
            const SizedBox(height: 16),
            Divider(height: 1, thickness: 1, color: s.outline.withOpacity(0.2)),
            const SizedBox(height: 8),
            _OptionsActionRow(
              s: s,
              assetName: 'grid',
              label: 'Canvas',
              onTap: () {
                Navigator.pop(ctx);
                onOpenCanvas();
              },
            ),
            const SizedBox(height: 8),
            _OptionsSwitchRow(
              s: s,
              assetName: 'globe',
              label: 'Pesquisar web',
              value: webSearchEnabled,
              onChanged: (v) {
                onWebSearchChanged(v);
                setModalState(() {});
              },
            ),
            const SizedBox(height: 8),
            _OptionsSwitchRow(
              s: s,
              assetName: 'sparkles',
              label: 'Competências',
              value: widgetsEnabled,
              onChanged: (v) {
                onWidgetsChanged(v);
                setModalState(() {});
              },
            ),
          ],
        ),
      ),
    ),
  );
}

class _ModelOptionRow extends StatelessWidget {
  final AppColorScheme s;
  final AiModel model;
  final bool selected;
  final VoidCallback onTap;
  const _ModelOptionRow({
    required this.s,
    required this.model,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? s.primary.withOpacity(0.1) : s.hover,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      color: s.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    model.description,
                    style: TextStyle(fontSize: 11.5, color: s.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (selected)
              const AppIcon(
                'check',
                color: Color(0xFF2F7BF6),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

class _OptionsActionRow extends StatelessWidget {
  final AppColorScheme s;
  final String assetName;
  final String label;
  final VoidCallback onTap;
  const _OptionsActionRow({
    required this.s,
    required this.assetName,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: s.hover,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            AppIcon(assetName, size: 18, color: s.onSurface),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(fontSize: 14, color: s.onSurface),
            ),
            const Spacer(),
            AppIcon('chevron_forward', size: 14, color: s.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _OptionsSwitchRow extends StatelessWidget {
  final AppColorScheme s;
  final String assetName;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _OptionsSwitchRow({
    required this.s,
    required this.assetName,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: s.hover,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          AppIcon(assetName, size: 18, color: s.onSurface),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(fontSize: 14, color: s.onSurface),
          ),
          const Spacer(),
          _CustomSwitch(value: value, onChanged: onChanged, s: s),
        ],
      ),
    );
  }
}

class _CustomSwitch extends StatelessWidget {
  final AppColorScheme s;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _CustomSwitch({required this.s, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        width: 44, height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? s.primary : s.outline,
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20, height: 20,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}