// ══════════════════════════════════════════════════════════════
// FILE: lib/aitab/aitab_input_bar.dart
// A barra de input do chat, pills de anexo, e todos os sheets
// acionados a partir dela (voz, opções de IA, apps, canvas,
// ficheiros anexados, seleção de texto).
//
// ATUALIZAÇÃO NESTA VERSÃO:
// 1) _FloatingAttachmentChip deixou de renderizar preview de
//    imagem inline — mostra sempre nome + ícone close_circle,
//    igual a qualquer outro tipo de ficheiro. O toque no chip
//    (fora do botão de remover) abre a visualização em ecrã
//    inteiro, tanto para imagens como para outros ficheiros.
// 2) showAttachMenuSheet agora usa a mesma lógica de popup
//    ancorado (crescimento a partir do botão, scale+fade) já
//    usada — trazida da mesma família de _AnchoredPopupRoute que
//    já existia neste ficheiro, sem depender de nada do main.dart.
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
  final List<AttachedFile> attachedFiles;
  final bool incognito;
  final bool sending;
  final GlobalKey attachButtonKey;
  final VoidCallback onSend;
  final VoidCallback onPause;
  final VoidCallback onAttach;
  final ValueChanged<String> onRemoveFile;

  const ChatInput({
    super.key,
    required this.s,
    required this.ctrl,
    required this.focusNode,
    required this.attachedTool,
    required this.attachedFiles,
    required this.incognito,
    required this.sending,
    required this.attachButtonKey,
    required this.onSend,
    required this.onPause,
    required this.onAttach,
    required this.onRemoveFile,
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

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Anexos flutuam por cima do bottombar, não dentro dele.
            if (attachedFiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _FloatingAttachmentsRow(
                  s: s,
                  files: attachedFiles,
                  onRemove: onRemoveFile,
                ),
              ),
            _ChatInputShell(
              s: s,
              hasText: hasText,
              incognito: incognito,
              sending: sending,
              floatingShadow: floatingShadow,
              attachedTool: attachedTool,
              attachButtonKey: attachButtonKey,
              ctrl: ctrl,
              focusNode: focusNode,
              onSend: onSend,
              onPause: onPause,
              onAttach: onAttach,
            ),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHELL DO INPUT — cresce progressivamente com o texto, com
// altura máxima definida (não expande tudo de uma vez ao focar).
// ══════════════════════════════════════════════════════════════

class _ChatInputShell extends StatelessWidget {
  final AppColorScheme s;
  final bool hasText;
  final bool incognito;
  final bool sending;
  final List<BoxShadow> floatingShadow;
  final EditorType? attachedTool;
  final GlobalKey attachButtonKey;
  final TextEditingController ctrl;
  final FocusNode focusNode;
  final VoidCallback onSend;
  final VoidCallback onPause;
  final VoidCallback onAttach;

  // Altura máxima do bottombar antes de o texto passar a fazer
  // scroll internamente. Ajusta este valor se quiseres mais/menos
  // linhas visíveis antes do limite.
  static const double _maxInputHeight = 168.0;
  static const double _minInputHeight = 52.0;

  const _ChatInputShell({
    required this.s,
    required this.hasText,
    required this.incognito,
    required this.sending,
    required this.floatingShadow,
    required this.attachedTool,
    required this.attachButtonKey,
    required this.ctrl,
    required this.focusNode,
    required this.onSend,
    required this.onPause,
    required this.onAttach,
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

  Widget _textField() {
    return TextField(
      controller: ctrl,
      focusNode: focusNode,
      minLines: 1,
      maxLines: null,
      keyboardType: TextInputType.multiline,
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

  Widget _toolPillRow() {
    if (attachedTool == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _AttachedToolPill(s: s, type: attachedTool!, onClear: () {}),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // O teclado abre imediatamente ao tocar (foco normal do
    // TextField); o que aqui controlamos é só a altura visual do
    // shell, que cresce com o conteúdo até _maxInputHeight e depois
    // passa a fazer scroll interno do texto.
    final content = Container(
      constraints: const BoxConstraints(
        minHeight: _minInputHeight,
        maxHeight: _maxInputHeight,
      ),
      decoration: BoxDecoration(
        color: s.isDark ? s.cardBackground : s.floatingSurface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: floatingShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolPillRow(),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              reverse: true,
              child: _textField(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 0, 12, 8),
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

    final animated = AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      child: content,
    );

    return incognito
        ? DashedRRectBorder(
            color: s.outline,
            radius: 26,
            child: animated,
          )
        : animated;
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

// ══════════════════════════════════════════════════════════════
// ANEXOS FLUTUANTES — ficam por cima do bottombar (não dentro
// dele). Cada chip mostra SOMENTE nome + ícone close_circle, para
// qualquer tipo de ficheiro (imagem ou não) — nunca renderiza a
// imagem em si dentro do chip. O toque no chip (fora do botão de
// remover) abre a visualização em ecrã inteiro.
// ══════════════════════════════════════════════════════════════

class _FloatingAttachmentsRow extends StatelessWidget {
  final AppColorScheme s;
  final List<AttachedFile> files;
  final ValueChanged<String> onRemove;
  const _FloatingAttachmentsRow({
    required this.s,
    required this.files,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: files.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => _FloatingAttachmentChip(
          s: s,
          file: files[i],
          onRemove: () => onRemove(files[i].id),
        ),
      ),
    );
  }
}

class _FloatingAttachmentChip extends StatelessWidget {
  final AppColorScheme s;
  final AttachedFile file;
  final VoidCallback onRemove;
  const _FloatingAttachmentChip({
    required this.s,
    required this.file,
    required this.onRemove,
  });

  bool get _isImage => file.mimeType.startsWith('image/');

  void _openFullScreen(BuildContext context) {
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.92),
        pageBuilder: (_, anim, __) => FadeTransition(
          opacity: anim,
          child: _FullScreenFileView(file: file, isImage: _isImage),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullScreen(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 44,
        padding: const EdgeInsets.only(left: 14, right: 8),
        decoration: BoxDecoration(
          color: s.isDark ? const Color(0xFF262626) : const Color(0xFF262626),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(s.isDark ? 0.24 : 0.08),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 160),
              child: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: onRemove,
              child: Container(
                width: 26, height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close, size: 15, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Visualização em ecrã inteiro de um anexo. Para imagens, mostra
/// a imagem com zoom/pan. Para outros ficheiros, mostra um cartão
/// com o ícone do tipo e o nome — nunca tenta renderizar preview
/// de binários não suportados.
class _FullScreenFileView extends StatelessWidget {
  final AttachedFile file;
  final bool isImage;
  const _FullScreenFileView({required this.file, required this.isImage});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).pop(),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: isImage
                    ? InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4,
                        child: Image.memory(file.bytes, fit: BoxFit.contain),
                      )
                    : GestureDetector(
                        onTap: () {}, // evita fechar ao tocar no cartão
                        child: Container(
                          width: 220,
                          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.insert_drive_file,
                                  size: 48, color: Colors.white70),
                              const SizedBox(height: 14),
                              Text(
                                file.name,
                                textAlign: TextAlign.center,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    width: 36, height: 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      shape: BoxShape.circle,
                    ),
                    child: const AppIcon('close', color: Colors.white, size: 18),
                  ),
                ),
              ),
              if (isImage)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 20,
                  child: Text(
                    file.name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
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
// MENU POPUP: "+" — ancorado ao botão, cresce a partir dele com
// animação suave de scale + fade, cantos bem curvos. Esta é a
// MESMA lógica de popup ancorado (_AnchoredPopupRoute) usada em
// todo o resto da app para o botão de opções.
// ══════════════════════════════════════════════════════════════

enum _AttachMenuPageKind { root, modelSelect }

Future<void> showAttachMenuSheet(
  BuildContext context,
  AppColorScheme s, {
  required GlobalKey anchorKey,
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
  final renderBox = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null) return Future.value();

  final anchorPosition = renderBox.localToGlobal(Offset.zero);
  final anchorSize = renderBox.size;
  final screenSize = MediaQuery.of(context).size;

  return Navigator.of(context, rootNavigator: true).push(
    _AnchoredPopupRoute(
      anchorTopLeft: anchorPosition,
      anchorSize: anchorSize,
      screenSize: screenSize,
      builder: (ctx) => _AttachMenuSheetContent(
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
    ),
  );
}

/// Rota transparente que posiciona o menu ancorado ao botão de
/// origem e anima crescimento (scale a partir do canto do botão)
/// + fade, em vez de um bottom sheet a subir do fundo do ecrã.
class _AnchoredPopupRoute extends PopupRoute<void> {
  final Offset anchorTopLeft;
  final Size anchorSize;
  final Size screenSize;
  final WidgetBuilder builder;

  _AnchoredPopupRoute({
    required this.anchorTopLeft,
    required this.anchorSize,
    required this.screenSize,
    required this.builder,
  });

  @override
  Color? get barrierColor => Colors.black.withOpacity(0.32);

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Fechar menu';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 240);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 180);

  static const double _menuWidth = 300.0;
  static const double _margin = 12.0;

  @override
  Widget buildPage(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation) {
    // Ancora o menu por cima do botão "+", alinhado à esquerda dele,
    // com a base do menu assente logo acima do topo do botão.
    final anchorCenterX = anchorTopLeft.dx + (anchorSize.width / 2);
    double left = anchorTopLeft.dx - 4;
    if (left + _menuWidth > screenSize.width - _margin) {
      left = screenSize.width - _margin - _menuWidth;
    }
    if (left < _margin) left = _margin;

    final bottomAnchor = screenSize.height - anchorTopLeft.dy + 10;
    final alignmentX = ((anchorCenterX - left) / _menuWidth).clamp(0.0, 1.0);

    return Stack(
      children: [
        Positioned(
          left: left,
          right: null,
          bottom: bottomAnchor,
          width: _menuWidth,
          child: _AnimatedAnchoredMenu(
            animation: animation,
            growthAlignment: Alignment(alignmentX * 2 - 1, 1.0),
            child: builder(context),
          ),
        ),
      ],
    );
  }

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation,
      Animation<double> secondaryAnimation, Widget child) {
    // O crescimento animado já acontece dentro de buildPage via
    // _AnimatedAnchoredMenu, para poder ancorar corretamente ao
    // ponto do botão (Alignment dinâmico consoante a posição).
    return child;
  }
}

class _AnimatedAnchoredMenu extends StatelessWidget {
  final Animation<double> animation;
  final Alignment growthAlignment;
  final Widget child;
  const _AnimatedAnchoredMenu({
    required this.animation,
    required this.growthAlignment,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Curves.easeOutBack,
      reverseCurve: Curves.easeIn,
    );
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      reverseCurve: Curves.easeIn,
    );

    return Align(
      alignment: growthAlignment,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.82, end: 1.0).animate(curved),
        alignment: growthAlignment,
        child: FadeTransition(
          opacity: fade,
          child: SafeArea(
            top: false,
            child: Material(
              color: Colors.transparent,
              child: child,
            ),
          ),
        ),
      ),
    );
  }
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
    return Container(
      decoration: BoxDecoration(
        color: s.isDark ? s.cardBackground : s.floatingSurface,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(s.isDark ? 0.36 : 0.16),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: Alignment.bottomCenter,
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
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
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
          const SizedBox(height: 16),
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