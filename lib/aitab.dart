// ══════════════════════════════════════════════════════════════
// FILE: lib/aitab.dart
// ══════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'colors.dart';
import 'widgets.dart';
import 'richtext.dart';
import 'edittab.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'aiwidgets.dart';
import 'widgets.dart';
import 'exportservice.dart';
import 'drawermenu.dart' show conversationsController, ConversationItem;

// ══════════════════════════════════════════════════════════════
// AI MODEL — 3 modelos DeepSeek reais (flash/pro/reasoning), já
// mapeados para os providers deepseekFlash/deepseekPro/deepseekReasoning
// definidos em api_service.dart. Os labels "DeepSeek V4" antigos foram
// substituídos pelos nomes pedidos: Flash (padrão), Pro, Raciocínio.
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

  bool get think => this == AiModel.deepseekReasoning;
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
Podes usar notação LaTeX-like: frações com \\frac{a}{b}, raízes com
\\sqrt{x} ou \\sqrt[n]{x}, potências com x^2 ou x^{10}, índices com x_1 ou
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

- ```widget_table``` — { "headers": ["Col1","Col2"], "rows": [["a","b"]] }
- ```widget_bar``` — { "data": [{"label":"Jan","value":10,"unit":"","color":"#6F5AF6"}] }
- ```widget_pie``` — { "data": [{"label":"A","value":30,"color":"#2F80ED"}] }
- ```widget_market``` — { "type": "crypto", "symbol": "BTC", "name": "Bitcoin" } ou { "type": "forex", "symbol": "USDEUR" }
- ```widget_calendar``` — { "events": [{"date":"2026-08-10","name":"Reunião","time":"14:00","color":"#6F5AF6"}] }
- ```widget_timer``` — { "seconds": 300, "label": "Foco" }
- ```widget_mindmap``` — { "tree": {"id":"root","label":"Tema","color":"#6F5AF6","children":[]} }
- ```widget_graph``` — { "expression": "sin(x)", "xMin": -10, "xMax": 10 }
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
  String get svgAsset => const {
        ConversationAction.newChat:   'newchat.svg',
        ConversationAction.incognito: 'incognito.svg',
        ConversationAction.rename:    'edit.svg',
        ConversationAction.delete:    'trash.svg',
      }[this]!;

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
  final String? svgIcon;
  final bool selected;
  final bool disabled;
  final bool destructive;
  const PopupMenuEntry({
    required this.value,
    required this.label,
    this.subtitle,
    this.svgIcon,
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
                  borderRadius: BorderRadius.circular(24),
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
            if (e.svgIcon != null) ...[
              AppIcon(e.svgIcon!, color: color, size: 18),
              const SizedBox(width: 10),
            ],
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
              AppIcon('check.svg', color: s.primary, size: 16),
          ]),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// AI CONVERSATION MENU BUTTON
// ══════════════════════════════════════════════════════════════

class AiConversationMenuButton extends StatelessWidget {
  final AppColorScheme s;
  final ValueChanged<ConversationAction> onSelect;
  final bool hasMessages;
  final int canvasCount;
  final VoidCallback onOpenCanvas;
  final bool webSearchEnabled;
  final ValueChanged<bool> onToggleWebSearch;
  final bool widgetsEnabled;
  final ValueChanged<bool> onToggleWidgets;

  const AiConversationMenuButton({
    super.key,
    required this.s,
    required this.onSelect,
    required this.hasMessages,
    required this.canvasCount,
    required this.onOpenCanvas,
    required this.webSearchEnabled,
    required this.onToggleWebSearch,
    required this.widgetsEnabled,
    required this.onToggleWidgets,
  });

  @override
  Widget build(BuildContext context) {
    return _HeaderMenuButton(
      s: s,
      hasMessages: hasMessages,
      canvasCount: canvasCount,
      onSelect: onSelect,
      onOpenCanvas: onOpenCanvas,
      webSearchEnabled: webSearchEnabled,
      onToggleWebSearch: onToggleWebSearch,
      widgetsEnabled: widgetsEnabled,
      onToggleWidgets: onToggleWidgets,
    );
  }
}

class _HeaderMenuButton extends StatefulWidget {
  final AppColorScheme s;
  final bool hasMessages;
  final int canvasCount;
  final ValueChanged<ConversationAction> onSelect;
  final VoidCallback onOpenCanvas;
  final bool webSearchEnabled;
  final ValueChanged<bool> onToggleWebSearch;
  final bool widgetsEnabled;
  final ValueChanged<bool> onToggleWidgets;

  const _HeaderMenuButton({
    required this.s,
    required this.hasMessages,
    required this.canvasCount,
    required this.onSelect,
    required this.onOpenCanvas,
    required this.webSearchEnabled,
    required this.onToggleWebSearch,
    required this.widgetsEnabled,
    required this.onToggleWidgets,
  });

