// ══════════════════════════════════════════════════════════════
// FILE: lib/aitab/aitab_widgets_shared.dart
// ══════════════════════════════════════════════════════════════

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lottie/lottie.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../core/widgets/animated_canvas_icon.dart';
import '../apps/app_types.dart';
import 'aitab_models.dart';

// ══════════════════════════════════════════════════════════════
// SHEET GENÉRICO PLANO
// ══════════════════════════════════════════════════════════════

const double _kFlatModalRadius = 20.0;

class _SharedModalHandlebar extends StatelessWidget {
  final AppColorScheme s;
  const _SharedModalHandlebar({required this.s});

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

Future<T?> _showSharedFlatBottomSheet<T>(
  BuildContext context,
  AppColorScheme s, {
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
          _SharedModalHandlebar(s: s),
          Flexible(child: builder(sheetContext)),
        ],
      ),
    ),
  );
}

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
// NEXA BRAND LOGO
// ══════════════════════════════════════════════════════════════

class NexaBrandLogo extends StatefulWidget {
  final double size;
  final bool animated;
  const NexaBrandLogo({
    super.key,
    this.size = 40,
    this.animated = true,
  });

  @override
  State<NexaBrandLogo> createState() => _NexaBrandLogoState();
}

class _NexaBrandLogoState extends State<NexaBrandLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
    if (widget.animated) _c.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant NexaBrandLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated != oldWidget.animated) {
      if (widget.animated) {
        _c.repeat(reverse: true);
      } else {
        _c.stop();
        _c.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logo = SvgPicture.asset(
      'assets/icons/png/logo.svg',
      width: widget.size,
      height: widget.size,
    );
    if (!widget.animated) return logo;

    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final v = Curves.easeInOut.transform(_c.value);
        return Opacity(
          opacity: 0.82 + 0.18 * v,
          child: Transform.scale(
            scale: 0.96 + 0.04 * v,
            child: logo,
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════
// NEXA SPINNING RING LOADER
// ══════════════════════════════════════════════════════════════

class NexaSpinningRingLoader extends StatefulWidget {
  final double size;
  final Color? color;
  final double strokeWidth;
  const NexaSpinningRingLoader({
    super.key,
    this.size = 28,
    this.color,
    this.strokeWidth = 2.5,
  });

  @override
  State<NexaSpinningRingLoader> createState() => _NexaSpinningRingLoaderState();
}

class _NexaSpinningRingLoaderState extends State<NexaSpinningRingLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final ringColor = widget.color ?? (s.isDark ? Colors.white : s.primary);

    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        return Transform.rotate(
          angle: _c.value * 2 * math.pi,
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: CustomPaint(
              painter: _RingGradientPainter(
                color: ringColor,
                strokeWidth: widget.strokeWidth,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RingGradientPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  const _RingGradientPainter({required this.color, required this.strokeWidth});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - strokeWidth) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final gradient = SweepGradient(
      startAngle: 0.0,
      endAngle: 2 * math.pi,
      colors: [
        color.withOpacity(0.0),
        color.withOpacity(0.15),
        color,
      ],
      stops: const [0.0, 0.55, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(rect, 0, 2 * math.pi * 0.92, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingGradientPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.strokeWidth != strokeWidth;
}

// ══════════════════════════════════════════════════════════════
// NEXA LOTTIE LOADER
// ══════════════════════════════════════════════════════════════

class NexaLottieLoader extends StatelessWidget {
  final double size;
  const NexaLottieLoader({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        'assets/icons/lottie/loader.json',
        fit: BoxFit.contain,
        repeat: true,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// NEXA LOADER LOGO
// ══════════════════════════════════════════════════════════════

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

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.animated) {
      _c.repeat(reverse: true);
    } else {
      _c.value = 0.0;
    }
  }

  @override
  void didUpdateWidget(covariant NexaLoaderLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated != oldWidget.animated) {
      if (widget.animated) {
        _c.repeat(reverse: true);
      } else {
        _c.stop();
        _c.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = AppTheme.of(context);
    final ballColor = widget.tintColor
        ?? (s.isDark ? Colors.white : Colors.black);

    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = Curves.easeInOut.transform(_c.value);
            final d = widget.size * (0.40 + 0.60 * t);
            return Container(
              width: d,
              height: d,
              decoration: BoxDecoration(
                color: ballColor,
                shape: BoxShape.circle,
              ),
            );
          },
        ),
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

// ══════════════════════════════════════════════════════════════
// HEADER MENU BUTTON
// ══════════════════════════════════════════════════════════════

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
        final overlayBox =
            overlayState.context.findRenderObject() as RenderBox;
        final anchorTopLeft =
            box.localToGlobal(Offset.zero, ancestor: overlayBox);
        final anchorSize = box.size;

        final result = await _showHeaderPopupMenu(
          context,
          s,
          anchorTopLeft: anchorTopLeft,
          anchorSize: anchorSize,
          overlaySize: overlayBox.size,
          hasMessages: hasMessages,
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
}

Future<ConversationAction?> _showHeaderPopupMenu(
  BuildContext context,
  AppColorScheme s, {
  required Offset anchorTopLeft,
  required Size anchorSize,
  required Size overlaySize,
  required bool hasMessages,
}) {
  const double popupWidth = 220.0;
  const double gap = 6.0;

  final rawLeft = anchorTopLeft.dx + anchorSize.width - popupWidth;
  final clampedLeft =
      rawLeft.clamp(8.0, overlaySize.width - popupWidth - 8.0);
  final popupTop = anchorTopLeft.dy + anchorSize.height + gap;

  return showGeneralDialog<ConversationAction>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar menu',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogCtx, anim, secAnim) {
      return Stack(
        children: [
          Positioned(
            left: clampedLeft,
            top: popupTop,
            width: popupWidth,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: s.floatingSurface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: s.outline.withOpacity(0.25)),
                  boxShadow: [
                    BoxShadow(
                      color:
                          Colors.black.withOpacity(s.isDark ? 0.45 : 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHeaderMenuItem(dialogCtx, s,
                          ConversationAction.newChat, false, false),
                      _buildHeaderMenuItem(dialogCtx, s,
                          ConversationAction.incognito, false, hasMessages),
                      _buildHeaderMenuItem(dialogCtx, s,
                          ConversationAction.rename, false, false),
                      _buildHeaderMenuItem(dialogCtx, s,
                          ConversationAction.delete, true, false),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (dialogCtx, anim, secAnim, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          alignment: Alignment.topRight,
          child: child,
        ),
      );
    },
  );
}

Widget _buildHeaderMenuItem(
  BuildContext context,
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

  return InkWell(
    onTap: disabled
        ? null
        : () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop(action);
          },
    borderRadius: BorderRadius.circular(14),
    child: Container(
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
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// POPUP DE OPÇÕES DO INPUT BAR
// (Canvas / Pesquisar web / Competências) — mesmo padrão visual
// e de animação do popup de opções do cabeçalho
// (_showHeaderPopupMenu), ancorado ao botão que o abriu, em vez
// de bottom sheet.
// ══════════════════════════════════════════════════════════════

enum InputBarOption { canvas, webSearch, widgets }

Future<void> showAttachOptionsPopup(
  BuildContext context,
  AppColorScheme s, {
  required GlobalKey anchorKey,
  required bool webSearchEnabled,
  required bool widgetsEnabled,
  required VoidCallback onOpenCanvas,
  required ValueChanged<bool> onWebSearchChanged,
  required ValueChanged<bool> onWidgetsChanged,
}) async {
  final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
  if (box == null) return;
  final overlayState = Overlay.of(context);
  final overlayBox = overlayState.context.findRenderObject() as RenderBox;
  final anchorTopLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
  final anchorSize = box.size;
  final overlaySize = overlayBox.size;

  const double popupWidth = 240.0;
  const double gap = 6.0;

  final rawLeft = anchorTopLeft.dx;
  final clampedLeft = rawLeft.clamp(8.0, overlaySize.width - popupWidth - 8.0);
  final popupBottom = overlaySize.height - anchorTopLeft.dy + gap;

  await showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar menu',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogCtx, anim, secAnim) {
      return Stack(
        children: [
          Positioned(
            left: clampedLeft,
            bottom: popupBottom,
            width: popupWidth,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: s.floatingSurface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: s.outline.withOpacity(0.25)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(s.isDark ? 0.45 : 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(dialogCtx).pop();
                          onOpenCanvas();
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          child: Row(
                            children: [
                              AppIcon('stacks', size: 18, color: s.onSurface),
                              const SizedBox(width: 10),
                              Text('Canvas',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: s.onSurface)),
                            ],
                          ),
                        ),
                      ),
                      _buildToggleMenuItem(
                        dialogCtx, s, 'globe', 'Pesquisar web', webSearchEnabled, onWebSearchChanged,
                      ),
                      _buildToggleMenuItem(
                        dialogCtx, s, 'skills', 'Competências', widgetsEnabled, onWidgetsChanged,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (dialogCtx, anim, secAnim, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          alignment: Alignment.bottomLeft,
          child: child,
        ),
      );
    },
  );
}

Widget _buildToggleMenuItem(
  BuildContext context,
  AppColorScheme s,
  String assetName,
  String label,
  bool value,
  ValueChanged<bool> onChanged,
) {
  return InkWell(
    onTap: () {
      HapticFeedback.lightImpact();
      onChanged(!value);
    },
    borderRadius: BorderRadius.circular(14),
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          AppIcon(assetName, size: 18, color: s.onSurface),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: s.onSurface)),
          ),
          _CustomSwitchSmall(value: value, onChanged: onChanged, s: s),
        ],
      ),
    ),
  );
}

class _CustomSwitchSmall extends StatelessWidget {
  final AppColorScheme s;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _CustomSwitchSmall({required this.s, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOutCubic,
      width: 40,
      height: 24,
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
          width: 18,
          height: 18,
          decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════
// POPUP DE AÇÕES DE MENSAGEM — mesmo padrão (showGeneralDialog +
// Positioned + ScaleTransition) do _showHeaderPopupMenu. Deixou
// de usar showMenu nativo.
// ══════════════════════════════════════════════════════════════

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
  final overlaySize = overlayBox.size;

  const double popupWidth = 200.0;
  const double gap = 6.0;

  final rawLeft = anchorOffset.dx + anchorSize.width - popupWidth;
  final clampedLeft = rawLeft.clamp(8.0, overlaySize.width - popupWidth - 8.0);
  final popupTop = anchorOffset.dy + anchorSize.height + gap;

  final result = await showGeneralDialog<int>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar menu',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (dialogCtx, anim, secAnim) {
      return Stack(
        children: [
          Positioned(
            left: clampedLeft,
            top: popupTop,
            width: popupWidth,
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: s.floatingSurface,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: s.outline.withOpacity(0.25)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(s.isDark ? 0.45 : 0.15),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildMessageMenuItemTappable(dialogCtx, s, 'pencil', 'Editar', 0),
                      _buildMessageMenuItemTappable(dialogCtx, s, 'copy', 'Copiar', 1),
                      _buildMessageMenuItemTappable(dialogCtx, s, 'select_text', 'Selecionar texto', 2),
                      _buildMessageMenuItemTappable(dialogCtx, s, 'trash', 'Eliminar', 3, destructive: true),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
    transitionBuilder: (dialogCtx, anim, secAnim, child) {
      final curved = CurvedAnimation(
        parent: anim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.85, end: 1.0).animate(curved),
          alignment: Alignment.topRight,
          child: child,
        ),
      );
    },
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

// Versão com InkWell + Navigator.pop(value) — necessária porque
// showGeneralDialog não fecha nem devolve valor automaticamente ao
// tocar, ao contrário de PopupMenuItem dentro de showMenu.
Widget _buildMessageMenuItemTappable(
  BuildContext context,
  AppColorScheme s,
  String assetName,
  String label,
  int value, {
  bool destructive = false,
}) {
  final color = destructive ? s.error : s.onSurface;
  return InkWell(
    onTap: () {
      HapticFeedback.lightImpact();
      Navigator.of(context).pop(value);
    },
    borderRadius: BorderRadius.circular(14),
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 1, horizontal: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
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
    ),
  );
}

// ══════════════════════════════════════════════════════════════
// ATTACH POPUP
// ══════════════════════════════════════════════════════════════

Future<void> showAttachPopup(
  BuildContext context,
  AppColorScheme s, {
  required VoidCallback onFiles,
  required VoidCallback onPhotos,
  required VoidCallback onCamera,
  required ValueChanged<EditorType> onSelectTool,
}) async {
  await _showSharedFlatBottomSheet<void>(
    context,
    s,
    builder: (sheetContext) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: _AttachOptionCardShared(
              s: s,
              assetName: 'attach',
              label: 'Arquivos',
              onTap: () {
                Navigator.pop(sheetContext);
                onFiles();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _AttachOptionCardShared(
              s: s,
              assetName: 'image',
              label: 'Fotos',
              onTap: () {
                Navigator.pop(sheetContext);
                onPhotos();
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _AttachOptionCardShared(
              s: s,
              assetName: 'camera',
              label: 'Câmera',
              onTap: () {
                Navigator.pop(sheetContext);
                onCamera();
              },
            ),
          ),
        ],
      ),
    ),
  );
}

class _AttachOptionCardShared extends StatefulWidget {
  final AppColorScheme s;
  final String assetName;
  final String label;
  final VoidCallback onTap;
  const _AttachOptionCardShared({
    required this.s,
    required this.assetName,
    required this.label,
    required this.onTap,
  });
  @override
  State<_AttachOptionCardShared> createState() => _AttachOptionCardSharedState();
}

class _AttachOptionCardSharedState extends State<_AttachOptionCardShared> {
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
      child: AnimatedScale(
        scale: _p ? 0.95 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: _p ? s.hover : s.cardBackground,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AppIcon(widget.assetName, size: 22, color: s.onSurface),
                const SizedBox(height: 8),
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
        ),
      ),
    );
  }
}

class _AttachSheetItem extends StatelessWidget {
  final AppColorScheme s;
  final String iconAsset;
  final String label;
  final VoidCallback onTap;
  const _AttachSheetItem({
    required this.s,
    required this.iconAsset,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: s.cardBackground,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            AppIcon(iconAsset, size: 18, color: s.onSurface),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 15, color: s.onSurface, fontWeight: FontWeight.w500),
              ),
            ),
            AppIcon('chevron_forward', size: 14, color: s.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
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