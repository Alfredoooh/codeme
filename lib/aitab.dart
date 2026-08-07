import 'dart:async';
import 'dart:math' as math;
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
// AI MODEL
// ══════════════════════════════════════════════════════════════

enum AiModel { v4Flash, v4Pro, r1Think }

extension AiModelX on AiModel {
  String get label => const {
        AiModel.v4Flash: 'V4 Flash',
        AiModel.v4Pro:   'V4 Pro',
        AiModel.r1Think: 'R1 Think',
      }[this]!;

  String get badge => const {
        AiModel.v4Flash: 'Rápido',
        AiModel.v4Pro:   'Avançado',
        AiModel.r1Think: 'Raciocínio',
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
                  color: s.floatingSurface,
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
  AiModel  _model        = AiModel.v4Flash;
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

  @override
  void dispose() { _ctrl.dispose(); _scroll.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
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
        onToolSelected: _onToolSelected,
        onToggleWebSearch: _onToggleWebSearch,
        onVoice: _openVoiceSheet,
        onModelSelected: _onModelSelected,
        onClearTool: _onClearTool,
      ),
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
  final ValueChanged<EditorType> onToolSelected;
  final ValueChanged<bool> onToggleWebSearch;
  final VoidCallback onVoice;
  final ValueChanged<AiModel> onModelSelected;
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
    required this.onToolSelected,
    required this.onToggleWebSearch,
    required this.onVoice,
    required this.onModelSelected,
    required this.onClearTool,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
        child: Container(
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
                    _AttachMenuButton(
                      s: s,
                      webSearchOn: webSearchOn,
                      attachedTool: attachedTool,
                      onFiles: onFiles,
                      onPhotos: onPhotos,
                      onCamera: onCamera,
                      onToolSelected: onToolSelected,
                      onToggleWebSearch: onToggleWebSearch,
                    ),
                    const SizedBox(width: 6),
                    _ModelMenuButton(
                      s: s,
                      current: model,
                      onSelected: onModelSelected,
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

// ── Pill que mostra a ferramenta ligada ─────────────────────────

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
// POPUP BASE — helper genérico para popups ancorados
// ══════════════════════════════════════════════════════════════

class _AnchoredPopupButton extends StatefulWidget {
  final AppColorScheme s;
  final Widget Function(BuildContext, VoidCallback close) menuBuilder;
  final Widget child;
  final double width;
  const _AnchoredPopupButton({
    required this.s,
    required this.menuBuilder,
    required this.child,
    this.width = 240,
  });

  @override
  State<_AnchoredPopupButton> createState() => _AnchoredPopupButtonState();
}

class _AnchoredPopupButtonState extends State<_AnchoredPopupButton>
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

    _ov = OverlayEntry(builder: (ctx) {
      final s = widget.s;
      final screenH = MediaQuery.of(ctx).size.height;
      return Stack(children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: close,
            behavior: HitTestBehavior.opaque,
            child: Container(color: Colors.transparent),
          ),
        ),
        Positioned(
          bottom: screenH - off.dy + 6,
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
            child: Material(
              type: MaterialType.transparency,
              child: Container(
                width: widget.width,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: s.floatingSurface,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: s.floatingShadow,
                ),
                child: widget.menuBuilder(ctx, close),
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
        child: widget.child,
      );
}

class _MenuOption extends StatefulWidget {
  final AppColorScheme s;
  final String icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  const _MenuOption({
    required this.s,
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
  });
  @override State<_MenuOption> createState() => _MenuOptionState();
}

class _MenuOptionState extends State<_MenuOption> {
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _h
              ? s.hover
              : widget.selected
                  ? s.primaryContainer.withOpacity(0.5)
                  : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(children: [
          AppIcon(widget.icon,
              color: widget.selected ? s.primary : s.onSurface, size: 18),
          const SizedBox(width: 10),
          Text(widget.label,
              style: TextStyle(
                fontSize: 14,
                color: widget.selected ? s.primary : s.onSurface,
                fontWeight: widget.selected ? FontWeight.w600 : FontWeight.normal,
              )),
        ]),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// ATTACH MENU BUTTON (popup ancorado)
// ══════════════════════════════════════════════════════════════

class _AttachMenuButton extends StatefulWidget {
  final AppColorScheme s;
  final bool webSearchOn;
  final EditorType? attachedTool;
  final VoidCallback onFiles;
  final VoidCallback onPhotos;
  final VoidCallback onCamera;
  final ValueChanged<EditorType> onToolSelected;
  final ValueChanged<bool> onToggleWebSearch;

  const _AttachMenuButton({
    required this.s,
    required this.webSearchOn,
    required this.attachedTool,
    required this.onFiles,
    required this.onPhotos,
    required this.onCamera,
    required this.onToolSelected,
    required this.onToggleWebSearch,
  });

  @override
  State<_AttachMenuButton> createState() => _AttachMenuButtonState();
}

class _AttachMenuButtonState extends State<_AttachMenuButton> {
  late bool _webSearchOn = widget.webSearchOn;

  @override
  Widget build(BuildContext context) => _AnchoredPopupButton(
        s: widget.s,
        width: 240,
        menuBuilder: (ctx, close) => StatefulBuilder(
          builder: (ctx, setOverlayState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _MenuOption(
                s: widget.s, icon: 'file.svg', label: 'Arquivos',
                onTap: () { widget.onFiles(); close(); },
              ),
              _MenuOption(
                s: widget.s, icon: 'image.svg', label: 'Fotos',
                onTap: () { widget.onPhotos(); close(); },
              ),
              _MenuOption(
                s: widget.s, icon: 'camera.svg', label: 'Câmera',
                onTap: () { widget.onCamera(); close(); },
              ),
              ...EditorType.values.map((t) => _MenuOption(
                    s: widget.s,
                    icon: 'tools.svg',
                    label: t.label,
                    selected: widget.attachedTool == t,
                    onTap: () { widget.onToolSelected(t); close(); },
                  )),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Divider(height: 1),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                child: Row(children: [
                  AppIcon('globe.svg', color: widget.s.onSurface, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Pesquisa online',
                        style: TextStyle(
                            fontSize: 14, color: widget.s.onSurface)),
                  ),
                  AppSwitch(
                    value: _webSearchOn,
                    s: widget.s,
                    onChanged: (v) {
                      setOverlayState(() => _webSearchOn = v);
                      widget.onToggleWebSearch(v);
                    },
                  ),
                ]),
              ),
            ],
          ),
        ),
        child: Container(
          width: 36, height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: widget.s.hover, shape: BoxShape.circle),
          child: AppIcon('add.svg', color: widget.s.onSurface, size: 22),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// MODEL MENU BUTTON (popup ancorado — V4 Flash / V4 Pro / R1 Think)
// ══════════════════════════════════════════════════════════════

class _ModelMenuButton extends StatelessWidget {
  final AppColorScheme s;
  final AiModel current;
  final ValueChanged<AiModel> onSelected;
  const _ModelMenuButton(
      {required this.s, required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) => _AnchoredPopupButton(
        s: s,
        width: 200,
        menuBuilder: (ctx, close) => Column(
          mainAxisSize: MainAxisSize.min,
          children: AiModel.values
              .map((m) => Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () { onSelected(m); close(); },
                      child: Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(m.label,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: current == m ? s.primary : s.onSurface,
                                  )),
                              Text(m.badge,
                                  style: TextStyle(
                                      fontSize: 12, color: s.onSurfaceVariant)),
                            ],
                          ),
                        ),
                        if (current == m)
                          AppIcon('check.svg', color: s.primary, size: 16),
                      ]),
                    ),
                  ))
              .toList(),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: s.hover,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(current.label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: s.onSurface)),
              const SizedBox(width: 3),
              Text(current.badge,
                  style: TextStyle(fontSize: 12, color: s.onSurfaceVariant)),
            ],
          ),
        ),
      );
}

