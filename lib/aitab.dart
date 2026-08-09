// ══════════════════════════════════════════════════════════════
// FILE: lib/aitab.dart
// ══════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'colors.dart';
import 'widgets.dart';
import 'richtext.dart';
import 'edittab.dart';
import 'api_service.dart';
import 'auth_service.dart';
import 'aiwidgets.dart';
import 'drawermenu.dart' show conversationsController, ConversationItem;

// ══════════════════════════════════════════════════════════════
// AI MODEL
// ══════════════════════════════════════════════════════════════

enum AiModel { deepseekV4, deepseekV4Pro, deepseekR1 }

extension AiModelX on AiModel {
  String get label => const {
        AiModel.deepseekV4:    'DeepSeek V4',
        AiModel.deepseekV4Pro: 'DeepSeek V4 Pro',
        AiModel.deepseekR1:    'DeepSeek R1',
      }[this]!;

  String get badge => const {
        AiModel.deepseekV4:    'Rápido',
        AiModel.deepseekV4Pro: 'Avançado',
        AiModel.deepseekR1:    'Raciocínio',
      }[this]!;

  String get description => const {
        AiModel.deepseekV4:    'Respostas rápidas para o dia a dia',
        AiModel.deepseekV4Pro: 'Mais capacidade para tarefas complexas',
        AiModel.deepseekR1:    'Pensa passo a passo antes de responder',
      }[this]!;

  ApiProvider get provider => const {
        AiModel.deepseekV4:    ApiProvider.gemini,
        AiModel.deepseekV4Pro: ApiProvider.groqVersatile,
        AiModel.deepseekR1:    ApiProvider.gemini,
      }[this]!;

