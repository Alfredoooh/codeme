// ══════════════════════════════════════════════════════════════
// FILE: lib/aitab/aitab_input_bar.dart
//
// MUDANÇAS NESTA VERSÃO:
// 1) Zero Cupertino, zero showAppSheet — todos os sheets deste
//    ficheiro usam a MESMA infraestrutura do drawermenu.dart:
//    showFlatBottomSheet + _ModalHandlebar, radius 20, mesma cor
//    de fundo (s.cardBackground) e mesma handlebar.
// 2) Os cards de anexo (Câmera / Fotos / Arquivo local) usam
//    s.pageBackground como fundo (fundo do corpo do app), não
//    s.cardBackground/s.hover — só o fundo do sheet em si continua
//    com a cor de card, igual ao drawer.
// 3) Botão de enviar: em "sending" (respondendo), no tema escuro
//    fica branco puro sem borda com ícone pause azul (s.primary);
//    no tema claro fica com s.primary sólido e ícone pause branco
//    puro. Sem bordas em nenhum dos dois casos.
// 4) Novo botão de gravação de voz ao lado do botão de enviar:
//    tema escuro = fundo branco + ícone record.svg; tema claro =
//    fundo s.primary + ícone record.svg. Quando o campo está vazio,
//    o botão de enviar desaparece e o de gravar ocupa o lugar dele
//    (anima suavemente até lá); ao digitar, o botão de gravar volta
//    deslizando para o seu lugar enquanto o de enviar entra com
//    crescimento suave (scale 0 → 1).
// 5) Câmera e visualizador de imagem passam a ser telas próprias do
//    app, em ficheiros separados: aitab_camera_screen.dart e
//    aitab_image_viewer_screen.dart.
// ══════════════════════════════════════════════════════════════

import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../core/widgets/animated_canvas_icon.dart';
import '../apps/app_types.dart';
import '../apps/registry/app_registry.dart';
import '../apps/sheets/sheets.dart';
import 'aitab_models.dart';
import 'aitab_widgets_shared.dart';
import 'aitab_camera_screen.dart';
import 'aitab_image_viewer_screen.dart';

// ══════════════════════════════════════════════════════════════
// SHEET GENÉRICO PLANO — mesma infraestrutura do drawermenu.dart.
// Radius, handlebar e cor de fundo idênticos: s.cardBackground,
// topo arredondado em _kFlatModalRadius, handlebar 36×4 centrada.
// ══════════════════════════════════════════════════════════════

const double _kFlatModalRadius = 20.0;

class _ModalHandlebar extends StatelessWidget {
  final AppColorScheme s;
  const _ModalHandlebar({required this.s});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 4),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: s.onSurfaceVariant.withOpacity(0.35),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }
}

Future<T?> showFlatBottomSheet<T>({
  required BuildContext context,
  required AppColorScheme s,
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: s.cardBackground,
    barrierColor: Colors.black.withOpacity(0.35),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(_kFlatModalRadius)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ModalHandlebar(s: s),
          Flexible(child: builder(sheetContext)),
        ],
      ),
    ),
  );
}

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
  final VoidCallback onRecord;
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
    required this.onRecord,
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
              onRecord: onRecord,
            ),
          ],
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// SHELL DO INPUT
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
  final VoidCallback onRecord;

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
    required this.onRecord,
  });

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
                _SendRecordCluster(
                  s: s,
                  hasText: hasText,
                  sending: sending,
                  onSend: onSend,
                  onPause: onPause,
                  onRecord: onRecord,
                ),
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

// ══════════════════════════════════════════════════════════════
// CLUSTER: botão de gravar + botão de enviar/pausa
//
// Comportamento pedido:
// - Sem texto: botão de enviar não existe (nem invisível — some do
//   layout), e o botão de gravar ocupa exatamente o lugar dele
//   (mesma posição à direita).
// - Ao escrever: o botão de gravar desliza suavemente para a sua
//   posição própria (à esquerda do de enviar) enquanto o botão de
//   enviar entra com um crescimento suave (scale 0 → 1, do centro).
// - Durante "sending": o botão de enviar vira botão de pausa com
//   as cores por tema descritas acima; o botão de gravar continua
//   visível na sua posição normal (ainda com texto presente).
// ══════════════════════════════════════════════════════════════

class _SendRecordCluster extends StatelessWidget {
  final AppColorScheme s;
  final bool hasText;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onPause;
  final VoidCallback onRecord;

  static const double _btnSize = 36;
  static const Duration _dur = Duration(milliseconds: 220);
  static const Curve _curve = Curves.easeOutCubic;

  const _SendRecordCluster({
    required this.s,
    required this.hasText,
    required this.sending,
    required this.onSend,
    required this.onPause,
    required this.onRecord,
  });

