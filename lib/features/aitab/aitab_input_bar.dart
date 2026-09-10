// ══════════════════════════════════════════════════════════════
// FILE: lib/aitab/aitab_input_bar.dart
//
// MUDANÇAS NESTA VERSÃO:
// 1) O modal de gravação (_VoiceRecordSheetContent / showVoiceRecordSheet)
//    foi TOTALMENTE REMOVIDO. A gravação agora vive apenas dentro do
//    próprio input bar (pill).
// 2) A pill de gravação perdeu o gradiente. Em vez disso usa uma
//    waveform de traços verticais animados, como os recorders
//    modernos (estilo IA de hoje em dia).
// 3) O botão de close já não fica flutuante em cima da pill —
//    está DE LADO, à direita, num botão circular separado. A pill
//    foi encurtada (é Expanded) para o close caber ao lado.
// 4) Adicionados botões de PAUSAR / RETOMAR dentro da pill.
//    Ao pausar: a waveform congela, o mic deixa de pulsar, o texto
//    muda para "Pausado" e o timer para de contar.
// 5) ChatInput ganhou dois callbacks opcionais novos:
//    onRecordPause e onRecordResume (para o pai pausar/retomar a
//    gravação real do microfone).
// 6) Continua compatível com web: só AnimationController, Timer,
//    math, MouseRegion — nada específico de Android/iOS.
// ══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FontFeature;
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
    enableDrag: true,
    isDismissible: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius:
          BorderRadius.vertical(top: Radius.circular(_kFlatModalRadius)),
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
// SUPERFÍCIE REUTILIZÁVEL COM HOVER + PRESS + TAP
// ══════════════════════════════════════════════════════════════

class _HoverSurface extends StatefulWidget {
  final AppColorScheme s;
  final BorderRadius borderRadius;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;
  final Color? baseColor;
  final Color? hoverColor;
  final Color? pressedColor;

  const _HoverSurface({
    required this.s,
    required this.borderRadius,
    required this.child,
    this.onTap,
    this.padding,
    this.baseColor,
    this.hoverColor,
    this.pressedColor,
  });

  @override
  State<_HoverSurface> createState() => _HoverSurfaceState();
}

class _HoverSurfaceState extends State<_HoverSurface> {
  bool _hovered = false;
  bool _pressed = false;

  Color _resolveColor() {
    final s = widget.s;

    if (_pressed) {
      return widget.pressedColor ??
          (s.isDark ? Colors.white.withOpacity(0.10) : s.hover);
    }

    if (_hovered) {
      return widget.hoverColor ??
          (s.isDark ? Colors.white.withOpacity(0.07) : s.hover);
    }

    return widget.baseColor ??
        (s.isDark ? Colors.white.withOpacity(0.045) : s.surface);
  }

  @override
  Widget build(BuildContext context) {
    final tappable = widget.onTap != null;

    return MouseRegion(
      cursor: tappable ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: tappable ? (_) => setState(() => _pressed = true) : null,
        onTapUp: tappable ? (_) => setState(() => _pressed = false) : null,
        onTapCancel: tappable ? () => setState(() => _pressed = false) : null,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOutCubic,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: _resolveColor(),
            borderRadius: widget.borderRadius,
          ),
          child: widget.child,
        ),
      ),
    );
  }
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
  final VoidCallback? onRecordCancel;
  final VoidCallback? onRecordPause;
  final VoidCallback? onRecordResume;
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
    this.onRecordCancel,
    this.onRecordPause,
    this.onRecordResume,
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
              onRecordCancel: onRecordCancel,
              onRecordPause: onRecordPause,
              onRecordResume: onRecordResume,
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

class _ChatInputShell extends StatefulWidget {
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
  final VoidCallback? onRecordCancel;
  final VoidCallback? onRecordPause;
  final VoidCallback? onRecordResume;

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
    required this.onRecordCancel,
    required this.onRecordPause,
    required this.onRecordResume,
  });

  @override
  State<_ChatInputShell> createState() => _ChatInputShellState();
}