// ══════════════════════════════════════════════════════════════
// VOICE RECORD SHEET
// ── SEM dependência de pacote de áudio nenhum (nem 'record', nem
// qualquer outro): o projeto compila para Web via Render e o teu
// pubspec.yaml não tinha 'record' instalado, o que causou a falha
// de build reportada ("Compilation failed" no import de
// package:record). Em vez de acrescentar mais uma dependência
// nova (risco de build outra vez, especialmente em Web, onde nem
// todo pacote de áudio tem suporte pleno), as ondas aqui são
// puramente visuais: alturas geradas localmente por Timer, sem
// captar o microfone real.
// Se mais tarde quiseres ondas ligadas à amplitude REAL do som,
// terás de correr `flutter pub add record` tu mesmo (ou escolher
// outro pacote), confirmar que builda em Web, e então eu ligo o
// stream de amplitude aqui — não posso adicionar essa dependência
// sem essa confirmação prévia, para não repetir este erro.
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

class _VoiceRecordSheetContentState extends State<_VoiceRecordSheetContent> {
  Timer? _clock;
  Timer? _waveTimer;
  int _seconds = 0;
  bool _recording = true;
  final math.Random _rnd = math.Random();

  // Histórico de "níveis" (0.0–1.0) só visual, suavizado para não
  // saltar de forma brusca entre frames.
  final List<double> _levels = List.filled(28, 0.06);

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
    _waveTimer = Timer.periodic(const Duration(milliseconds: 90), (_) {
      if (!mounted || !_recording) return;
      setState(() {
        _levels.removeAt(0);
        // Passeio aleatório suave em torno do último valor, com
        // picos ocasionais — dá uma sensação orgânica sem ligação
        // real ao som do utilizador.
        final last = _levels.isNotEmpty ? _levels.last : 0.3;
        final spike = _rnd.nextDouble() < 0.12
            ? _rnd.nextDouble() * 0.5
            : 0.0;
        final next = (last + (_rnd.nextDouble() - 0.5) * 0.35 + spike)
            .clamp(0.06, 1.0);
        _levels.add(next);
      });
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    _waveTimer?.cancel();
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
                style: TextStyle(fontSize: 13, color: s.onSurfaceVariant),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 64,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: _levels
                      .map((lvl) => AnimatedContainer(
                            duration: const Duration(milliseconds: 90),
                            curve: kCupertinoOut,
                            width: 3.5,
                            height: 8 + (lvl * 48),
                            margin: const EdgeInsets.symmetric(horizontal: 1.6),
                            decoration: BoxDecoration(
                              color: s.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ))
                      .toList(),
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