// ══════════════════════════════════════════════════════════════
// FILE: lib/aitab.dart
// ══════════════════════════════════════════════════════════════
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'colors.dart';
import 'widgets.dart';
import 'edittab.dart';
import 'api_service.dart';
import 'auth_service.dart';

// ══════════════════════════════════════════════════════════════
// AI MODEL — deepseek v4 / v4 pro / R1, ligados aos providers reais
// do worker (gemini / groq) via kProviderMap em api_service.dart
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
// SYSTEM PROMPT — pede formatação rica e ensina a IA a usar o
// protocolo de canvas, agora incluindo cor de texto e destaque
// (highlight) via comandos editorApi.setColor / editorApi.setHighlight
// no documento HTML gerado.
// ══════════════════════════════════════════════════════════════

const String kAiSystemPrompt = '''
Respondes sempre em português europeu, de forma clara e bem estruturada.
Usa formatação markdown completa sempre que ajudar a organizar a informação:
negrito para destacar termos-chave, listas com marcadores ou numeradas para
sequências e opções, tabelas para comparações ou dados tabulares, e títulos
curtos quando a resposta tiver várias secções. Evita parágrafos longos e
densos quando a informação pode ser organizada visualmente.

Quando o utilizador pedir para criares, escreveres ou editares um documento,
uma folha de cálculo ou uma apresentação, gera o conteúdo e embrulha-o EXATAMENTE
neste formato, no fim da tua resposta:

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
''';

// ══════════════════════════════════════════════════════════════
// TEXT CLEANUP — agora preserva markdown estrutural (negrito, listas,
// tabelas, títulos) para o MarkdownBody renderizar; só limpa artefactos
// que não fazem sentido dentro de uma bolha de chat.
// ══════════════════════════════════════════════════════════════

String cleanAiText(String raw) {
  var t = raw;
  // Remove blocos de canvas residuais que não tenham sido apanhados pelo
  // parser (ex: streaming interrompido) para nunca vazarem para a bolha.
  t = t.replaceAll(RegExp(r'\[\[canvas:[\s\S]*?\]\]'), '');
  return t.trim();
}

// ══════════════════════════════════════════════════════════════
// CONVERSATION MENU (popup — mesmo padrão do EditTypeButton)
// ══════════════════════════════════════════════════════════════

enum ConversationAction { newChat, incognito, rename, delete }

