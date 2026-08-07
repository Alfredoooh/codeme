// ══════════════════════════════════════════════════════════════
// FILE: lib/aitab.dart
// ══════════════════════════════════════════════════════════════
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'colors.dart';
import 'widgets.dart';
import 'edittab.dart';
import 'api_service.dart';
import 'auth_service.dart';

// ══════════════════════════════════════════════════════════════
// AI TAB
// ══════════════════════════════════════════════════════════════

class AiTab extends StatefulWidget {
  final VoidCallback onFirstMessage;
  const AiTab({super.key, required this.onFirstMessage});
  @override State<AiTab> createState() => _AiTabState();
}

enum QuickAction { doc, sheet, slide, whiteboard }

extension QuickActionX on QuickAction {
  String get asset => const {
        QuickAction.doc:        'doc.png',
        QuickAction.sheet:      'sheet.png',
        QuickAction.slide:      'slide.png',
        QuickAction.whiteboard: 'whiteboard.png',
      }[this]!;

  String get label => const {
        QuickAction.doc:        'Criar documento Word',
        QuickAction.sheet:      'Criar folha de cálculo',
        QuickAction.slide:      'Criar apresentação',
        QuickAction.whiteboard: 'Criar com o canvas',
      }[this]!;

  Color get tint => const {
        QuickAction.doc:        Color(0xFF2B579A),
        QuickAction.sheet:      Color(0xFF217346),
        QuickAction.slide:      Color(0xFFD24726),
        QuickAction.whiteboard: Color(0xFFE1306C),
      }[this]!;

  String get promptSeed => const {
        QuickAction.doc:        'Cria um documento Word sobre ',
        QuickAction.sheet:      'Cria uma folha de cálculo sobre ',
        QuickAction.slide:      'Cria uma apresentação sobre ',
        QuickAction.whiteboard: 'Cria um quadro branco sobre ',
      }[this]!;

  EditorType get editorType => const {
        QuickAction.doc:        EditorType.docs,
        QuickAction.sheet:      EditorType.sheets,
        QuickAction.slide:      EditorType.slides,
        QuickAction.whiteboard: EditorType.whiteboard,
      }[this]!;
}

// ══════════════════════════════════════════════════════════════
// AI MODEL — labels DeepSeek mantidos, ligados aos providers reais
// do worker (gemini / groq) via kProviderMap em api_service.dart
// ══════════════════════════════════════════════════════════════

enum AiModel { deepseekV3, deepseekR1, deepseekCoder }

extension AiModelX on AiModel {
  String get label => const {
        AiModel.deepseekV3:    'DeepSeek V3',
        AiModel.deepseekR1:    'DeepSeek R1',
        AiModel.deepseekCoder: 'DeepSeek Coder',
      }[this]!;

  String get badge => const {
        AiModel.deepseekV3:    'Rápido',
        AiModel.deepseekR1:    'Raciocínio',
        AiModel.deepseekCoder: 'Código',
      }[this]!;

  ApiProvider get provider => const {
        AiModel.deepseekV3:    ApiProvider.gemini,
        AiModel.deepseekR1:    ApiProvider.gemini,
        AiModel.deepseekCoder: ApiProvider.groqVersatile,
      }[this]!;

  bool get think => this == AiModel.deepseekR1;
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

class AiConversationMenuButton extends StatefulWidget {
  final AppColorScheme s;
  final ValueChanged<ConversationAction> onSelect;
  const AiConversationMenuButton(
      {super.key, required this.s, required this.onSelect});
  @override
  State<AiConversationMenuButton> createState() =>
      _AiConversationMenuButtonState();
}

class _AiConversationMenuButtonState extends State<AiConversationMenuButton>
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

  void _toggle() => _ov == null ? _open() : _close();