  @override
  Widget build(BuildContext context) {
    // showSend: há texto (ou está a enviar/responder, para permitir pausar).
    final showSend = hasText || sending;

    return SizedBox(
      height: _btnSize,
      // Largura total: botão de gravar + gap + botão de enviar, quando
      // ambos visíveis; só o de gravar, quando o de enviar some.
      width: showSend ? (_btnSize * 2 + 8) : _btnSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Botão de gravar: anima a sua posição horizontal (left)
          // entre "no lugar do botão de enviar" (0) e "na sua posição
          // própria" (0, já que fica à esquerda quando os dois existem).
          AnimatedPositioned(
            duration: _dur,
            curve: _curve,
            left: 0,
            top: 0,
            child: _RecordButton(s: s, size: _btnSize, onTap: onRecord),
          ),
          // Botão de enviar/pausa: só existe quando showSend é true.
          // Entrada com crescimento suave (scale 0 → 1) a partir do
          // centro da sua posição final.
          AnimatedPositioned(
            duration: _dur,
            curve: _curve,
            right: 0,
            top: 0,
            child: AnimatedScale(
              duration: _dur,
              curve: _curve,
              scale: showSend ? 1.0 : 0.0,
              alignment: Alignment.center,
              child: AnimatedOpacity(
                duration: _dur,
                curve: _curve,
                opacity: showSend ? 1.0 : 0.0,
                child: IgnorePointer(
                  ignoring: !showSend,
                  child: _SendButton(
                    s: s,
                    hasText: hasText,
                    sending: sending,
                    onSend: onSend,
                    onPause: onPause,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final AppColorScheme s;
  final bool hasText;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onPause;

  static const double _size = 36;

  const _SendButton({
    required this.s,
    required this.hasText,
    required this.sending,
    required this.onSend,
    required this.onPause,
  });

  @override
  Widget build(BuildContext context) {
    final active = hasText && !sending;

    // Cores durante "sending" (respondendo):
    // - escuro: fundo branco puro, sem borda; ícone pause em s.primary (azul).
    // - claro: fundo s.primary sólido, sem borda; ícone pause branco puro.
    final Color sendingBg = s.isDark ? Colors.white : s.primary;
    final Color sendingIcon = s.isDark ? s.primary : Colors.white;

    return GestureDetector(
      onTap: sending ? onPause : (hasText ? onSend : null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: _size,
        height: _size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sending
              ? sendingBg
              : active
                  ? s.primary
                  : s.hover,
          shape: BoxShape.circle,
        ),
        child: AppIcon(
          sending ? 'pause' : 'arrow_up',
          color: sending
              ? sendingIcon
              : active
                  ? Colors.white
                  : s.onSurfaceVariant,
          size: sending ? 16 : 20,
        ),
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  final AppColorScheme s;
  final double size;
  final VoidCallback onTap;

  const _RecordButton({
    required this.s,
    required this.size,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Escuro: fundo branco puro + ícone record.svg.
    // Claro: fundo s.primary sólido + ícone record.svg.
    final Color bg = s.isDark ? Colors.white : s.primary;
    final Color iconColor = s.isDark ? s.primary : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
        ),
        child: AppIcon('record', color: iconColor, size: 18),
      ),
    );
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
// ANEXOS FLUTUANTES
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
        physics: const BouncingScrollPhysics(),
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
    // Visualizador de imagem em ficheiro próprio.
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.92),
        pageBuilder: (_, anim, __) => FadeTransition(
          opacity: anim,
          child: AitabImageViewerScreen(file: file, isImage: _isImage),
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

// ══════════════════════════════════════════════════════════════
// SHEET: TEXTO SELECIONÁVEL
// ══════════════════════════════════════════════════════════════

Future<void> showSelectTextSheet(
  BuildContext context,
  AppColorScheme s, {
  required String text,
}) {
  return showFlatBottomSheet<void>(
    context: context,
    s: s,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Selecionar texto',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w600, color: s.onSurface)),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SelectableText(
                text,
                style: TextStyle(fontSize: 15, color: s.onSurface, height: 1.5),
              ),
            ),
          ),
        ],
      ),
    ),
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
  return showFlatBottomSheet<void>(
    context: context,
    s: s,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
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
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
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
  return showFlatBottomSheet<void>(
    context: context,
    s: s,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
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
// SHEET: MENU "+"
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
  return showFlatBottomSheet<void>(
    context: context,
    s: s,
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

// Card de opção de anexo: fundo igual ao fundo do corpo do app
// (s.pageBackground), não mais s.hover/s.cardBackground — só o
// sheet em si mantém a cor de card, como no drawer.
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
          color: _h ? s.pageBackground.withOpacity(0.6) : s.pageBackground,
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
  return showFlatBottomSheet<void>(
    context: context,
    s: s,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Apps',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: s.onSurface)),
          const SizedBox(height: 12),
          _AppsConnectSheetContent(s: s),
        ],
      ),
    ),
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
    return Column(
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
// Abre a câmera própria do app (ficheiro separado).
// Chame a partir de onCamera do showAttachMenuSheet, por exemplo:
//   onCamera: () => openAitabCamera(context, onCaptured: (bytes) {...}),
// ══════════════════════════════════════════════════════════════

Future<void> openAitabCamera(
  BuildContext context, {
  required ValueChanged<AttachedFile> onCaptured,
}) async {
  final result = await Navigator.of(context).push<AttachedFile>(
    PageRouteBuilder(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, anim, __) => FadeTransition(
        opacity: anim,
        child: const AitabCameraScreen(),
      ),
    ),
  );
  if (result != null) onCaptured(result);
}