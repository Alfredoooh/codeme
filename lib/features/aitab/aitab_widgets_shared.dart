// ══════════════════════════════════════════════════════════════
// FILE: lib/aitab/aitab_widgets_shared.dart
// Loaders reutilizáveis, popups genéricos, e o card simples de canvas.
// ══════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/widgets.dart';
import '../../core/widgets/animated_canvas_icon.dart';
import '../apps/app_types.dart';
import 'aitab_models.dart';

const double _kFlatModalRadius = 20.0;

class _SheetHandlebar extends StatelessWidget {
  final AppColorScheme s;
  const _SheetHandlebar({required this.s});
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
// NEXA LOADER LOGO
// ══════════════════════════════════════════════════════════════

class _NexaDotSpec {
  final double left;
  final double top;
  final Color color;
  final double delaySeconds;
  const _NexaDotSpec({
    required this.left,
    required this.top,
    required this.color,
    required this.delaySeconds,
  });
}

final List<_NexaDotSpec> _kNexaDots = [
  _NexaDotSpec(left: 28.21 / 128, top: 55.26 / 128, color: const Color.fromRGBO(88, 148, 247, 1),  delaySeconds: 0.00),
  _NexaDotSpec(left: 42.30 / 128, top: 49.85 / 128, color: const Color.fromRGBO(91, 150, 247, 1),  delaySeconds: 0.07),
  _NexaDotSpec(left: 35.05 / 128, top: 42.55 / 128, color: const Color.fromRGBO(99, 155, 247, 1),  delaySeconds: 0.13),
  _NexaDotSpec(left: 42.45 / 128, top: 35.10 / 128, color: const Color.fromRGBO(112, 164, 248, 1), delaySeconds: 0.20),
  _NexaDotSpec(left: 49.44 / 128, top: 42.51 / 128, color: const Color.fromRGBO(130, 175, 249, 1), delaySeconds: 0.27),
  _NexaDotSpec(left: 55.21 / 128, top: 29.38 / 128, color: const Color.fromRGBO(150, 188, 250, 1), delaySeconds: 0.33),
  _NexaDotSpec(left: 67.36 / 128, top: 29.33 / 128, color: const Color.fromRGBO(171, 201, 251, 1), delaySeconds: 0.40),
  _NexaDotSpec(left: 72.92 / 128, top: 42.55 / 128, color: const Color.fromRGBO(193, 215, 252, 1), delaySeconds: 0.47),
  _NexaDotSpec(left: 79.96 / 128, top: 35.10 / 128, color: const Color.fromRGBO(213, 228, 253, 1), delaySeconds: 0.53),
  _NexaDotSpec(left: 87.37 / 128, top: 42.55 / 128, color: const Color.fromRGBO(230, 239, 253, 1), delaySeconds: 0.60),
  _NexaDotSpec(left: 79.96 / 128, top: 49.85 / 128, color: const Color.fromRGBO(243, 247, 254, 1), delaySeconds: 0.67),
  _NexaDotSpec(left: 94.05 / 128, top: 55.26 / 128, color: const Color.fromRGBO(252, 253, 254, 1), delaySeconds: 0.73),
  _NexaDotSpec(left: 94.05 / 128, top: 67.82 / 128, color: const Color.fromRGBO(255, 255, 255, 1), delaySeconds: 0.80),
  _NexaDotSpec(left: 79.96 / 128, top: 73.53 / 128, color: const Color.fromRGBO(252, 253, 254, 1), delaySeconds: 0.87),
  _NexaDotSpec(left: 87.31 / 128, top: 80.78 / 128, color: const Color.fromRGBO(243, 247, 254, 1), delaySeconds: 0.93),
  _NexaDotSpec(left: 79.96 / 128, top: 88.13 / 128, color: const Color.fromRGBO(230, 239, 253, 1), delaySeconds: 1.00),
  _NexaDotSpec(left: 72.82 / 128, top: 80.78 / 128, color: const Color.fromRGBO(213, 228, 253, 1), delaySeconds: 1.07),
  _NexaDotSpec(left: 67.30 / 128, top: 93.94 / 128, color: const Color.fromRGBO(193, 215, 252, 1), delaySeconds: 1.13),
  _NexaDotSpec(left: 54.95 / 128, top: 93.94 / 128, color: const Color.fromRGBO(171, 201, 251, 1), delaySeconds: 1.20),
  _NexaDotSpec(left: 49.44 / 128, top: 80.78 / 128, color: const Color.fromRGBO(150, 188, 250, 1), delaySeconds: 1.27),
  _NexaDotSpec(left: 42.30 / 128, top: 88.13 / 128, color: const Color.fromRGBO(130, 175, 249, 1), delaySeconds: 1.33),
  _NexaDotSpec(left: 34.95 / 128, top: 80.78 / 128, color: const Color.fromRGBO(112, 164, 248, 1), delaySeconds: 1.40),
  _NexaDotSpec(left: 42.30 / 128, top: 73.53 / 128, color: const Color.fromRGBO(99, 155, 247, 1),  delaySeconds: 1.47),
  _NexaDotSpec(left: 28.21 / 128, top: 67.81 / 128, color: const Color.fromRGBO(91, 150, 247, 1),  delaySeconds: 1.53),
];

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
  late final AnimationController _shimmer;