extension ConversationActionX on ConversationAction {
  String get svgAsset => const {
        ConversationAction.newChat:   'plus.svg',
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

/// Popup unificado — substitui os antigos modais (attach/model/message
/// actions) por um único padrão de popup ancorado, igual ao usado em
/// EditTypeButton e AiConversationMenuButton. Item 1 do pedido.
class PopupMenu<T> extends StatefulWidget {
  final AppColorScheme s;
  final Widget anchor;
  final double anchorSize;
  final List<PopupMenuEntry<T>> entries;
  final ValueChanged<T> onSelect;
  final double width;
  final Alignment alignFrom; // topRight (abre para baixo) ou bottomRight (abre para cima)

  const PopupMenu({
    super.key,
    required this.s,
    required this.anchor,
    required this.entries,
    required this.onSelect,
    this.anchorSize = 36,
    this.width = 240,
    this.alignFrom = Alignment.topRight,
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
    final box = context.findRenderObject() as RenderBox;
    final off = box.localToGlobal(Offset.zero);
    final sz  = box.size;
    _ac.forward(from: 0);

    final opensUp = widget.alignFrom == Alignment.bottomRight;

    _ov = OverlayEntry(builder: (ctx) {
      final s = widget.s;
      final screenSize = MediaQuery.of(ctx).size;
      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: close,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          top: opensUp ? null : off.dy + sz.height + 6,
          bottom: opensUp ? screenSize.height - off.dy + 6 : null,
          right: (screenSize.width - off.dx - sz.width).clamp(12.0, screenSize.width - widget.width - 12),
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
        behavior: HitTestBehavior.opaque,
        onTap: toggle,
        child: widget.anchor,
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
// AI CONVERSATION MENU BUTTON — agora usa PopupMenu genérico e
// desativa a opção incógnito quando já existe conversa em curso
// (item 4: incógnito só pode ser escolhido antes da 1ª mensagem).
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
    final entries = <PopupMenuEntry<ConversationAction>>[
      PopupMenuEntry(
        value: ConversationAction.newChat,
        label: ConversationAction.newChat.label,
        svgIcon: ConversationAction.newChat.svgAsset,
      ),
      PopupMenuEntry(
        value: ConversationAction.incognito,
        label: ConversationAction.incognito.label,
        svgIcon: ConversationAction.incognito.svgAsset,
        disabled: hasMessages, // item 4
      ),
      PopupMenuEntry(
        value: ConversationAction.rename,
        label: ConversationAction.rename.label,
        svgIcon: ConversationAction.rename.svgAsset,
      ),
      PopupMenuEntry(
        value: ConversationAction.delete,
        label: ConversationAction.delete.label,
        svgIcon: ConversationAction.delete.svgAsset,
        destructive: true,
      ),
    ];

    return PopupMenu<ConversationAction>(
      s: s,
      entries: entries,
      onSelect: onSelect,
      anchor: AppTap(
        onTap: () {},
        s: s,
        child: AppIcon('more_filled.svg', color: s.onSurface, size: 20),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// AI TAB
// ══════════════════════════════════════════════════════════════

class AiTab extends StatefulWidget {
  final VoidCallback onFirstMessage;
  /// Conversa a carregar de imediato (ex: aberta a partir do drawer).
  /// Item 7 do pedido.
  final String? initialConversationId;
  final ConversationAction? externalAction;
  final VoidCallback? onExternalActionConsumed;
  final ValueChanged<bool>? onHasMessagesChanged;
  const AiTab({
    super.key,
    required this.onFirstMessage,
    this.initialConversationId,
    this.externalAction,
    this.onExternalActionConsumed,
    this.onHasMessagesChanged,
  });
  @override State<AiTab> createState() => AiTabState();
}

class AiTabState extends State<AiTab> {
  final TextEditingController _ctrl   = TextEditingController();
  final ScrollController       _scroll = ScrollController();
  final List<ChatMessage>      _msgs  = [];
  final List<CanvasItem>       _canvases = [];

  bool     _incognito    = false;
  bool     _sending      = false;
  String   _streamingText = '';
  String?  _streamingThink;
  String?  _conversationId;
  AiModel  _model        = AiModel.deepseekV4;
  EditorType? _attachedTool;
  int      _canvasIdSeq  = 0;
  CanvasKind? _creatingCanvasKind; // não-nulo enquanto a IA está a "desenhar" um canvas

  bool get _hasMessages => _msgs.isNotEmpty;

  StreamSubscription<ChatStreamEvent>? _streamSub;

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

  Future<void> _loadConversation(String id) async {
    final token = authController.token;
    if (token == null) return;
    final data = await ConversationsApiService.get(token, id);
    if (!mounted || data == null) return;
    final rawMsgs = data['messages'];
    final rawCanvases = data['canvases'];
    setState(() {
      _msgs.clear();
      if (rawMsgs is List) {
        _msgs.addAll(rawMsgs.whereType<Map<String, dynamic>>().map(ChatMessage.fromJson));
      }
      _canvases.clear();
      if (rawCanvases is List) {
        _canvases.addAll(rawCanvases.whereType<Map<String, dynamic>>().map(CanvasItem.fromJson));
      }
      _conversationId = id;
      _incognito = false;
      _sending = false;
      _streamingText = '';
      _streamingThink = null;
    });
    if (_msgs.isNotEmpty) widget.onFirstMessage();
    widget.onHasMessagesChanged?.call(_hasMessages);
    _scrollToEnd();
  }

  String _nextCanvasId() => 'cv_${DateTime.now().millisecondsSinceEpoch}_${_canvasIdSeq++}';

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
      _creatingCanvasKind = null;
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
      systemPrompt: kAiSystemPrompt,
    ).listen(
      (event) {
        if (!mounted) return;
        switch (event) {
          case ChatTokenEvent(text: final text):
            setState(() {
              _streamingText += text;
              _creatingCanvasKind = CanvasParser.hasOpenBlock(_streamingText)
                  ? CanvasParser.openBlockKind(_streamingText)
                  : null;
            });
            _scrollToEnd();
            break;
          case ChatThinkEvent(text: final text):
            setState(() => _streamingThink = (_streamingThink ?? '') + text);
            break;
          case ChatDoneEvent(fullText: final fullText):
            final finalText = fullText.isNotEmpty ? fullText : _streamingText;
            final parsed = CanvasParser.parse(finalText, idGen: _nextCanvasId);
            setState(() {
              if (parsed.cleanText.trim().isNotEmpty) {
                _msgs.add(ChatMessage(role: 'assistant', content: parsed.cleanText));
              }
              _canvases.addAll(parsed.items);
              _sending = false;
              _streamingText = '';
              _streamingThink = null;
              _creatingCanvasKind = null;
            });
            _scrollToEnd();
            _persistConversation();
            if (isFirst) _generateTitleInBackground(t);
            break;
          case ChatErrorEvent(message: final message):
            setState(() {
              _sending = false;
              _streamingText = '';
              _streamingThink = null;
              _creatingCanvasKind = null;
              _msgs.add(ChatMessage(role: 'assistant', content: 'Erro: $message'));
            });
            _scrollToEnd();
            break;
          case ChatCreditsExhaustedEvent():
            setState(() {
              _sending = false;
              _streamingText = '';
              _streamingThink = null;
              _creatingCanvasKind = null;
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
          _creatingCanvasKind = null;
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
    if (_incognito) return; // conversas incógnitas nunca são persistidas
    if (_conversationId == null) {
      final created = await ConversationsApiService.create(
        token,
        title: title,
        messages: _msgs,
        canvases: _canvases,
      );
      if (created != null && created['id'] != null) {
        _conversationId = created['id'].toString();
      }
    } else {
      await ConversationsApiService.update(token, _conversationId!,
          title: title, messages: _msgs, canvases: _canvases);
    }
  }

  Future<void> _persistConversation() async {
    if (_incognito) return; // nunca guarda conversas incógnitas
    final token = authController.token;
    if (token == null) return;
    if (_conversationId == null) {
      final created = await ConversationsApiService.create(
        token,
        title: 'Nova conversa',
        messages: _msgs,
        canvases: _canvases,
      );
      if (created != null && created['id'] != null) {
        _conversationId = created['id'].toString();
      }
    } else {
      await ConversationsApiService.update(token, _conversationId!,
          messages: _msgs, canvases: _canvases);
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
      onOpenCanvasPopup: _openCanvasPopup,
      canvasCount: _canvases.length,
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

  void _onOpenCanvas(CanvasItem item) {
    // Item 8: ao tocar num canvas, navega para o EditTab já carregado.
    editTabController.requestLoad(item);
    AiTabHostNavigation.of(context)?.goToEditTab(
      EditorTypeX.fromCanvasKind(item.kind),
    );
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
          _creatingCanvasKind = null;
          _conversationId = null;
        });
        widget.onHasMessagesChanged?.call(false);
        break;
      case ConversationAction.incognito:
        if (_hasMessages) return; // item 4: bloqueado depois de iniciar conversa
        _streamSub?.cancel();
        setState(() {
          _msgs.clear();
          _canvases.clear();
          _incognito = true;
          _sending = false;
          _streamingText = '';
          _streamingThink = null;
          _creatingCanvasKind = null;
          _conversationId = null;
        });
        widget.onHasMessagesChanged?.call(false);
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
          _creatingCanvasKind = null;
          _conversationId = null;
        });
        widget.onHasMessagesChanged?.call(false);
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

  // ── Ações da barra de reação sob cada resposta da IA ────────────

  void _onAssistantThumbUp(int index) {
    // Ponto de extensão para telemetria/feedback no worker, se/quando existir.
  }

  void _onAssistantThumbDown(int index) {
    // Ponto de extensão para telemetria/feedback no worker, se/quando existir.
  }

  void _onAssistantCopy(int index) {
    final msg = _msgs[index];
    Clipboard.setData(ClipboardData(text: msg.content));
  }

  void _onAssistantRefresh(int index) {
    // Reenvia a última mensagem do utilizador anterior a esta resposta,
    // removendo a resposta atual e tudo o que vem depois.
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
    _streamSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      color: _incognito ? s.pageBackground : null,
      child: Column(children: [
        Expanded(
          child: _incognito
              ? const _IncognitoState()
              : (_msgs.isEmpty && _streamingText.isEmpty)
                  ? _EmptyState(s: s)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      itemCount: _msgs.length + (_sending ? 1 : 0),
                      itemBuilder: (_, i) {
                        if (i >= _msgs.length) {
                          return _StreamingBubble(
                            s: s,
                            text: cleanAiText(_streamingText),
                            thinking: _streamingThink != null
                                ? cleanAiText(_streamingThink!)
                                : null,
                            creatingCanvasKind: _creatingCanvasKind,
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
                        return _AssistantBubble(
                          s: s,
                          text: cleanAiText(msg.content),
                          onThumbUp: () => _onAssistantThumbUp(i),
                          onThumbDown: () => _onAssistantThumbDown(i),
                          onCopy: () => _onAssistantCopy(i),
                          onRefresh: () => _onAssistantRefresh(i),
                        );
                      },
                    ),
        ),
        _ChatInput(
          s: s,
          ctrl: _ctrl,
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
        // Item 2: respiro extra por baixo do input, para não ficar
        // colado à borda do teclado/gesture bar do telemóvel.
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: kCupertinoOut,
          height: keyboardInset > 0 ? keyboardInset + 12 : 132,
        ),
      ]),
    );
  }
}

/// InheritedWidget leve para permitir que a AiTab (aninhada dentro de
/// AiTabHost) peça ao RootShell para mudar para a tab Editor com um
/// EditorType específico, sem acoplamento direto entre os dois widgets.
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

// ── Estado incógnito — nunca escurece o fundo; segue sempre o tema. ──

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

// ── Empty state — item 3: sem toggles/chips de ação rápida, apenas
// um estado neutro e acolhedor. ──

class _EmptyState extends StatelessWidget {
  final AppColorScheme s;
  const _EmptyState({required this.s});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppIcon('ai_tab_filled.svg', color: s.onSurfaceVariant, size: 40, useColorAsset: true),
              const SizedBox(height: 14),
              Text(
                'Como posso ajudar?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: s.onSurface,
                ),
              ),
            ],
          ),
        ),
      );
}

// ── Bolha de mensagem do utilizador ─────────────────────────────

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

// ── Bolha de resposta do assistente — agora com formatação rica
// (negrito, listas, tabelas, títulos) e uma barra de ações por baixo
// com thumb_up, thumb_down, copiar e regenerar, em ícones ligeiramente
// mais pequenos do que o resto da interface. ──

class _AssistantBubble extends StatelessWidget {
  final AppColorScheme s;
  final String text;
  final VoidCallback onThumbUp;
  final VoidCallback onThumbDown;
  final VoidCallback onCopy;
  final VoidCallback onRefresh;
  const _AssistantBubble({
    required this.s,
    required this.text,
    required this.onThumbUp,
    required this.onThumbDown,
    required this.onCopy,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichAiText(text: text, s: s),
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

// ── Barra de ações sob cada resposta da IA. Ícones ligeiramente
// menores (16px) do que os padrão da interface (18-20px), conforme
// pedido — "um pouco mais pequenos do que os de toda a interface". ──

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
        // 16px — ligeiramente menor do que o padrão de 18-20px usado
        // no resto da interface (ex: more_filled.svg, add.svg).
        child: AppIcon(widget.asset, color: s.onSurfaceVariant, size: 16),
      ),
    );
  }
}

// ── Bolha de streaming (resposta a chegar em tempo real) ────────
// Item 8: mostra "A criar documento..." com ícone tools.svg quando
// a IA está a meio de gerar um bloco de canvas.

class _StreamingBubble extends StatelessWidget {
  final AppColorScheme s;
  final String text;
  final String? thinking;
  final CanvasKind? creatingCanvasKind;
  const _StreamingBubble({
    required this.s,
    required this.text,
    this.thinking,
    this.creatingCanvasKind,
  });

  String get _creatingLabel {
    switch (creatingCanvasKind) {
      case CanvasKind.doc:        return 'A criar documento...';
      case CanvasKind.sheet:      return 'A criar folha de cálculo...';
      case CanvasKind.slide:      return 'A criar apresentação...';
      case CanvasKind.whiteboard: return 'A criar quadro branco...';
      case null:                  return '';
    }
  }

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
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
              if (text.isNotEmpty) RichAiText(text: text, s: s),
              if (creatingCanvasKind != null) ...[
                if (text.isNotEmpty) const SizedBox(height: 10),
                _CanvasCreatingPill(s: s, label: _creatingLabel),
              ] else if (text.isEmpty)
                // Item 6: loader de grade piscando enquanto não há nenhum
                // token de texto ainda (arranque da resposta).
                BlinkingGridLoader(color: s.onSurfaceVariant),
            ],
          ),
        ),
      );
}

class _CanvasCreatingPill extends StatelessWidget {
  final AppColorScheme s;
  final String label;
  const _CanvasCreatingPill({required this.s, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: s.primaryContainer.withOpacity(0.5),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon('tools.svg', color: s.primary, size: 15),
            const SizedBox(width: 8),
            Text(label,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: s.primary)),
          ],
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// BLINKING GRID LOADER — item 6 do pedido. Grelha 3x3 de pontos que
// piscam em cascata, tradução direta do loader "13. Grade piscando"
// do mockup de referência, feito em Flutter puro (sem CSS/HTML).
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
      duration: const Duration(milliseconds: _cycleMs.round()),
    )..repeat();
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  double _opacityFor(int index, double t) {
    final delay = (index * _stepDelayMs) / _cycleMs;
    var local = (t - delay) % 1.0;
    if (local < 0) local += 1.0;
    // Replica keyframes 0%,100%{opacity:.15} 50%{opacity:1}
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
// RICH AI TEXT — renderizador de markdown leve, sem dependências
// externas: negrito, itálico, títulos, listas com marcadores e
// numeradas, e tabelas. Item 9 do pedido.
// ══════════════════════════════════════════════════════════════

class RichAiText extends StatelessWidget {
  final String text;
  final AppColorScheme s;
  const RichAiText({super.key, required this.text, required this.s});

  @override
  Widget build(BuildContext context) {
    final blocks = _parseBlocks(text);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blocks,
    );
  }

  List<Widget> _parseBlocks(String raw) {
    final lines = raw.split('\n');
    final widgets = <Widget>[];
    int i = 0;
    List<List<String>>? tableRows;

    void flushTable() {
      if (tableRows != null && tableRows!.isNotEmpty) {
        widgets.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: _AiTable(rows: tableRows!, s: s),
        ));
      }
      tableRows = null;
    }

