// ══════════════════════════════════════════════════════════════
// FILE: lib/aitab/aitab.dart
// O widget principal AiTab/AiTabState — orquestração de estado,
// streaming, e o layout da tela. Toda a UI de apoio foi extraída
// para os outros arquivos deste pacote.
//
// MUDANÇA DE COMPORTAMENTO vs. versão anterior:
// _handleToolCalls agora usa processToolCalls (aitab_tools.dart),
// que separa resultados locais (visual/document/images) de
// passthrough, e SEMPRE volta a chamar o modelo depois de resultados
// locais — nunca mais fecha a mensagem só com o cartão, sem texto.
// Adicionalmente, os cartões locais agora são injetados diretamente
// no streaming notifier, eliminando a bolha intermédia prematura.
// ══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../colors.dart';
import '../widgets.dart';
import '../richtext.dart';
import '../api_service.dart';
import '../auth_service.dart';
import '../aiwidgets.dart';
import '../drawermenu.dart' show conversationsController, ConversationItem, showRenameSheet;
import '../apps/app_types.dart';
import '../apps/docs.dart';
import '../apps/sheets_app.dart';
import '../apps/slides_app.dart';
import '../apps/registry/app_registry.dart';

import 'aitab_models.dart';
import 'aitab_tools.dart';
import 'aitab_widgets_shared.dart';
import 'aitab_progress_cards.dart';
import 'aitab_message_bubbles.dart';
import 'aitab_input_bar.dart';