class _ChatInputShellState extends State<_ChatInputShell>
    with SingleTickerProviderStateMixin {
  bool _recording = false;
  bool _paused = false;
  int _elapsed = 0;
  Timer? _sessionTimer;
  late final AnimationController _waveCtrl;

  @override
  void initState() {
    super.initState();
    _waveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
  }

  @override
  void dispose() {
    _sessionTimer?.cancel();
    _waveCtrl.dispose();
    super.dispose();
  }

  // ── Ciclo de vida da gravação ─────────────────────────────
  void _startRecording() {
    if (_recording) return;
    setState(() {
      _recording = true;
      _paused = false;
      _elapsed = 0;
    });
    _waveCtrl.repeat();

    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && !_paused) {
        setState(() => _elapsed++);
      }
    });

    widget.onRecord();
  }

  void _cancelRecording() {
    if (!_recording) return;
    _waveCtrl.stop();
    _waveCtrl.reset();
    _sessionTimer?.cancel();
    _sessionTimer = null;
    setState(() {
      _recording = false;
      _paused = false;
      _elapsed = 0;
    });
    widget.onRecordCancel?.call();
  }

  void _togglePause() {
    if (!_recording) return;
    setState(() => _paused = !_paused);
    if (_paused) {
      _waveCtrl.stop();
      widget.onRecordPause?.call();
    } else {
      _waveCtrl.repeat();
      widget.onRecordResume?.call();
    }
  }

  String get _formattedElapsed {
    final m = (_elapsed ~/ 60).toString().padLeft(2, '0');
    final sec = (_elapsed % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;

    final Widget child = _recording
        ? _RecordingPill(
            key: const ValueKey('recording_pill'),
            s: s,
            waveCtrl: _waveCtrl,
            paused: _paused,
            elapsedLabel: _formattedElapsed,
            floatingShadow: widget.floatingShadow,
            onClose: _cancelRecording,
            onTogglePause: _togglePause,
          )
        : _buildInputBar(key: const ValueKey('input_bar'));

    final Widget animated = AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, anim) {
        return FadeTransition(
          opacity: anim,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.97, end: 1.0).animate(anim),
            alignment: Alignment.bottomCenter,
            child: child,
          ),
        );
      },
      child: child,
    );

    if (widget.incognito && !_recording) {
      return DashedRRectBorder(
        color: s.outline,
        radius: 26,
        child: animated,
      );
    }
    return animated;
  }

  // ── Input bar normal ──────────────────────────────────────
  Widget _attachButton() {
    return GestureDetector(
      key: widget.attachButtonKey,
      onTap: widget.onAttach,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: AppIcon('add', color: widget.s.onSurface, size: 22),
      ),
    );
  }

  Widget _textField() {
    final s = widget.s;
    return TextField(
      controller: widget.ctrl,
      focusNode: widget.focusNode,
      minLines: 1,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textCapitalization: TextCapitalization.sentences,
      style: const TextStyle(fontSize: 16.5, letterSpacing: 0.15)
          .copyWith(color: s.onSurface),
      cursorColor: s.primary,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: widget.incognito
            ? 'Mensagem incógnita...'
            : 'Pergunte qualquer coisa aqui...',
        hintStyle: TextStyle(
            fontSize: 16.5,
            letterSpacing: 0.15,
            color: s.onSurfaceVariant),
        contentPadding: EdgeInsets.zero,
      ),
      onSubmitted: (_) => widget.hasText ? widget.onSend() : null,
    );
  }

  Widget _toolPillRow() {
    if (widget.attachedTool == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: _AttachedToolPill(
            s: widget.s, type: widget.attachedTool!, onClear: () {}),
      ),
    );
  }

  Widget _buildInputBar({required Key key}) {
    final s = widget.s;
    return Container(
      key: key,
      constraints: const BoxConstraints(
        minHeight: _ChatInputShell._minInputHeight,
        maxHeight: _ChatInputShell._maxInputHeight,
      ),
      decoration: BoxDecoration(
        color: s.isDark ? s.cardBackground : s.floatingSurface,
        borderRadius: BorderRadius.circular(26),
        boxShadow: widget.floatingShadow,
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
                  hasText: widget.hasText,
                  sending: widget.sending,
                  onSend: widget.onSend,
                  onPause: widget.onPause,
                  onRecord: _startRecording,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// PILL DE GRAVAÇÃO
//
// Layout:  [ PILL (Expanded) ]  [ 10 ]  [ CLOSE ]
//   PILL  :  [mic]  [waveform]  [tempo]  [pausa/retomar]
//   CLOSE :  botão circular ao lado da pill (não flutuante)
//
// Sem gradiente. A "alma" da pill é a waveform de barras verticais
// animadas, ao estilo dos recorders/IA modernos.
// ══════════════════════════════════════════════════════════════

class _RecordingPill extends StatelessWidget {
  final AppColorScheme s;
  final AnimationController waveCtrl;
  final bool paused;
  final String elapsedLabel;
  final List<BoxShadow> floatingShadow;
  final VoidCallback onClose;
  final VoidCallback onTogglePause;

  static const double _pillHeight = 56;
  static const double _closeSize = 44;

  const _RecordingPill({
    super.key,
    required this.s,
    required this.waveCtrl,
    required this.paused,
    required this.elapsedLabel,
    required this.floatingShadow,
    required this.onClose,
    required this.onTogglePause,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _pillHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Pill principal ──────────────────────────────────
          Expanded(
            child: Container(
              height: _pillHeight,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: s.isDark ? s.cardBackground : s.floatingSurface,
                borderRadius: BorderRadius.circular(_pillHeight / 2),
                border: Border.all(
                  color: paused
                      ? s.outline.withOpacity(0.6)
                      : s.primary.withOpacity(0.55),
                  width: 1.2,
                ),
                boxShadow: floatingShadow,
              ),
              child: Row(
                children: [
                  // Mic — pulsa quando a gravar, estático quando pausado
                  AnimatedBuilder(
                    animation: waveCtrl,
                    builder: (_, __) {
                      final scale = paused
                          ? 1.0
                          : 1.0 +
                              0.10 *
                                  (0.5 +
                                      0.5 *
                                          math.sin(waveCtrl.value *
                                              2 *
                                              math.pi));
                      return Transform.scale(
                        scale: scale,
                        child: AppIcon(
                          paused ? 'mic_off' : 'mic',
                          color:
                              paused ? s.onSurfaceVariant : s.primary,
                          size: 20,
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 12),

                  // Waveform animada
                  Expanded(
                    child: _Waveform(
                      s: s,
                      t: waveCtrl,
                      paused: paused,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Tempo
                  Text(
                    elapsedLabel,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: s.onSurfaceVariant,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Pausar / Retomar
                  _PauseResumeButton(
                    s: s,
                    paused: paused,
                    onTap: onTogglePause,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(width: 10),

          // ── Botão de close AO LADO da pill ──────────────────
          GestureDetector(
            onTap: onClose,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: _closeSize,
              height: _closeSize,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: s.isDark ? s.cardBackground : s.floatingSurface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: s.outline.withOpacity(0.35),
                  width: 1.0,
                ),
                boxShadow: floatingShadow,
              ),
              child: AppIcon('close', color: s.onSurface, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Waveform — barras verticais animadas ao estilo recorder/IA.
// Sem gradiente: cor sólida s.primary (ou neutra quando pausado).
// Alturas pseudo-aleatórias + soma de três senos para dar aquele
// movimento orgânico e suave.
// ─────────────────────────────────────────────────────────────

class _Waveform extends StatelessWidget {
  final AppColorScheme s;
  final Animation<double> t;
  final bool paused;

  static const int _barCount = 26;
  static const double _barWidth = 2.4;
  static const double _barSpacing = 1.4;
  static const double _minHeight = 4.0;
  static const double _maxHeight = 24.0;

  const _Waveform({
    required this.s,
    required this.t,
    required this.paused,
  });

  double _heightFor(int i, double progress) {
    // Duas fases pseudo-aleatórias por barra (dá aspeto natural).
    final seedA = math.sin(i * 12.9898) * 43758.5453;
    final phaseA = (seedA - seedA.floor()) * 2 * math.pi;
    final seedB = math.sin(i * 78.233) * 43758.5453;
    final phaseB = (seedB - seedB.floor()) * 2 * math.pi;
    final seedC = math.sin(i * 39.425) * 43758.5453;
    final phaseC = (seedC - seedC.floor()) * 2 * math.pi;

    final twoPi = 2 * math.pi;
    final w1 = 0.5 + 0.5 * math.sin(progress * twoPi * 2.3 + phaseA);
    final w2 = 0.5 + 0.5 * math.sin(progress * twoPi * 3.9 + phaseB);
    final w3 = 0.5 + 0.5 * math.sin(progress * twoPi * 1.4 + phaseC);

    // Mistura ponderada → movimento suave e contínuo
    final combined = w1 * 0.45 + w2 * 0.35 + w3 * 0.20;

    return _minHeight + combined * (_maxHeight - _minHeight);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: t,
      builder: (_, __) {
        final progress = t.value;
        final color = paused
            ? s.onSurfaceVariant.withOpacity(0.55)
            : s.primary.withOpacity(0.90);

        return SizedBox(
          height: _maxHeight,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(_barCount, (i) {
              final h = _heightFor(i, progress);
              return Padding(
                padding: EdgeInsets.symmetric(horizontal: _barSpacing / 2),
                child: Container(
                  width: _barWidth,
                  height: h,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(_barWidth),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}

// Botão pequeno de pausar/retomar dentro da pill.
class _PauseResumeButton extends StatelessWidget {
  final AppColorScheme s;
  final bool paused;
  final VoidCallback onTap;

  static const double _size = 30;

  const _PauseResumeButton({
    required this.s,
    required this.paused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: _size,
        height: _size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: paused
              ? s.primary.withOpacity(0.14)
              : s.hover,
          shape: BoxShape.circle,
        ),
        child: AppIcon(
          paused ? 'play' : 'pause',
          color: paused ? s.primary : s.onSurface,
          size: 15,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// CLUSTER: botão de gravar + botão de enviar
// ══════════════════════════════════════════════════════════════

class _SendRecordCluster extends StatelessWidget {
  final AppColorScheme s;
  final bool hasText;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onPause;
  final VoidCallback onRecord;

  static const double _btnSize = 36;

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
    return SizedBox(
      height: _btnSize,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _RecordButton(
            s: s,
            size: _btnSize,
            enabled: !sending,
            onTap: onRecord,
          ),
          const SizedBox(width: 2),
          _SendButton(
            s: s,
            hasText: hasText,
            sending: sending,
            onSend: onSend,
            onPause: onPause,
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

    final Color sendingBg = s.isDark ? Colors.white : s.primary;
    final Color sendingIcon = s.isDark ? s.primary : Colors.white;

    final Color idleBg = s.hover;
    final Color idleIcon = s.onSurfaceVariant.withOpacity(0.45);

    final Color bg = sending
        ? sendingBg
        : active
            ? s.primary
            : idleBg;

    final Color iconColor = sending
        ? sendingIcon
        : active
            ? Colors.white
            : idleIcon;

    return GestureDetector(
      onTap: sending ? onPause : (hasText ? onSend : null),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: _size,
        height: _size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
        ),
        child: AppIcon(
          sending ? 'pause' : 'arrow_up',
          color: iconColor,
          size: sending ? 16 : 20,
        ),
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  final AppColorScheme s;
  final double size;
  final bool enabled;
  final VoidCallback onTap;

  const _RecordButton({
    required this.s,
    required this.size,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        enabled ? s.primary : s.onSurfaceVariant.withOpacity(0.4);

    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: size,
        height: size,
        child: Center(
          child: AppIcon('record', color: color, size: 22),
        ),
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
                child:
                    AppIcon('close', color: s.onPrimaryContainer, size: 9),
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
          color: const Color(0xFF262626),
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
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    size: 15, color: Colors.white),
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
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: s.onSurface)),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: SelectableText(
                text,
                style: TextStyle(
                    fontSize: 15, color: s.onSurface, height: 1.5),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: s.onSurface)),
          ]),
          const SizedBox(height: 12),
          if (canvases.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('Ainda não há documentos nesta conversa.',
                    style: TextStyle(
                        fontSize: 13.5, color: s.onSurfaceVariant)),
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

class _CanvasCard extends StatelessWidget {
  final AppColorScheme s;
  final LocalCanvasItem item;
  final VoidCallback onTap;
  const _CanvasCard(
      {required this.s, required this.item, required this.onTap});

  EditorType get _editorType => item.kind.editorType;

  @override
  Widget build(BuildContext context) {
    return _HoverSurface(
      s: s,
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
              Text(item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: s.onSurface)),
              const SizedBox(height: 2),
              Text(_editorType.label,
                  style: TextStyle(
                      fontSize: 12, color: s.onSurfaceVariant)),
            ],
          ),
        ),
      ]),
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
  State<_AttachMenuSheetContent> createState() =>
      _AttachMenuSheetContentState();
}

class _AttachMenuSheetContentState extends State<_AttachMenuSheetContent> {
  _AttachMenuPageKind _page = _AttachMenuPageKind.root;
  late AiModel _selectedModel = widget.currentModel;
  late bool _localWeb = widget.webSearchEnabled;
  late bool _localWidgets = widget.widgetsEnabled;

  void _goToModelSelect() =>
      setState(() => _page = _AttachMenuPageKind.modelSelect);
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
                  .animate(CurvedAnimation(
                      parent: anim, curve: Curves.easeOutCubic)),
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
                  s: s,
                  assetName: 'camera',
                  label: 'Câmera',
                  onTap: onCamera,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AttachOptionCard(
                  s: s,
                  assetName: 'image',
                  label: 'Fotos',
                  onTap: onPhotos,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _AttachOptionCard(
                  s: s,
                  assetName: 'folder_upload',
                  label: 'Arquivo local',
                  onTap: onLocalFile,
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

class _AttachOptionCard extends StatelessWidget {
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

  @override
  Widget build(BuildContext context) {
    return _HoverSurface(
      s: s,
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(assetName, size: 22, color: s.onSurface),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: s.onSurface,
            ),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: _HoverSurface(
        s: s,
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            AppIcon(assetName, size: 20, color: s.onSurface),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: s.onSurface)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(subtitle!,
                        style: TextStyle(
                            fontSize: 12.5, color: s.onSurfaceVariant)),
                  ],
                ],
              ),
            ),
            AppIcon('chevron_forward',
                size: 14, color: s.onSurfaceVariant),
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
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: s.onSurface)),
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
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child:
                      AppIcon('chevron_back', size: 20, color: s.onSurface),
                ),
              ),
              const SizedBox(width: 4),
              Text('Modelo',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: s.onSurface)),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: _HoverSurface(
        s: s,
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.label,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: s.onSurface,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    model.description,
                    style: TextStyle(
                        fontSize: 12, color: s.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (selected)
              AppIcon('check', color: s.primary, size: 20)
            else
              const SizedBox(width: 20),
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
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: s.onSurface)),
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
  State<_AppsConnectSheetContent> createState() =>
      _AppsConnectSheetContentState();
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
            onChanged: (v) =>
                enabledAppsController.setEnabled(entry.manifest.slug, v),
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
    return _HoverSurface(
      s: s,
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Image.asset(app.manifest.iconAsset, width: 18, height: 18),
          const SizedBox(width: 10),
          Text(app.manifest.label,
              style: TextStyle(fontSize: 14, color: s.onSurface)),
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
  const _CustomSwitch(
      {required this.s, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: 44,
        height: 26,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: value ? s.primary : s.outline,
          borderRadius: BorderRadius.circular(999),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          alignment:
              value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 20,
            height: 20,
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
// Câmera própria do app (ficheiro separado)
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