  @override
  State<_HeaderMenuButton> createState() => _HeaderMenuButtonState();
}

class _HeaderMenuButtonState extends State<_HeaderMenuButton>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _ov;
  late AnimationController _ac;
  final GlobalKey _anchorKey = GlobalKey();
  late ValueNotifier<bool> _webNotifier;
  late ValueNotifier<bool> _widgetsNotifier;

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 200));
    _webNotifier = ValueNotifier(widget.webSearchEnabled);
    _widgetsNotifier = ValueNotifier(widget.widgetsEnabled);
  }

  @override
  void didUpdateWidget(covariant _HeaderMenuButton old) {
    super.didUpdateWidget(old);
    if (_ov == null) {
      _webNotifier.value = widget.webSearchEnabled;
      _widgetsNotifier.value = widget.widgetsEnabled;
    }
  }

  @override
  void dispose() {
    _ac.dispose();
    _ov?.remove();
    _webNotifier.dispose();
    _widgetsNotifier.dispose();
    super.dispose();
  }

  void _toggle() => _ov == null ? _open() : _close();

  void _open() {
    final box = _anchorKey.currentContext!.findRenderObject() as RenderBox;
    final off = box.localToGlobal(Offset.zero);
    final sz  = box.size;
    _ac.forward(from: 0);
    _webNotifier.value = widget.webSearchEnabled;
    _widgetsNotifier.value = widget.widgetsEnabled;

    _ov = OverlayEntry(builder: (ctx) {
      final s = widget.s;
      final screenSize = MediaQuery.of(ctx).size;
      const width = 260.0;
      const estimatedHeight = 400.0;

      final desiredTop = off.dy + sz.height + 6;
      final overflowsBottom = desiredTop + estimatedHeight > screenSize.height - 24;
      final top = overflowsBottom ? null : desiredTop;
      final bottom = overflowsBottom ? screenSize.height - off.dy + 6 : null;
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
                alignment: overflowsBottom ? Alignment.bottomRight : Alignment.topRight,
                child: child,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: screenSize.height * 0.7),
                child: SingleChildScrollView(
                  child: Container(
                    width: width,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: s.floatingSurface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: s.floatingShadow,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _MenuActionRow(
                          s: s,
                          icon: ConversationAction.newChat.svgAsset,
                          label: ConversationAction.newChat.label,
                          onTap: () { _close(); widget.onSelect(ConversationAction.newChat); },
                        ),
                        _MenuActionRow(
                          s: s,
                          icon: ConversationAction.incognito.svgAsset,
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
                          icon: ConversationAction.rename.svgAsset,
                          label: ConversationAction.rename.label,
                          onTap: () { _close(); widget.onSelect(ConversationAction.rename); },
                        ),
                        _MenuActionRow(
                          s: s,
                          icon: ConversationAction.delete.svgAsset,
                          label: ConversationAction.delete.label,
                          destructive: true,
                          onTap: () { _close(); widget.onSelect(ConversationAction.delete); },
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: Divider(height: 1),
                        ),
                        _MenuActionRow(
                          s: s,
                          icon: 'cards.svg',
                          label: 'Canvas',
                          subtitle: widget.canvasCount == 0
                              ? 'Ainda sem documentos'
                              : '${widget.canvasCount} documento${widget.canvasCount == 1 ? '' : 's'} nesta conversa',
                          onTap: () { _close(); widget.onOpenCanvas(); },
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: Divider(height: 1),
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: _webNotifier,
                          builder: (_, enabled, __) => _MenuSwitchRow(
                            s: s,
                            icon: 'globe.svg',
                            label: 'Pesquisar web',
                            subtitle: enabled ? 'Ativado' : 'Desativado',
                            value: enabled,
                            onChanged: (v) {
                              _webNotifier.value = v;
                              widget.onToggleWebSearch(v);
                            },
                          ),
                        ),
                        ValueListenableBuilder<bool>(
                          valueListenable: _widgetsNotifier,
                          builder: (_, enabled, __) => _MenuSwitchRow(
                            s: s,
                            icon: 'widgets.svg',
                            label: 'Widgets',
                            subtitle: enabled ? 'Gráficos, mapas e cartões' : 'Desativado',
                            value: enabled,
                            onChanged: (v) {
                              _widgetsNotifier.value = v;
                              widget.onToggleWidgets(v);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
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
        child: IgnorePointer(
          child: AppTap(
            onTap: () {},
            s: widget.s,
            child: AppIcon('more_filled.svg', color: widget.s.onSurface, size: 20),
          ),
        ),
      );
}

class _MenuActionRow extends StatefulWidget {
  final AppColorScheme s;
  final String icon;
  final String label;
  final String? subtitle;
  final bool destructive;
  final bool disabled;
  final VoidCallback onTap;
  const _MenuActionRow({
    required this.s,
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
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
            AppIcon(widget.icon, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label,
                      style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w500)),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(widget.subtitle!,
                        style: TextStyle(fontSize: 11.5, color: widget.s.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _MenuSwitchRow extends StatelessWidget {
  final AppColorScheme s;
  final String icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _MenuSwitchRow({
    required this.s,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(children: [
        AppIcon(icon, size: 18, color: s.onSurface),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w400, color: s.onSurface)),
              Text(subtitle,
                  style: TextStyle(fontSize: 11.5, color: s.onSurfaceVariant)),
            ],
          ),
        ),
        AppSwitch(value: value, s: s, onChanged: onChanged),
      ]),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// DOCUMENT WIDGET CARD
// ══════════════════════════════════════════════════════════════

String _previewHtmlAsset(LocalCanvasKind kind) {
  final base = kind.editorType.htmlAsset;
  if (kind == LocalCanvasKind.whiteboard) return base;
  return '$base?preview=1';
}

int _docPageCount(LocalCanvasItem item) {
  if (item.kind != LocalCanvasKind.doc) return 1;
  const marker = '<div class="page-break-marker"></div>';
  if (item.content.isEmpty) return 1;
  return item.content.split(marker).length;
}

class DocumentWidgetCard extends StatefulWidget {
  final AppColorScheme s;
  final LocalCanvasItem item;
  final VoidCallback onOpenEditor;
  const DocumentWidgetCard({
    super.key,
    required this.s,
    required this.item,
    required this.onOpenEditor,
  });

  @override
  State<DocumentWidgetCard> createState() => _DocumentWidgetCardState();
}

class _DocumentWidgetCardState extends State<DocumentWidgetCard> {
  String? _exportingFormat;

  InAppWebViewController? _previewController;

  List<({String id, String label, String icon})> get _downloadOptions {
    switch (widget.item.kind) {
      case LocalCanvasKind.doc:
        return const [
          (id: 'docx', label: 'Baixar como .docx', icon: 'description_outlined.svg'),
          (id: 'pdf', label: 'Baixar como PDF', icon: 'picture_as_pdf.svg'),
          (id: 'png', label: 'Baixar como imagem (PNG)', icon: 'image.svg'),
        ];
      case LocalCanvasKind.sheet:
        return const [
          (id: 'xlsx', label: 'Baixar como .xlsx', icon: 'table_chart.svg'),
          (id: 'pdf', label: 'Baixar como PDF', icon: 'picture_as_pdf.svg'),
          (id: 'png', label: 'Baixar como imagem (PNG)', icon: 'image.svg'),
        ];
      case LocalCanvasKind.slide:
        return const [
          (id: 'pptx', label: 'Baixar como .pptx', icon: 'slideshow.svg'),
          (id: 'pdf', label: 'Baixar como PDF', icon: 'picture_as_pdf.svg'),
          (id: 'png', label: 'Baixar como imagem (PNG)', icon: 'image.svg'),
        ];
      case LocalCanvasKind.whiteboard:
        return const [
          (id: 'png', label: 'Baixar como imagem (PNG)', icon: 'image.svg'),
          (id: 'pdf', label: 'Baixar como PDF', icon: 'picture_as_pdf.svg'),
        ];
    }
  }

  void _openDownloadSheet() {
    final s = widget.s;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
              decoration: BoxDecoration(
                color: s.floatingSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                boxShadow: s.floatingShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: SheetGrabber(s: s)),
                  Row(children: [
                    AppIcon('download.svg', color: s.onSurface, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Baixar "${widget.item.title}"',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: s.onSurface),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 10),
                  for (final opt in _downloadOptions)
                    _DownloadOptionRow(
                      s: s,
                      label: opt.label,
                      icon: opt.icon,
                      loading: _exportingFormat == opt.id,
                      onTap: _exportingFormat != null
                          ? null
                          : () async {
                              setModalState(() => _exportingFormat = opt.id);
                              await _exportAs(context, opt.id);
                              setModalState(() => _exportingFormat = null);
                            },
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _exportAs(BuildContext context, String format) async {
    try {
      final bytes = await ExportService.export(item: widget.item, format: format);
      await ExportService.shareBytes(bytes, filename: '${widget.item.title}.$format');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Não foi possível exportar: $e')),
      );
    }
  }

  void _injectPreviewContent(InAppWebViewController ctrl) {
    final item = widget.item;
    if (item.kind == LocalCanvasKind.doc) {
      final escaped = item.content
          .replaceAll('\\', '\\\\')
          .replaceAll("'", "\\'")
          .replaceAll('\n', '\\n');
      ctrl.evaluateJavascript(source: "editorApi.setContent('$escaped')");
    } else if (item.kind == LocalCanvasKind.sheet || item.kind == LocalCanvasKind.slide) {
      final escaped = item.content
          .replaceAll('\\', '\\\\')
          .replaceAll("'", "\\'")
          .replaceAll('\n', '\\n');
      ctrl.evaluateJavascript(source: "editorApi.setContentFromAi('$escaped')");
    } else {
      final escaped = item.content
          .replaceAll('\\', '\\\\')
          .replaceAll("'", "\\'")
          .replaceAll('\n', '\\n');
      ctrl.evaluateJavascript(source: "editorApi.setContent('$escaped')");
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final item = widget.item;
    final pageCount = _docPageCount(item);
    final showStack = item.kind == LocalCanvasKind.doc && pageCount > 1;

    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: s.cardBackground,
        borderRadius: BorderRadius.circular(16),
        boxShadow: s.cardShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        GestureDetector(
          onTap: widget.onOpenEditor,
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              width: double.infinity,
              color: s.previewBackdrop,
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  if (showStack)
                    Positioned(
                      top: 14, left: 10, right: -6, bottom: -6,
                      child: Container(
                        decoration: BoxDecoration(
                          color: s.cardBackground,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: s.cardShadow,
                        ),
                      ),
                    ),
                  if (showStack)
                    Positioned(
                      top: 7, left: 5, right: -3, bottom: -3,
                      child: Container(
                        decoration: BoxDecoration(
                          color: s.cardBackground,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: s.cardShadow,
                        ),
                      ),
                    ),
                  Positioned(
                    top: showStack ? 0 : 0,
                    left: showStack ? 0 : 0,
                    right: showStack ? 12 : 0,
                    bottom: showStack ? 12 : 0,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: IgnorePointer(
                        child: InAppWebView(
                          initialFile: _previewHtmlAsset(item.kind),
                          initialSettings: InAppWebViewSettings(
                            transparentBackground: true,
                            javaScriptEnabled: true,
                            allowFileAccessFromFileURLs: true,
                            allowUniversalAccessFromFileURLs: true,
                            useHybridComposition: true,
                            disableVerticalScroll: true,
                            disableHorizontalScroll: true,
                            supportZoom: false,
                          ),
                          onWebViewCreated: (c) {
                            _previewController = c;
                          },
                          onLoadStop: (c, _) => _injectPreviewContent(c),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: showStack ? 20 : 8,
                    bottom: showStack ? 20 : 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: s.cardBackground.withOpacity(0.85),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          EditorTypeIcon(item.kind.editorType.svgAsset, size: 13),
                          const SizedBox(width: 4),
                          Text(item.kind.shortLabel,
                              style: TextStyle(fontSize: 10, color: s.onSurfaceVariant, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          color: s.downloadButtonBg,
          child: Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: widget.onOpenEditor,
                child: Container(
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: s.primary, borderRadius: BorderRadius.circular(999)),
                  child: Text('Abrir direto no editor',
                      style: TextStyle(color: s.onPrimary, fontSize: 13.5, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _openDownloadSheet,
              child: Container(
                width: 40, height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: s.cardBackground, shape: BoxShape.circle),
                child: AppIcon('download.svg', color: s.onSurface, size: 18),
              ),
            ),
          ]),
        ),
      ]),
    );
  }
}

class _DownloadOptionRow extends StatefulWidget {
  final AppColorScheme s;
  final String label;
  final String icon;
  final bool loading;
  final VoidCallback? onTap;
  const _DownloadOptionRow({
    required this.s,
    required this.label,
    required this.icon,
    required this.loading,
    required this.onTap,
  });
  @override State<_DownloadOptionRow> createState() => _DownloadOptionRowState();
}

class _DownloadOptionRowState extends State<_DownloadOptionRow> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   widget.onTap == null ? null : (_) => setState(() => _h = true),
      onTapCancel: widget.onTap == null ? null : ()  => setState(() => _h = false),
      onTapUp:     widget.onTap == null ? null : (_) => setState(() => _h = false),
      onTap:       widget.onTap,
      child: Opacity(
        opacity: widget.onTap == null && !widget.loading ? 0.4 : 1.0,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: _h ? s.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(children: [
            if (widget.loading)
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: s.primary))
            else
              AppIcon(widget.icon, size: 18, color: s.onSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Text(widget.label,
                  style: TextStyle(fontSize: 14, color: s.onSurface, fontWeight: FontWeight.w500)),
            ),
          ]),
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
      return const _OpenBlockInfo('A criar widget...', partial);
    }
  }

  if (_endsWithPartialMarker(text)) {
    return const _OpenBlockInfo('A criar...', '');
  }

  return null;
}

const List<String> _kPartialMarkerPrefixes = [
  '[[canvas:',
  '```widget_table',
  '```widget_code',
  '```widget_bar',
  '```widget_pie',
  '```widget_market',
  '```widget_calendar',
  '```widget_timer',
  '```widget_mindmap',
  '```widget_graph',
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

class AiTabState extends State<AiTab> {
  final TextEditingController _ctrl   = TextEditingController();
  final ScrollController       _scroll = ScrollController();
  final List<ChatMessage>      _msgs  = [];
  final List<LocalCanvasItem>  _canvases = [];

  bool     _incognito    = false;
  bool     _sending      = false;
  bool     _widgetsEnabled = false;
  bool     _webSearchEnabled = false;
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

  bool get _hasMessages => _msgs.isNotEmpty;

  StreamSubscription<ChatStreamEvent>? _streamSub;

  final FocusNode _inputFocus = FocusNode();

  @override
  void initState() {
    super.initState();
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
    final userMsg = ChatMessage(
      role: 'user',
      content: t,
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
      think: _model.think,
      language: 'pt',
      systemPrompt: _effectiveSystemPrompt,
    ).listen(
      (event) {
        if (!mounted) return;
        switch (event) {
          case ChatTitleEvent(title: final title):
            if (!_incognito) {
              _applyGeneratedTitle(title);
            }
            break;
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
            _persistConversation();
            if (isFirst && _conversationId == null) {
              _generateTitleInBackground(t);
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

  Future<void> _applyGeneratedTitle(String title) async {
    final token = authController.token;
    if (token == null) return;
    if (_conversationId == null) {
      final created = await ConversationsApiService.create(
        token,
        title: title,
        messages: _msgs,
        canvases: const [],
      );
      if (created != null && created['id'] != null) {
        _conversationId = created['id'].toString();
        conversationsController.upsertLocal(ConversationItem.fromJson(created));
      }
    } else {
      await ConversationsApiService.update(token, _conversationId!, title: title);
      final existing = conversationsController.items
          .where((c) => c.id == _conversationId)
          .toList();
      conversationsController.upsertLocal(ConversationItem(
        id: _conversationId!,
        title: title,
        preview: _msgs.isNotEmpty ? _msgs.last.content : '',
        pinned: existing.isNotEmpty ? existing.first.pinned : false,
        archived: existing.isNotEmpty ? existing.first.archived : false,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ));
    }
  }

  Future<void> _generateTitleInBackground(String firstMessage) async {
    final token = authController.token;
    if (token == null) return;
    final title = await AiApiService.generateTitle(token, firstMessage);
    if (!mounted) return;
    if (_incognito) return;
    if (_conversationId != null) return;
    final created = await ConversationsApiService.create(
      token,
      title: title,
      messages: _msgs,
      canvases: const [],
    );
    if (created != null && created['id'] != null) {
      _conversationId = created['id'].toString();
      conversationsController.upsertLocal(ConversationItem.fromJson(created));
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
        canvases: const [],
      );
      if (created != null && created['id'] != null) {
        _conversationId = created['id'].toString();
        conversationsController.upsertLocal(ConversationItem.fromJson(created));
      }
    } else {
      await ConversationsApiService.update(token, _conversationId!,
          messages: _msgs, canvases: const []);
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

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300), curve: kCupertinoOut);
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

  void _openAttachSheet(GlobalKey anchorKey) {
    showAttachPopup(
      context,
      AppTheme.of(context),
      anchorKey: anchorKey,
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

  void _openModelPopup(GlobalKey anchorKey) {
    showModelSelectPopup(
      context,
      AppTheme.of(context),
      anchorKey: anchorKey,
      current: _model,
      onSelect: _onModelSelected,
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

  final GlobalKey _attachAnchorKey = GlobalKey();
  final GlobalKey _modelAnchorKey  = GlobalKey();

  @override
  void dispose() {
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        color: _incognito ? s.pageBackground : s.pageBackground,
        child: Column(children: [
          Expanded(
            child: _incognito
                ? const _IncognitoState()
                : (_msgs.isEmpty && _streamingText.isEmpty)
                    ? _EmptyState(s: s, topPadding: headerHeight)
                    : ListView.builder(
                        controller: _scroll,
                        padding: EdgeInsets.fromLTRB(16, headerHeight, 16, 8),
                        itemCount: _msgs.length + (_sending ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i >= _msgs.length) {
                            final elements = _parseStreamingContent(_streamingText, _nextCanvasId);
                            return _StreamingBubble(
                              s: s,
                              elements: elements,
                              thinking: _streamingThink != null
                                  ? cleanAiText(_streamingThink!)
                                  : null,
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
          ),
          _ChatInput(
            s: s,
            ctrl: _ctrl,
            focusNode: _inputFocus,
            model: _model,
            attachedTool: _attachedTool,
            attachedFilesCount: _attachedFiles.length,
            incognito: _incognito,
            sending: _sending,
            attachAnchorKey: _attachAnchorKey,
            modelAnchorKey: _modelAnchorKey,
            onSend: _send,
            onAttach: () => _openAttachSheet(_attachAnchorKey),
            onVoice: _openVoiceSheet,
            onModel: () => _openModelPopup(_modelAnchorKey),
            onClearTool: _onClearTool,
            onOpenAttachedFiles: _openAttachedFilesSheet,
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: kCupertinoOut,
            height: keyboardInset > 0 ? keyboardInset + 8 : MediaQuery.of(context).padding.bottom + 8,
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
        'incognito_filled.svg',
        color: s.onSurface,
        size: 72,
        useColorAsset: false,
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
                Image.asset('assets/logo.png', width: 40, height: 40),
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
              borderRadius: BorderRadius.circular(18),
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
                DocumentWidgetCard(s: s, item: item, onOpenEditor: () => onOpenCanvas(item)),
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
          _AssistantActionIcon(s: s, asset: 'thumb_up.svg', onTap: onThumbUp),
          const SizedBox(width: 4),
          _AssistantActionIcon(s: s, asset: 'thumb_down.svg', onTap: onThumbDown),
          const SizedBox(width: 4),
          _AssistantActionIcon(s: s, asset: 'copy.svg', onTap: onCopy),
          const SizedBox(width: 4),
          _AssistantActionIcon(s: s, asset: 'refresh.svg', onTap: onRefresh),
        ],
      );
}

class _AssistantActionIcon extends StatefulWidget {
  final AppColorScheme s;
  final String asset;
  final VoidCallback onTap;
  const _AssistantActionIcon({
    required this.s,
    required this.asset,
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
        child: AppIcon(widget.asset, color: s.onSurfaceVariant, size: 16),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// STREAMING BUBBLE
// ══════════════════════════════════════════════════════════════

class _StreamingBubble extends StatelessWidget {
  final AppColorScheme s;
  final List<_StreamElement> elements;
  final String? thinking;
  final bool widgetsEnabled;
  final VoidCallback onEnableWidgets;
  final ValueChanged<String> onSuggestionTap;
  final ValueChanged<LocalCanvasItem> onOpenCanvas;
  const _StreamingBubble({
    required this.s,
    required this.elements,
    this.thinking,
    required this.widgetsEnabled,
    required this.onEnableWidgets,
    required this.onSuggestionTap,
    required this.onOpenCanvas,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];

    if (thinking != null && thinking!.isNotEmpty) {
      children.add(Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(thinking!,
            style: TextStyle(
                color: s.onSurfaceVariant,
                fontSize: 12.5,
                fontStyle: FontStyle.italic,
                height: 1.4)),
      ));
    }

    bool anyContent = false;
    for (final el in elements) {
      switch (el) {
        case _StreamText(:final text):
          final cleaned = cleanAiText(text);
          if (cleaned.trim().isEmpty) continue;
          anyContent = true;
          children.add(RichAiText(
            text: cleaned,
            s: s,
            widgetsEnabled: widgetsEnabled,
            onEnableWidgets: onEnableWidgets,
            onSuggestionTap: onSuggestionTap,
          ));
        case _StreamOpenBlock(:final label, :final partialContent):
          anyContent = true;
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: _GeneratingProcessCard(
              key: const ValueKey('active_process'),
              s: s,
              label: label,
              partialContent: partialContent,
            ),
          ));
        case _StreamClosedCanvas(:final item):
          anyContent = true;
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: DocumentWidgetCard(s: s, item: item, onOpenEditor: () => onOpenCanvas(item)),
          ));
        case _StreamClosedWidget(:final block):
          anyContent = true;
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: buildAiWidget(block, s),
          ));
      }
    }

    if (!anyContent) {
      children.add(AiSmallDotsLoader(color: s.onSurfaceVariant));
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

class _GeneratingProcessCard extends StatefulWidget {
  final AppColorScheme s;
  final String label;
  final String partialContent;
  final String iconAsset;

  const _GeneratingProcessCard({
    required this.s,
    required this.label,
    required this.partialContent,
    this.iconAsset = 'tools.svg',
  });

  @override
  State<_GeneratingProcessCard> createState() => _GeneratingProcessCardState();
}

class _GeneratingProcessCardState extends State<_GeneratingProcessCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = true;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  int _elapsedSeconds = 0;

  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds = _stopwatch.elapsed.inSeconds);
    });
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _shimmerController.dispose();
    _stopwatch.stop();
    super.dispose();
  }

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final primary = s.primary;
    final highlight = s.isDark ? Colors.white : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: s.hover.withOpacity(0.6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: s.outline.withOpacity(0.4)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _toggleExpanded,
            child: Row(
              children: [
                _ShimmerIcon(
                  asset: widget.iconAsset,
                  size: 16,
                  baseColor: primary,
                  highlightColor: highlight,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ShimmerText(
                    text: widget.label,
                    baseColor: primary,
                    highlightColor: highlight,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${_elapsedSeconds}s',
                  style: TextStyle(
                    fontSize: 11,
                    color: s.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                AnimatedRotation(
                  turns: _expanded ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: AppIcon(
                    'chevron_down.svg',
                    size: 14,
                    color: s.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: s.cardBackground.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  widget.partialContent,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: s.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 200),
          ),
        ],
      ),
    );
  }
}

class _ShimmerIcon extends StatefulWidget {
  final String asset;
  final double size;
  final Color baseColor;
  final Color highlightColor;

  const _ShimmerIcon({
    required this.asset,
    required this.size,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  State<_ShimmerIcon> createState() => _ShimmerIconState();
}

class _ShimmerIconState extends State<_ShimmerIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final t = _controller.value;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.35, 0.5, 0.65],
              begin: Alignment(-1.0 - 2 * (1 - t), 0),
              end: Alignment(1.0 - 2 * (1 - t) + 2, 0),
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          child: AppIcon(
            widget.asset,
            size: widget.size,
            color: widget.baseColor,
          ),
        );
      },
    );
  }
}

class _ShimmerText extends StatefulWidget {
  final String text;
  final Color baseColor;
  final Color highlightColor;
  const _ShimmerText({required this.text, required this.baseColor, required this.highlightColor});
  @override State<_ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<_ShimmerText> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = _c.value;
        return ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (bounds) {
            return LinearGradient(
              colors: [widget.baseColor, widget.highlightColor, widget.baseColor],
              stops: const [0.35, 0.5, 0.65],
              begin: Alignment(-1.0 - 2 * (1 - t), 0),
              end: Alignment(1.0 - 2 * (1 - t) + 2, 0),
              tileMode: TileMode.clamp,
            ).createShader(bounds);
          },
          child: child,
        );
      },
      child: Text(
        widget.text,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: widget.baseColor,
        ),
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
                    icon: 'edit.svg',
                    label: 'Editar',
                    onTap: () { close(); onEdit(); },
                  ),
                  _MessageActionRow(
                    s: s,
                    icon: 'copy.svg',
                    label: 'Copiar',
                    onTap: () { close(); onCopy(); },
                  ),
                  _MessageActionRow(
                    s: s,
                    icon: 'text_select.svg',
                    label: 'Selecionar texto',
                    onTap: () { close(); onSelectText(); },
                  ),
                  _MessageActionRow(
                    s: s,
                    icon: 'trash.svg',
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
  final String icon;
  final String label;
  final bool destructive;
  final VoidCallback onTap;
  const _MessageActionRow({
    required this.s,
    required this.icon,
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
          AppIcon(widget.icon, size: 18, color: color),
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
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: BoxDecoration(
            color: s.floatingSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            boxShadow: s.floatingShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: SheetGrabber(s: s)),
              Text('Selecionar texto',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600, color: s.onSurface)),
              const SizedBox(height: 12),
              Flexible(
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
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setModalState) => Material(
        type: MaterialType.transparency,
        child: SafeArea(
          top: false,
          child: Container(
            constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            decoration: BoxDecoration(
              color: s.floatingSurface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              boxShadow: s.floatingShadow,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: SheetGrabber(s: s)),
                Row(children: [
                  AppIcon('file.svg', color: s.onSurface, size: 18),
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
                  Flexible(
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
          borderRadius: BorderRadius.circular(12),
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
              child: AppIcon('file.svg', color: s.onPrimaryContainer, size: 18),
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
              child: AppIcon('close.svg', color: s.error, size: 14),
            ),
          ),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════
// CHAT INPUT
// ══════════════════════════════════════════════════════════════

class _ChatInput extends StatelessWidget {
  final AppColorScheme s;
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final AiModel model;
  final EditorType? attachedTool;
  final int attachedFilesCount;
  final bool incognito;
  final bool sending;
  final GlobalKey attachAnchorKey;
  final GlobalKey modelAnchorKey;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onVoice;
  final VoidCallback onModel;
  final VoidCallback onClearTool;
  final VoidCallback onOpenAttachedFiles;

  const _ChatInput({
    required this.s,
    required this.ctrl,
    required this.focusNode,
    required this.model,
    required this.attachedTool,
    required this.attachedFilesCount,
    required this.incognito,
    required this.sending,
    required this.attachAnchorKey,
    required this.modelAnchorKey,
    required this.onSend,
    required this.onAttach,
    required this.onVoice,
    required this.onModel,
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
        color: s.floatingSurface,
        borderRadius: BorderRadius.circular(22),
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
                hintText: incognito ? 'Mensagem incógnita...' : 'Conversar com Claude...',
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
                  key: attachAnchorKey,
                  onTap: onAttach,
                  child: Container(
                    width: 36, height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: s.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: AppIcon('add.svg', color: s.onSurface, size: 22),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  key: modelAnchorKey,
                  onTap: onModel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: s.hover,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(model.label,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: s.onSurface)),
                        const SizedBox(width: 3),
                        Text(model.badge,
                            style: TextStyle(
                                fontSize: 12,
                                color: s.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: onVoice,
                  child: Container(
                    width: 36, height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: s.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: AppIcon('record.svg',
                        color: s.onSurfaceVariant, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: sending ? null : onSend,
                  child: Container(
                    width: 36, height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: sending ? s.primary.withOpacity(0.5) : s.primary,
                        shape: BoxShape.circle),
                    child: sending
                        ? _SpinningIcon(asset: 'stop_button.svg', color: s.onPrimary)
                        : AppIcon('send.svg', color: s.onPrimary, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final bordered = incognito
        ? DashedRRectBorder(color: s.outline, radius: 22, child: inner)
        : inner;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: bordered,
    );
  }
}

class _SpinningIcon extends StatefulWidget {
  final String asset;
  final Color color;
  const _SpinningIcon({required this.asset, required this.color});
  @override State<_SpinningIcon> createState() => _SpinningIconState();
}

class _SpinningIconState extends State<_SpinningIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat();
  }
  @override void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => RotationTransition(
        turns: _c,
        child: AppIcon(widget.asset, color: widget.color, size: 18),
      );
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
              EditorTypeIcon(type.svgAsset, size: 13),
              const SizedBox(width: 4),
              Text(type.label,
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: s.onPrimaryContainer)),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: onClear,
                child: AppIcon('close.svg',
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
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(
            color: s.primary.withOpacity(0.12),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon('file.svg', color: s.primary, size: 13),
              const SizedBox(width: 4),
              Text('$count anexo${count == 1 ? '' : 's'}',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: s.primary)),
            ],
          ),
        ),
      );
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
  final box = anchorKey.currentContext!.findRenderObject() as RenderBox;
  final off = box.localToGlobal(Offset.zero);
  final sz = box.size;
  final screenSize = MediaQuery.of(context).size;

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
    const estimatedHeight = 210.0;
    final spaceAbove = off.dy;
    final opensUp = spaceAbove >= estimatedHeight + 24;
    final top = opensUp ? off.dy - 6 - estimatedHeight : off.dy + sz.height + 6;
    final left = off.dx.clamp(12.0, screenSize.width - width - 12);

    final entries = <PopupMenuEntry<_AttachAction>>[
      const PopupMenuEntry(value: _AttachAction.files, label: 'Arquivos', subtitle: 'Enviar qualquer tipo de arquivo', svgIcon: 'file.svg'),
      const PopupMenuEntry(value: _AttachAction.photos, label: 'Fotos', subtitle: 'Enviar fotos da galeria', svgIcon: 'image.svg'),
      const PopupMenuEntry(value: _AttachAction.camera, label: 'Câmera', subtitle: 'Tirar uma foto agora', svgIcon: 'camera.svg'),
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
        top: top,
        left: left,
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
                borderRadius: BorderRadius.circular(24),
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
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: s.floatingSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            boxShadow: s.floatingShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: SheetGrabber(s: s)),
              Row(children: [
                AppIcon('cards.svg', color: s.onSurface, size: 18),
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
                Flexible(
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _h ? s.hover : s.cardBackground,
          borderRadius: BorderRadius.circular(16),
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
            child: EditorTypeIcon(_editorType.svgAsset, size: 20),
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
          AppIcon('chevron_right.svg', color: s.onSurfaceVariant, size: 14),
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
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
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
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          decoration: BoxDecoration(
            color: s.floatingSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            boxShadow: s.floatingShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SheetGrabber(s: s),
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
                  child: _recording
                      ? AppIcon('mic.svg', size: 30, color: s.error)
                      : AppIcon('mic_none.svg', size: 30, color: s.error),
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
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MODEL SELECT POPUP
// ══════════════════════════════════════════════════════════════

void showModelSelectPopup(
  BuildContext context,
  AppColorScheme s, {
  required GlobalKey anchorKey,
  required AiModel current,
  required ValueChanged<AiModel> onSelect,
}) {
  final box = anchorKey.currentContext!.findRenderObject() as RenderBox;
  final off = box.localToGlobal(Offset.zero);
  final sz = box.size;
  final screenSize = MediaQuery.of(context).size;

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
    const width = 250.0;
    const estimatedHeight = 200.0;
    final spaceAbove = off.dy;
    final opensUp = spaceAbove >= estimatedHeight + 24;
    final top = opensUp ? off.dy - 6 - estimatedHeight : off.dy + sz.height + 6;
    final left = off.dx.clamp(12.0, screenSize.width - width - 12);

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
        left: left,
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
                borderRadius: BorderRadius.circular(24),
                boxShadow: s.floatingShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: AiModel.values
                    .map((m) => _PopupRow<AiModel>(
                          s: s,
                          entry: PopupMenuEntry(
                            value: m,
                            label: m.label,
                            subtitle: m.description,
                            selected: current == m,
                          ),
                          onTap: () { close(); onSelect(m); },
                        ))
                    .toList(),
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