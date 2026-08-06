import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'colors.dart';
import 'widgets.dart';
import 'edittab.dart';

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
        QuickAction.doc:        Color(0xFF2B579A), // azul Word
        QuickAction.sheet:      Color(0xFF217346), // verde Excel
        QuickAction.slide:      Color(0xFFD24726), // laranja/vermelho PowerPoint
        QuickAction.whiteboard: Color(0xFFE1306C), // vermelho/rosa
      }[this]!;

  /// Texto inicial colocado no input ao seleccionar o toggle.
  String get promptSeed => const {
        QuickAction.doc:        'Cria um documento Word sobre ',
        QuickAction.sheet:      'Cria uma folha de cálculo sobre ',
        QuickAction.slide:      'Cria uma apresentação sobre ',
        QuickAction.whiteboard: 'Cria um quadro branco sobre ',
      }[this]!;

  /// EditorType correspondente, para navegação automática após criação.
  EditorType get editorType => const {
        QuickAction.doc:        EditorType.docs,
        QuickAction.sheet:      EditorType.sheets,
        QuickAction.slide:      EditorType.slides,
        QuickAction.whiteboard: EditorType.whiteboard,
      }[this]!;
}

// ══════════════════════════════════════════════════════════════
// AI MODEL (selector estilo "Sonnet 5 Extra")
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
}

// ══════════════════════════════════════════════════════════════
// CONVERSATION MENU (popup — mesmo padrão do EditTypeButton)
// ══════════════════════════════════════════════════════════════

enum ConversationAction { newChat, rename, delete }

extension ConversationActionX on ConversationAction {
  String get svgAsset => const {
        ConversationAction.newChat: 'plus.svg',
        ConversationAction.rename:  'edit.svg',
        ConversationAction.delete:  'trash.svg',
      }[this]!;