export 'aitab_models.dart' show ConversationAction, AiModel, AttachedFile;
export 'aitab_widgets_shared.dart' show AiConversationMenuButton, NexaLoaderLogo, ShimmerText;

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
  String?  _conversationId;
  AiModel  _model        = AiModel.deepseekFlash;
  EditorType? _attachedTool;
  int      _canvasIdSeq  = 0;

  final List<AttachedFile> _attachedFiles = [];
  int _attachedFileIdSeq = 0;

  final ValueNotifier<String> _streamingTextNotifier = ValueNotifier<String>('');
  final ValueNotifier<String?> _streamingThinkNotifier = ValueNotifier<String?>(null);

  final ValueNotifier<String> _openCanvasContentNotifier = ValueNotifier<String>('');
  final ValueNotifier<bool> _openCanvasDoneNotifier = ValueNotifier<bool>(false);
  LocalCanvasItem? _openCanvasFinalItem;

  final ValueNotifier<String> _openWidgetContentNotifier = ValueNotifier<String>('');
  final ValueNotifier<bool> _openWidgetDoneNotifier = ValueNotifier<bool>(false);

  String? _activeToolCallLabel;
  String? _activeToolCallName;
  String  _pendingLocalMarkers = '';

  List<AttachedFile> get attachedFiles => List.unmodifiable(_attachedFiles);

  int get canvasCount => _canvases.length;
  bool get widgetsEnabled => _widgetsEnabled;
  bool get webSearchEnabled => _webSearchEnabled;
  String? get conversationId => _conversationId;

  bool get _hasMessages => _msgs.isNotEmpty;

  StreamSubscription<ChatStreamEvent>? _streamSub;

  final FocusNode _inputFocus = FocusNode();
  final GlobalKey _attachButtonKey = GlobalKey();

  final GlobalKey _bottomBarKey = GlobalKey();
  double _bottomBarHeight = 96;

  @override
  void initState() {
    super.initState();
    enabledAppsController.setDefaultIfAbsent('docs', true);
    enabledAppsController.setDefaultIfAbsent('sheets', true);
    enabledAppsController.setDefaultIfAbsent('slides', true);
    enabledAppsController.setDefaultIfAbsent('sound', false);
    enabledAppsController.addListener(_onEnabledAppsChanged);
    _scroll.addListener(_onScroll);
    if (widget.initialConversationId != null) {
      _loadConversation(widget.initialConversationId!);
    }
  }

  void _onEnabledAppsChanged() {
    if (mounted) setState(() {});
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
          final scan = scanForCanvasItems(m.content, _nextCanvasId);
          _canvases.addAll(scan.items);
        }
      }
      _conversationId = id;
      _incognito = false;
      _sending = false;
      _attachedFiles.clear();
    });
    _streamingTextNotifier.value = '';
    _streamingThinkNotifier.value = null;
    _openCanvasContentNotifier.value = '';
    _openCanvasDoneNotifier.value = false;
    _openCanvasFinalItem = null;
    _openWidgetContentNotifier.value = '';
    _openWidgetDoneNotifier.value = false;
    _activeToolCallLabel = null;
    _activeToolCallName = null;
    _pendingLocalMarkers = '';
    if (_msgs.isNotEmpty) widget.onFirstMessage();
    widget.onHasMessagesChanged?.call(_hasMessages);
    _notifyHeader();
    _scrollToEnd();
  }

  String _nextCanvasId() => 'cv_${DateTime.now().millisecondsSinceEpoch}_${_canvasIdSeq++}';
  String _nextAttachedFileId() => 'af_${DateTime.now().millisecondsSinceEpoch}_${_attachedFileIdSeq++}';

  String get _emojiInstruction {
    switch (appPreferences.emojiFrequency) {
      case EmojiFrequency.never:
        return 'Nunca uses emojis nas tuas respostas.';
      case EmojiFrequency.rare:
        return 'Usa emojis apenas quando forem realmente necessários para clarificar o tom, no máximo um por resposta.';
      case EmojiFrequency.medium:
        return 'Podes usar emojis com moderação para dar vida à resposta.';
      case EmojiFrequency.often:
        return 'Usa emojis livremente para enriquecer a comunicação.';
    }
  }

  String get _effectiveSystemPrompt {
    var prompt = kAiSystemPrompt;
    prompt += '\n\n' + _emojiInstruction;
    if (appPreferences.prompt.isNotEmpty) {
      prompt += '\n\nPreferências adicionais do utilizador (segue sempre):\n${appPreferences.prompt}';
    }
    if (_widgetsEnabled) prompt += kAiWidgetsInstructions;
    if (_webSearchEnabled) prompt += kAiWebSearchInstructions;
    final enabledSlugs = enabledAppsController.all.entries
        .where((e) => e.value == true)
        .map((e) => e.key)
        .toSet();
    prompt += AppRegistry.instructionsForEnabled(enabledSlugs);
    return prompt;
  }

  void sendSuggestedMessage(String text) {
    if (text.trim().isEmpty || _sending) return;
    _ctrl.text = text;
    _send();
  }

  void _updateOpenCanvasNotifier() {
    final openMatch = RegExp(r'\[\[canvas:(doc|sheet|slide):').allMatches(_streamingTextNotifier.value).toList();
    if (openMatch.isEmpty) return;
    final last = openMatch.last;
    final afterLast = _streamingTextNotifier.value.substring(last.start);
    if (afterLast.contains(']]')) return;
    final markerEnd = _streamingTextNotifier.value.indexOf('||', last.start);
    final partial = markerEnd >= 0 ? _streamingTextNotifier.value.substring(markerEnd + 2) : '';
    _openCanvasContentNotifier.value = partial;
  }

  void _updateOpenWidgetNotifier() {
    final openMatch = RegExp(r'```(widget_[a-z]+)').allMatches(_streamingTextNotifier.value).toList();
    if (openMatch.isEmpty) return;
    final last = openMatch.last;
    final afterLast = _streamingTextNotifier.value.substring(last.start);
    final closesAfter = afterLast.contains('```', 3);
    if (closesAfter) return;
    final markerEnd = _streamingTextNotifier.value.indexOf('\n', last.start);
    if (markerEnd == -1) {
      _openWidgetContentNotifier.value = '';
    } else {
      _openWidgetContentNotifier.value = _streamingTextNotifier.value.substring(markerEnd + 1);
    }
  }

  /// Processa as tool calls recebidas do modelo. Separa resultados
  /// locais (visual/document/images — cada um vira um marcador que a
  /// UI já sabe renderizar) do passthrough (vai para o modelo).
  /// Independentemente da mistura, SEMPRE volta a chamar o modelo no
  /// fim — nunca fecha a mensagem só com cartões, sem nenhum texto.
  /// Os cartões locais são injetados diretamente no streaming
  /// notifier, para aparecerem imediatamente dentro da MESMA bolha
  /// de streaming que continuará com o texto do modelo.
  Future<void> _handleToolCalls(List<ToolCall> calls, bool isFirst, String originalUserText) async {
    if (calls.isEmpty) return;
    setState(() {
      _activeToolCallLabel = labelForToolName(calls.first.name);
      _activeToolCallName = calls.first.name;
    });
    _notifyHeader();

    final assistantToolCallMsg = ChatMessage(
      role: 'assistant',
      content: '',
      toolCalls: calls.map((c) => c.toMessageJson()).toList(),
    );

    final outcome = await processToolCalls(calls);

    if (!mounted) return;

    // Em vez de adicionar uma mensagem assistant intermédia própria
    // (o que criava uma bolha extra com a sua própria barra de ações
    // antes da resposta terminar), injetamos os marcadores locais
    // diretamente no notifier de streaming. Isto faz os cartões
    // aparecerem de imediato dentro da MESMA bolha que vai continuar
    // a crescer com o texto do modelo — uma única bolha, uma única
    // barra de ações, no fim.
    final localMarkersText = buildLocalResultMarkersText(outcome);
    setState(() {
      _activeToolCallLabel = null;
      _activeToolCallName = null;
    });
    if (localMarkersText.isNotEmpty) {
      _streamingTextNotifier.value = localMarkersText;
      _scrollToEnd();
    }

    final token = authController.token;
    if (token == null) {
      setState(() {
        _sending = false;
        _msgs.add(const ChatMessage(role: 'assistant', content: 'Sessão expirada. Volta a iniciar sessão.'));
      });
      _streamingTextNotifier.value = '';
      _pendingLocalMarkers = '';
      return;
    }

    // SEMPRE volta a chamar o modelo com os resultados das tools no
    // histórico — mesmo quando todos os resultados já foram
    // renderizados localmente, para o modelo poder comentar/explicar
    // o que acabou de ser gerado (ex: interpretar um gráfico).
    // Já não excluímos nenhuma mensagem local de _msgs, porque
    // nenhuma foi adicionada — os marcadores vivem apenas no notifier
    // de streaming até à finalização.
    final historyWithToolResults = [
      ..._msgs,
      assistantToolCallMsg,
      ...outcome.toolResultMessages,
    ];

    // Guardamos os marcadores locais para os juntar ao texto final
    // do modelo quando o stream terminar (ChatDoneEvent) — ver
    // _handleStreamEvent, onde _pendingLocalMarkers é consumido.
    _pendingLocalMarkers = localMarkersText;

    _streamSub?.cancel();
    _streamSub = AiApiService.streamChat(
      token: token,
      messages: historyWithToolResults,
      provider: _model.provider,
      language: 'pt',
      systemPrompt: _effectiveSystemPrompt,
      tools: kAllTools,
    ).listen(
      (event) => _handleStreamEvent(event, isFirst, originalUserText, historyWithToolResults),
      onError: (e) => _handleStreamError(e),
    );
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
    });
    _streamingTextNotifier.value = '';
    _streamingThinkNotifier.value = null;
    _openCanvasContentNotifier.value = '';
    _openCanvasDoneNotifier.value = false;
    _openCanvasFinalItem = null;
    _openWidgetContentNotifier.value = '';
    _openWidgetDoneNotifier.value = false;
    _activeToolCallLabel = null;
    _activeToolCallName = null;
    _pendingLocalMarkers = '';
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
      tools: _widgetsEnabled ? kAllTools : null,
    ).listen(
      (event) => _handleStreamEvent(event, isFirst, t, _msgs),
      onError: (e) => _handleStreamError(e),
    );
  }

  void _handleStreamEvent(
    ChatStreamEvent event,
    bool isFirst,
    String originalUserText,
    List<ChatMessage> historySnapshot,
  ) {
    if (!mounted) return;
    switch (event) {
      case ChatTokenEvent(text: final text):
        _streamingTextNotifier.value += text;
        _updateOpenCanvasNotifier();
        _updateOpenWidgetNotifier();
        break;
      case ChatThinkEvent(text: final text):
        _streamingThinkNotifier.value = (_streamingThinkNotifier.value ?? '') + text;
        break;
      case ChatToolCallEvent(calls: final calls):
        _handleToolCalls(calls, isFirst, originalUserText);
        break;
      case ChatDoneEvent(fullText: final fullText):
        final modelText = fullText.isNotEmpty ? fullText : _streamingTextNotifier.value;
        // Junta os marcadores locais (cartões de imagem/documento/visual
        // já resolvidos por processToolCalls) com o texto que o modelo
        // escreveu a seguir — para ficarem numa ÚNICA mensagem final,
        // com uma única bolha e uma única barra de ações no fim.
        final finalText = _pendingLocalMarkers.isNotEmpty
            ? '$_pendingLocalMarkers\n$modelText'
            : modelText;
        _pendingLocalMarkers = '';

        final scan = markCanvasItems(finalText, _nextCanvasId);
        final thinkingText = _streamingThinkNotifier.value != null ? cleanAiText(_streamingThinkNotifier.value!) : '';
        final bodyWithCanvasBlocks = resolveCanvasMarkersToBlocks(scan.textWithMarkers, scan.items);
        final combined = thinkingText.isNotEmpty
            ? '[[THINKING]]\n$thinkingText\n[[/THINKING]]\n\n$bodyWithCanvasBlocks'
            : bodyWithCanvasBlocks;

        setState(() {
          if (combined.trim().isNotEmpty || scan.items.isNotEmpty) {
            _msgs.add(ChatMessage(role: 'assistant', content: combined));
          }
          _canvases.addAll(scan.items);
          _sending = false;
          _activeToolCallLabel = null;
          _activeToolCallName = null;
        });
        _streamingTextNotifier.value = '';
        _streamingThinkNotifier.value = null;
        if (scan.items.isNotEmpty) {
          _openCanvasDoneNotifier.value = true;
          _openCanvasFinalItem = scan.items.last;
        }
        final widgetParse = parseAiWidgetBlocks(finalText);
        if (widgetParse.blocks.isNotEmpty) {
          _openWidgetDoneNotifier.value = true;
        }
        _notifyHeader();
        _scrollToEnd();
        final enabledSlugs = enabledAppsController.all.entries
            .where((e) => e.value == true)
            .map((e) => e.key)
            .toSet();
        AppRegistry.checkAiTriggers(context, combined, enabledSlugs);
        if (isFirst && _conversationId == null && !_incognito) {
          _createConversationWithGeneratedTitle(originalUserText);
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
          _activeToolCallLabel = null;
          _activeToolCallName = null;
          _msgs.add(ChatMessage(role: 'assistant', content: 'Erro: $message'));
        });
        _streamingTextNotifier.value = '';
        _streamingThinkNotifier.value = null;
        _pendingLocalMarkers = '';
        _scrollToEnd();
        break;
      case ChatCreditsExhaustedEvent():
        setState(() {
          _sending = false;
          _activeToolCallLabel = null;
          _activeToolCallName = null;
          _msgs.add(const ChatMessage(
              role: 'assistant',
              content: 'Sem créditos disponíveis. Recarrega para continuar a conversar.'));
        });
        _streamingTextNotifier.value = '';
        _streamingThinkNotifier.value = null;
        _pendingLocalMarkers = '';
        _scrollToEnd();
        authController.refreshBalance();
        break;
    }
  }

  void _handleStreamError(Object e) {
    if (!mounted) return;
    setState(() {
      _sending = false;
      _activeToolCallLabel = null;
      _activeToolCallName = null;
      _msgs.add(ChatMessage(role: 'assistant', content: 'Erro de rede: $e'));
    });
    _streamingTextNotifier.value = '';
    _streamingThinkNotifier.value = null;
    _pendingLocalMarkers = '';
    _scrollToEnd();
  }

  void _pauseGeneration() {
    if (!_sending) return;
    _streamSub?.cancel();
    _streamSub = null;
    final partial = _streamingTextNotifier.value;
    final thinkingText = _streamingThinkNotifier.value != null ? cleanAiText(_streamingThinkNotifier.value!) : '';
    final scan = markCanvasItems(partial, _nextCanvasId);
    final bodyWithCanvasBlocks = resolveCanvasMarkersToBlocks(scan.textWithMarkers, scan.items);
    setState(() {
      final combined = thinkingText.isNotEmpty
          ? '[[THINKING]]\n$thinkingText\n[[/THINKING]]\n\n$bodyWithCanvasBlocks'
          : bodyWithCanvasBlocks;
      if (combined.trim().isNotEmpty) {
        _msgs.add(ChatMessage(role: 'assistant', content: combined));
      }
      _canvases.addAll(scan.items);
      _sending = false;
      _activeToolCallLabel = null;
      _activeToolCallName = null;
    });
    _streamingTextNotifier.value = '';
    _streamingThinkNotifier.value = null;
    _pendingLocalMarkers = '';
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
              duration: const Duration(milliseconds: 300), curve: Curves.easeOutCubic);
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
    final result = await FilePicker.platform.pickFiles(allowMultiple: true, withData: true);
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
      onOpenApps: _openAppsConnectSheet,
    );
  }

  void _openAppsConnectSheet() {
    showAppsConnectSheet(
      context,
      AppTheme.of(context),
    );
  }

  void _onOpenCanvas(LocalCanvasItem item) {
    editTabController.requestLoadLocal(item);
    final screen = switch (item.kind.editorType) {
      EditorType.docs   => const DocsScreen(),
      EditorType.sheets => const SheetsScreen(),
      EditorType.slides => const SlidesScreen(),
    };
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
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
          _conversationId = null;
          _attachedFiles.clear();
        });
        _streamingTextNotifier.value = '';
        _streamingThinkNotifier.value = null;
        _openCanvasContentNotifier.value = '';
        _openCanvasDoneNotifier.value = false;
        _openCanvasFinalItem = null;
        _openWidgetContentNotifier.value = '';
        _openWidgetDoneNotifier.value = false;
        _activeToolCallLabel = null;
        _activeToolCallName = null;
        _pendingLocalMarkers = '';
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
          _conversationId = null;
          _attachedFiles.clear();
        });
        _streamingTextNotifier.value = '';
        _streamingThinkNotifier.value = null;
        _openCanvasContentNotifier.value = '';
        _openCanvasDoneNotifier.value = false;
        _openCanvasFinalItem = null;
        _openWidgetContentNotifier.value = '';
        _openWidgetDoneNotifier.value = false;
        _activeToolCallLabel = null;
        _activeToolCallName = null;
        _pendingLocalMarkers = '';
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
          _conversationId = null;
          _attachedFiles.clear();
        });
        _streamingTextNotifier.value = '';
        _streamingThinkNotifier.value = null;
        _openCanvasContentNotifier.value = '';
        _openCanvasDoneNotifier.value = false;
        _openCanvasFinalItem = null;
        _openWidgetContentNotifier.value = '';
        _openWidgetDoneNotifier.value = false;
        _activeToolCallLabel = null;
        _activeToolCallName = null;
        _pendingLocalMarkers = '';
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
    enabledAppsController.removeListener(_onEnabledAppsChanged);
    _scroll.removeListener(_onScroll);
    _ctrl.dispose();
    _scroll.dispose();
    _inputFocus.dispose();
    _streamSub?.cancel();
    _streamingTextNotifier.dispose();
    _streamingThinkNotifier.dispose();
    _openCanvasContentNotifier.dispose();
    _openCanvasDoneNotifier.dispose();
    _openWidgetContentNotifier.dispose();
    _openWidgetDoneNotifier.dispose();
    super.dispose();
  }

  List<LocalCanvasItem> _canvasesForMessage(String rawContent) {
    final scan = scanForCanvasItems(rawContent, () => '');
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

  void _measureBottomBar() {
    final ctx = _bottomBarKey.currentContext;
    if (ctx == null) return;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null) return;
    final h = box.size.height;
    if ((h - _bottomBarHeight).abs() > 0.5) {
      setState(() => _bottomBarHeight = h);
    }
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

    WidgetsBinding.instance.addPostFrameCallback((_) => _measureBottomBar());

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Container(
        color: s.pageBackground,
        child: Stack(children: [
          Column(children: [
            Expanded(
              child: Stack(children: [
                _incognito
                    ? const IncognitoState()
                    : (_msgs.isEmpty && _streamingTextNotifier.value.isEmpty)
                        ? EmptyState(s: s, topPadding: headerHeight)
                        : ListView.builder(
                            controller: _scroll,
                            padding: EdgeInsets.fromLTRB(16, headerHeight, 16, _bottomBarHeight + 12),
                            itemCount: totalCount,
                            itemBuilder: (_, i) {
                              Widget item;
                              if (showDisclaimer && i == totalCount - 1) {
                                item = const DisclaimerFooter();
                              } else if (i >= _msgs.length) {
                                item = ValueListenableBuilder<String>(
                                  valueListenable: _streamingTextNotifier,
                                  builder: (_, text, __) {
                                    final elements = parseStreamingContent(text, _nextCanvasId);
                                    final thinking = _streamingThinkNotifier.value;
                                    final isThinkingOnly = text.isEmpty &&
                                        (thinking == null || thinking.isEmpty) &&
                                        _activeToolCallLabel == null;
                                    return StreamingBubble(
                                      s: s,
                                      elements: elements,
                                      thinking: thinking != null ? cleanAiText(thinking) : null,
                                      showLogoLoader: isThinkingOnly,
                                      activeToolCallLabel: _activeToolCallLabel,
                                      activeToolCallName: _activeToolCallName,
                                      widgetsEnabled: _widgetsEnabled,
                                      onEnableWidgets: () => setWidgetsEnabled(true),
                                      onSuggestionTap: sendSuggestedMessage,
                                      onOpenCanvas: _onOpenCanvas,
                                      openCanvasContentNotifier: _openCanvasContentNotifier,
                                      openCanvasDoneNotifier: _openCanvasDoneNotifier,
                                      openCanvasFinalItem: () => _openCanvasFinalItem,
                                      openWidgetContentNotifier: _openWidgetContentNotifier,
                                      openWidgetDoneNotifier: _openWidgetDoneNotifier,
                                    );
                                  },
                                );
                              } else {
                                final msg = _msgs[i];
                                if (msg.role == 'user') {
                                  item = UserBubble(
                                    s: s,
                                    text: msg.content,
                                    onEdit: () => _onBubbleEdit(i),
                                    onCopy: () => _onBubbleCopy(i),
                                    onDelete: () => _onBubbleDelete(i),
                                    onSelectText: () => _onBubbleSelectText(i),
                                  );
                                } else {
                                  final scan = scanForCanvasItems(msg.content, () => '');
                                  final thinkScan = extractThinking(scan.cleanText);
                                  final msgCanvases = _canvasesForMessage(msg.content);
                                  item = AssistantBubble(
                                    s: s,
                                    text: cleanAiText(thinkScan.cleanText),
                                    thinking: thinkScan.thinking,
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
                                }
                              }
                              return RepaintBoundary(child: item);
                            },
                          ),
              ]),
            ),
          ]),

          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              key: _bottomBarKey,
              padding: const EdgeInsets.fromLTRB(16, 28, 16, 0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    s.pageBackground.withOpacity(0.0),
                    s.pageBackground,
                  ],
                  stops: const [0.0, 0.45],
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ChatInput(
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
                    curve: Curves.easeOutCubic,
                    height: keyboardInset > 0
                        ? keyboardInset + 16
                        : MediaQuery.of(context).padding.bottom + 16,
                  ),
                ],
              ),
            ),
          ),

          if (!_incognito && (_msgs.isNotEmpty || _streamingTextNotifier.value.isNotEmpty))
            Positioned(
              left: 0, right: 0,
              bottom: _bottomBarHeight + 8,
              child: Center(
                child: AnimatedOpacity(
                  opacity: _showScrollToBottom ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 180),
                  child: IgnorePointer(
                    ignoring: !_showScrollToBottom,
                    child: ScrollToBottomButton(
                      s: s,
                      onTap: () => _scrollToEnd(),
                    ),
                  ),
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