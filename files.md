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
// CORREÇÃO: os cards de progresso das tools mantêm-se visíveis
// até ao primeiro token de resposta do modelo (não desaparecem
// prematuramente).
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

    // NÃO limpar _activeToolCallLabel aqui. O card de progresso
    // deve permanecer visível até ao primeiro token de resposta.
    final localMarkersText = buildLocalResultMarkersText(outcome);
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
      setState(() {
        _activeToolCallLabel = null;
        _activeToolCallName = null;
      });
      return;
    }

    final historyWithToolResults = [
      ..._msgs,
      assistantToolCallMsg,
      ...outcome.toolResultMessages,
    ];

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
        // Limpa o card de progresso apenas quando o texto real começa
        if (_activeToolCallLabel != null) {
          setState(() {
            _activeToolCallLabel = null;
            _activeToolCallName = null;
          });
        }
        _streamingTextNotifier.value += text;
        _updateOpenCanvasNotifier();
        _updateOpenWidgetNotifier();
        break;
      case ChatThinkEvent(text: final text):
        // Limpa o card de progresso se houver raciocínio a chegar
        if (_activeToolCallLabel != null) {
          setState(() {
            _activeToolCallLabel = null;
            _activeToolCallName = null;
          });
        }
        _streamingThinkNotifier.value = (_streamingThinkNotifier.value ?? '') + text;
        break;
      case ChatToolCallEvent(calls: final calls):
        _handleToolCalls(calls, isFirst, originalUserText);
        break;
      case ChatDoneEvent(fullText: final fullText):
        final modelText = fullText.isNotEmpty ? fullText : _streamingTextNotifier.value;
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
                                    text: thinkScan.cleanText,
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

// ══════════════════════════════════════════════════════════════
// FILE: lib/aitab/aitab_input_bar.dart
// A barra de input do chat, pills de anexo, e todos os sheets
// acionados a partir dela (voz, opções de IA, apps, canvas,
// ficheiros anexados, seleção de texto).
// ══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import '../colors.dart';
import '../widgets.dart';
import '../widgets/animated_canvas_icon.dart';
import '../app_sheet.dart';
import '../apps/app_types.dart';
import '../apps/registry/app_registry.dart';
import '../sheets.dart';
import 'aitab_models.dart';
import 'aitab_widgets_shared.dart';

// ══════════════════════════════════════════════════════════════
// CHAT INPUT
// ══════════════════════════════════════════════════════════════

class ChatInput extends StatelessWidget {
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
  final VoidCallback onOpenAttachedFiles;

  const ChatInput({
    super.key,
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

    // Dois estados fundem-se num só widget: "compacto" (vazio, sem foco)
    // e "expandido" (com texto ou focado). AnimatedBuilder ouve tanto o
    // texto quanto o foco para decidir qual layout desenhar.
    return AnimatedBuilder(
      animation: Listenable.merge([ctrl, focusNode]),
      builder: (context, _) {
        final hasText = ctrl.text.trim().isNotEmpty;
        final expanded = hasText || focusNode.hasFocus;

        return _ChatInputShell(
          s: s,
          expanded: expanded,
          hasText: hasText,
          incognito: incognito,
          sending: sending,
          floatingShadow: floatingShadow,
          attachedTool: attachedTool,
          attachedFilesCount: attachedFilesCount,
          attachButtonKey: attachButtonKey,
          ctrl: ctrl,
          focusNode: focusNode,
          onSend: onSend,
          onPause: onPause,
          onAttach: onAttach,
          onOpenAttachedFiles: onOpenAttachedFiles,
        );
      },
    );
  }
}

class _ChatInputShell extends StatelessWidget {
  final AppColorScheme s;
  final bool expanded;
  final bool hasText;
  final bool incognito;
  final bool sending;
  final List<BoxShadow> floatingShadow;
  final EditorType? attachedTool;
  final int attachedFilesCount;
  final GlobalKey attachButtonKey;
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onPause;
  final VoidCallback onAttach;
  final VoidCallback onOpenAttachedFiles;

  const _ChatInputShell({
    required this.s,
    required this.expanded,
    required this.hasText,
    required this.incognito,
    required this.sending,
    required this.floatingShadow,
    required this.attachedTool,
    required this.attachedFilesCount,
    required this.attachButtonKey,
    required this.ctrl,
    required this.focusNode,
    required this.onSend,
    required this.onPause,
    required this.onAttach,
    required this.onOpenAttachedFiles,
  });

  Widget _sendButton() {
    // Enviar é o único botão à direita agora — mic e sliders saíram de
    // vez. Cor/opacidade obedecem hasText; toque só surte efeito com
    // texto (o GestureDetector ainda existe para não trocar de posição
    // quando o estado muda, mas onTap é null quando vazio).
    final active = hasText && !sending;
    return GestureDetector(
      onTap: sending ? onPause : (hasText ? onSend : null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: 36, height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sending
              ? Colors.white
              : active
                  ? s.primary
                  : s.hover,
          shape: BoxShape.circle,
          border: sending ? Border.all(color: s.primary) : null,
        ),
        child: AppIcon(
          sending ? 'pause' : 'arrow_up',
          color: sending
              ? s.primary
              : active
                  ? Colors.white
                  : s.onSurfaceVariant,
          size: sending ? 16 : 20,
        ),
      ),
    );
  }