  bool get think => this == AiModel.deepseekR1;
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

Para expressões matemáticas, usa $expressão$ para matemática dentro do
texto corrido e $$expressão$$ numa linha própria para fórmulas em destaque.
Podes usar notação LaTeX-like: frações com \\frac{a}{b}, raízes com
\\sqrt{x} ou \\sqrt[n]{x}, potências com x^2 ou x^{10}, índices com x_1 ou
x_{ij}, letras gregas com \\alpha, \\beta, \\pi, \\Delta, etc., e operadores
como \\leq, \\geq, \\neq, \\times, \\cdot, \\sum, \\int, \\infty, \\rightarrow.
A aplicação converte tudo automaticamente para uma apresentação visual
correta — nunca precisas de explicar a notação, apenas escrevê-la.

Quando o utilizador pedir para criares, escreveres ou editares um documento
de texto, uma folha de cálculo ou uma apresentação, gera o conteúdo e
embrulha-o EXATAMENTE neste formato, no fim da tua resposta:

[[canvas:doc:Título do documento||<p>conteúdo em html aqui</p>]]

Para documentos (doc), podes aplicar cor ao texto e destaque (highlight/marcador)
diretamente no HTML gerado, usando estilos inline no próprio texto, exatamente
como o editor os interpreta:
- Cor de texto: <span style="color:#HEXCOR">texto colorido</span>
- Destaque/marcador: <span style="background-color:#HEXCOR">texto realçado</span>
Podes combinar ambos no mesmo span quando fizer sentido. Usa cor com intenção —
por exemplo vermelho para avisos, verde para conclusões positivas, amarelo para
destacar pontos importantes — e nunca abuses, só onde realmente ajudar a leitura.

Usa "sheet" para folhas de cálculo (conteúdo em JSON de células) e "slide" para
apresentações (conteúdo em JSON de slides). Nunca mostres este bloco ao
utilizador como texto explicado — ele é processado automaticamente pela
aplicação e transformado num cartão de documento navegável.

IMPORTANTE: blocos de código normais (```dart, ```python, ```js, ```html,
```css, etc.) NUNCA devem ser embrulhados em [[canvas:...]] — mesmo que sejam
uma página HTML completa, um componente, ou um ficheiro inteiro. Blocos de
código ficam sempre como blocos de código markdown normais, visíveis
diretamente na conversa, exatamente como qualquer outra resposta técnica.
Só documentos de texto corrido, folhas de cálculo e apresentações usam o
formato [[canvas:...]] — nunca código.
''';

const String kAiWidgetsInstructions = '''

Tens também acesso a widgets visuais interativos, que aparecem diretamente
dentro da conversa (nunca em canvas). Quando fizer sentido para a resposta,
gera um bloco de código com uma das seguintes linguagens especiais, contendo
APENAS um objeto JSON válido no corpo do bloco:

- ```widget_table``` — { "headers": ["Col1","Col2"], "rows": [["a","b"]] }
- ```widget_bar``` — { "data": [{"label":"Jan","value":10,"unit":"","color":"#6F5AF6"}] }
- ```widget_pie``` — { "data": [{"label":"A","value":30,"color":"#2F80ED"}] }
- ```widget_sheet``` — { "lines": [{"text":"Título","title":true},{"text":"linha normal"}] }
- ```widget_market``` — { "type": "crypto", "symbol": "BTC", "name": "Bitcoin" } ou { "type": "forex", "symbol": "USDEUR" }
- ```widget_calendar``` — { "events": [{"date":"2026-08-10","name":"Reunião","time":"14:00","color":"#6F5AF6"}] }
- ```widget_timer``` — { "seconds": 300, "label": "Foco" }
- ```widget_mindmap``` — { "tree": {"id":"root","label":"Tema","color":"#6F5AF6","children":[]} }
- ```widget_graph``` — { "expression": "sin(x)", "xMin": -10, "xMax": 10 }
- ```widget_map``` — { "lat": 38.7223, "lng": -9.1393, "zoom": 12, "name": "Lisboa" }

Não uses widget_code — blocos de código normais já aparecem automaticamente
formatados. Usa estes widgets apenas quando acrescentam valor real à resposta
(dados quantitativos, comparações visuais, localização, tempo), nunca como
enfeite. Nunca expliques ao utilizador que estás a gerar um bloco widget —
ele é processado automaticamente e transformado num cartão interativo, sem
nunca mostrar o JSON cru.
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
}

class LocalCanvasItem {
  final String id;
  final LocalCanvasKind kind;
  final String title;
  final String content; // HTML para doc; JSON cru para sheet/slide/whiteboard
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

/// Extrai APENAS blocos [[canvas:...]] explícitos. Blocos de código
/// (``` de qualquer linguagem, incluindo widget_*) nunca são tocados
/// aqui — ficam no texto para RichAiText tratar (código normal ou
/// widget interativo).
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
  final String? pngIcon;
  final bool selected;
  final bool disabled;
  final bool destructive;
  const PopupMenuEntry({
    required this.value,
    required this.label,
    this.subtitle,
    this.svgIcon,
    this.pngIcon,
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
            ] else if (e.pngIcon != null) ...[
              EditorTypeIcon(e.pngIcon!, size: 18),
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
// AI TAB
// ══════════════════════════════════════════════════════════════

class AiTab extends StatefulWidget {
  final VoidCallback onFirstMessage;
  final String? initialConversationId;
  final ConversationAction? externalAction;
  final VoidCallback? onExternalActionConsumed;
  final ValueChanged<bool>? onHasMessagesChanged;
  final VoidCallback? onHeaderStateChanged;
  /// Chamado sempre que um documento (canvas) novo é criado pela IA
  /// nesta conversa — o RootShell usa isto para abrir automaticamente
  /// o EditTab já a mostrar esse documento, sem o utilizador ter de
  /// clicar em mais nada.
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
  AiModel  _model        = AiModel.deepseekV4;
  EditorType? _attachedTool;
  int      _canvasIdSeq  = 0;

  /// Não-nulo enquanto a IA está a "desenhar" um canvas OU um widget.
  String? _creatingLabel;

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
    });
    if (_msgs.isNotEmpty) widget.onFirstMessage();
    widget.onHasMessagesChanged?.call(_hasMessages);
    _notifyHeader();
    _scrollToEnd();
  }

  String _nextCanvasId() => 'cv_${DateTime.now().millisecondsSinceEpoch}_${_canvasIdSeq++}';

  String get _effectiveSystemPrompt {
    var prompt = kAiSystemPrompt;
    if (_widgetsEnabled) prompt += kAiWidgetsInstructions;
    if (_webSearchEnabled) prompt += kAiWebSearchInstructions;
    return prompt;
  }

  String? _detectOpeningLabel(String text) {
    final canvasOpenMatch = RegExp(r'\[\[canvas:(doc|sheet|slide|whiteboard):').allMatches(text).toList();
    if (canvasOpenMatch.isNotEmpty) {
      final closesAfter = text.substring(canvasOpenMatch.last.start).contains(']]');
      if (!closesAfter) {
        final kindStr = canvasOpenMatch.last.group(1)!;
        return switch (kindStr) {
          'sheet' => 'A criar folha de cálculo...',
          'slide' => 'A criar apresentação...',
          'whiteboard' => 'A criar quadro branco...',
          _ => 'A criar documento...',
        };
      }
    }
    if (hasOpenWidgetBlock(text)) {
      return 'A criar widget...';
    }
    return null;
  }

