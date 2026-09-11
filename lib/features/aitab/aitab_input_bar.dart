// ══════════════════════════════════════════════════════════════
// FILE: lib/aitab/aitab_input_bar.dart
//
// MUDANÇAS NESTA VERSÃO:
// - Controlo de pensamento saiu do sheet do "+" (switch) e passou
//   a ser um texto puro "Rápido ⌄" / "Raciocínio ⌄" com chevron,
//   encostado à direita do botão "+", dentro do rodapé do input.
//   Abre um PopupMenuButton nativo (menu ancorado ao próprio texto,
//   não modal centrado). O estado vive em `thinkingMode`
//   (ThinkingModeNotifier, definido em aitab_models.dart) — este
//   ficheiro apenas o lê e emite o toggle para cima.
// - showAttachMenuSheet deixou de receber/trazer thinking: só
//   mantém Canvas, Pesquisar web e Competências.
// ══════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:record/record.dart';
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
// SHEET GENÉRICO PLANO
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
  final bool thinkingEnabled;
  final ValueChanged<bool> onThinkingChanged;
  final VoidCallback onSend;
  final VoidCallback onPause;
  final VoidCallback onAttach;
  final ValueChanged<String> onRecordingComplete;
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
    required this.thinkingEnabled,
    required this.onThinkingChanged,
    required this.onSend,
    required this.onPause,
    required this.onAttach,
    required this.onRecordingComplete,
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
              thinkingEnabled: thinkingEnabled,
              onThinkingChanged: onThinkingChanged,
              onSend: onSend,
              onPause: onPause,
              onAttach: onAttach,
              onRecordingComplete: onRecordingComplete,
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
  final bool thinkingEnabled;
  final ValueChanged<bool> onThinkingChanged;
  final VoidCallback onSend;
  final VoidCallback onPause;
  final VoidCallback onAttach;
  final ValueChanged<String> onRecordingComplete;

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
    required this.thinkingEnabled,
    required this.onThinkingChanged,
    required this.onSend,
    required this.onPause,
    required this.onAttach,
    required this.onRecordingComplete,
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
      style: const TextStyle(fontSize: 16.5, letterSpacing: 0.15)
          .copyWith(color: s.onSurface),
      cursorColor: s.primary,
      decoration: InputDecoration(
        isDense: true,
        border: InputBorder.none,
        hintText: incognito
            ? 'Mensagem incógnita...'
            : 'Pergunte qualquer coisa aqui...',
        hintStyle: TextStyle(
            fontSize: 16.5,
            letterSpacing: 0.15,
            color: s.onSurfaceVariant),
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

  Future<void> _openRecordingModal(BuildContext context) async {
    final transcript = await showRecordingModal(context, s);
    if (transcript != null && transcript.trim().isNotEmpty) {
      onRecordingComplete(transcript);
    }
  }

  @override
  Widget build(BuildContext context) {
    final Widget bar = Container(
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
                const SizedBox(width: 2),
                ThinkingModeText(
                  s: s,
                  enabled: thinkingEnabled,
                  onChanged: onThinkingChanged,
                ),
                const Spacer(),
                _SendRecordCluster(
                  s: s,
                  hasText: hasText,
                  sending: sending,
                  onSend: onSend,
                  onPause: onPause,
                  onRecord: () => _openRecordingModal(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    if (incognito) {
      return DashedRRectBorder(color: s.outline, radius: 26, child: bar);
    }
    return bar;
  }
}

// ══════════════════════════════════════════════════════════════
// CONTROLRO DE PENSAMENTO — texto puro "Rápido ⌄" / "Raciocínio ⌄"
// com PopupMenuButton ancorado ao próprio texto. Encostado à
// direita do botão "+". O estado é lido/escrito pelo AiTabState via
// thinkingMode (ThinkingModeNotifier em aitab_models.dart).
// ══════════════════════════════════════════════════════════════

class ThinkingModeText extends StatelessWidget {
  final AppColorScheme s;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const ThinkingModeText({
    super.key,
    required this.s,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<bool>(
      tooltip: '',
      onSelected: onChanged,
      color: s.cardBackground,
      elevation: 8,
      position: PopupMenuPosition.under,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      itemBuilder: (ctx) => [
        PopupMenuItem<bool>(
          value: false,
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                child: !enabled
                    ? AppIcon('check', size: 14, color: s.primary)
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 6),
              Text(
                'Rápido',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: !enabled ? FontWeight.w700 : FontWeight.w500,
                  color: s.onSurface,
                ),
              ),
            ],
          ),
        ),
        PopupMenuItem<bool>(
          value: true,
          height: 44,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                child: enabled
                    ? AppIcon('check', size: 14, color: s.primary)
                    : const SizedBox.shrink(),
              ),
              const SizedBox(width: 6),
              Text(
                'Raciocínio',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: enabled ? FontWeight.w700 : FontWeight.w500,
                  color: s.onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              enabled ? 'Raciocínio' : 'Rápido',
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: s.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.expand_more, size: 16, color: s.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// MODAL DE GRAVAÇÃO
// ══════════════════════════════════════════════════════════════

Future<String?> showRecordingModal(BuildContext context, AppColorScheme s) {
  return showFlatBottomSheet<String>(
    context: context,
    s: s,
    builder: (sheetContext) => _RecordingModalContent(s: s),
  );
}

class _RecordingModalContent extends StatefulWidget {
  final AppColorScheme s;
  const _RecordingModalContent({required this.s});

  @override
  State<_RecordingModalContent> createState() => _RecordingModalContentState();
}

class _RecordingModalContentState extends State<_RecordingModalContent>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _recorder = AudioRecorder();
  StreamSubscription<Amplitude>? _amplitudeSub;

  bool _playing = false;
  bool _hasStarted = false;
  int _elapsed = 0;
  Timer? _sessionTimer;
  String? _recordingPath;

  double _currentAmplitude = 0.0;

  static const int _barCount = 32;
  final List<double> _barHistory = List.filled(_barCount, 0.0);

  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _startRecording();
  }

  @override
  void dispose() {
    _amplitudeSub?.cancel();
    _sessionTimer?.cancel();
    _pulseCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;

    final dir = await _tempRecordingPath();
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: dir,
    );

    setState(() {
      _playing = true;
      _hasStarted = true;
      _recordingPath = dir;
    });

    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _playing) setState(() => _elapsed++);
    });

    _amplitudeSub?.cancel();
    _amplitudeSub = _recorder
        .onAmplitudeChanged(const Duration(milliseconds: 90))
        .listen((amp) {
      if (!mounted) return;
      const silenceFloorDb = -45.0;
      const peakDb = -5.0;
      final raw = amp.current;
      final normalized = ((raw - silenceFloorDb) / (peakDb - silenceFloorDb))
          .clamp(0.0, 1.0);
      setState(() {
        _currentAmplitude = normalized;
        _barHistory.removeAt(0);
        _barHistory.add(normalized);
      });
    });
  }

  Future<String> _tempRecordingPath() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '/tmp/aitab_recording_$ts.m4a';
  }

  Future<void> _togglePlayPause() async {
    if (!_hasStarted) return;
    if (_playing) {
      await _recorder.pause();
      _amplitudeSub?.pause();
      setState(() {
        _playing = false;
        _currentAmplitude = 0.0;
        for (var i = 0; i < _barHistory.length; i++) {
          _barHistory[i] = 0.0;
        }
      });
    } else {
      await _recorder.resume();
      _amplitudeSub?.resume();
      setState(() => _playing = true);
    }
  }

  Future<void> _confirmOk() async {
    String? path = _recordingPath;
    if (_hasStarted) {
      path = await _recorder.stop();
    }
    _amplitudeSub?.cancel();
    _sessionTimer?.cancel();
    if (!mounted) return;
    Navigator.of(context).pop(path);
  }

  String get _formattedElapsed {
    final m = (_elapsed ~/ 60).toString().padLeft(2, '0');
    final sec = (_elapsed % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    final topButtonBg = s.isDark ? Colors.white : Colors.black;
    final topButtonIcon = s.isDark ? Colors.black : Colors.white;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24, 8, 24, 20 + MediaQuery.of(context).padding.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              width: 64,
              height: 64,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: topButtonBg,
                shape: BoxShape.circle,
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: AppIcon(
                  _playing ? 'pause' : 'play',
                  key: ValueKey(_playing),
                  size: 26,
                  color: topButtonIcon,
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Diz qualquer coisa',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: s.onSurface,
            ),
          ),
          const SizedBox(height: 22),
          _RealWaveform(s: s, barHistory: _barHistory, active: _playing),
          const SizedBox(height: 10),
          Text(
            _formattedElapsed,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: s.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 26),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ModalCircleButton(
                icon: _playing ? 'pause' : 'play',
                background: topButtonBg,
                iconColor: topButtonIcon,
                onTap: _togglePlayPause,
              ),
              const SizedBox(width: 18),
              _ModalCircleButton(
                icon: 'check',
                background: s.primary,
                iconColor: Colors.white,
                onTap: _confirmOk,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModalCircleButton extends StatefulWidget {
  final String icon;
  final Color background;
  final Color iconColor;
  final VoidCallback onTap;
  const _ModalCircleButton({
    required this.icon,
    required this.background,
    required this.iconColor,
    required this.onTap,
  });

  @override
  State<_ModalCircleButton> createState() => _ModalCircleButtonState();
}

class _ModalCircleButtonState extends State<_ModalCircleButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Container(
          width: 56,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.background,
            shape: BoxShape.circle,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: AppIcon(
              widget.icon,
              key: ValueKey(widget.icon),
              size: 22,
              color: widget.iconColor,
            ),
          ),
        ),
      ),
    );
  }
}

