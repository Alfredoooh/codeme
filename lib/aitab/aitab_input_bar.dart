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

  Widget _compact() {
    return Container(
      key: const ValueKey('compact'),
      height: 52,
      padding: const EdgeInsets.fromLTRB(6, 0, 6, 0),
      decoration: BoxDecoration(
        color: s.isDark ? s.cardBackground : s.floatingSurface,
        borderRadius: BorderRadius.circular(26),
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