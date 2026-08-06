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

  void _openToolsSheet() {
    showToolsSheet(
      context,
      AppTheme.of(context),
      current: _attachedTool,
      onSelect: _onToolSelected,
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
    // Espaço ocupado pelo teclado — usado para empurrar o floating
    // input bar para cima quando o teclado abre.
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Column(children: [
      Expanded(
        child: _msgs.isEmpty
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
        webSearchOn: _webSearchOn,
        attachedTool: _attachedTool,
        onSend: _send,
        onFiles: _onAttachFiles,
        onPhotos: _onAttachPhotos,
        onCamera: _onOpenCamera,
        onOpenTools: _openToolsSheet,
        onToggleWebSearch: _onToggleWebSearch,
        onVoice: _openVoiceSheet,
        onModel: _openModelSheet,
        onClearTool: _onClearTool,
      ),
      // Sobe com o teclado (keyboard avoiding) + espaço extra em
      // baixo quando o teclado está fechado, para o bar ficar mais
      // afastada do fundo do ecrã.
      AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: kCupertinoOut,
        height: keyboardInset > 0 ? keyboardInset : 20,
      ),
    ]);
  }
}

// ── Bolha de mensagem ─────────────────────────────────────────

class _Bubble extends StatefulWidget {
  final AppColorScheme s;
  final String text;
  const _Bubble({required this.s, required this.text});
  @override State<_Bubble> createState() => _BubbleState();
}

class _BubbleState extends State<_Bubble> {
  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: s.primaryContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          widget.text,
          style: TextStyle(fontSize: 15, color: s.onPrimaryContainer),
        ),
      ),
    );
  }
}

class _ChatInput extends StatelessWidget {
  final AppColorScheme s;
  final TextEditingController ctrl;
  final AiModel model;
  final bool webSearchOn;
  final EditorType? attachedTool;
  final VoidCallback onSend;
  final VoidCallback onFiles;
  final VoidCallback onPhotos;
  final VoidCallback onCamera;
  final VoidCallback onOpenTools;
  final ValueChanged<bool> onToggleWebSearch;
  final VoidCallback onVoice;
  final VoidCallback onModel;
  final VoidCallback onClearTool;

  const _ChatInput({
    required this.s,
    required this.ctrl,
    required this.model,
    required this.webSearchOn,
    required this.attachedTool,
    required this.onSend,
    required this.onFiles,
    required this.onPhotos,
    required this.onCamera,
    required this.onOpenTools,
    required this.onToggleWebSearch,
    required this.onVoice,
    required this.onModel,
    required this.onClearTool,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
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
                    // Botão de adicionar (esquerda) — abre popup ancorado
                    // com as opções de anexo (mesmo padrão do popup do
                    // menu de conversa), em vez de bottom sheet modal.
                    _AttachMenuButton(
                      s: s,
                      webSearchOn: webSearchOn,
                      onFiles: onFiles,
                      onPhotos: onPhotos,
                      onCamera: onCamera,
                      onOpenTools: onOpenTools,
                      onToggleWebSearch: onToggleWebSearch,
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
                    // Botão de voz — ícone maior
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
                    // Botão de enviar — ícone maior
                    GestureDetector(
                      onTap: onSend,
                      child: Container(
                        width: 36, height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            color: s.primary, shape: BoxShape.circle),
                        child: AppIcon('send.svg', color: s.onPrimary, size: 20),
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
// Comprimento reduzido: paddings e espaçamentos internos mais
// apertados, mantendo cantos totalmente redondos.

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
// ATTACH MENU BUTTON (popup ancorado — substitui o antigo bottom
// sheet modal de anexos). Mesmo padrão de overlay (fade + scale)
// do AiConversationMenuButton, ancorado ao próprio botão "+".
// ══════════════════════════════════════════════════════════════

class _AttachMenuButton extends StatefulWidget {
  final AppColorScheme s;
  final bool webSearchOn;
  final VoidCallback onFiles;
  final VoidCallback onPhotos;
  final VoidCallback onCamera;
  final VoidCallback onOpenTools;
  final ValueChanged<bool> onToggleWebSearch;

  const _AttachMenuButton({
    required this.s,
    required this.webSearchOn,
    required this.onFiles,
    required this.onPhotos,
    required this.onCamera,
    required this.onOpenTools,
    required this.onToggleWebSearch,
  });

  @override
  State<_AttachMenuButton> createState() => _AttachMenuButtonState();
}

class _AttachMenuButtonState extends State<_AttachMenuButton>
    with SingleTickerProviderStateMixin {
  OverlayEntry? _ov;
  late AnimationController _ac;
  late bool _webSearchOn = widget.webSearchOn;

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
          // Abre para cima do botão, já que este fica junto ao fundo
          // do ecrã, dentro da barra de input.
          bottom: MediaQuery.of(ctx).size.height - off.dy + 6,
          left: off.dx,
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
                alignment: Alignment.bottomLeft,
                child: child,
              ),
            ),
            child: StatefulBuilder(
              builder: (ctx, setOverlayState) => Material(
                type: MaterialType.transparency,
                child: Container(
                  width: 240,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: s.isDark ? const Color(0xFF2C2C2E) : Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: s.floatingShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _AttachMenuOption(
                        s: s,
                        icon: 'file.svg',
                        label: 'Arquivos',
                        onTap: () { widget.onFiles(); _close(); },
                      ),
                      _AttachMenuOption(
                        s: s,
                        icon: 'image.svg',
                        label: 'Fotos',
                        onTap: () { widget.onPhotos(); _close(); },
                      ),
                      _AttachMenuOption(
                        s: s,
                        icon: 'camera.svg',
                        label: 'Câmera',
                        onTap: () { widget.onCamera(); _close(); },
                      ),
                      _AttachMenuOption(
                        s: s,
                        icon: 'tools.svg',
                        label: 'Ferramentas',
                        onTap: () { widget.onOpenTools(); _close(); },
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6, vertical: 4),
                        child: Divider(height: 1),
                      ),
                      _AttachMenuSwitchOption(
                        s: s,
                        icon: 'globe.svg',
                        label: 'Pesquisa online',
                        value: _webSearchOn,
                        onChanged: (v) {
                          setOverlayState(() => _webSearchOn = v);
                          widget.onToggleWebSearch(v);
                        },
                      ),
                    ],
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
        behavior: HitTestBehavior.opaque,
        onTap: _toggle,
        child: Container(
          width: 36, height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.s.hover,
            shape: BoxShape.circle,
          ),
          child: AppIcon('add.svg', color: widget.s.onSurface, size: 22),
        ),
      );
}

class _AttachMenuOption extends StatefulWidget {
  final AppColorScheme s;
  final String icon;
  final String label;
  final VoidCallback onTap;
  const _AttachMenuOption({
    required this.s,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  @override State<_AttachMenuOption> createState() => _AttachMenuOptionState();
}

class _AttachMenuOptionState extends State<_AttachMenuOption> {
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
            AppIcon(widget.icon, color: widget.s.onSurface, size: 18),
            const SizedBox(width: 10),
            Text(widget.label,
                style: TextStyle(fontSize: 14, color: widget.s.onSurface)),
          ]),
        ),
      );
}