  String get label => const {
        ConversationAction.newChat: 'Iniciar nova conversa',
        ConversationAction.rename:  'Renomear conversa',
        ConversationAction.delete:  'Eliminar conversa',
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
  Widget build(BuildContext context) => GestureDetector(
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
            AppIcon(widget.action.svgAsset, color: widget.s.onSurface, size: 18),
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

// ══════════════════════════════════════════════════════════════
// AI TAB STATE
// ══════════════════════════════════════════════════════════════

class _AiTabState extends State<AiTab> {
  final TextEditingController _ctrl   = TextEditingController();
  final ScrollController       _scroll = ScrollController();
  final List<String>           _msgs  = [];

  bool     _showToggles  = true;
  bool     _webSearchOn  = false;
  AiModel  _model        = AiModel.deepseekV3;
  EditorType? _attachedTool;

  void _send() {
    final t = _ctrl.text.trim();
    if (t.isEmpty) return;
    final isFirst = _msgs.isEmpty;
    setState(() {
      _msgs.add(t);
      _ctrl.clear();
      _showToggles = false;
      _attachedTool = null;
    });
    if (isFirst) widget.onFirstMessage();
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
    // TODO: ligar resultado (result.files) ao envio da mensagem.
    await FilePicker.pickFiles(allowMultiple: true);
  }

  void _onAttachPhotos() async {
    // TODO: ligar imagem seleccionada ao envio da mensagem.
    await ImagePicker().pickImage(source: ImageSource.gallery);
  }

  void _onOpenCamera() async {
    // TODO: ligar foto capturada ao envio da mensagem.
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
      onOpenTools: () => showToolsSheet(
        context,
        AppTheme.of(context),
        current: _attachedTool,
        onSelect: _onToolSelected,
      ),
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

  @override
  void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    return Column(children: [
      Expanded(
        child: (_msgs.isEmpty && _showToggles)
            ? _EmptyState(s: s, onQuickAction: _onQuickAction)
            : _msgs.isEmpty
                ? const SizedBox.shrink()
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _msgs.length,
                    itemBuilder: (_, i) => _Bubble(s: s, text: _msgs[i]),
                  ),
      ),
      _ChatInput(
        s: s,
        ctrl: _ctrl,
        model: _model,
        attachedTool: _attachedTool,
        onSend: _send,
        onAttach: _openAttachSheet,
        onVoice: _openVoiceSheet,
        onModel: _openModelSheet,
        onClearTool: _onClearTool,
      ),
      const SizedBox(height: 84),
    ]);
  }
}

// ── Empty state — toggles em grelha, somem ao seleccionar ──────

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

// ── Toggle individual (chip compacto com ícone + label + borda) ─

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

// ── Bolha de mensagem ─────────────────────────────────────────

class _Bubble extends StatefulWidget {
  final AppColorScheme s;
  final String text;
  const _Bubble({required this.s, required this.text});
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
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              color: widget.s.primaryContainer,
              borderRadius: BorderRadius.circular(18),
              boxShadow: widget.s.cardShadow,
            ),
            child: Text(widget.text,
                style: TextStyle(
                    color: widget.s.onPrimaryContainer, fontSize: 14)),
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
    required this.onSend,
    required this.onAttach,
    required this.onVoice,
    required this.onModel,
    required this.onClearTool,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Container(
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
                    hintText: 'Escreve uma mensagem...',
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
                    // Botão de adicionar (esquerda) — circular
                    GestureDetector(
                      onTap: onAttach,
                      child: Container(
                        width: 34, height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: s.hover,
                          shape: BoxShape.circle,
                        ),
                        child: AppIcon('add.svg', color: s.onSurface, size: 18),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Selector de modelo
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
                    // Botão de voz — escuro/cinza, não colorido
                    GestureDetector(
                      onTap: onVoice,
                      child: Container(
                        width: 34, height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: s.isDark
                              ? const Color(0xFF3A3A3C)
                              : const Color(0xFFE5E5EA),
                          shape: BoxShape.circle,
                        ),
                        child: AppIcon('record.svg',
                            color: s.onSurfaceVariant, size: 16),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Botão de enviar
                    GestureDetector(
                      onTap: onSend,
                      child: Container(
                        width: 34, height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: s.primary, shape: BoxShape.circle),
                        child: AppIcon('send.svg', color: s.onPrimary, size: 16),
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

// ── Pill que mostra a ferramenta ligada (aparece acima do input) ─

class _AttachedToolPill extends StatelessWidget {
  final AppColorScheme s;
  final EditorType type;
  final VoidCallback onClear;
  const _AttachedToolPill(
      {required this.s, required this.type, required this.onClear});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: s.primaryContainer,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            EditorTypeIcon(type.pngAsset, size: 14),
            const SizedBox(width: 6),
            Text(type.label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: s.onPrimaryContainer)),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: onClear,
              child: AppIcon('close.svg',
                  color: s.onPrimaryContainer, size: 12),
            ),
          ],
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// ATTACH SHEET (modal de anexos: arquivos, fotos, câmera, pesquisa
// online, ferramentas)
// ══════════════════════════════════════════════════════════════

Future<void> showAttachSheet(
  BuildContext context,
  AppColorScheme s, {
  required bool webSearchOn,
  required ValueChanged<bool> onToggleWebSearch,
  required VoidCallback onFiles,
  required VoidCallback onPhotos,
  required VoidCallback onCamera,
  required VoidCallback onOpenTools,
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
      onOpenTools: onOpenTools,
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
  final VoidCallback onOpenTools;

  const _AttachSheetContent({
    required this.s,
    required this.webSearchOn,
    required this.onToggleWebSearch,
    required this.onFiles,
    required this.onPhotos,
    required this.onCamera,
    required this.onOpenTools,
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
              _SheetOption(
                s: s,
                icon: 'tools.svg',
                label: 'Ferramentas',
                subtitle: 'Ligar um documento, folha ou quadro',
                onTap: () { Navigator.pop(context); widget.onOpenTools(); },
              ),
              const SizedBox(height: 2),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
            ],
          ),
        ),
      ),
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
          decoration: BoxDecoration(
            color: _h ? widget.s.hover : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
          ),
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
// TOOLS SHEET (opções do editor: docs / sheets / slides / whiteboard)
// ══════════════════════════════════════════════════════════════

Future<void> showToolsSheet(
  BuildContext context,
  AppColorScheme s, {
  required EditorType? current,
  required ValueChanged<EditorType> onSelect,
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
              ...EditorType.values.map((t) => _ToolOption(
                    s: s,
                    type: t,
                    selected: current == t,
                    onTap: () {
                      onSelect(t);
                      Navigator.pop(ctx);
                    },
                  )),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ToolOption extends StatefulWidget {
  final AppColorScheme s;
  final EditorType type;
  final bool selected;
  final VoidCallback onTap;
  const _ToolOption(
      {required this.s, required this.type, required this.selected, required this.onTap});
  @override State<_ToolOption> createState() => _ToolOptionState();
}

class _ToolOptionState extends State<_ToolOption> {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: _h
                ? widget.s.hover
                : widget.selected
                    ? widget.s.primaryContainer.withOpacity(0.5)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(children: [
            EditorTypeIcon(widget.type.pngAsset, size: 18),
            const SizedBox(width: 10),
            Text(widget.type.label,
                style: TextStyle(
                  fontSize: 14,
                  color: widget.selected
                      ? widget.s.primary
                      : widget.s.onSurface,
                  fontWeight:
                      widget.selected ? FontWeight.w600 : FontWeight.normal,
                )),
          ]),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// VOICE RECORD SHEET (transcrição — só UI, callback TODO)
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
    // TODO: enviar áudio gravado para o serviço de transcrição real
    // e chamar widget.onTranscribed(textoTranscrito).
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
// MODEL SELECT SHEET (lista de modelos DeepSeek)
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
              ...AiModel.values.map((m) => _ModelOption(
                    s: s,
                    model: m,
                    selected: current == m,
                    onTap: () {
                      onSelect(m);
                      Navigator.pop(ctx);
                    },
                  )),
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
  const _ModelOption(
      {required this.s, required this.model, required this.selected, required this.onTap});
  @override State<_ModelOption> createState() => _ModelOptionState();
}

class _ModelOptionState extends State<_ModelOption> {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: _h
                ? widget.s.hover
                : widget.selected
                    ? widget.s.primaryContainer.withOpacity(0.5)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.model.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: widget.selected
                            ? widget.s.primary
                            : widget.s.onSurface,
                      )),
                  const SizedBox(height: 1),
                  Text(widget.model.badge,
                      style: TextStyle(
                          fontSize: 12, color: widget.s.onSurfaceVariant)),
                ],
              ),
            ),
            if (widget.selected)
              AppIcon('check.svg', color: widget.s.primary, size: 16),
          ]),
        ),
      );
}