  /// Reenvia uma mensagem exatamente como se o utilizador a tivesse
  /// escrito e tocado em enviar — usado pela pill de sugestão que
  /// aparece no fim de uma resposta da IA (item pedido: ao tocar na
  /// sugestão, essa mesma mensagem é enviada, não apenas copiada).
  void sendSuggestedMessage(String text) {
    if (text.trim().isEmpty || _sending) return;
    _ctrl.text = text;
    _send();
  }

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || _sending) return;
    final isFirst = _msgs.isEmpty;
    final userMsg = ChatMessage(role: 'user', content: t);

    setState(() {
      _msgs.add(userMsg);
      _ctrl.clear();
      _attachedTool = null;
      _sending = true;
      _streamingText = '';
      _streamingThink = null;
      _creatingLabel = null;
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
          case ChatTokenEvent(text: final text):
            setState(() {
              _streamingText += text;
              _creatingLabel = _detectOpeningLabel(_streamingText);
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
              _creatingLabel = null;
            });
            _notifyHeader();
            _scrollToEnd();
            _persistConversation();
            if (isFirst) _generateTitleInBackground(t);
            // Documento criado nesta resposta: abre-o automaticamente
            // no EditTab, sem o utilizador ter de tocar em nada.
            if (scan.items.isNotEmpty) {
              widget.onCanvasCreated?.call(scan.items.last);
            }
            break;
          case ChatErrorEvent(message: final message):
            setState(() {
              _sending = false;
              _streamingText = '';
              _streamingThink = null;
              _creatingLabel = null;
              _msgs.add(ChatMessage(role: 'assistant', content: 'Erro: $message'));
            });
            _scrollToEnd();
            break;
          case ChatCreditsExhaustedEvent():
            setState(() {
              _sending = false;
              _streamingText = '';
              _streamingThink = null;
              _creatingLabel = null;
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
          _creatingLabel = null;
          _msgs.add(ChatMessage(role: 'assistant', content: 'Erro de rede: $e'));
        });
        _scrollToEnd();
      },
    );
  }

  Future<void> _generateTitleInBackground(String firstMessage) async {
    final token = authController.token;
    if (token == null) return;
    final title = await AiApiService.generateTitle(token, firstMessage);
    if (!mounted) return;
    if (_incognito) return;
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
      await ConversationsApiService.update(token, _conversationId!,
          title: title, messages: _msgs, canvases: const []);
      conversationsController.upsertLocal(ConversationItem(
        id: _conversationId!,
        title: title,
        preview: _msgs.isNotEmpty ? _msgs.last.content : '',
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ));
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
    await FilePicker.pickFiles(allowMultiple: true);
  }

  void _onAttachPhotos() async {
    await ImagePicker().pickImage(source: ImageSource.gallery);
  }

  void _onOpenCamera() async {
    await ImagePicker().pickImage(source: ImageSource.camera);
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

  /// Abre o EditTab já carregado com o documento clicado.
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
          _creatingLabel = null;
          _conversationId = null;
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
          _creatingLabel = null;
          _conversationId = null;
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
          _creatingLabel = null;
          _conversationId = null;
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
                            final scan = _scanForCanvasItems(_streamingText, () => '');
                            return _StreamingBubble(
                              s: s,
                              text: cleanAiText(scan.cleanText),
                              thinking: _streamingThink != null
                                  ? cleanAiText(_streamingThink!)
                                  : null,
                              creatingLabel: _creatingLabel,
                              widgetsEnabled: _widgetsEnabled,
                              onEnableWidgets: () => setWidgetsEnabled(true),
                              onSuggestionTap: sendSuggestedMessage,
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
            incognito: _incognito,
            sending: _sending,
            attachAnchorKey: _attachAnchorKey,
            modelAnchorKey: _modelAnchorKey,
            onSend: _send,
            onAttach: () => _openAttachSheet(_attachAnchorKey),
            onVoice: _openVoiceSheet,
            onModel: () => _openModelPopup(_modelAnchorKey),
            onClearTool: _onClearTool,
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
                AppIcon('ai_tab_filled.svg', color: s.onSurfaceVariant, size: 40, useColorAsset: true),
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
                _CanvasLink(s: s, item: item, onTap: () => onOpenCanvas(item)),
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

class _CanvasLink extends StatefulWidget {
  final AppColorScheme s;
  final LocalCanvasItem item;
  final VoidCallback onTap;
  const _CanvasLink({required this.s, required this.item, required this.onTap});
  @override State<_CanvasLink> createState() => _CanvasLinkState();
}

class _CanvasLinkState extends State<_CanvasLink> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final linkColor = widget.s.isDark ? const Color(0xFF6CB6FF) : const Color(0xFF0F6CBD);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _h = true),
      onTapCancel: ()  => setState(() => _h = false),
      onTapUp:     (_) => setState(() => _h = false),
      onTap:       widget.onTap,
      child: Opacity(
        opacity: _h ? 0.7 : 1.0,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.description_outlined, size: 16, color: linkColor),
          const SizedBox(width: 6),
          Text(
            widget.item.title,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: linkColor,
              decoration: TextDecoration.underline,
              decorationColor: linkColor,
            ),
          ),
        ]),
      ),
    );
  }
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