class _RealWaveform extends StatelessWidget {
  final AppColorScheme s;
  final List<double> barHistory;
  final bool active;

  static const double _barWidth = 3.0;
  static const double _barSpacing = 2.6;
  static const double _minHeight = 4.0;
  static const double _maxHeight = 40.0;

  const _RealWaveform({
    required this.s,
    required this.barHistory,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    final color = active
        ? s.primary
        : s.onSurfaceVariant.withOpacity(0.4);

    return SizedBox(
      height: _maxHeight,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final amplitude in barHistory)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: _barSpacing / 2),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                curve: Curves.easeOut,
                width: _barWidth,
                height: _minHeight + amplitude * (_maxHeight - _minHeight),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(_barWidth),
                ),
              ),
            ),
        ],
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
//
// O controlo de pensamento já não vive aqui — passou a ser um
// texto "Rápido ⌄" / "Raciocínio ⌄" no rodapé do input bar.
// Este sheet só mantém: Câmera / Fotos / Arquivo local, Canvas,
// Pesquisar web e Competências.
// ══════════════════════════════════════════════════════════════

Future<void> showAttachMenuSheet(
  BuildContext context,
  AppColorScheme s, {
  required GlobalKey anchorKey,
  required bool webSearchEnabled,
  required bool widgetsEnabled,
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
      webSearchEnabled: webSearchEnabled,
      widgetsEnabled: widgetsEnabled,
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
  final bool webSearchEnabled;
  final bool widgetsEnabled;
  final ValueChanged<bool> onWebSearchChanged;
  final ValueChanged<bool> onWidgetsChanged;
  final VoidCallback onOpenCanvas;
  final VoidCallback onCamera;
  final VoidCallback onPhotos;
  final VoidCallback onLocalFile;

  const _AttachMenuSheetContent({
    required this.s,
    required this.webSearchEnabled,
    required this.widgetsEnabled,
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
  late bool _localWeb = widget.webSearchEnabled;
  late bool _localWidgets = widget.widgetsEnabled;

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return _RootPage(
      s: s,
      webSearchEnabled: _localWeb,
      widgetsEnabled: _localWidgets,
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
    );
  }
}

class _RootPage extends StatelessWidget {
  final AppColorScheme s;
  final bool webSearchEnabled;
  final bool widgetsEnabled;
  final VoidCallback onCanvasTap;
  final ValueChanged<bool> onWebSearchChanged;
  final ValueChanged<bool> onWidgetsChanged;
  final VoidCallback onCamera;
  final VoidCallback onPhotos;
  final VoidCallback onLocalFile;

  const _RootPage({
    required this.s,
    required this.webSearchEnabled,
    required this.widgetsEnabled,
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
// Câmera própria do app
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