  Widget _attachButton() {
    return GestureDetector(
      key: attachButtonKey,
      onTap: onAttach,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: AppIcon('add', color: s.onSurface, size: 22),
      ),
    );
  }

  Widget _textField({required int minLines, required int maxLines}) {
    return TextField(
      controller: ctrl,
      focusNode: focusNode,
      minLines: minLines, maxLines: maxLines,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 16.5, letterSpacing: 0.15).copyWith(color: s.onSurface),
      cursorColor: s.primary,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: incognito ? 'Mensagem incógnita...' : 'Pergunte qualquer coisa aqui...',
        hintStyle: TextStyle(fontSize: 16.5, letterSpacing: 0.15, color: s.onSurfaceVariant),
        contentPadding: EdgeInsets.zero,
      ),
      onSubmitted: (_) => hasText ? onSend() : null,
    );
  }

  Widget _attachmentPills() {
    if (attachedTool == null && attachedFilesCount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Wrap(
        spacing: 8, runSpacing: 8,
        children: [
          if (attachedTool != null)
            _AttachedToolPill(s: s, type: attachedTool!, onClear: () {}),
          if (attachedFilesCount > 0)
            _AttachedFilesPill(
                s: s, count: attachedFilesCount, onTap: onOpenAttachedFiles),
        ],
      ),
    );
  }

  // ── Estado compacto: uma linha só, pill baixa e bem curva ──────
  Widget _compact() {
    return Container(
      key: const ValueKey('compact'),
      height: 52,
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
      decoration: BoxDecoration(
        color: s.isDark ? s.cardBackground : s.floatingSurface,
        borderRadius: BorderRadius.circular(26), // metade da altura = pill total
        boxShadow: floatingShadow,
      ),
      child: Row(
        children: [
          _attachButton(),
          Expanded(child: _textField(minLines: 1, maxLines: 1)),
          const SizedBox(width: 4),
          _sendButton(),
          const SizedBox(width: 2),
        ],
      ),
    );
  }

  // ── Estado expandido: formato alto original, sem sliders/mic ───
  Widget _expandedForm() {
    return Container(
      key: const ValueKey('expanded'),
      decoration: BoxDecoration(
        color: s.isDark ? s.cardBackground : s.floatingSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: floatingShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _attachmentPills(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: _textField(minLines: 1, maxLines: 6),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 4, 12, 10),
            child: Row(
              children: [
                _attachButton(),
                const Spacer(),
                _sendButton(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SizeTransition(
          sizeFactor: anim,
          axisAlignment: -1.0,
          child: child,
        ),
      ),
      child: expanded ? _expandedForm() : _compact(),
    );

    return incognito
        ? DashedRRectBorder(
            color: s.outline,
            radius: expanded ? 20 : 26,
            child: content,
          )
        : content;
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
              AppIcon(iconForEditorType(type),
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
// SHEET: TEXTO SELECIONÁVEL
// ══════════════════════════════════════════════════════════════

Future<void> showSelectTextSheet(
  BuildContext context,
  AppColorScheme s, {
  required String text,
}) {
  return showCraftBottomSheet<void>(
    context: context,
    s: s,
    child: Builder(builder: (ctx) => Padding(
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
    )),
  );
}

// ══════════════════════════════════════════════════════════════
// SHEET: FICHEIROS ANEXADOS
// ══════════════════════════════════════════════════════════════

Future<void> showAttachedFilesSheet(
  BuildContext context,
  AppColorScheme s, {
  required List<AttachedFile> files,
  required ValueChanged<String> onRemove,
}) {
  return showCraftBottomSheet<void>(
    context: context,
    s: s,
    child: StatefulBuilder(
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
          color: s.surface,
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
// SHEET: CANVAS DA CONVERSA
// ══════════════════════════════════════════════════════════════

Future<void> showCanvasSheet(
  BuildContext context,
  AppColorScheme s, {
  required List<LocalCanvasItem> canvases,
  required ValueChanged<LocalCanvasItem> onOpenCanvas,
}) {
  return showCraftBottomSheet<void>(
    context: context,
    s: s,
    child: Builder(builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            AppIcon('stacks', color: s.onSurface, size: 18),
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
    )),
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
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: _h ? s.hover : s.surface,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(children: [
          AnimatedCanvasIcon(
            editorType: _editorType,
            s: s,
            size: 40,
            animated: false,
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
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHEET: GRAVAÇÃO DE VOZ
// (mantido — a entrada para ele deixou de estar no ChatInput, mas o
// sheet em si continua disponível para quem quiser acioná-lo, ex.
// dentro do novo modal unificado, se um dia precisares reativar voz)
// ══════════════════════════════════════════════════════════════

Future<void> showVoiceRecordSheet(
  BuildContext context,
  AppColorScheme s, {
  required ValueChanged<String> onTranscribed,
}) {
  return showCraftBottomSheet<void>(
    context: context,
    s: s,
    child: _VoiceRecordSheetContent(
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
// SHEET UNIFICADO: "+" — anexar, plugins, modelo, canvas, apps
// Substitui showAiOptionsSheet e o antigo showAppsConnectSheet
// como pontos de entrada separados. Duas páginas internas:
// _AttachMenuPage (raiz) <-> _ModelSelectPage (sub-tela "Modelo"),
// trocadas por AnimatedSwitcher sem fechar o sheet.
// ══════════════════════════════════════════════════════════════

enum _AttachMenuPageKind { root, modelSelect }

Future<void> showAttachMenuSheet(
  BuildContext context,
  AppColorScheme s, {
  required AiModel currentModel,
  required bool webSearchEnabled,
  required bool widgetsEnabled,
  required ValueChanged<AiModel> onModelSelected,
  required ValueChanged<bool> onWebSearchChanged,
  required ValueChanged<bool> onWidgetsChanged,
  required VoidCallback onOpenCanvas,
  required VoidCallback onCamera,
  required VoidCallback onPhotos,
  required VoidCallback onLocalFile,
}) {
  return showCraftBottomSheet<void>(
    context: context,
    s: s,
    // Curva reduzida — "um pouquinho curvo", não o arredondamento
    // pronunciado que showCraftBottomSheet usa por padrão nos outros
    // sheets deste ficheiro.
    borderRadiusOverride: 18,
    child: _AttachMenuSheetContent(
      s: s,
      currentModel: currentModel,
      webSearchEnabled: webSearchEnabled,
      widgetsEnabled: widgetsEnabled,
      onModelSelected: onModelSelected,
      onWebSearchChanged: onWebSearchChanged,
      onWidgetsChanged: onWidgetsChanged,
      onOpenCanvas: onOpenCanvas,
      onCamera: onCamera,
      onPhotos: onPhotos,
      onLocalFile: onLocalFile,
    ),
  );
}

class _AttachMenuSheetContent extends StatefulWidget {
  final AppColorScheme s;
  final AiModel currentModel;
  final bool webSearchEnabled;
  final bool widgetsEnabled;
  final ValueChanged<AiModel> onModelSelected;
  final ValueChanged<bool> onWebSearchChanged;
  final ValueChanged<bool> onWidgetsChanged;
  final VoidCallback onOpenCanvas;
  final VoidCallback onCamera;
  final VoidCallback onPhotos;
  final VoidCallback onLocalFile;

  const _AttachMenuSheetContent({
    required this.s,
    required this.currentModel,
    required this.webSearchEnabled,
    required this.widgetsEnabled,
    required this.onModelSelected,
    required this.onWebSearchChanged,
    required this.onWidgetsChanged,
    required this.onOpenCanvas,
    required this.onCamera,
    required this.onPhotos,
    required this.onLocalFile,
  });

  @override
  State<_AttachMenuSheetContent> createState() => _AttachMenuSheetContentState();
}

class _AttachMenuSheetContentState extends State<_AttachMenuSheetContent> {
  _AttachMenuPageKind _page = _AttachMenuPageKind.root;
  late AiModel _selectedModel = widget.currentModel;
  late bool _localWeb = widget.webSearchEnabled;
  late bool _localWidgets = widget.widgetsEnabled;

  void _goToModelSelect() => setState(() => _page = _AttachMenuPageKind.modelSelect);
  void _backToRoot() => setState(() => _page = _AttachMenuPageKind.root);

  void _pickModel(AiModel model) {
    setState(() => _selectedModel = model);
    widget.onModelSelected(model);
    _backToRoot();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) {
          // Entrada da sub-página desliza da direita; saída (voltar)
          // desliza de volta — dá a sensação de navegação real "dentro"
          // do modal, sem nunca fechar o showCraftBottomSheet.
          final isModelPage = child.key == const ValueKey('model_page');
          final beginOffset = isModelPage
              ? const Offset(0.06, 0)
              : const Offset(-0.06, 0);
          return FadeTransition(
            opacity: anim,
            child: SlideTransition(
              position: Tween<Offset>(begin: beginOffset, end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            ),
          );
        },
        child: _page == _AttachMenuPageKind.root
            ? _RootPage(
                key: const ValueKey('root_page'),
                s: s,
                selectedModel: _selectedModel,
                webSearchEnabled: _localWeb,
                widgetsEnabled: _localWidgets,
                onModelTap: _goToModelSelect,
                onCanvasTap: () {
                  Navigator.pop(context);
                  widget.onOpenCanvas();
                },
                onWebSearchChanged: (v) {
                  setState(() => _localWeb = v);
                  widget.onWebSearchChanged(v);
                },
                onWidgetsChanged: (v) {
                  setState(() => _localWidgets = v);
                  widget.onWidgetsChanged(v);
                },
                onCamera: () {
                  Navigator.pop(context);
                  widget.onCamera();
                },
                onPhotos: () {
                  Navigator.pop(context);
                  widget.onPhotos();
                },
                onLocalFile: () {
                  Navigator.pop(context);
                  widget.onLocalFile();
                },
              )
            : _ModelSelectPage(
                key: const ValueKey('model_page'),
                s: s,
                selectedModel: _selectedModel,
                onBack: _backToRoot,
                onPick: _pickModel,
              ),
      ),
    );
  }
}

// ── Página raiz: 3 cards horizontais + lista sem card ─────────

class _RootPage extends StatelessWidget {
  final AppColorScheme s;
  final AiModel selectedModel;
  final bool webSearchEnabled;
  final bool widgetsEnabled;
  final VoidCallback onModelTap;
  final VoidCallback onCanvasTap;
  final ValueChanged<bool> onWebSearchChanged;
  final ValueChanged<bool> onWidgetsChanged;
  final VoidCallback onCamera;
  final VoidCallback onPhotos;
  final VoidCallback onLocalFile;

  const _RootPage({
    super.key,
    required this.s,
    required this.selectedModel,
    required this.webSearchEnabled,
    required this.widgetsEnabled,
    required this.onModelTap,
    required this.onCanvasTap,
    required this.onWebSearchChanged,
    required this.onWidgetsChanged,
    required this.onCamera,
    required this.onPhotos,
    required this.onLocalFile,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 3 cards horizontais — curvos, mesma linha, iguais na largura.
          Row(
            children: [
              Expanded(
                child: _AttachOptionCard(
                  s: s, assetName: 'camera', label: 'Câmera', onTap: onCamera,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AttachOptionCard(
                  s: s, assetName: 'image', label: 'Fotos', onTap: onPhotos,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AttachOptionCard(
                  s: s, assetName: 'folder_upload', label: 'Arquivo local', onTap: onLocalFile,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Lista sem card — só cor de fundo própria por linha, igual
          // ao estilo de "Plugins"/"Habilidades" da imagem de referência.
          _PlainMenuRow(
            s: s,
            assetName: 'sliders',
            title: 'Modelo',
            subtitle: selectedModel.label,
            onTap: onModelTap,
          ),
          _PlainMenuRow(
            s: s,
            assetName: 'stacks',
            title: 'Canvas',
            onTap: onCanvasTap,
          ),
          _PlainSwitchRow(
            s: s,
            assetName: 'globe',
            title: 'Pesquisar web',
            value: webSearchEnabled,
            onChanged: onWebSearchChanged,
          ),
          _PlainSwitchRow(
            s: s,
            assetName: 'skills',
            title: 'Competências',
            value: widgetsEnabled,
            onChanged: onWidgetsChanged,
          ),
        ],
      ),
    );
  }
}

class _AttachOptionCard extends StatefulWidget {
  final AppColorScheme s;
  final String assetName;
  final String label;
  final VoidCallback onTap;
  const _AttachOptionCard({
    required this.s,
    required this.assetName,
    required this.label,
    required this.onTap,
  });
  @override State<_AttachOptionCard> createState() => _AttachOptionCardState();
}

class _AttachOptionCardState extends State<_AttachOptionCard> {
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
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: _h ? s.pressed : s.hover,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(widget.assetName, size: 22, color: s.onSurface),
            const SizedBox(height: 6),
            Text(
              widget.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: s.onSurface),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlainMenuRow extends StatelessWidget {
  final AppColorScheme s;
  final String assetName;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  const _PlainMenuRow({
    required this.s,
    required this.assetName,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            AppIcon(assetName, size: 20, color: s.onSurface),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: s.onSurface)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: TextStyle(fontSize: 12.5, color: s.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            AppIcon('chevron_forward', size: 14, color: s.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

class _PlainSwitchRow extends StatelessWidget {
  final AppColorScheme s;
  final String assetName;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _PlainSwitchRow({
    required this.s,
    required this.assetName,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          AppIcon(assetName, size: 20, color: s.onSurface),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: s.onSurface)),
          ),
          _CustomSwitch(value: value, onChanged: onChanged, s: s),
        ],
      ),
    );
  }
}

// ── Sub-página: seleção de modelo, com botão voltar ────────────

class _ModelSelectPage extends StatelessWidget {
  final AppColorScheme s;
  final AiModel selectedModel;
  final VoidCallback onBack;
  final ValueChanged<AiModel> onPick;

  const _ModelSelectPage({
    super.key,
    required this.s,
    required this.selectedModel,
    required this.onBack,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: AppIcon('chevron_back', size: 20, color: s.onSurface),
                ),
              ),
              const SizedBox(width: 4),
              Text('Modelo',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: s.onSurface)),
            ],
          ),
          const SizedBox(height: 8),
          for (final model in AiModel.values)
            _ModelOptionRow(
              s: s,
              model: model,
              selected: model == selectedModel,
              onTap: () => onPick(model),
            ),
        ],
      ),
    );
  }
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
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? s.primary.withOpacity(0.1) : s.surface,
          borderRadius: BorderRadius.circular(18),
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
              AppIcon('check', color: s.primary, size: 20),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHEET: APPS CONECTADOS
// (mantido standalone — não foi mencionado como parte do novo modal)
// ══════════════════════════════════════════════════════════════

Future<void> showAppsConnectSheet(
  BuildContext context,
  AppColorScheme s,
) {
  return showCraftBottomSheet<void>(
    context: context,
    s: s,
    title: 'Apps',
    child: _AppsConnectSheetContent(s: s),
  );
}

class _AppsConnectSheetContent extends StatefulWidget {
  final AppColorScheme s;
  const _AppsConnectSheetContent({required this.s});

  @override
  State<_AppsConnectSheetContent> createState() => _AppsConnectSheetContentState();
}

class _AppsConnectSheetContentState extends State<_AppsConnectSheetContent> {
  @override
  void initState() {
    super.initState();
    enabledAppsController.addListener(_onChanged);
  }

  @override
  void dispose() {
    enabledAppsController.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final entry in AppRegistry.all) ...[
            if (entry != AppRegistry.all.first) const SizedBox(height: 8),
            _AppSwitchRow(
              s: s,
              app: entry,
              value: enabledAppsController.isEnabled(entry.manifest.slug),
              onChanged: (v) => enabledAppsController.setEnabled(entry.manifest.slug, v),
            ),
          ],
        ],
      ),
    );
  }
}

class _AppSwitchRow extends StatelessWidget {
  final AppColorScheme s;
  final AppEntry app;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _AppSwitchRow({
    required this.s,
    required this.app,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: s.surface,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Image.asset(app.manifest.iconAsset, width: 18, height: 18),
          const SizedBox(width: 10),
          Text(app.manifest.label, style: TextStyle(fontSize: 14, color: s.onSurface)),
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
        curve: Curves.easeOutCubic,
        width: 44, height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? s.primary : s.outline,
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
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


// ══════════════════════════════════════════════════════════════
// FILE: lib/aitab/aitab_message_bubbles.dart
// ══════════════════════════════════════════════════════════════

import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../colors.dart';
import '../widgets.dart';
import '../richtext.dart';
import '../app_sheet.dart';
import '../aiwidgets.dart';
import '../apps/app_types.dart';
import '../sheets.dart';
import 'aitab_models.dart';
import 'aitab_widgets_shared.dart';
import 'aitab_progress_cards.dart';

// ──────────────────────────────────────────────────────────────
// BOLHA DO UTILIZADOR
// ──────────────────────────────────────────────────────────────

class UserBubble extends StatelessWidget {
  final AppColorScheme s;
  final String text;
  final VoidCallback onEdit;
  final VoidCallback onCopy;
  final VoidCallback onDelete;
  final VoidCallback onSelectText;
  const UserBubble({
    super.key,
    required this.s,
    required this.text,
    required this.onEdit,
    required this.onCopy,
    required this.onDelete,
    required this.onSelectText,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = s.userBubbleBg;
    final textColor = s.userBubbleText;

    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onLongPress: () {
          final box = context.findRenderObject() as RenderBox;
          final off = box.localToGlobal(Offset.zero);
          final sz = box.size;
          showMessageActionsPopup(
            context,
            s,
            anchorOffset: off,
            anchorSize: sz,
            onEdit: onEdit,
            onCopy: onCopy,
            onDelete: onDelete,
            onSelectText: onSelectText,
          );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.75),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: s.cardShadow,
          ),
          child: Text(text,
              style: TextStyle(color: textColor, fontSize: 14)),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// CARDS DE RESULTADO DE TOOL
// ──────────────────────────────────────────────────────────────

class ToolResultImageCard extends StatefulWidget {
  final AppColorScheme s;
  final String base64Png;
  final String label;

  const ToolResultImageCard({
    super.key,
    required this.s,
    required this.base64Png,
    required this.label,
  });

  @override
  State<ToolResultImageCard> createState() => _ToolResultImageCardState();
}

class _ToolResultImageCardState extends State<ToolResultImageCard> {
  Uint8List? _cachedBytes;

  @override
  void initState() {
    super.initState();
    _decode();
  }

  @override
  void didUpdateWidget(covariant ToolResultImageCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.base64Png != widget.base64Png) {
      _decode();
    }
  }

  void _decode() {
    try {
      _cachedBytes = base64Decode(widget.base64Png);
    } catch (_) {
      _cachedBytes = null;
    }
  }

  void _openFullscreen(BuildContext context) {
    final bytes = _cachedBytes;
    if (bytes == null) return;
    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => _FullscreenImageScreen(
          bytes: bytes,
          label: widget.label,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final bytes = _cachedBytes;
    return GestureDetector(
      onTap: () => _openFullscreen(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: s.pageBackground,
          borderRadius: BorderRadius.zero,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (bytes != null)
              Image.memory(bytes, fit: BoxFit.contain)
            else
              Container(
                height: 160,
                color: s.hover,
                alignment: Alignment.center,
                child: Text(
                  'Imagem inválida',
                  style: TextStyle(color: s.onSurfaceVariant, fontSize: 12),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(fontSize: 12.5, color: s.onSurfaceVariant, fontWeight: FontWeight.w500),
                    ),
                  ),
                  AppIcon('expand', size: 16, color: s.onSurfaceVariant),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenImageScreen extends StatelessWidget {
  final Uint8List bytes;
  final String label;
  const _FullscreenImageScreen({required this.bytes, required this.label});

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: s.pageBackground,
        child: SafeArea(
          child: Stack(
            children: [
              // Conteúdo central
              Center(
                child: InteractiveViewer(
                  child: Image.memory(bytes, fit: BoxFit.contain),
                ),
              ),
              // Appbar custom (igual ao settings)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        s.pageBackground,
                        s.pageBackground.withOpacity(0.0),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      _CircularBackButton(
                        s: s,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: s.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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

class _CircularBackButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const _CircularBackButton({required this.s, required this.onTap});
  @override
  State<_CircularBackButton> createState() => _CircularBackButtonState();
}

class _CircularBackButtonState extends State<_CircularBackButton> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _p = true),
      onTapCancel: () => setState(() => _p = false),
      onTapUp: (_) => setState(() => _p = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _p ? s.pressed : s.cardBackground,
          shape: BoxShape.circle,
          boxShadow: s.cardShadow,
        ),
        child: AppIcon('back', color: s.onSurface, size: 18),
      ),
    );
  }
}

class ToolResultDownloadCard extends StatelessWidget {
  final AppColorScheme s;
  final String base64Data;
  final String filename;
  final String mimeType;

  const ToolResultDownloadCard({
    super.key,
    required this.s,
    required this.base64Data,
    required this.filename,
    required this.mimeType,
  });

  String get _icon {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return 'pdf';
    if (lower.endsWith('.docx')) return 'doc';
    if (lower.endsWith('.xlsx')) return 'table';
    if (lower.endsWith('.pptx')) return 'stacks';
    return 'doc';
  }

  String get _label {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.pdf')) return 'Documento PDF';
    if (lower.endsWith('.docx')) return 'Documento Word';
    if (lower.endsWith('.xlsx')) return 'Folha de cálculo';
    if (lower.endsWith('.pptx')) return 'Apresentação';
    return 'Documento';
  }

  Future<void> _download(BuildContext context) async {
    try {
      final bytes = base64Decode(base64Data);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: filename);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao preparar download: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _download(context),
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: s.cardBackground,
          borderRadius: BorderRadius.circular(20),
          boxShadow: s.cardShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: AppIcon(_icon, size: 22, color: s.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(filename, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: s.onSurface)),
                  const SizedBox(height: 2),
                  Text(_label, style: TextStyle(fontSize: 12, color: s.onSurfaceVariant)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AppIcon('download', size: 20, color: s.primary),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// CARROSSEL DE IMAGENS DE PESQUISA
// ──────────────────────────────────────────────────────────────

class ImageSearchCarousel extends StatefulWidget {
  final AppColorScheme s;
  final List<Map<String, dynamic>> images;
  const ImageSearchCarousel({super.key, required this.s, required this.images});

  @override
  State<ImageSearchCarousel> createState() => _ImageSearchCarouselState();
}

class _ImageSearchCarouselState extends State<ImageSearchCarousel> {
  final Set<String> _failedUrls = {};

  void _markFailed(String url) {
    if (_failedUrls.contains(url)) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _failedUrls.add(url));
    });
  }

  void _openFullscreen(BuildContext context, int initialIndex) {
    final visibleImages = widget.images.where((img) {
      final url = img['imageUrl']?.toString() ?? '';
      return url.isNotEmpty && !_failedUrls.contains(url);
    }).toList();

    if (visibleImages.isEmpty) return;

    Navigator.of(context).push(
      CupertinoPageRoute(
        builder: (_) => _ImageSearchFullscreenScreen(
          images: visibleImages,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final visibleImages = widget.images.where((img) {
      final url = img['imageUrl']?.toString() ?? '';
      return url.isNotEmpty && !_failedUrls.contains(url);
    }).toList();

    if (visibleImages.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SizedBox(
        height: 160,
        child: ScrollConfiguration(
          behavior: const _ElasticScrollBehavior(),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: visibleImages.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final img = visibleImages[i];
              final url = img['imageUrl']?.toString() ?? '';
              return GestureDetector(
                key: ValueKey(url),
                onTap: () => _openFullscreen(context, i),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.network(
                    url,
                    key: ValueKey(url),
                    width: 160,
                    height: 160,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                    frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                      if (wasSynchronouslyLoaded) return child;
                      return AnimatedOpacity(
                        opacity: frame == null ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeOut,
                        child: child,
                      );
                    },
                    errorBuilder: (_, __, ___) {
                      _markFailed(url);
                      return const SizedBox(width: 160, height: 160);
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ElasticScrollBehavior extends ScrollBehavior {
  const _ElasticScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
  }

  @override
  Widget buildOverscrollIndicator(BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}

class _ImageSearchFullscreenScreen extends StatefulWidget {
  final List<Map<String, dynamic>> images;
  final int initialIndex;
  const _ImageSearchFullscreenScreen({required this.images, required this.initialIndex});

  @override
  State<_ImageSearchFullscreenScreen> createState() => _ImageSearchFullscreenScreenState();
}

class _ImageSearchFullscreenScreenState extends State<_ImageSearchFullscreenScreen> {
  late final PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final topInset = MediaQuery.of(context).padding.top;
    final currentTitle = widget.images[_current]['title']?.toString() ?? '${_current + 1}/${widget.images.length}';

    return Material(
      type: MaterialType.transparency,
      child: ColoredBox(
        color: s.pageBackground,
        child: SafeArea(
          child: Stack(
            children: [
              // Galeria de imagens
              Positioned.fill(
                child: PageView.builder(
                  controller: _pageCtrl,
                  itemCount: widget.images.length,
                  onPageChanged: (i) => setState(() => _current = i),
                  itemBuilder: (_, i) {
                    final url = widget.images[i]['imageUrl']?.toString() ?? '';
                    return Center(
                      child: InteractiveViewer(
                        child: Image.network(
                          url,
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.image_not_supported_outlined,
                            color: s.onSurfaceVariant,
                            size: 48,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Appbar custom (igual ao settings)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        s.pageBackground,
                        s.pageBackground.withOpacity(0.0),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      _CircularBackButton(
                        s: s,
                        onTap: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          currentTitle,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: s.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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

// ──────────────────────────────────────────────────────────────
// FONTES (web_search)
// ──────────────────────────────────────────────────────────────

class SourcesRow extends StatelessWidget {
  final AppColorScheme s;
  final List<String> urls;
  const SourcesRow({super.key, required this.s, required this.urls});

  String _domain(String url) {
    try {
      return Uri.parse(url).host.replaceFirst('www.', '');
    } catch (_) {
      return url;
    }
  }

  String _faviconUrl(String url) => 'https://www.google.com/s2/favicons?sz=64&domain=${_domain(url)}';

  void _openSourcesModal(BuildContext context) {
    showCraftBottomSheet<void>(
      context: context,
      s: s,
      title: 'Fontes',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: SheetOptionsGroup(
          s: s,
          options: urls.map((url) {
            return _SourceRow(s: s, url: url, domain: _domain(url), faviconUrl: _faviconUrl(url));
          }).toList(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => _openSourcesModal(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 20,
              width: 20.0 + (urls.length - 1).clamp(0, 3) * 12.0,
              child: Stack(
                children: [
                  for (int i = 0; i < urls.length.clamp(0, 4); i++)
                    Positioned(
                      left: i * 12.0,
                      child: ClipOval(
                        child: Container(
                          width: 20,
                          height: 20,
                          color: s.cardBackground,
                          child: Image.network(
                            _faviconUrl(urls[i]),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (_, __, ___) => Icon(Icons.public, size: 11, color: s.onSurfaceVariant),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Text('Fontes', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500, color: s.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

class _SourceRow extends StatelessWidget {
  final AppColorScheme s;
  final String url;
  final String domain;
  final String faviconUrl;
  const _SourceRow({required this.s, required this.url, required this.domain, required this.faviconUrl});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            ClipOval(
              child: Container(
                width: 28,
                height: 28,
                color: s.hover,
                child: Image.network(
                  faviconUrl,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => Icon(Icons.public, size: 14, color: s.onSurfaceVariant),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(domain, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: s.onSurface)),
                  Text(url, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: s.onSurfaceVariant)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// BOLHA DO ASSISTENTE (já finalizada)
// ──────────────────────────────────────────────────────────────

class AssistantBubble extends StatelessWidget {
  final AppColorScheme s;
  final String text;
  final String? thinking;
  final List<LocalCanvasItem> canvases;
  final ValueChanged<LocalCanvasItem> onOpenCanvas;
  final VoidCallback onThumbUp;
  final VoidCallback onThumbDown;
  final VoidCallback onCopy;
  final VoidCallback onRefresh;
  final bool widgetsEnabled;
  final VoidCallback onEnableWidgets;
  final ValueChanged<String> onSuggestionTap;
  const AssistantBubble({
    super.key,
    required this.s,
    required this.text,
    this.thinking,
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
              for (final v in extractVisualResults(text))
                ToolResultImageCard(s: s, base64Png: v.base64Png, label: v.label),
              for (final d in extractDocumentResults(text))
                ToolResultDownloadCard(s: s, base64Data: d.base64Data, filename: d.filename, mimeType: d.mimeType),
              ImageSearchCarousel(s: s, images: extractImages(text)),
              if (thinking != null && thinking!.isNotEmpty)
                _ThinkingHistoryCollapsible(
                  s: s,
                  thinking: thinking!,
                  widgetsEnabled: widgetsEnabled,
                ),
              if (text.isNotEmpty)
                RichAiText(
                  text: text
                      .replaceAll(kVisualResultRe, '')
                      .replaceAll(kDocumentResultRe, '')
                      .replaceAll(kSourcesRe, '')
                      .replaceAll(kImagesRe, '')
                      .trim(),
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
                sources: extractSources(text),
              ),
            ],
          ),
        ),
      );
}

class _ThinkingHistoryCollapsible extends StatelessWidget {
  final AppColorScheme s;
  final String thinking;
  final bool widgetsEnabled;

  const _ThinkingHistoryCollapsible({
    required this.s,
    required this.thinking,
    required this.widgetsEnabled,
  });

  void _openThinkingModal(BuildContext context) {
    showCraftBottomSheet<void>(
      context: context,
      s: s,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon('brain', size: 22, color: s.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Pensamento',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: s.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
              child: SingleChildScrollView(
                child: RichAiText(
                  text: thinking,
                  s: s,
                  widgetsEnabled: widgetsEnabled,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openThinkingModal(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: s.pageBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            AppIcon('brain', size: 16, color: s.onSurfaceVariant),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Pensamento',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: s.onSurfaceVariant),
              ),
            ),
            AppIcon('arrow_right', size: 14, color: s.onSurfaceVariant),
          ],
        ),
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
  final List<String> sources;
  const _AssistantActionBar({
    required this.s,
    required this.onThumbUp,
    required this.onThumbDown,
    required this.onCopy,
    required this.onRefresh,
    this.sources = const [],
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          _AssistantActionIcon(s: s, assetName: 'thumbs_up', onTap: onThumbUp),
          const SizedBox(width: 4),
          _AssistantActionIcon(s: s, assetName: 'thumbs_down', onTap: onThumbDown),
          const SizedBox(width: 4),
          _AssistantActionIcon(s: s, assetName: 'copy', onTap: onCopy),
          const SizedBox(width: 4),
          _AssistantActionIcon(s: s, assetName: 'refresh', onTap: onRefresh),
          if (sources.isNotEmpty) ...[
            const Spacer(),
            SourcesRow(s: s, urls: sources),
          ],
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
  @override
  State<_AssistantActionIcon> createState() => _AssistantActionIconState();
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

// ──────────────────────────────────────────────────────────────
// BOLHA DE STREAMING (em construção)
// ──────────────────────────────────────────────────────────────

class StreamingBubble extends StatefulWidget {
  final AppColorScheme s;
  final List<StreamElement> elements;
  final String? thinking;
  final bool showLogoLoader;
  final String? activeToolCallLabel;
  final String? activeToolCallName;
  final bool widgetsEnabled;
  final VoidCallback onEnableWidgets;
  final ValueChanged<String> onSuggestionTap;
  final ValueChanged<LocalCanvasItem> onOpenCanvas;
  final ValueNotifier<String> openCanvasContentNotifier;
  final ValueNotifier<bool> openCanvasDoneNotifier;
  final LocalCanvasItem? Function() openCanvasFinalItem;
  final ValueNotifier<String> openWidgetContentNotifier;
  final ValueNotifier<bool> openWidgetDoneNotifier;
  const StreamingBubble({
    super.key,
    required this.s,
    required this.elements,
    this.thinking,
    this.showLogoLoader = false,
    this.activeToolCallLabel,
    this.activeToolCallName,
    required this.widgetsEnabled,
    required this.onEnableWidgets,
    required this.onSuggestionTap,
    required this.onOpenCanvas,
    required this.openCanvasContentNotifier,
    required this.openCanvasDoneNotifier,
    required this.openCanvasFinalItem,
    required this.openWidgetContentNotifier,
    required this.openWidgetDoneNotifier,
  });

  @override
  State<StreamingBubble> createState() => _StreamingBubbleState();
}

class _StreamingBubbleState extends State<StreamingBubble> {
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final thinking = widget.thinking;
    final children = <Widget>[];

    if (thinking != null && thinking.isNotEmpty) {
      children.add(_ThinkingCollapsible(
        s: s,
        thinking: thinking,
        widgetsEnabled: widget.widgetsEnabled,
      ));
    }

    bool anyContent = false;
    for (final el in widget.elements) {
      switch (el) {
        case StreamText(:final text):
          final cleaned = cleanAiText(text);
          if (cleaned.trim().isEmpty) continue;
          anyContent = true;
          children.add(
            RichAiText(
              text: cleaned,
              s: s,
              widgetsEnabled: widget.widgetsEnabled,
              onEnableWidgets: widget.onEnableWidgets,
              onSuggestionTap: widget.onSuggestionTap,
            ),
          );
        case StreamCanvasBlock(:final label, :final item):
          anyContent = true;
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: CanvasProgressCard(
              s: s,
              title: label,
              item: item,
              contentNotifier: widget.openCanvasContentNotifier,
              doneNotifier: widget.openCanvasDoneNotifier,
              finalItem: widget.openCanvasFinalItem,
              onOpenCanvas: widget.onOpenCanvas,
            ),
          ));
        case StreamWidgetBlock(:final label, :final block):
          anyContent = true;
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: WidgetProgressCard(
              s: s,
              label: label,
              block: block,
              contentNotifier: widget.openWidgetContentNotifier,
              doneNotifier: widget.openWidgetDoneNotifier,
            ),
          ));
        case StreamVisualResult(:final base64Png, :final label):
          anyContent = true;
          children.add(
            Padding(
              key: ValueKey('visual_${base64Png.hashCode}'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ToolResultImageCard(
                key: ValueKey('tool_image_${base64Png.hashCode}'),
                s: s,
                base64Png: base64Png,
                label: label,
              ),
            ),
          );
        case StreamDocumentResult(:final base64Data, :final filename, :final mimeType):
          anyContent = true;
          children.add(
            Padding(
              key: ValueKey('doc_${base64Data.hashCode}'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ToolResultDownloadCard(
                key: ValueKey('download_${base64Data.hashCode}'),
                s: s,
                base64Data: base64Data,
                filename: filename,
                mimeType: mimeType,
              ),
            ),
          );
        case StreamImagesResult(:final images):
          anyContent = true;
          children.add(
            Padding(
              key: ValueKey('images_${images.map((e) => e['imageUrl']?.toString() ?? '').join('|')}'),
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ImageSearchCarousel(s: s, images: images),
            ),
          );
        case StreamGenericOpenBlock(:final label):
          anyContent = true;
          children.add(Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: StreamingMarkdownCard(s: s, label: label),
          ));
      }
    }

    if (widget.activeToolCallLabel != null) {
      anyContent = true;
      children.add(ToolCallProgressCard(
        s: s,
        label: widget.activeToolCallLabel!,
        toolName: widget.activeToolCallName ?? '',
      ));
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

class _ThinkingCollapsible extends StatelessWidget {
  final AppColorScheme s;
  final String thinking;
  final bool widgetsEnabled;

  const _ThinkingCollapsible({
    required this.s,
    required this.thinking,
    required this.widgetsEnabled,
  });

  void _openThinkingModal(BuildContext context) {
    showCraftBottomSheet<void>(
      context: context,
      s: s,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppIcon('brain', size: 22, color: s.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  'Pensamento',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: s.onSurface),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
              child: SingleChildScrollView(
                child: RichAiText(
                  text: thinking,
                  s: s,
                  widgetsEnabled: widgetsEnabled,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openThinkingModal(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: s.pageBackground,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            ShimmerBrainIcon(size: 16, color: s.onSurfaceVariant, active: true),
            const SizedBox(width: 8),
            Expanded(
              child: ShimmerText(
                text: 'Pensando...',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: s.onSurfaceVariant),
                active: true,
              ),
            ),
            AppIcon('arrow_right', size: 14, color: s.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// ESTADOS ESPECIAIS DA LISTA
// ──────────────────────────────────────────────────────────────

class IncognitoState extends StatelessWidget {
  const IncognitoState({super.key});

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

class DisclaimerFooter extends StatelessWidget {
  const DisclaimerFooter({super.key});

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

class ScrollToBottomButton extends StatefulWidget {
  final AppColorScheme s;
  final VoidCallback onTap;
  const ScrollToBottomButton({super.key, required this.s, required this.onTap});
  @override
  State<ScrollToBottomButton> createState() => _ScrollToBottomButtonState();
}

class _ScrollToBottomButtonState extends State<ScrollToBottomButton> {
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
        curve: Curves.easeOutCubic,
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

class EmptyState extends StatelessWidget {
  final AppColorScheme s;
  final double topPadding;
  const EmptyState({super.key, required this.s, required this.topPadding});

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                NexaLoaderLogo(
                  size: 112,
                  tintColor: s.isDark ? null : s.primary,
                ),
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

// ══════════════════════════════════════════════════════════════
// FILE: lib/aitab/aitab_models.dart
// Tipos de dados puros do AiTab: mensagens auxiliares, modelos de
// IA, ações de conversa, e todos os parsers de marcadores
// ([[VISUAL:...]], [[DOCUMENT:...]], [[images:...]], [[canvas:...]],
// [[THINKING]], [[sources:...]]). Zero UI neste arquivo.
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
dentro da conversa (nunca em canvas), e a várias funções (tools) para pesquisar, criar documentos, converter ficheiros, etc. As tools disponíveis são: web_search, search_images, search_market, search_place, search_calendar_date, get_weather, generate_chart, generate_mindmap, generate_qrcode, generate_barcode, generate_math, generate_table_image, generate_html_image, create_pdf, create_docx, create_xlsx, create_pptx, csv_to_xlsx, json_transform, convert_document, html_to_docx, html_to_pdf, html_to_xlsx, html_to_pptx.

Para widgets de mercado, lugar e calendário, chama primeiro a tool correspondente, espera o resultado, e escreve o bloco widget com os dados reais.

Quando usares web_search, no final da resposta escreve exatamente um bloco [[sources:url1,url2,url3]] com os links das fontes mais relevantes que usaste (máximo 4), sem nenhum outro texto a acompanhar esse bloco. Não escrevas "Fontes:" nem menciones os links de outra forma.

Quando usares search_images, as imagens já são exibidas automaticamente pela aplicação assim que a pesquisa termina — nunca escrevas URLs de imagens em texto, nunca as descrevas uma a uma, e nunca menciones "aqui estão as imagens" seguido de links. Podes apenas acrescentar um comentário breve sobre o que as imagens mostram, se fizer sentido.

Quando o resultado de uma tool de geração visual (gráfico, QR code, código de barras, cálculo, tabela visual, imagem HTML, clima) ou de criação de documento (PDF, Word, Excel, PowerPoint) já tiver sido processado, a aplicação mostra automaticamente o cartão visual ou o botão de download correspondente — nunca descrevas em texto que "aqui está o gráfico" ou "podes descarregar o PDF aqui", nunca inventes um link. Podes comentar o conteúdo (ex: interpretar os dados do gráfico) mas nunca anuncies a existência do cartão.

Não uses widget_code — blocos de código normais já aparecem automaticamente
formatados. Não uses widget_sheet — foi descontinuado (usa
[[canvas:sheet:...]] para folhas de cálculo reais). Usa estes widgets
apenas quando acrescentam valor real à resposta (dados quantitativos,
comparações visuais, localização, tempo), nunca como enfeite. Nunca
expliques ao utilizador que estás a chamar uma função ou a gerar um bloco
widget — isso é processado automaticamente e transformado num cartão
interativo, sem nunca mostrar o JSON cru nem mencionar "tool" ou "função"
na tua resposta em texto.
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
String labelForToolName(String toolName) => switch (toolName) {
      'web_search'           => 'A pesquisar na web...',
      'search_images'        => 'A pesquisar imagens...',
      'search_market'        => 'A pesquisar mercado...',
      'search_place'         => 'A localizar...',
      'search_calendar_date' => 'A interpretar data...',
      'get_weather'          => 'A obter clima...',
      'generate_chart'       => 'A gerar gráfico...',
      'generate_mindmap'     => 'A criar mapa mental...',
      'generate_qrcode'      => 'A gerar QR code...',
      'generate_barcode'     => 'A gerar código de barras...',
      'generate_math'        => 'A calcular...',
      'generate_table_image' => 'A gerar tabela visual...',
      'generate_html_image'  => 'A gerar imagem...',
      'create_pdf'           => 'A criar PDF...',
      'create_docx'          => 'A criar documento Word...',
      'create_xlsx'          => 'A criar folha de cálculo...',
      'create_pptx'          => 'A criar apresentação...',
      'csv_to_xlsx'          => 'A converter CSV...',
      'json_transform'       => 'A transformar JSON...',
      'convert_document'     => 'A converter documento...',
      'html_to_docx'         => 'A converter HTML para Word...',
      'html_to_pdf'          => 'A converter HTML para PDF...',
      'html_to_xlsx'         => 'A converter HTML para Excel...',
      'html_to_pptx'         => 'A converter HTML para PowerPoint...',
      _                      => 'A executar...',
    };

/// Mapa central nome-da-tool → asset SVG específico. Tools sem entrada
/// aqui (ou cujo ficheiro não exista em assets/icons/outline/) caem
/// automaticamente no fallback 'tools' via ToolIcon (ver aitab_tools.dart).
const Map<String, String> kToolIconAssets = {
  'web_search':           'globe',
  'search_images':        'image',
  'search_market':        'trending_up',
  'search_place':         'map_pin',
  'search_calendar_date': 'calendar',
  'get_weather':          'cloud',
  'generate_chart':       'bar_chart',
  'generate_mindmap':     'mindmap',
  'generate_qrcode':      'qr_code',
  'generate_barcode':     'barcode',
  'generate_math':        'calculator',
  'generate_table_image': 'table',
  'generate_html_image':  'image',
  'create_pdf':           'pdf',
  'create_docx':          'doc',
  'create_xlsx':          'table',
  'create_pptx':          'stacks',
  'csv_to_xlsx':          'table',
  'json_transform':       'code',
  'convert_document':     'doc',
  'html_to_docx':         'doc',
  'html_to_pdf':          'pdf',
  'html_to_xlsx':         'table',
  'html_to_pptx':         'stacks',
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
  'generate_math', 'generate_table_image', 'generate_html_image',
  'get_weather',
};

const Set<String> kDocumentTools = {
  'create_pdf', 'create_docx', 'create_xlsx', 'create_pptx',
  'csv_to_xlsx', 'convert_document',
  'html_to_docx', 'html_to_pdf', 'html_to_xlsx', 'html_to_pptx',
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

/// Executa uma única tool call contra o backend (ou localmente para
/// search_market/search_place/search_calendar_date, que já tinham
/// resolvers locais antes desta refatoração).
Future<Map<String, dynamic>> executeToolCall(ToolCall call) async {
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

  try {
    final result = await ToolsApiService.executeTool(
      token: token,
      name: call.name,
      input: call.arguments,
    );
    return result;
  } catch (e) {
    return {'found': false, 'reason': 'Erro: $e'};
  }
}

/// Processa uma lista de tool calls já resolvidas, separando o que
/// é renderizável localmente do que precisa de ir para o modelo.
Future<ToolExecutionOutcome> processToolCalls(List<ToolCall> calls) async {
  final visuals = <VisualToolResult>[];
  final documents = <DocumentToolResult>[];
  final images = <ImagesToolResult>[];
  final toolResultMsgs = <ChatMessage>[];

  for (final call in calls) {
    final resultJson = await executeToolCall(call);

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


// ══════════════════════════════════════════════════════════════
// FILE: lib/aitab/aitab_widgets_shared.dart
// Loaders reutilizáveis, popups genéricos, e o card simples de canvas.
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../colors.dart';
import '../widgets.dart';
import '../widgets/animated_canvas_icon.dart';
import '../apps/app_types.dart';
import 'aitab_models.dart';

// ══════════════════════════════════════════════════════════════
// SHIMMER TEXT
// ══════════════════════════════════════════════════════════════

class ShimmerText extends StatefulWidget {
  final String text;
  final TextStyle style;
  final bool active;
  const ShimmerText({super.key, required this.text, required this.style, this.active = true});

  @override
  State<ShimmerText> createState() => _ShimmerTextState();
}

class _ShimmerTextState extends State<ShimmerText> with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));
    if (widget.active) _c.repeat();
  }

  @override
  void didUpdateWidget(covariant ShimmerText old) {
    super.didUpdateWidget(old);
    if (widget.active != old.active) {
      widget.active ? _c.repeat() : _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) return Text(widget.text, style: widget.style);
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return ShaderMask(
          shaderCallback: (bounds) {
            final shift = (_c.value * 2 - 1) * bounds.width;
            return LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                widget.style.color!.withOpacity(0.35),
                widget.style.color!,
                widget.style.color!.withOpacity(0.35),
              ],
              stops: const [0.0, 0.5, 1.0],
            ).createShader(bounds.shift(Offset(shift, 0)));
          },
          blendMode: BlendMode.srcIn,
          child: Text(widget.text, style: widget.style.copyWith(color: Colors.white)),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// NEXA LOADER LOGO
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
  final Color? tintColor;
  final bool animated;
  const NexaLoaderLogo({
    super.key,
    this.size = 40,
    this.tintColor,
    this.animated = true,
  });

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
    );
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.animated) {
      _c.repeat();
      _shimmer.repeat(reverse: true);
    } else {
      _c.value = 0.5;
      _shimmer.value = 0.5;
    }
  }

  @override
  void didUpdateWidget(covariant NexaLoaderLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated != oldWidget.animated) {
      if (widget.animated) {
        _c.repeat();
        _shimmer.repeat(reverse: true);
      } else {
        _c.stop();
        _shimmer.stop();
      }
    }
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
    return 0.15 + (0.85 * eased);
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
          final content = Stack(
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
                        color: widget.tintColor ?? dot.color,
                        borderRadius: BorderRadius.circular(dotSize * 0.22),
                      ),
                    ),
                  ),
                ),
            ],
          );

          if (widget.tintColor != null) {
            return content;
          }

          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.75),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ).createShader(bounds.shift(Offset(shimmerX, 0)));
            },
            blendMode: BlendMode.srcIn,
            child: content,
          );
        },
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
// SHIMMER BRAIN ICON
// ══════════════════════════════════════════════════════════════

class ShimmerBrainIcon extends StatefulWidget {
  final double size;
  final Color color;
  final bool active;
  const ShimmerBrainIcon({super.key, this.size = 16, required this.color, this.active = true});

  @override
  State<ShimmerBrainIcon> createState() => _ShimmerBrainIconState();
}

class _ShimmerBrainIconState extends State<ShimmerBrainIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.active) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant ShimmerBrainIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        _controller.repeat();
      } else {
        _controller.stop();
        _controller.value = 0;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return AppIcon('brain', size: widget.size, color: widget.color);
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        final shimmerPosition = (_controller.value * 2 - 1) * widget.size;
        return ShaderMask(
          shaderCallback: (bounds) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              widget.color.withOpacity(0.3),
              widget.color,
              widget.color.withOpacity(0.3),
            ],
            stops: const [0.0, 0.5, 1.0],
          ).createShader(bounds.shift(Offset(shimmerPosition, 0))),
          child: AppIcon('brain', size: widget.size, color: Colors.white),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// POPUP MENU GENÉRICO
// ══════════════════════════════════════════════════════════════

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

class PopupMenu<T> extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final GlobalKey anchorKey = GlobalKey();
    return GestureDetector(
      key: anchorKey,
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
        if (box == null) return;
        final overlayState = Overlay.of(context);
        final overlayBox = overlayState.context.findRenderObject() as RenderBox;
        final anchorTopLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
        final anchorSize = box.size;

        final RelativeRect position = RelativeRect.fromLTRB(
          anchorTopLeft.dx,
          anchorTopLeft.dy + anchorSize.height,
          overlayBox.size.width - (anchorTopLeft.dx + anchorSize.width),
          overlayBox.size.height - (anchorTopLeft.dy + anchorSize.height),
        );

        final result = await showMenu<T>(
          context: context,
          position: position,
          color: s.floatingSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: s.outline.withOpacity(0.25)),
          ),
          items: entries.map((e) {
            final color = e.disabled
                ? s.onSurfaceVariant.withOpacity(0.4)
                : e.destructive
                    ? s.error
                    : e.selected
                        ? s.primary
                        : s.onSurface;
            return PopupMenuItem<T>(
              value: e.value,
              enabled: !e.disabled,
              padding: EdgeInsets.zero,
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: e.selected
                      ? s.primaryContainer.withOpacity(0.4)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    AppIcon(e.assetName, size: 18, color: color),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.label,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: e.selected ? FontWeight.w600 : FontWeight.w400,
                              color: color,
                            ),
                          ),
                          if (e.subtitle != null) ...[
                            const SizedBox(height: 1),
                            Text(
                              e.subtitle!,
                              style: TextStyle(fontSize: 11.5, color: s.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (e.selected)
                      AppIcon('check', size: 16, color: s.primary),
                  ],
                ),
              ),
            );
          }).toList(),
        );

        if (result != null) onSelect(result);
      },
      child: IgnorePointer(child: anchor),
    );
  }
}

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

class _HeaderMenuButton extends StatelessWidget {
  final AppColorScheme s;
  final bool hasMessages;
  final ValueChanged<ConversationAction> onSelect;

  const _HeaderMenuButton({
    required this.s,
    required this.hasMessages,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final GlobalKey anchorKey = GlobalKey();
    return GestureDetector(
      key: anchorKey,
      behavior: HitTestBehavior.opaque,
      onTap: () async {
        final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
        if (box == null) return;
        final overlayState = Overlay.of(context);
        final overlayBox = overlayState.context.findRenderObject() as RenderBox;
        final anchorTopLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
        final anchorSize = box.size;

        final RelativeRect position = RelativeRect.fromLTRB(
          anchorTopLeft.dx,
          anchorTopLeft.dy + anchorSize.height,
          overlayBox.size.width - (anchorTopLeft.dx + anchorSize.width),
          overlayBox.size.height - (anchorTopLeft.dy + anchorSize.height),
        );

        final result = await showMenu<ConversationAction>(
          context: context,
          position: position,
          color: s.floatingSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: s.outline.withOpacity(0.25)),
          ),
          items: [
            PopupMenuItem<ConversationAction>(
              value: ConversationAction.newChat,
              padding: EdgeInsets.zero,
              child: _buildMenuItem(s, ConversationAction.newChat, false, false),
            ),
            PopupMenuItem<ConversationAction>(
              value: ConversationAction.incognito,
              enabled: !hasMessages,
              padding: EdgeInsets.zero,
              child: _buildMenuItem(s, ConversationAction.incognito, false, hasMessages),
            ),
            PopupMenuItem<ConversationAction>(
              value: ConversationAction.rename,
              padding: EdgeInsets.zero,
              child: _buildMenuItem(s, ConversationAction.rename, false, false),
            ),
            PopupMenuItem<ConversationAction>(
              value: ConversationAction.delete,
              padding: EdgeInsets.zero,
              child: _buildMenuItem(s, ConversationAction.delete, true, false),
            ),
          ],
        );

        if (result != null) onSelect(result);
      },
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        child: AppIcon('more_vert', color: s.onSurface, size: 20),
      ),
    );
  }

  Widget _buildMenuItem(
    AppColorScheme s,
    ConversationAction action,
    bool destructive,
    bool disabled,
  ) {
    final color = disabled
        ? s.onSurfaceVariant.withOpacity(0.4)
        : destructive
            ? s.error
            : s.onSurface;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          AppIcon(action.assetName, size: 18, color: color),
          const SizedBox(width: 10),
          Text(
            action.label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

void showMessageActionsPopup(
  BuildContext context,
  AppColorScheme s, {
  required Offset anchorOffset,
  required Size anchorSize,
  required VoidCallback onEdit,
  required VoidCallback onCopy,
  required VoidCallback onDelete,
  required VoidCallback onSelectText,
}) async {
  final overlayState = Overlay.of(context);
  final overlayBox = overlayState.context.findRenderObject() as RenderBox;
  final screenSize = overlayBox.size;

  final RelativeRect position = RelativeRect.fromLTRB(
    anchorOffset.dx,
    anchorOffset.dy,
    screenSize.width - (anchorOffset.dx + anchorSize.width),
    screenSize.height - (anchorOffset.dy + anchorSize.height),
  );

  final result = await showMenu<int>(
    context: context,
    position: position,
    color: s.floatingSurface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(color: s.outline.withOpacity(0.25)),
    ),
    items: [
      PopupMenuItem<int>(
        value: 0,
        padding: EdgeInsets.zero,
        child: _buildMessageMenuItem(s, 'pencil', 'Editar'),
      ),
      PopupMenuItem<int>(
        value: 1,
        padding: EdgeInsets.zero,
        child: _buildMessageMenuItem(s, 'copy', 'Copiar'),
      ),
      PopupMenuItem<int>(
        value: 2,
        padding: EdgeInsets.zero,
        child: _buildMessageMenuItem(s, 'select_text', 'Selecionar texto'),
      ),
      PopupMenuItem<int>(
        value: 3,
        padding: EdgeInsets.zero,
        child: _buildMessageMenuItem(s, 'trash', 'Eliminar', destructive: true),
      ),
    ],
  );

  switch (result) {
    case 0: onEdit(); break;
    case 1: onCopy(); break;
    case 2: onSelectText(); break;
    case 3: onDelete(); break;
  }
}

Widget _buildMessageMenuItem(AppColorScheme s, String assetName, String label, {bool destructive = false}) {
  final color = destructive ? s.error : s.onSurface;
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        AppIcon(assetName, size: 18, color: color),
        const SizedBox(width: 10),
        Text(
          label,
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: color),
        ),
      ],
    ),
  );
}

void showAttachPopup(
  BuildContext context,
  AppColorScheme s, {
  required GlobalKey anchorKey,
  required VoidCallback onFiles,
  required VoidCallback onPhotos,
  required VoidCallback onCamera,
  required ValueChanged<EditorType> onSelectTool,
}) async {
  final anchorContext = anchorKey.currentContext;
  if (anchorContext == null) return;
  final box = anchorContext.findRenderObject() as RenderBox;
  final anchorOffset = box.localToGlobal(Offset.zero);
  final anchorSize = box.size;
  final overlayState = Overlay.of(context);
  final overlayBox = overlayState.context.findRenderObject() as RenderBox;
  final screenSize = overlayBox.size;

  final RelativeRect position = RelativeRect.fromLTRB(
    anchorOffset.dx,
    anchorOffset.dy,
    screenSize.width - (anchorOffset.dx + anchorSize.width),
    screenSize.height - (anchorOffset.dy + anchorSize.height),
  );

  final result = await showMenu<int>(
    context: context,
    position: position,
    color: s.floatingSurface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(color: s.outline.withOpacity(0.25)),
    ),
    items: [
      PopupMenuItem<int>(
        value: 0,
        padding: EdgeInsets.zero,
        child: _buildAttachMenuItem(s, 'folder', 'Arquivos', 'Enviar qualquer tipo de arquivo'),
      ),
      PopupMenuItem<int>(
        value: 1,
        padding: EdgeInsets.zero,
        child: _buildAttachMenuItem(s, 'image', 'Fotos', 'Enviar fotos da galeria'),
      ),
      PopupMenuItem<int>(
        value: 2,
        padding: EdgeInsets.zero,
        child: _buildAttachMenuItem(s, 'camera', 'Câmera', 'Tirar uma foto agora'),
      ),
    ],
  );

  switch (result) {
    case 0: onFiles(); break;
    case 1: onPhotos(); break;
    case 2: onCamera(); break;
  }
}

Widget _buildAttachMenuItem(AppColorScheme s, String assetName, String label, String subtitle) {
  return Container(
    margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 6),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        AppIcon(assetName, size: 18, color: s.onSurface),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: s.onSurface)),
              const SizedBox(height: 1),
              Text(subtitle, style: TextStyle(fontSize: 11.5, color: s.onSurfaceVariant)),
            ],
          ),
        ),
      ],
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// CANVAS CARD SIMPLES
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
            AnimatedCanvasIcon(
              editorType: item.kind.editorType,
              s: s,
              size: 44,
              animated: false,
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
          ],
        ),
      ),
    );
  }
}


// ══════════════════════════════════════════════════════════════
// FILE: lib/api_service.dart
// ══════════════════════════════════════════════════════════════
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

const String kApiBase = 'https://ipc.alfredopjonas.workers.dev';

// ── Providers reais suportados pelo worker. O backend é DeepSeek —
//    os 3 modelos (flash/pro/reasoning) são todos provider "deepseek",
//    diferenciados pelo campo model. gemini/groq foram removidos
//    porque o chat principal já não os usa.
enum ApiProvider { deepseekFlash, deepseekPro, deepseekReasoning }

class ProviderConfig {
  final String provider; // será sempre "deepseek"
  final String deepseekModel;
  const ProviderConfig(this.provider, {required this.deepseekModel});
}

const Map<ApiProvider, ProviderConfig> kProviderMap = {
  ApiProvider.deepseekFlash:     ProviderConfig('deepseek', deepseekModel: 'flash'),
  ApiProvider.deepseekPro:       ProviderConfig('deepseek', deepseekModel: 'pro'),
  ApiProvider.deepseekReasoning: ProviderConfig('deepseek', deepseekModel: 'reasoning'),
};

// ══════════════════════════════════════════════════════════════
// MENSAGEM DE CHAT
// ══════════════════════════════════════════════════════════════
class ChatMessage {
  final String role; // "user" | "assistant" | "tool"
  final String content;
  final List<Map<String, dynamic>>? attachments;
  // Presentes apenas em mensagens do ciclo de tool calling:
  final String? toolCallId; // usado em mensagens role:"tool" — id da chamada que este resultado responde
  final List<Map<String, dynamic>>? toolCalls; // usado em mensagens role:"assistant" que pediram tool calls
  final String? name; // nome da função, usado em mensagens role:"tool"

  const ChatMessage({
    required this.role,
    required this.content,
    this.attachments,
    this.toolCallId,
    this.toolCalls,
    this.name,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
        if (attachments != null && attachments!.isNotEmpty) 'attachments': attachments,
        if (toolCallId != null) 'tool_call_id': toolCallId,
        if (toolCalls != null) 'tool_calls': toolCalls,
        if (name != null) 'name': name,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        role: j['role']?.toString() ?? 'user',
        content: j['content']?.toString() ?? '',
        attachments: (j['attachments'] is List)
            ? (j['attachments'] as List).whereType<Map<String, dynamic>>().toList()
            : null,
        toolCallId: j['tool_call_id']?.toString(),
        toolCalls: (j['tool_calls'] is List)
            ? (j['tool_calls'] as List).whereType<Map<String, dynamic>>().toList()
            : null,
        name: j['name']?.toString(),
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
// TOOL CALLING
// ══════════════════════════════════════════════════════════════
//
// Fluxo: 1) Flutter manda `tools` no body do POST /ai/chat.
// 2) DeepSeek devolve tool_calls em vez de content, via SSE
//    (delta.tool_calls, fragmentado em vários chunks por índice).
// 3) Ao fechar o stream (finish_reason == "tool_calls" ou [DONE]
//    com tool_calls pendentes), emitimos ChatToolCallEvent com a
//    lista de chamadas já reconstruídas.
// 4) Quem consome o stream (aitab.dart) executa a função local
//    correspondente, e faz uma SEGUNDA chamada a streamChat
//    passando o histórico + a mensagem assistant com tool_calls +
//    uma mensagem role:"tool" com o resultado. Só essa segunda
//    resposta é que chega ao utilizador como texto final.
// ══════════════════════════════════════════════════════════════

class ToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;
  const ToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });

  Map<String, dynamic> toJson() => {
        'type': 'function',
        'function': {
          'name': name,
          'description': description,
          'parameters': parameters,
        },
      };
}

class ToolCall {
  final String id;
  final String name;
  final String argumentsJson;
  const ToolCall({required this.id, required this.name, required this.argumentsJson});

  Map<String, dynamic> get arguments {
    if (argumentsJson.trim().isEmpty) return {};
    try {
      final decoded = jsonDecode(argumentsJson);
      return decoded is Map<String, dynamic> ? decoded : {};
    } catch (_) {
      return {};
    }
  }

  /// Representação desta chamada como apareceria numa mensagem
  /// assistant com tool_calls, para reenviar no histórico da
  /// segunda chamada.
  Map<String, dynamic> toMessageJson() => {
        'id': id,
        'type': 'function',
        'function': {'name': name, 'arguments': argumentsJson},
      };
}

class ChatToolCallEvent extends ChatStreamEvent {
  final List<ToolCall> calls;
  ChatToolCallEvent(this.calls);
}

/// Se o Worker rejeitar `tools` uma vez (400/422) numa sessão de
/// app, paramos de o mandar nas chamadas seguintes em vez de
/// falhar sempre. Reinicia a cada abertura da app (estado em
/// memória, não persistido).
class ToolCallingSupport {
  static bool _supported = true;
  static bool get supported => _supported;
  static void markUnsupported() => _supported = false;
}

// ══════════════════════════════════════════════════════════════
// CANVAS
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
  final String content;
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
    String? currentPassword,
    Map<String, dynamic>? preferences,
  }) async {
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (password != null) body['password'] = password;
    if (currentPassword != null) body['currentPassword'] = currentPassword;
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
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$kApiBase/conversations'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'title': title,
          'messages': messages.map((m) => m.toJson()).toList(),
          if (model != null) 'model': model,
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
  }) async {
    try {
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (messages != null) body['messages'] = messages.map((m) => m.toJson()).toList();
      await http.put(
        Uri.parse('$kApiBase/conversations/$id'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(body),
      );
    } catch (_) {}
  }

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
// EVENTS API
// ══════════════════════════════════════════════════════════════
class EventItem {
  final String id;
  final String title;
  final String description;
  final int startAt;
  final int endAt;
  final bool allDay;
  final String color;

  const EventItem({
    required this.id,
    required this.title,
    required this.description,
    required this.startAt,
    required this.endAt,
    required this.allDay,
    required this.color,
  });

  DateTime get startDate => DateTime.fromMillisecondsSinceEpoch(startAt);
  DateTime get endDate => DateTime.fromMillisecondsSinceEpoch(endAt);

  factory EventItem.fromJson(Map<String, dynamic> j) => EventItem(
        id: j['id']?.toString() ?? '',
        title: j['title']?.toString() ?? '',
        description: j['description']?.toString() ?? '',
        startAt: (j['startAt'] is num) ? (j['startAt'] as num).toInt() : 0,
        endAt: (j['endAt'] is num) ? (j['endAt'] as num).toInt() : 0,
        allDay: j['allDay'] == true,
        color: j['color']?.toString() ?? '#6F5AF6',
      );
}

class EventsApiService {
  static Future<List<EventItem>> list(String token) async {
    try {
      final res = await http.get(
        Uri.parse('$kApiBase/events'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return [];
      final data = _decode(res.body);
      final events = data['events'];
      if (events is! List) return [];
      return events.whereType<Map<String, dynamic>>().map(EventItem.fromJson).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<EventItem?> create(
    String token, {
    required String title,
    String description = '',
    required int startAt,
    int? endAt,
    bool allDay = false,
    String color = '#6F5AF6',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$kApiBase/events'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode({
          'title': title,
          'description': description,
          'startAt': startAt,
          if (endAt != null) 'endAt': endAt,
          'allDay': allDay,
          'color': color,
        }),
      );
      if (res.statusCode < 200 || res.statusCode >= 300) return null;
      return EventItem.fromJson(_decode(res.body));
    } catch (_) {
      return null;
    }
  }

  static Future<bool> delete(String token, String id) async {
    try {
      final res = await http.delete(
        Uri.parse('$kApiBase/events/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      return res.statusCode >= 200 && res.statusCode < 300;
    } catch (_) {
      return false;
    }
  }
}

// ══════════════════════════════════════════════════════════════
// AI CHAT API
// ══════════════════════════════════════════════════════════════
class AiApiService {
  static Stream<ChatStreamEvent> streamChat({
    required String token,
    required List<ChatMessage> messages,
    required ApiProvider provider,
    String language = 'pt',
    String? systemPrompt,
    List<ToolDefinition>? tools,
  }) async* {
    final cfg = kProviderMap[provider]!;
    final client = http.Client();
    final sendTools = tools != null && tools.isNotEmpty && ToolCallingSupport.supported;

    try {
      final req = http.Request('POST', Uri.parse('$kApiBase/ai/chat'));
      req.headers['Content-Type'] = 'application/json';
      req.headers['Authorization'] = 'Bearer $token';
      req.body = jsonEncode({
        'messages': messages.map((m) => m.toJson()).toList(),
        'stream': true,
        'language': language,
        'provider': cfg.provider,
        'model': cfg.deepseekModel,
        if (systemPrompt != null && systemPrompt.trim().isNotEmpty) 'systemPrompt': systemPrompt,
        if (sendTools) 'tools': tools.map((t) => t.toJson()).toList(),
      });

      final streamed = await client.send(req);

      if (streamed.statusCode == 402) {
        yield ChatCreditsExhaustedEvent();
        return;
      }
      if (streamed.statusCode < 200 || streamed.statusCode >= 300) {
        final bodyStr = await streamed.stream.bytesToString();
        // Se mandámos `tools` e o Worker rejeitou por causa disso,
        // desativa para as próximas chamadas desta sessão de app —
        // a chamada seguinte (sem tools) tende a funcionar normalmente
        // em vez de falhar sempre.
        if (sendTools && (streamed.statusCode == 400 || streamed.statusCode == 422)) {
          ToolCallingSupport.markUnsupported();
        }
        String msg = 'Erro ${streamed.statusCode}';
        try {
          final decoded = jsonDecode(bodyStr);
          if (decoded is Map && decoded['error'] != null) msg = decoded['error'].toString();
        } catch (_) {}
        yield ChatErrorEvent(msg);
        return;
      }

      String pending = '';
      String fullText = '';
      // Tool calls chegam fragmentados por índice ao longo de vários
      // chunks SSE (ex: chunk 1 traz o nome, chunks seguintes trazem
      // pedaços dos argumentos). Acumulamos por índice até ao fim.
      final Map<int, ({String? id, String name, StringBuffer args})> pendingToolCalls = {};

      List<ToolCall> finalizeToolCalls() {
        final entries = pendingToolCalls.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));
        return entries
            .where((e) => e.value.id != null && e.value.name.isNotEmpty)
            .map((e) => ToolCall(
                  id: e.value.id!,
                  name: e.value.name,
                  argumentsJson: e.value.args.toString(),
                ))
            .toList();
      }

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
            if (pendingToolCalls.isNotEmpty) {
              final calls = finalizeToolCalls();
              if (calls.isNotEmpty) {
                yield ChatToolCallEvent(calls);
                return;
              }
            }
            yield ChatDoneEvent(fullText);
            return;
          }
          try {
            final decoded = jsonDecode(raw);
            if (decoded is! Map) continue;

            final choices = decoded['choices'];
            bool handledAsChoices = false;
            if (choices is List && choices.isNotEmpty) {
              final choice = choices[0];
              final delta = choice is Map ? choice['delta'] : null;

              if (delta is Map) {
                final rawToolCalls = delta['tool_calls'];
                if (rawToolCalls is List) {
                  for (final tc in rawToolCalls) {
                    if (tc is! Map) continue;
                    final index = (tc['index'] is num) ? (tc['index'] as num).toInt() : 0;
                    final fn = tc['function'];
                    final existing = pendingToolCalls[index];
                    final id = tc['id']?.toString() ?? existing?.id;
                    final name = (fn is Map ? fn['name']?.toString() : null) ?? existing?.name ?? '';
                    final argsFragment = (fn is Map ? fn['arguments']?.toString() : null) ?? '';
                    final buf = existing?.args ?? StringBuffer();
                    buf.write(argsFragment);
                    pendingToolCalls[index] = (id: id, name: name, args: buf);
                  }
                  handledAsChoices = true;
                }

                final deltaContent = delta['content']?.toString();
                final deltaThink = delta['reasoning_content']?.toString() ?? delta['reasoning']?.toString();
                if (deltaThink != null && deltaThink.isNotEmpty) {
                  yield ChatThinkEvent(deltaThink);
                  handledAsChoices = true;
                }
                if (deltaContent != null && deltaContent.isNotEmpty) {
                  fullText += deltaContent;
                  yield ChatTokenEvent(deltaContent);
                  handledAsChoices = true;
                }
              }

              final fr = choice is Map ? choice['finish_reason']?.toString() : null;
              if (fr != null && fr.isNotEmpty && fr != 'null') {
                if (fr == 'tool_calls' && pendingToolCalls.isNotEmpty) {
                  final calls = finalizeToolCalls();
                  if (calls.isNotEmpty) {
                    yield ChatToolCallEvent(calls);
                    return;
                  }
                }
                yield ChatDoneEvent(fullText);
                return;
              }
              if (handledAsChoices) continue;
            }

            final candidates = decoded['candidates'];
            if (candidates is List && candidates.isNotEmpty) {
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
                    yield ChatTokenEvent(text);
                  }
                }
              }
              final finishReason = first is Map ? first['finishReason']?.toString() : null;
              if (finishReason == 'STOP' || finishReason == 'MAX_TOKENS') {
                yield ChatDoneEvent(fullText);
                return;
              }
            }
          } catch (_) {}
        }
      }

      if (pendingToolCalls.isNotEmpty) {
        final calls = finalizeToolCalls();
        if (calls.isNotEmpty) {
          yield ChatToolCallEvent(calls);
          return;
        }
      }
      yield ChatDoneEvent(fullText);
    } catch (e) {
      yield ChatErrorEvent('Erro de rede: $e');
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>> chatOnce({
    required String token,
    required List<ChatMessage> messages,
    required ApiProvider provider,
    String language = 'pt',
    String? systemPrompt,
    List<ToolDefinition>? tools,
  }) async {
    final cfg = kProviderMap[provider]!;
    final sendTools = tools != null && tools.isNotEmpty && ToolCallingSupport.supported;
    final res = await http.post(
      Uri.parse('$kApiBase/ai/chat'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({
        'messages': messages.map((m) => m.toJson()).toList(),
        'stream': false,
        'language': language,
        'provider': cfg.provider,
        'model': cfg.deepseekModel,
        if (systemPrompt != null && systemPrompt.trim().isNotEmpty) 'systemPrompt': systemPrompt,
        if (sendTools) 'tools': tools.map((t) => t.toJson()).toList(),
      }),
    );
    final data = _decode(res.body);
    if (res.statusCode == 402) throw CreditsExhaustedException();
    if (res.statusCode < 200 || res.statusCode >= 300) {
      if (sendTools && (res.statusCode == 400 || res.statusCode == 422)) {
        ToolCallingSupport.markUnsupported();
      }
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

// ══════════════════════════════════════════════════════════════
// TOOLS API — execução no servidor de tools
// ══════════════════════════════════════════════════════════════
class ToolsApiService {
  static Future<Map<String, dynamic>> executeTool({
    required String token,
    required String name,
    required Map<String, dynamic> input,
  }) async {
    final res = await http.post(
      Uri.parse('$kApiBase/tools/execute'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'name': name, 'input': input}),
    );
    final data = _decode(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw ApiException(data['error']?.toString() ?? 'Erro ao executar tool', statusCode: res.statusCode);
    }
    // O servidor devolve { tool_name: "...", result: { ... } }
    // Extrai apenas o result para uniformizar com as tools locais.
    if (data is Map && data.containsKey('result')) {
      final result = data['result'];
      if (result is Map<String, dynamic>) return result;
      if (result is Map) return Map<String, dynamic>.from(result);
      return {};
    }
    return data;
  }
}

// ══════════════════════════════════════════════════════════════
// DEFINIÇÕES COMPLETAS DAS TOOLS — todas as expostas pelo servidor
// ══════════════════════════════════════════════════════════════
const List<ToolDefinition> kAllTools = [
  ToolDefinition(
    name: 'web_search',
    description: 'Pesquisa informação atual na web. Devolve resultados com snippets, imagens e a data atual injetada automaticamente. Usa sempre que precisares de informação recente — nunca inventes resultados.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'description': 'Termo de busca'},
      },
      'required': ['query'],
    },
  ),
  ToolDefinition(
    name: 'search_images',
    description: 'Pesquisa imagens na web via Serper. Devolve URLs de imagens relevantes. Usa quando o utilizador pede imagens de algo.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'description': 'Termo de busca de imagens'},
      },
      'required': ['query'],
    },
  ),
  ToolDefinition(
    name: 'search_market',
    description: 'Pesquisa dados reais de um ativo financeiro: cripto (nome/símbolo, ex "bitcoin"), câmbio (código ISO, ex "EUR", "USD/JPY"), ou ação/índice (ticker, ex "AAPL"). Devolve preço e variação reais — nunca inventes valores.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'description': 'Nome, símbolo, código ou ticker'},
      },
      'required': ['query'],
    },
  ),
  ToolDefinition(
    name: 'search_place',
    description: 'Pesquisa a localização real (coordenadas e nome formal) de um lugar — cidade, morada, ponto de interesse. Nunca inventes coordenadas.',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'description': 'Nome do lugar'},
      },
      'required': ['query'],
    },
  ),
  ToolDefinition(
    name: 'search_calendar_date',
    description: 'Resolve uma data em linguagem natural (ex "próxima sexta-feira") para ISO (YYYY-MM-DD).',
    parameters: {
      'type': 'object',
      'properties': {
        'query': {'type': 'string', 'description': 'Referência de data em linguagem natural'},
      },
      'required': ['query'],
    },
  ),
  ToolDefinition(
    name: 'get_weather',
    description: 'Obtém o clima atual de uma cidade e gera um card visual PNG base64. Usa sempre que o utilizador perguntar sobre o tempo ou clima — nunca inventes valores meteorológicos.',
    parameters: {
      'type': 'object',
      'properties': {
        'city': {'type': 'string', 'description': 'Nome da cidade'},
      },
      'required': ['city'],
    },
  ),
  ToolDefinition(
    name: 'generate_chart',
    description: 'Gera um gráfico visual como PNG base64. Suporta line, bar, pie, doughnut, radar, polarArea. Aceita múltiplos datasets. Devolve content_base64 com PNG — exibe diretamente no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'chart_type': {'type': 'string', 'enum': ['line', 'bar', 'pie', 'doughnut', 'radar', 'polarArea']},
        'title': {'type': 'string'},
        'labels': {'type': 'array', 'items': {'type': 'string'}},
        'datasets': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'label': {'type': 'string'},
              'data': {'type': 'array', 'items': {'type': 'number'}},
              'color': {'type': 'string'},
            },
          },
        },
      },
      'required': ['chart_type', 'labels', 'datasets'],
    },
  ),
  ToolDefinition(
    name: 'generate_qrcode',
    description: 'Gera um QR code como PNG base64 a partir de qualquer texto ou URL. Devolve content_base64 — exibe diretamente no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'content': {'type': 'string', 'description': 'Texto ou URL para o QR code'},
        'size': {'type': 'number', 'description': 'Tamanho em pixels (default 300)'},
      },
      'required': ['content'],
    },
  ),
  ToolDefinition(
    name: 'generate_barcode',
    description: 'Gera um código de barras como PNG base64. Devolve content_base64 — exibe diretamente no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'content': {'type': 'string', 'description': 'Conteúdo do código de barras'},
        'format': {'type': 'string', 'enum': ['code128', 'ean13', 'ean8', 'upca', 'qrcode']},
      },
      'required': ['content'],
    },
  ),
  ToolDefinition(
    name: 'generate_math',
    description: 'Avalia uma expressão matemática e gera imagem PNG com resultado. Se for função (ex: x^2), gera gráfico automaticamente. Devolve content_base64 — exibe diretamente no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'expression': {'type': 'string', 'description': 'Expressão matemática ex: "2^10", "sqrt(144)", "x^2 + 2*x + 1"'},
        'variable_range': {
          'type': 'object',
          'properties': {
            'min': {'type': 'number'},
            'max': {'type': 'number'},
          },
        },
      },
      'required': ['expression'],
    },
  ),
  ToolDefinition(
    name: 'generate_table_image',
    description: 'Gera uma tabela complexa como PNG base64. Usa quando markdown não é suficiente. Devolve content_base64 — exibe diretamente no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'headers': {'type': 'array', 'items': {'type': 'string'}},
        'rows': {'type': 'array', 'items': {'type': 'array', 'items': {'type': 'string'}}},
        'theme': {'type': 'string', 'enum': ['dark', 'light', 'purple']},
      },
      'required': ['headers', 'rows'],
    },
  ),
  ToolDefinition(
    name: 'generate_html_image',
    description: 'Converte um snippet HTML/CSS em PNG base64. Usa para criar cards visuais, infográficos, dashboards, snippets de código com syntax highlight, ou qualquer layout visual personalizado. Devolve content_base64 — exibe diretamente no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'html': {'type': 'string', 'description': 'HTML completo com estilos inline ou tag <style>'},
        'width': {'type': 'number', 'description': 'Largura em pixels (default 800)'},
        'height': {'type': 'number', 'description': 'Altura em pixels (default 600)'},
      },
      'required': ['html'],
    },
  ),
  ToolDefinition(
    name: 'create_pdf',
    description: 'Gera um PDF a partir de HTML rico. Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'html_content': {'type': 'string'},
      },
      'required': ['title', 'html_content'],
    },
  ),
  ToolDefinition(
    name: 'create_docx',
    description: 'Gera um Word (.docx) a partir de HTML. Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'html_content': {'type': 'string'},
      },
      'required': ['title', 'html_content'],
    },
  ),
  ToolDefinition(
    name: 'create_xlsx',
    description: 'Gera planilha Excel (.xlsx). Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'sheet_name': {'type': 'string'},
        'headers': {'type': 'array', 'items': {'type': 'string'}},
        'rows': {'type': 'array', 'items': {'type': 'array', 'items': {'type': 'string'}}},
      },
      'required': ['headers', 'rows'],
    },
  ),
  ToolDefinition(
    name: 'create_pptx',
    description: 'Gera PowerPoint (.pptx). Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'title': {'type': 'string'},
        'slides': {
          'type': 'array',
          'items': {
            'type': 'object',
            'properties': {
              'heading': {'type': 'string'},
              'bullets': {'type': 'array', 'items': {'type': 'string'}},
            },
          },
        },
      },
      'required': ['title', 'slides'],
    },
  ),
  ToolDefinition(
    name: 'csv_to_xlsx',
    description: 'Converte CSV em Excel (.xlsx). Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'csv_content': {'type': 'string'},
      },
      'required': ['csv_content'],
    },
  ),
  ToolDefinition(
    name: 'json_transform',
    description: 'Transforma array JSON de objetos em tabela (headers + rows).',
    parameters: {
      'type': 'object',
      'properties': {
        'json_data': {'type': 'string'},
      },
      'required': ['json_data'],
    },
  ),
  ToolDefinition(
    name: 'convert_document',
    description: 'Converte um documento entre formatos a partir de conteúdo base64. Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'source_format': {'type': 'string'},
        'target_format': {'type': 'string'},
        'content_base64': {'type': 'string'},
        'filename': {'type': 'string'},
      },
      'required': ['source_format', 'target_format', 'content_base64'],
    },
  ),
  ToolDefinition(
    name: 'html_to_docx',
    description: 'Converte HTML em Word (.docx). Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'html_content': {'type': 'string'},
        'filename': {'type': 'string'},
      },
      'required': ['html_content'],
    },
  ),
  ToolDefinition(
    name: 'html_to_pdf',
    description: 'Converte HTML em PDF. Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'html_content': {'type': 'string'},
        'title': {'type': 'string'},
      },
      'required': ['html_content'],
    },
  ),
  ToolDefinition(
    name: 'html_to_xlsx',
    description: 'Converte HTML em Excel (.xlsx). Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'html_content': {'type': 'string'},
        'sheet_name': {'type': 'string'},
      },
      'required': ['html_content'],
    },
  ),
  ToolDefinition(
    name: 'html_to_pptx',
    description: 'Converte HTML em PowerPoint (.pptx). Devolve content_base64 e filename — mostra botão de download no chat.',
    parameters: {
      'type': 'object',
      'properties': {
        'html_content': {'type': 'string'},
        'title': {'type': 'string'},
      },
      'required': ['html_content'],
    },
  ),
];