  void _open() {
    final box = context.findRenderObject() as RenderBox;
    final off = box.localToGlobal(Offset.zero);
    final sz  = box.size;
    _ac.forward(from: 0);

    _ov = OverlayEntry(builder: (ctx) {
      final s = widget.s;
      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _close,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          top: off.dy + sz.height + 6,
          right: MediaQuery.of(ctx).size.width - off.dx - sz.width,
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
                alignment: Alignment.topRight,
                child: child,
              ),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                width: 220,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: s.isDark ? const Color(0xFF2C2C2E) : Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: s.floatingShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: ConversationAction.values
                      .map((a) => _ConversationOption(
                            s: s,
                            action: a,
                            onTap: () { widget.onSelect(a); _close(); },
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

  void _close() {
    _ac.reverse().then((_) {
      _ov?.remove();
      _ov = null;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) => AppTap(
        onTap: _toggle,
        s: widget.s,
        size: 36,
        child: AppIcon('more_filled.svg', color: widget.s.onSurface, size: 20),
      );
}

class _ConversationOption extends StatefulWidget {
  final AppColorScheme s;
  final ConversationAction action;
  final VoidCallback onTap;
  const _ConversationOption(
      {required this.s, required this.action, required this.onTap});
  @override State<_ConversationOption> createState() => _ConversationOptionState();
}

class _ConversationOptionState extends State<_ConversationOption> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final isIncognito = widget.action == ConversationAction.incognito;
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
          isIncognito
              ? _GhostIcon(color: widget.s.onSurface, size: 18)
              : AppIcon(widget.action.svgAsset, color: widget.s.onSurface, size: 18),
          const SizedBox(width: 10),
          Text(widget.action.label,
              style: TextStyle(
                fontSize: 14,
                color: widget.s.onSurface,
                fontWeight: FontWeight.normal,
              )),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// GHOST ICON — desenhado via CustomPainter, sem depender de asset
// externo. Usa sempre a cor recebida (nunca fixa cores próprias),
// para que o modo incógnito respeite sempre o tema claro/escuro.
// ══════════════════════════════════════════════════════════════

class _GhostIcon extends StatelessWidget {
  final Color color;
  final double size;
  const _GhostIcon({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _GhostPainter(color: color)),
      );
}

class _GhostPainter extends CustomPainter {
  final Color color;
  _GhostPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bodyPaint = Paint()..color = color..style = PaintingStyle.fill;
    final eyePaint = Paint()
      ..color = Colors.black.withOpacity(color.computeLuminance() > 0.5 ? 0.82 : 0.55)
      ..style = PaintingStyle.fill;

    final domeTop = h * 0.06;
    final bodyLeft = w * 0.14;
    final bodyRight = w * 0.86;
    final bodyWidth = bodyRight - bodyLeft;
    final domeRadius = bodyWidth / 2;
    final domeCenterY = domeTop + domeRadius;
    final waveTop = h * 0.68;
    final baseY = h * 0.92;

    final path = Path();
    // Cúpula semicircular no topo
    path.moveTo(bodyLeft, domeCenterY);
    path.arcTo(
      Rect.fromCircle(center: Offset(bodyLeft + domeRadius, domeCenterY), radius: domeRadius),
      3.14159, // pi — começa à esquerda
      3.14159, // meia volta até à direita
      false,
    );
    // Desce pelo lado direito até à zona das ondas
    path.lineTo(bodyRight, waveTop);
    // Base ondulada — 3 arcos côncavos (efeito clássico de fantasma)
    final segW = bodyWidth / 3;
    for (int i = 0; i < 3; i++) {
      final xStart = bodyRight - segW * i;
      final xEnd = bodyRight - segW * (i + 1);
      final xMid = (xStart + xEnd) / 2;
      path.quadraticBezierTo(xMid, baseY, xEnd, waveTop);
    }
    // Sobe pelo lado esquerdo de volta ao início da cúpula
    path.lineTo(bodyLeft, domeCenterY);
    path.close();

    canvas.drawPath(path, bodyPaint);

    // Olhos
    final eyeY = domeCenterY + domeRadius * 0.12;
    final eyeR = w * 0.055;
    final eyeOffsetX = bodyWidth * 0.19;
    canvas.drawCircle(Offset(w / 2 - eyeOffsetX, eyeY), eyeR, eyePaint);
    canvas.drawCircle(Offset(w / 2 + eyeOffsetX, eyeY), eyeR, eyePaint);
  }

  @override
  bool shouldRepaint(covariant _GhostPainter oldDelegate) => oldDelegate.color != color;
}

// ══════════════════════════════════════════════════════════════
// DASHED ROUNDED BORDER — usado no input de chat quando incógnito
// ══════════════════════════════════════════════════════════════

class _DashedRRectBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dashWidth;
  final double dashGap;
  final double strokeWidth;
  _DashedRRectBorderPainter({
    required this.color,
    required this.radius,
    this.dashWidth = 5,
    this.dashGap = 4,
    this.strokeWidth = 1.3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2,
          size.width - strokeWidth, size.height - strokeWidth),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dashWidth;
        canvas.drawPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          paint,
        );
        distance = next + dashGap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class DashedRRectBorder extends StatelessWidget {
  final Widget child;
  final Color color;
  final double radius;
  const DashedRRectBorder({
    super.key,
    required this.child,
    required this.color,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) => CustomPaint(
        foregroundPainter: _DashedRRectBorderPainter(color: color, radius: radius),
        child: child,
      );
}

// ══════════════════════════════════════════════════════════════
// AI TAB STATE
// ══════════════════════════════════════════════════════════════

class _AiTabState extends State<AiTab> {
  final TextEditingController _ctrl   = TextEditingController();
  final ScrollController       _scroll = ScrollController();
  final List<ChatMessage>      _msgs  = [];

  bool     _showToggles  = true;
  bool     _webSearchOn  = false;
  bool     _incognito    = false;
  bool     _sending      = false;
  String   _streamingText = '';
  String?  _streamingThink;
  String?  _conversationId;
  AiModel  _model        = AiModel.deepseekV3;
  EditorType? _attachedTool;

  StreamSubscription<ChatStreamEvent>? _streamSub;

  Future<void> _send() async {
    final t = _ctrl.text.trim();
    if (t.isEmpty || _sending) return;
    final isFirst = _msgs.isEmpty;
    final userMsg = ChatMessage(role: 'user', content: t);

    setState(() {
      _msgs.add(userMsg);
      _ctrl.clear();
      _showToggles = false;
      _attachedTool = null;
      _sending = true;
      _streamingText = '';
      _streamingThink = null;
    });
    if (isFirst) widget.onFirstMessage();
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
    ).listen(
      (event) {
        if (!mounted) return;
        switch (event) {
          case ChatTokenEvent(text: final text):
            setState(() => _streamingText += text);
            _scrollToEnd();
            break;
          case ChatThinkEvent(text: final text):
            setState(() => _streamingThink = (_streamingThink ?? '') + text);
            break;
          case ChatDoneEvent(fullText: final fullText):
            final finalText = fullText.isNotEmpty ? fullText : _streamingText;
            setState(() {
              if (finalText.trim().isNotEmpty) {
                _msgs.add(ChatMessage(role: 'assistant', content: finalText));
              }
              _sending = false;
              _streamingText = '';
              _streamingThink = null;
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
      );
      if (created != null && created['id'] != null) {
        _conversationId = created['id'].toString();
      }
    } else {
      await ConversationsApiService.update(token, _conversationId!, title: title, messages: _msgs);
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
      );
      if (created != null && created['id'] != null) {
        _conversationId = created['id'].toString();
      }
    } else {
      await ConversationsApiService.update(token, _conversationId!, messages: _msgs);
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

  void _onQuickAction(QuickAction action) {
    setState(() {
      _showToggles = false;
      _ctrl.text = action.promptSeed;
      _ctrl.selection =
          TextSelection.collapsed(offset: _ctrl.text.length);
      _attachedTool = action.editorType;
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

  void _onToggleWebSearch(bool v) => setState(() => _webSearchOn = v);

  void _onToolSelected(EditorType t) => setState(() => _attachedTool = t);
  void _onClearTool() => setState(() => _attachedTool = null);

  void _openAttachSheet() {
    showAttachSheet(
      context,
      AppTheme.of(context),
      webSearchOn: _webSearchOn,
      onToggleWebSearch: _onToggleWebSearch,
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

  void _openModelSheet() {
    showModelSelectSheet(
      context,
      AppTheme.of(context),
      current: _model,
      onSelect: _onModelSelected,
    );
  }

  void _onConversationAction(ConversationAction action) {
    switch (action) {
      case ConversationAction.newChat:
        _streamSub?.cancel();
        setState(() {
          _msgs.clear();
          _showToggles = true;
          _incognito = false;
          _sending = false;
          _streamingText = '';
          _streamingThink = null;
          _conversationId = null;
        });
        break;
      case ConversationAction.incognito:
        _streamSub?.cancel();
        setState(() {
          _msgs.clear();
          _showToggles = false;
          _incognito = true;
          _sending = false;
          _streamingText = '';
          _streamingThink = null;
          _conversationId = null;
        });
        break;
      case ConversationAction.rename:
        // Sem UI de conversas guardadas neste ecrã para renomear ainda;
        // aplica-se quando o histórico de conversas estiver ligado ao drawer.
        break;
      case ConversationAction.delete:
        if (_conversationId != null) {
          final token = authController.token;
          if (token != null) ConversationsApiService.delete(token, _conversationId!);
        }
        _streamSub?.cancel();
        setState(() {
          _msgs.clear();
          _showToggles = true;
          _incognito = false;
          _sending = false;
          _streamingText = '';
          _streamingThink = null;
          _conversationId = null;
        });
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

    return Column(children: [
      Expanded(
        child: _incognito
            ? _IncognitoState(s: s)
            : (_msgs.isEmpty && _streamingText.isEmpty && _showToggles)
                ? _EmptyState(s: s, onQuickAction: _onQuickAction)
                : (_msgs.isEmpty && _streamingText.isEmpty)
                    ? const SizedBox.shrink()
                    : ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        itemCount: _msgs.length + (_sending ? 1 : 0),
                        itemBuilder: (_, i) {
                          if (i >= _msgs.length) {
                            return _StreamingBubble(
                              s: s,
                              text: _streamingText,
                              thinking: _streamingThink,
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
                          return _AssistantBubble(s: s, text: msg.content);
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
        onSend: _send,
        onAttach: _openAttachSheet,
        onVoice: _openVoiceSheet,
        onModel: _openModelSheet,
        onClearTool: _onClearTool,
      ),
      AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: kCupertinoOut,
        height: keyboardInset > 0 ? keyboardInset : 104,
      ),
    ]);
  }
}

// ── Estado incógnito — nunca escurece o fundo; segue sempre o tema ──

class _IncognitoState extends StatelessWidget {
  final AppColorScheme s;
  const _IncognitoState({required this.s});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _GhostIcon(color: s.onSurface, size: 72),
              const SizedBox(height: 22),
              Text('Conversa incógnita',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: s.onSurface)),
              const SizedBox(height: 10),
              Text(
                'Esta conversa não é guardada nem usada para melhorar os modelos.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, color: s.onSurfaceVariant, height: 1.4),
              ),
            ],
          ),
        ),
      );
}

// ── Toggle individual (chip compacto com ícone + label + borda) ─

class _EmptyState extends StatelessWidget {
  final AppColorScheme s;
  final ValueChanged<QuickAction> onQuickAction;
  const _EmptyState({required this.s, required this.onQuickAction});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: QuickAction.values
                .map((a) => _QuickActionChip(
                      s: s,
                      action: a,
                      onTap: () => onQuickAction(a),
                    ))
                .toList(),
          ),
        ),
      );
}

class _QuickActionChip extends StatefulWidget {
  final AppColorScheme s;
  final QuickAction action;
  final VoidCallback onTap;
  const _QuickActionChip({
    required this.s,
    required this.action,
    required this.onTap,
  });

  @override
  State<_QuickActionChip> createState() => _QuickActionChipState();
}

class _QuickActionChipState extends State<_QuickActionChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapCancel: ()  => setState(() => _pressed = false),
      onTapUp:     (_) => setState(() => _pressed = false),
      onTap:       widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: kCupertinoOut,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: widget.action.tint.withOpacity(s.isDark ? 0.16 : 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: widget.action.tint,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                'assets/icons/png/${widget.action.asset}',
                width: 14,
                height: 14,
                fit: BoxFit.contain,
              ),
              const SizedBox(width: 5),
              Text(
                widget.action.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: widget.action.tint,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
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
    showMessageActionsMenu(
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
  Widget build(BuildContext context) => AnimatedBuilder(
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
                color: widget.s.isDark
                    ? widget.s.primaryContainer
                    : const Color(0xFFCFE1FF), // reforçado no claro — mais visível que primaryContainer padrão
                borderRadius: BorderRadius.circular(18),
                boxShadow: widget.s.cardShadow,
              ),
              child: Text(widget.text,
                  style: TextStyle(
                      color: widget.s.isDark
                          ? widget.s.onPrimaryContainer
                          : const Color(0xFF002E6B),
                      fontSize: 14)),
            ),
          ),
        ),
      );
}

// ── Bolha de resposta do assistente ──────────────────────────────

class _AssistantBubble extends StatelessWidget {
  final AppColorScheme s;
  final String text;
  const _AssistantBubble({required this.s, required this.text});

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
          child: SelectableText(
            text,
            style: TextStyle(color: s.onSurface, fontSize: 14.5, height: 1.45),
          ),
        ),
      );
}

// ── Bolha de streaming (resposta a chegar em tempo real) ────────

class _StreamingBubble extends StatelessWidget {
  final AppColorScheme s;
  final String text;
  final String? thinking;
  const _StreamingBubble({required this.s, required this.text, this.thinking});

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
              if (text.isEmpty)
                SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(s.onSurfaceVariant),
                  ),
                )
              else
                Text(text,
                    style: TextStyle(color: s.onSurface, fontSize: 14.5, height: 1.45)),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// MESSAGE ACTIONS MENU (editar / copiar / eliminar / selecionar texto)
// ══════════════════════════════════════════════════════════════

void showMessageActionsMenu(
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
    // Ancora o popup por cima da bolha, alinhado à direita (mensagens
    // do utilizador ficam à direita), com margem de segurança para não
    // sair do ecrã.
    final desiredTop = anchorOffset.dy - 6 - 176;
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
                color: s.isDark ? const Color(0xFF2C2C2E) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: s.floatingShadow,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MessageActionRow(
                    s: s,
                    icon: Icons.edit_outlined,
                    label: 'Editar',
                    onTap: () { close(); onEdit(); },
                  ),
                  _MessageActionRow(
                    s: s,
                    icon: Icons.copy_outlined,
                    label: 'Copiar',
                    onTap: () { close(); onCopy(); },
                  ),
                  _MessageActionRow(
                    s: s,
                    icon: Icons.text_fields_rounded,
                    label: 'Selecionar texto',
                    onTap: () { close(); onSelectText(); },
                  ),
                  _MessageActionRow(
                    s: s,
                    icon: Icons.delete_outline_rounded,
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
  final IconData icon;
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
          Icon(widget.icon, size: 18, color: color),
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
            color: s.isDark ? const Color(0xFF2C2C2E) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: s.floatingShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: s.outline,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
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
  final AiModel model;
  final EditorType? attachedTool;
  final bool incognito;
  final bool sending;
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
        color: s.isDark ? const Color(0xFF2C2C2E) : Colors.white,
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
                hintText: incognito ? 'Mensagem incógnita...' : 'Escreve uma mensagem...',
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
                        ? SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation(s.onPrimary),
                            ),
                          )
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
// ATTACH SHEET — 4 opções diretas com pngs (doc/sheet/slide/whiteboard)
// substituem o item genérico "Ferramentas" com ícone tools.svg
// ══════════════════════════════════════════════════════════════

Future<void> showAttachSheet(
  BuildContext context,
  AppColorScheme s, {
  required bool webSearchOn,
  required ValueChanged<bool> onToggleWebSearch,
  required VoidCallback onFiles,
  required VoidCallback onPhotos,
  required VoidCallback onCamera,
  required ValueChanged<EditorType> onSelectTool,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => _AttachSheetContent(
      s: s,
      webSearchOn: webSearchOn,
      onToggleWebSearch: onToggleWebSearch,
      onFiles: onFiles,
      onPhotos: onPhotos,
      onCamera: onCamera,
      onSelectTool: onSelectTool,
    ),
  );
}

class _AttachSheetContent extends StatefulWidget {
  final AppColorScheme s;
  final bool webSearchOn;
  final ValueChanged<bool> onToggleWebSearch;
  final VoidCallback onFiles;
  final VoidCallback onPhotos;
  final VoidCallback onCamera;
  final ValueChanged<EditorType> onSelectTool;

  const _AttachSheetContent({
    required this.s,
    required this.webSearchOn,
    required this.onToggleWebSearch,
    required this.onFiles,
    required this.onPhotos,
    required this.onCamera,
    required this.onSelectTool,
  });

  @override
  State<_AttachSheetContent> createState() => _AttachSheetContentState();
}

class _AttachSheetContentState extends State<_AttachSheetContent> {
  late bool _webSearchOn = widget.webSearchOn;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 0, 10, 10),
          padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
          decoration: BoxDecoration(
            color: s.isDark ? const Color(0xFF2C2C2E) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: s.floatingShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: s.outline,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              _SheetOptionsGroup(s: s, options: [
                _SheetOption(
                  s: s,
                  icon: 'file.svg',
                  label: 'Arquivos',
                  subtitle: 'Enviar qualquer tipo de arquivo',
                  onTap: () { Navigator.pop(context); widget.onFiles(); },
                ),
                _SheetOption(
                  s: s,
                  icon: 'image.svg',
                  label: 'Fotos',
                  subtitle: 'Enviar fotos da galeria',
                  onTap: () { Navigator.pop(context); widget.onPhotos(); },
                ),
                _SheetOption(
                  s: s,
                  icon: 'camera.svg',
                  label: 'Câmera',
                  subtitle: 'Tirar uma foto agora',
                  onTap: () { Navigator.pop(context); widget.onCamera(); },
                ),
              ]),
              const SizedBox(height: 6),
              // 4 opções diretas com pngs — substitui o item único
              // "Ferramentas" com o ícone genérico tools.svg
              _SheetOptionsGroup(
                s: s,
                options: EditorType.values
                    .map((t) => _ToolPngSheetOption(
                          s: s,
                          type: t,
                          onTap: () {
                            Navigator.pop(context);
                            widget.onSelectTool(t);
                          },
                        ))
                    .toList(),
              ),
              const SizedBox(height: 6),
              _SettingsStyleCard(
                s: s,
                radius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      AppIcon('globe.svg', color: s.onSurface, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text('Pesquisa online',
                            style: TextStyle(
                                fontSize: 14, color: s.onSurface)),
                      ),
                      AppSwitch(
                        value: _webSearchOn,
                        s: s,
                        onChanged: (v) {
                          setState(() => _webSearchOn = v);
                          widget.onToggleWebSearch(v);
                        },
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

// ── Opção do attach sheet com png real (doc/sheet/slide/whiteboard) ─

class _ToolPngSheetOption extends StatefulWidget {
  final AppColorScheme s;
  final EditorType type;
  final VoidCallback onTap;
  const _ToolPngSheetOption({required this.s, required this.type, required this.onTap});
  @override State<_ToolPngSheetOption> createState() => _ToolPngSheetOptionState();
}

class _ToolPngSheetOptionState extends State<_ToolPngSheetOption> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown:   (_) => setState(() => _h = true),
        onTapCancel: ()  => setState(() => _h = false),
        onTapUp:     (_) => setState(() => _h = false),
        onTap:       widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: _h ? widget.s.hover : Colors.transparent,
          child: Row(children: [
            EditorTypeIcon(widget.type.pngAsset, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(widget.type.label,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: widget.s.onSurface)),
            ),
          ]),
        ),
      );
}

// ── Card genérico (mesmo padrão do _SettingsCard) ──────────────

class _SettingsStyleCard extends StatelessWidget {
  final AppColorScheme s;
  final BorderRadius radius;
  final Widget child;
  const _SettingsStyleCard(
      {required this.s, required this.radius, required this.child});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(color: s.cardBackground, borderRadius: radius),
        clipBehavior: Clip.antiAlias,
        child: child,
      );
}

class _SheetOptionsGroup extends StatelessWidget {
  final AppColorScheme s;
  final List<Widget> options;
  const _SheetOptionsGroup({required this.s, required this.options});