class _StreamingBubble extends StatelessWidget {
  final AppColorScheme s;
  final String text;
  final String? thinking;
  final String? creatingLabel;
  final bool widgetsEnabled;
  final VoidCallback onEnableWidgets;
  final ValueChanged<String> onSuggestionTap;
  const _StreamingBubble({
    required this.s,
    required this.text,
    this.thinking,
    this.creatingLabel,
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
              if (thinking != null && thinking!.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(thinking!,
                      style: TextStyle(
                          color: s.onSurfaceVariant,
                          fontSize: 12.5,
                          fontStyle: FontStyle.italic,
                          height: 1.4)),
                ),
              if (text.isNotEmpty)
                RichAiText(
                  text: text,
                  s: s,
                  widgetsEnabled: widgetsEnabled,
                  onEnableWidgets: onEnableWidgets,
                  onSuggestionTap: onSuggestionTap,
                ),
              if (creatingLabel != null) ...[
                if (text.isNotEmpty) const SizedBox(height: 10),
                _CanvasCreatingPill(s: s, label: creatingLabel!),
              ] else if (text.isEmpty)
                AiSmallDotsLoader(color: s.onSurfaceVariant),
            ],
          ),
        ),
      );
}

/// Pill "A criar..." — ícone tools.svg + texto com shimmer contínuo.
class _CanvasCreatingPill extends StatelessWidget {
  final AppColorScheme s;
  final String label;
  const _CanvasCreatingPill({required this.s, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon('tools.svg', color: s.primary, size: 15),
          const SizedBox(width: 8),
          _ShimmerText(
            text: label,
            baseColor: s.primary,
            highlightColor: s.isDark ? Colors.white : Colors.white,
          ),
        ],
      );
}

/// Texto com efeito shimmer.
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
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          decoration: BoxDecoration(
            color: s.floatingSurface,
            borderRadius: BorderRadius.circular(28),
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
// CHAT INPUT
// ══════════════════════════════════════════════════════════════

class _ChatInput extends StatelessWidget {
  final AppColorScheme s;
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final AiModel model;
  final EditorType? attachedTool;
  final bool incognito;
  final bool sending;
  final GlobalKey attachAnchorKey;
  final GlobalKey modelAnchorKey;
  final VoidCallback onSend;
  final VoidCallback onAttach;
  final VoidCallback onVoice;
  final VoidCallback onModel;
  final VoidCallback onClearTool;

  const _ChatInput({
    required this.s,
    required this.ctrl,
    required this.focusNode,
    required this.model,
    required this.attachedTool,
    required this.incognito,
    required this.sending,
    required this.attachAnchorKey,
    required this.modelAnchorKey,
    required this.onSend,
    required this.onAttach,
    required this.onVoice,
    required this.onModel,
    required this.onClearTool,
  });

  @override
  Widget build(BuildContext context) {
    final reducedShadow = <BoxShadow>[
      BoxShadow(
        color: Colors.black.withOpacity(s.isDark ? 0.16 : 0.05),
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ];

    final inner = Container(
      decoration: BoxDecoration(
        color: s.floatingSurface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: reducedShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (attachedTool != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: _AttachedToolPill(
                  s: s, type: attachedTool!, onClear: onClearTool),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: ctrl,
              focusNode: focusNode,
              minLines: 1, maxLines: 6,
              style: TextStyle(fontSize: 15, color: s.onSurface),
              cursorColor: s.primary,
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: incognito ? 'Mensagem incógnita...' : 'Conversar com Claude...',
                hintStyle: TextStyle(fontSize: 15, color: s.onSurfaceVariant),
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
                      color: s.hover,
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
                      color: s.isDark
                          ? const Color(0xFF3A3A3C)
                          : const Color(0xFFE5E5EA),
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
                        ? _SpinningIcon(asset: 'progress.svg', color: s.onPrimary)
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
              EditorTypeIcon(type.pngAsset, size: 13),
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
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          decoration: BoxDecoration(
            color: s.floatingSurface,
            borderRadius: BorderRadius.circular(28),
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
            child: EditorTypeIcon(_editorType.pngAsset, size: 20),
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
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
          decoration: BoxDecoration(
            color: s.floatingSurface,
            borderRadius: BorderRadius.circular(28),
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
                  child: Icon(
                    _recording ? Icons.mic : Icons.mic_none,
                    color: s.error,
                    size: 30,
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