    while (i < lines.length) {
      final line = lines[i];
      final trimmed = line.trim();

      // Linha de tabela markdown: | a | b | c |
      if (trimmed.startsWith('|') && trimmed.endsWith('|') && trimmed.contains('|', 1)) {
        // ignora a linha separadora |---|---|
        final isSeparator = RegExp(r'^\|[\s\-:|]+\|$').hasMatch(trimmed);
        if (!isSeparator) {
          final cells = trimmed
              .substring(1, trimmed.length - 1)
              .split('|')
              .map((c) => c.trim())
              .toList();
          tableRows ??= [];
          tableRows!.add(cells);
        }
        i++;
        continue;
      } else if (tableRows != null) {
        flushTable();
      }

      if (trimmed.isEmpty) {
        widgets.add(const SizedBox(height: 6));
        i++;
        continue;
      }

      // Títulos: ### Texto
      final headerMatch = RegExp(r'^(#{1,4})\s+(.*)$').firstMatch(trimmed);
      if (headerMatch != null) {
        final level = headerMatch.group(1)!.length;
        final content = headerMatch.group(2)!;
        widgets.add(Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 8, bottom: 4),
          child: _formattedText(
            content, s,
            fontSize: level == 1 ? 18 : level == 2 ? 16.5 : 15,
            fontWeight: FontWeight.w700,
          ),
        ));
        i++;
        continue;
      }

      // Lista com marcadores: - item / * item
      final bulletMatch = RegExp(r'^[\-\*]\s+(.*)$').firstMatch(trimmed);
      if (bulletMatch != null) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2, right: 8),
                child: Container(
                  width: 5, height: 5,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(color: s.onSurfaceVariant, shape: BoxShape.circle),
                ),
              ),
              Expanded(child: _formattedText(bulletMatch.group(1)!, s)),
            ],
          ),
        ));
        i++;
        continue;
      }

      // Lista numerada: 1. item
      final numberedMatch = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(trimmed);
      if (numberedMatch != null) {
        widgets.add(Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Text('${numberedMatch.group(1)}.',
                    style: TextStyle(
                        fontSize: 14.5, color: s.onSurfaceVariant, fontWeight: FontWeight.w600)),
              ),
              Expanded(child: _formattedText(numberedMatch.group(2)!, s)),
            ],
          ),
        ));
        i++;
        continue;
      }

      // Parágrafo normal
      widgets.add(Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: _formattedText(trimmed, s),
      ));
      i++;
    }

    flushTable();
    return widgets;
  }

  Widget _formattedText(String raw, AppColorScheme s, {double fontSize = 14.5, FontWeight? fontWeight}) {
    final spans = <TextSpan>[];
    final pattern = RegExp(r'(\*\*.+?\*\*|__.+?__|\*[^\*]+?\*|_[^_]+?_|`[^`]+?`)');
    int last = 0;
    for (final m in pattern.allMatches(raw)) {
      if (m.start > last) {
        spans.add(TextSpan(text: raw.substring(last, m.start)));
      }
      final token = m.group(0)!;
      if (token.startsWith('**') || token.startsWith('__')) {
        spans.add(TextSpan(
          text: token.substring(2, token.length - 2),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ));
      } else if (token.startsWith('`')) {
        spans.add(TextSpan(
          text: token.substring(1, token.length - 1),
          style: TextStyle(
            fontFamily: 'monospace',
            backgroundColor: s.hover,
            fontSize: fontSize - 1,
          ),
        ));
      } else {
        spans.add(TextSpan(
          text: token.substring(1, token.length - 1),
          style: const TextStyle(fontStyle: FontStyle.italic),
        ));
      }
      last = m.end;
    }
    if (last < raw.length) spans.add(TextSpan(text: raw.substring(last)));

    return SelectableText.rich(
      TextSpan(
        style: TextStyle(
          color: s.onSurface,
          fontSize: fontSize,
          fontWeight: fontWeight ?? FontWeight.normal,
          height: 1.45,
        ),
        children: spans,
      ),
    );
  }
}