  static const double _outerRadius = 16;
  static const double _innerRadius = 4;
  static const double _gap = 2;

  @override
  Widget build(BuildContext context) {
    final count = options.length;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < count; i++) ...[
          if (i > 0) const SizedBox(height: _gap),
          _SettingsStyleCard(
            s: s,
            radius: _radiusFor(i, count),
            child: options[i],
          ),
        ],
      ],
    );
  }

  BorderRadius _radiusFor(int index, int count) {
    if (count == 1) return BorderRadius.circular(_outerRadius);
    final isFirst = index == 0;
    final isLast  = index == count - 1;
    return BorderRadius.only(
      topLeft:     Radius.circular(isFirst ? _outerRadius : _innerRadius),
      topRight:    Radius.circular(isFirst ? _outerRadius : _innerRadius),
      bottomLeft:  Radius.circular(isLast  ? _outerRadius : _innerRadius),
      bottomRight: Radius.circular(isLast  ? _outerRadius : _innerRadius),
    );
  }
}

class _SheetOption extends StatefulWidget {
  final AppColorScheme s;
  final String icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const _SheetOption({
    required this.s,
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
  @override State<_SheetOption> createState() => _SheetOptionState();
}

class _SheetOptionState extends State<_SheetOption> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown:   (_) => setState(() => _h = true),
        onTapCancel: ()  => setState(() => _h = false),
        onTapUp:     (_) => setState(() => _h = false),
        onTap:       widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 100),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          color: _h ? widget.s.hover : Colors.transparent,
          child: Row(children: [
            AppIcon(widget.icon, color: widget.s.onSurface, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: widget.s.onSurface)),
                  const SizedBox(height: 1),
                  Text(widget.subtitle,
                      style: TextStyle(
                          fontSize: 12, color: widget.s.onSurfaceVariant)),
                ],
              ),
            ),
          ]),
        ),
      );
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
            color: s.isDark ? const Color(0xFF2C2C2E) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: s.floatingShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: s.outline,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
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
// MODEL SELECT SHEET
// ══════════════════════════════════════════════════════════════