class _AttachMenuSwitchOption extends StatelessWidget {
  final AppColorScheme s;
  final String icon;
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _AttachMenuSwitchOption({
    required this.s,
    required this.icon,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(children: [
          AppIcon(icon, color: s.onSurface, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 14, color: s.onSurface)),
          ),
          AppSwitch(value: value, s: s, onChanged: onChanged),
        ]),
      );
}

// ══════════════════════════════════════════════════════════════
// CARD GENÉRICO (mesmo padrão do _SettingsCard, ainda usado pelo
// tools sheet e model sheet abaixo) e opções em grupo
// ══════════════════════════════════════════════════════════════

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
  final List<_SheetOption> options;
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
              _SheetOptionsGroup(
                s: s,
                options: EditorType.values
                    .map((t) => _ToolOptionAsSheetOption(
                          s: s,
                          type: t,
                          selected: current == t,
                          onTap: () {
                            onSelect(t);
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

// _ToolOption adaptado para o novo padrão de card (extends
// _SheetOption por composição, não por herança, para reaproveitar
// o mesmo grupo/raios; aqui é um widget próprio pois o layout
// interno difere — inclui indicador de selecção).

class _ToolOptionAsSheetOption extends _SheetOption {
  final bool selected;
  _ToolOptionAsSheetOption({
    required AppColorScheme s,
    required EditorType type,
    required this.selected,
    required VoidCallback onTap,
  }) : super(
          s: s,
          icon: '',
          label: type.label,
          subtitle: '',
          onTap: onTap,
        ) {
    _type = type;
  }
  late final EditorType _type;

  @override
  State<_SheetOption> createState() => _ToolOptionAsSheetOptionState();
}

class _ToolOptionAsSheetOptionState extends State<_SheetOption> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final w = widget as _ToolOptionAsSheetOption;
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
          EditorTypeIcon(w._type.pngAsset, size: 18),
          const SizedBox(width: 10),
          Text(w._type.label,
              style: TextStyle(
                fontSize: 14,
                color: w.selected ? w.s.primary : w.s.onSurface,
                fontWeight: w.selected ? FontWeight.w600 : FontWeight.normal,
              )),
        ]),
      ),
    );
  }
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
                  child: AppIcon(
                    _recording ? 'record.svg' : 'record.svg',
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
              _SheetOptionsGroup(
                s: s,
                options: AiModel.values
                    .map((m) => _ModelOptionAsSheetOption(
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

class _ModelOptionAsSheetOption extends _SheetOption {
  final bool selected;
  _ModelOptionAsSheetOption({
    required AppColorScheme s,
    required AiModel model,
    required this.selected,
    required VoidCallback onTap,
  }) : super(s: s, icon: '', label: '', subtitle: '', onTap: onTap) {
    _model = model;
  }
  late final AiModel _model;

  @override
  State<_SheetOption> createState() => _ModelOptionAsSheetOptionState();
}

class _ModelOptionAsSheetOptionState extends State<_SheetOption> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final w = widget as _ModelOptionAsSheetOption;
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
                Text(w._model.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: w.selected ? w.s.primary : w.s.onSurface,
                    )),
                const SizedBox(height: 1),
                Text(w._model.badge,
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