class _AiTable extends StatelessWidget {
  final List<List<String>> rows;
  final AppColorScheme s;
  const _AiTable({required this.rows, required this.s});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final header = rows.first;
    final body = rows.length > 1 ? rows.sublist(1) : <List<String>>[];

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Table(
        border: TableBorder.all(color: s.outline.withOpacity(0.4), width: 0.7),
        columnWidths: {
          for (int i = 0; i < header.length; i++) i: const FlexColumnWidth(),
        },
        children: [
          TableRow(
            decoration: BoxDecoration(color: s.hover),
            children: header
                .map((c) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      child: Text(c,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: s.onSurface)),
                    ))
                .toList(),
          ),
          for (final row in body)
            TableRow(
              children: row
                  .map((c) => Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        child: Text(c,
                            style: TextStyle(fontSize: 12.5, color: s.onSurface)),
                      ))
                  .toList(),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MESSAGE ACTIONS POPUP (editar / copiar / eliminar / selecionar texto)
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
    final desiredTop = anchorOffset.dy - 6 - 200;
    final top = desiredTop < 40 ? anchorOffset.dy + anchorSize.height + 6 : desiredTop;
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
              alignment: Alignment.topRight,
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
// SELECT TEXT SHEET — modal estilo settings, texto só selecionável
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
// CHAT INPUT — item 2 (mais respiro por baixo) e item 3 (sem toggles)
// e item 5 (ícone do botão de enviar muda para progress.svg enquanto
// a IA está a responder).
// ══════════════════════════════════════════════════════════════

class _ChatInput extends StatelessWidget {
  final AppColorScheme s;
  final TextEditingController ctrl;
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
    final inner = Container(
      decoration: BoxDecoration(
        color: s.floatingSurface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: s.floatingShadow,
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
                    // Item 5: enquanto `sending` é true, mostra progress.svg
                    // (com rotação contínua) em vez do CircularProgressIndicator
                    // genérico; volta a send.svg assim que a resposta termina.
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: incognito
          ? DashedRRectBorder(color: s.outline, radius: 22, child: inner)
          : inner,
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

// ── Pill que mostra a ferramenta ligada (aparece acima do input) ─

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
// ATTACH POPUP — item 1: agora é popup ancorado, não modal de baixo.
// Inclui a entrada "Canvas" (item 8) com cards.svg e contador.
// ══════════════════════════════════════════════════════════════

enum _AttachAction { files, photos, camera, canvas }

void showAttachPopup(
  BuildContext context,
  AppColorScheme s, {
  required GlobalKey anchorKey,
  required VoidCallback onFiles,
  required VoidCallback onPhotos,
  required VoidCallback onCamera,
  required ValueChanged<EditorType> onSelectTool,
  required VoidCallback onOpenCanvasPopup,
  required int canvasCount,
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
    final width = 240.0;
    final desiredTop = off.dy - 6 - 360;
    final top = desiredTop < 40 ? null : desiredTop;
    final bottom = desiredTop < 40 ? screenSize.height - off.dy + 6 : null;

    final entries = <PopupMenuEntry<_AttachAction>>[
      const PopupMenuEntry(value: _AttachAction.files, label: 'Arquivos', subtitle: 'Enviar qualquer tipo de arquivo', svgIcon: 'file.svg'),
      const PopupMenuEntry(value: _AttachAction.photos, label: 'Fotos', subtitle: 'Enviar fotos da galeria', svgIcon: 'image.svg'),
      const PopupMenuEntry(value: _AttachAction.camera, label: 'Câmera', subtitle: 'Tirar uma foto agora', svgIcon: 'camera.svg'),
      PopupMenuEntry(
        value: _AttachAction.canvas,
        label: 'Canvas',
        subtitle: canvasCount == 0 ? 'Ainda sem documentos' : '$canvasCount documento${canvasCount == 1 ? '' : 's'} nesta conversa',
        svgIcon: 'cards.svg',
      ),
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
        bottom: bottom,
        left: off.dx,
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
              alignment: top == null ? Alignment.bottomLeft : Alignment.topLeft,
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
                  for (final e in entries.sublist(0, 3))
                    _PopupRow<_AttachAction>(
                      s: s,
                      entry: e,
                      onTap: () {
                        close();
                        switch (e.value) {
                          case _AttachAction.files: onFiles(); break;
                          case _AttachAction.photos: onPhotos(); break;
                          case _AttachAction.camera: onCamera(); break;
                          case _AttachAction.canvas: break;
                        }
                      },
                    ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    child: Divider(height: 1),
                  ),
                  _PopupRow<_AttachAction>(
                    s: s,
                    entry: entries[3],
                    onTap: () { close(); onOpenCanvasPopup(); },
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
// CANVAS SHEET — item 8: modal com todos os documentos/folhas/slides
// criados nesta conversa, navegável verticalmente (swipe).
// ══════════════════════════════════════════════════════════════

Future<void> showCanvasSheet(
  BuildContext context,
  AppColorScheme s, {
  required List<CanvasItem> canvases,
  required ValueChanged<CanvasItem> onOpenCanvas,
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
                      final item = canvases[canvases.length - 1 - i]; // mais recente primeiro
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
  final CanvasItem item;
  final VoidCallback onTap;
  const _CanvasCard({required this.s, required this.item, required this.onTap});
  @override State<_CanvasCard> createState() => _CanvasCardState();
}

class _CanvasCardState extends State<_CanvasCard> {
  bool _h = false;

  EditorType get _editorType => EditorTypeX.fromCanvasKind(widget.item.kind);

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
// VOICE RECORD SHEET — grava com whisper via /ai/transcribe
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
// MODEL SELECT POPUP — item 1: agora popup ancorado ao botão de
// modelo, não modal de baixo. Modelos: V4 / V4 Pro / R1.
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
    final width = 250.0;
    final desiredTop = off.dy - 6 - 220;
    final top = desiredTop < 40 ? null : desiredTop;
    final bottom = desiredTop < 40 ? screenSize.height - off.dy + 6 : null;

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
        left: off.dx,
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
              alignment: top == null ? Alignment.bottomLeft : Alignment.topLeft,
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