Future<void> showModelSelectSheet(
  BuildContext context,
  AppColorScheme s, {
  required AiModel current,
  required ValueChanged<AiModel> onSelect,
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
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: s.isDark ? const Color(0xFF2C2C2E) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            boxShadow: s.floatingShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 10, top: 2),
                decoration: BoxDecoration(
                  color: s.outline,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              _SheetOptionsGroup(
                s: s,
                options: AiModel.values
                    .map((m) => _ModelOption(
                          s: s,
                          model: m,
                          selected: current == m,
                          onTap: () {
                            onSelect(m);
                            Navigator.pop(ctx);
                          },
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ModelOption extends StatefulWidget {
  final AppColorScheme s;
  final AiModel model;
  final bool selected;
  final VoidCallback onTap;
  const _ModelOption({
    required this.s,
    required this.model,
    required this.selected,
    required this.onTap,
  });
  @override State<_ModelOption> createState() => _ModelOptionState();
}

class _ModelOptionState extends State<_ModelOption> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final w = widget;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown:   (_) => setState(() => _h = true),
      onTapCancel: ()  => setState(() => _h = false),
      onTapUp:     (_) => setState(() => _h = false),
      onTap:       w.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        color: _h
            ? w.s.hover
            : w.selected
                ? w.s.primaryContainer.withOpacity(0.5)
                : Colors.transparent,
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(w.model.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: w.selected ? w.s.primary : w.s.onSurface,
                    )),
                const SizedBox(height: 1),
                Text(w.model.badge,
                    style: TextStyle(
                        fontSize: 12, color: w.s.onSurfaceVariant)),
              ],
            ),
          ),
          if (w.selected)
            AppIcon('check.svg', color: w.s.primary, size: 16),
        ]),
      ),
    );
  }
}