  static const double _cycleSeconds = 1.6;
  static const double _dotFraction = 5.64 / 128;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_cycleSeconds * 1000).round()),
    );
    _shimmer = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.animated) {
      _c.repeat();
      _shimmer.repeat(reverse: true);
    } else {
      _c.value = 0.5;
      _shimmer.value = 0.5;
    }
  }

  @override
  void didUpdateWidget(covariant NexaLoaderLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animated != oldWidget.animated) {
      if (widget.animated) {
        _c.repeat();
        _shimmer.repeat(reverse: true);
      } else {
        _c.stop();
        _shimmer.stop();
      }
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _shimmer.dispose();
    super.dispose();
  }

  double _opacityFor(double delaySeconds, double t) {
    final delayFrac = delaySeconds / _cycleSeconds;
    var local = (t - delayFrac) % 1.0;
    if (local < 0) local += 1.0;
    final phase = (local * 2).clamp(0.0, 2.0);
    final eased = phase <= 1.0 ? phase : (2.0 - phase);
    return 0.15 + (0.85 * eased);
  }

  @override
  Widget build(BuildContext context) {
    final dotSize = widget.size * _dotFraction;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: Listenable.merge([_c, _shimmer]),
        builder: (_, __) {
          final shimmerX = (_shimmer.value * 2 - 1) * widget.size * 0.4;
          final content = Stack(
            children: [
              for (final dot in _kNexaDots)
                Positioned(
                  left: dot.left * widget.size,
                  top: dot.top * widget.size,
                  child: Opacity(
                    opacity: _opacityFor(dot.delaySeconds, _c.value),
                    child: Container(
                      width: dotSize,
                      height: dotSize,
                      decoration: BoxDecoration(
                        color: widget.tintColor ?? dot.color,
                        borderRadius: BorderRadius.circular(dotSize * 0.22),
                      ),
                    ),
                  ),
                ),
            ],
          );

          if (widget.tintColor != null) {
            return content;
          }

          return ShaderMask(
            shaderCallback: (bounds) {
              return LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.transparent,
                  Colors.white.withOpacity(0.75),
                  Colors.transparent,
                ],
                stops: const [0.0, 0.5, 1.0],
              ).createShader(bounds.shift(Offset(shimmerX, 0)));
            },
            blendMode: BlendMode.srcIn,
            child: content,
          );
        },
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
        final overlayBox = overlayState.context.findRenderObject() as RenderBox;
        final anchorTopLeft = box.localToGlobal(Offset.zero, ancestor: overlayBox);
        final anchorSize = box.size;

        final RelativeRect position = RelativeRect.fromLTRB(
          anchorTopLeft.dx,
          anchorTopLeft.dy + anchorSize.height,
          overlayBox.size.width - (anchorTopLeft.dx + anchorSize.width),
          overlayBox.size.height - (anchorTopLeft.dy + anchorSize.height),
        );

        final result = await showMenu<ConversationAction>(
          context: context,
          position: position,
          color: s.floatingSurface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: BorderSide(color: s.outline.withOpacity(0.25)),
          ),
          items: [
            PopupMenuItem<ConversationAction>(
              value: ConversationAction.newChat,
              padding: EdgeInsets.zero,
              child: _buildMenuItem(s, ConversationAction.newChat, false, false),
            ),
            PopupMenuItem<ConversationAction>(
              value: ConversationAction.incognito,
              enabled: !hasMessages,
              padding: EdgeInsets.zero,
              child: _buildMenuItem(s, ConversationAction.incognito, false, hasMessages),
            ),
            PopupMenuItem<ConversationAction>(
              value: ConversationAction.rename,
              padding: EdgeInsets.zero,
              child: _buildMenuItem(s, ConversationAction.rename, false, false),
            ),
            PopupMenuItem<ConversationAction>(
              value: ConversationAction.delete,
              padding: EdgeInsets.zero,
              child: _buildMenuItem(s, ConversationAction.delete, true, false),
            ),
          ],
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

  Widget _buildMenuItem(
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
    return Container(
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
    );
  }
}

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
  final screenSize = overlayBox.size;

  final RelativeRect position = RelativeRect.fromLTRB(
    anchorOffset.dx,
    anchorOffset.dy,
    screenSize.width - (anchorOffset.dx + anchorSize.width),
    screenSize.height - (anchorOffset.dy + anchorSize.height),
  );

  final result = await showMenu<int>(
    context: context,
    position: position,
    color: s.floatingSurface,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(22),
      side: BorderSide(color: s.outline.withOpacity(0.25)),
    ),
    items: [
      PopupMenuItem<int>(
        value: 0,
        padding: EdgeInsets.zero,
        child: _buildMessageMenuItem(s, 'pencil', 'Editar'),
      ),
      PopupMenuItem<int>(
        value: 1,
        padding: EdgeInsets.zero,
        child: _buildMessageMenuItem(s, 'copy', 'Copiar'),
      ),
      PopupMenuItem<int>(
        value: 2,
        padding: EdgeInsets.zero,
        child: _buildMessageMenuItem(s, 'select_text', 'Selecionar texto'),
      ),
      PopupMenuItem<int>(
        value: 3,
        padding: EdgeInsets.zero,
        child: _buildMessageMenuItem(s, 'trash', 'Eliminar', destructive: true),
      ),
    ],
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

void showAttachPopup(
  BuildContext context,
  AppColorScheme s, {
  required VoidCallback onFiles,
  required VoidCallback onPhotos,
  required VoidCallback onCamera,
  required VoidCallback onChooseModel,
  required ValueChanged<EditorType> onSelectTool,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: s.cardBackground,
    barrierColor: Colors.black.withOpacity(0.35),
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(_kFlatModalRadius)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SheetHandlebar(s: s),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _AttachOptionCardShared(
                    s: s,
                    assetName: 'folder_upload',
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
            const SizedBox(height: 10),
            _AttachSheetItem(
              s: s,
              iconAsset: 'sliders',
              label: 'Modelo',
              onTap: () {
                Navigator.pop(sheetContext);
                onChooseModel();
              },
            ),
          ],
        ),
      ),
    ),
  );
}

// Card quadrado, mesmo estilo visual do DrawerSquareAction do
// drawer (fundo s.cardBackground/s.hover, ícone + label centrados).
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

// Item de lista simples — usado só para a linha "Modelo" abaixo dos
// cards.
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